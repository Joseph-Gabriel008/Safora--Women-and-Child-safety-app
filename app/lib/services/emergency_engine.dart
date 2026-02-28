import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:torch_light/torch_light.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

import '../models/app_settings.dart';
import '../models/emergency_level.dart';
import '../models/emergency_log.dart';
import '../models/guide_models.dart';
import '../models/queued_guardian_message.dart';
import '../storage/hive_storage.dart';
import 'code_word_message_builder.dart';
import 'foreground_execution_service.dart';
import 'location_service.dart';
import 'sms_dispatcher_service.dart';

enum EmergencyTrigger { sosButton, voice, panicTap, stealthPattern, childMode }

class EmergencyEngine extends ChangeNotifier {
  EmergencyEngine(
    this._storage, {
    LocationService? locationService,
    SmsDispatcherService? smsDispatcher,
    CodeWordMessageBuilder? codeWordMessageBuilder,
    ForegroundExecutionService? foregroundExecutionService,
  })  : _locationService = locationService ?? LocationService(_storage),
        _smsDispatcher = smsDispatcher ?? SmsDispatcherService(),
        _codeWordBuilder = codeWordMessageBuilder ?? CodeWordMessageBuilder(),
        _foregroundExecutionService =
            foregroundExecutionService ?? ForegroundExecutionService(),
        _escalationHandler = _EscalationHandler();

  final HiveStorage _storage;
  final LocationService _locationService;
  final SmsDispatcherService _smsDispatcher;
  final CodeWordMessageBuilder _codeWordBuilder;
  final ForegroundExecutionService _foregroundExecutionService;
  final _EscalationHandler _escalationHandler;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioRecorder _evidenceRecorder = AudioRecorder();

  AppSettings _settings = AppSettings();
  bool _isEmergencyActive = false;
  bool _isListeningForVoiceTrigger = false;
  bool _isTriggerInProgress = false;
  bool _strobeEnabled = false;
  bool _strobeBusy = false;
  bool _highPriorityMode = false;

  EmergencyLevel? _currentStealthLevel;
  String? _stealthSessionId;
  String? _evidenceManifestPath;
  bool _evidenceCollectionRunning = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _strobeTimer;
  Timer? _repeatSmsTimer;
  Timer? _safetyCheckTimer;

  final StreamController<int> _safetyCheckController =
      StreamController<int>.broadcast();
  final Map<int, Completer<bool>> _pendingSafetyChecks = <int, Completer<bool>>{};
  int _safetyCheckCounter = 0;

  bool get isEmergencyActive => _isEmergencyActive;
  bool get isListeningForVoiceTrigger => _isListeningForVoiceTrigger;
  bool get isHighPriorityMode => _highPriorityMode;
  AppSettings get settings => _settings;
  bool get hasSafeZone =>
      _settings.safeZoneLatitude != null && _settings.safeZoneLongitude != null;
  EmergencyLevel? get currentStealthLevel => _currentStealthLevel;
  Stream<int> get safetyCheckRequests => _safetyCheckController.stream;

  Future<void> initialize() async {
    _settings = _storage.getSettings();
    await flushQueuedMessages();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) {
        flushQueuedMessages();
        _flushMovementHistory();
      }
    });
  }

  Future<void> disposeEngine() async {
    await _connectivitySub?.cancel();
    await endStealthSession();
    _strobeTimer?.cancel();
    _safetyCheckTimer?.cancel();
    _repeatSmsTimer?.cancel();
    await _recorder.dispose();
    await _evidenceRecorder.dispose();
    await _safetyCheckController.close();
  }

  Future<void> updateMode(UserMode mode) async {
    _settings = _settings.copyWith(mode: mode);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateGuardianPhone(String phone) async {
    _settings = _settings.copyWith(guardianPhone: phone.trim());
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateTrustedContactsFromCsv(String csv) async {
    final contacts = csv
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    _settings = _settings.copyWith(trustedContacts: contacts);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateEmergencyReadyMode(bool enabled) async {
    _settings = _settings.copyWith(emergencyReadyMode: enabled);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateCodeWordEnabled(bool enabled) async {
    _settings = _settings.copyWith(codeWordEnabled: enabled);
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateCodeWordMessage(String message) async {
    _settings = _settings.copyWith(codeWordMessage: message.trim());
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateEmergencyNumber(String value) async {
    _settings = _settings.copyWith(emergencyNumber: value.trim().isEmpty ? '112' : value.trim());
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateSafeZone({
    required double latitude,
    required double longitude,
  }) async {
    _settings = _settings.copyWith(
      safeZoneLatitude: latitude,
      safeZoneLongitude: longitude,
    );
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> clearSafeZone() async {
    _settings = _settings.copyWith(
      safeZoneLatitude: null,
      safeZoneLongitude: null,
    );
    await _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> enableEmergencyReadyFromRisk() async {
    if (!_settings.emergencyReadyMode) {
      _settings = _settings.copyWith(emergencyReadyMode: true);
      await _storage.saveSettings(_settings);
    }
    notifyListeners();
  }

  Future<void> startPassiveLocationLogging() async {
    await _locationService.startTracking(EmergencyLevel.level1);
  }

  Future<bool> executeGuideQuickAction(QuickActionType action) async {
    switch (action) {
      case QuickActionType.activateStealth:
        await activateStealthLevel(
          level: EmergencyLevel.level1,
          delayedTriggerUsed: false,
          triggerSource: 'guide_quick_action',
        );
        return true;
      case QuickActionType.startSilentRecording:
        final path = await _startSilentEvidenceCollection();
        return path != null;
      case QuickActionType.flashlightOn:
        try {
          await TorchLight.enableTorch();
          return true;
        } catch (_) {
          return false;
        }
      case QuickActionType.fakeCall:
        await _storage.saveLog(
          EmergencyLog(
            id: _generateId(),
            type: 'guide_action',
            trigger: 'fake_call',
            timestamp: DateTime.now(),
            notes: 'Fake call quick action executed.',
          ),
        );
        return true;
      case QuickActionType.triggerSOS:
        await triggerEmergency(
          trigger: EmergencyTrigger.sosButton,
          customNote: 'Triggered from guide quick action',
        );
        return true;
    }
  }

  void setVoiceListening(bool listening) {
    _isListeningForVoiceTrigger = listening;
    notifyListeners();
  }

  Future<void> triggerEmergency({
    required EmergencyTrigger trigger,
    bool stealth = false,
    String? customNote,
  }) async {
    if (_isTriggerInProgress) {
      return;
    }

    _isTriggerInProgress = true;
    _isEmergencyActive = true;
    notifyListeners();

    try {
      if (stealth) {
        await _startSilentAlert();
      } else {
        await _startLoudAlert();
      }

      final locationFuture = _tryGetLocation().timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );
      final recordingFuture = _captureRecordingWithDuration(
        duration: const Duration(seconds: 10),
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () => null,
      );

      final position = await locationFuture;
      final audioPath = await recordingFuture;

      final log = EmergencyLog(
        id: _generateId(),
        type: stealth ? 'stealth' : 'standard',
        trigger: trigger.name,
        timestamp: DateTime.now(),
        latitude: position?.latitude,
        longitude: position?.longitude,
        audioPath: audioPath,
        notes: customNote,
      );

      await _storage.saveLog(log);
      await _queueMessageForContacts(
        recipients: _allContacts(),
        emergencyLevel: EmergencyLevel.level1,
        position: position,
      );
      await flushQueuedMessages();
    } finally {
      _isEmergencyActive = false;
      _isTriggerInProgress = false;
      notifyListeners();
    }
  }

  Future<void> activateStealthLevel({
    required EmergencyLevel level,
    required bool delayedTriggerUsed,
    String triggerSource = 'stealth_pin',
  }) async {
    if (_isTriggerInProgress) {
      return;
    }

    final current = _currentStealthLevel;
    if (current != null && level.stage <= current.stage) {
      return;
    }

    _isTriggerInProgress = true;
    _isEmergencyActive = true;
    notifyListeners();

    try {
      _stealthSessionId ??= _generateId();
      _currentStealthLevel = level;
      _highPriorityMode = level == EmergencyLevel.level3;
      await _foregroundExecutionService.startStealthService();

      final position = await _tryGetLocation();
      final encryptedRecordingPath = await _startSilentEvidenceCollection();

      if (level.stage >= EmergencyLevel.level2.stage) {
        await _locationService.startTracking(level);
      }

      final movementHistoryPath = await _locationService.persistMovementHistory();
      final log = EmergencyLog(
        id: _generateId(),
        type: 'stealth',
        trigger: triggerSource,
        timestamp: DateTime.now(),
        latitude: position?.latitude,
        longitude: position?.longitude,
        emergencyLevel: level,
        escalationStage: level.stage,
        movementHistoryPath: movementHistoryPath,
        encryptedRecordingPath: encryptedRecordingPath,
        codeWordUsed: _settings.codeWordEnabled,
        delayedTriggerUsed: delayedTriggerUsed,
      );

      await _storage.saveLog(log);
      await _escalationHandler.handle(
        engine: this,
        level: level,
        position: position,
      );

      _startSafetyConfirmationChecks();
      await flushQueuedMessages();
      await _flushMovementHistory();
    } finally {
      _isEmergencyActive = false;
      _isTriggerInProgress = false;
      notifyListeners();
    }
  }

  Future<void> endStealthSession() async {
    _repeatSmsTimer?.cancel();
    _safetyCheckTimer?.cancel();
    _pendingSafetyChecks.clear();
    _currentStealthLevel = null;
    _stealthSessionId = null;
    _highPriorityMode = false;
    await _locationService.stopTracking();
    await _foregroundExecutionService.stopStealthService();
    notifyListeners();
  }

  Future<void> respondSafetyCheck(int requestId, bool isSafe) async {
    final pending = _pendingSafetyChecks.remove(requestId);
    if (pending != null && !pending.isCompleted) {
      pending.complete(isSafe);
    }
  }

  List<EmergencyLog> getLogs() => _storage.getLogs();

  Future<void> flushQueuedMessages() async {
    final pending = _storage.getQueuedMessages();
    if (pending.isEmpty) {
      return;
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      return;
    }

    for (final message in pending) {
      try {
        final isSent = await _smsDispatcher.send(
          phone: message.phone,
          message: message.message,
        );
        if (isSent) {
          await _storage.markMessageSent(message.id);
        }
      } catch (_) {
        // Leave queued.
      }
    }
  }

  Future<void> stopAlerts() async {
    _strobeTimer?.cancel();
    _strobeEnabled = false;
    _strobeBusy = false;
    try {
      await TorchLight.disableTorch();
    } catch (_) {}
    Vibration.cancel();
    FlutterRingtonePlayer().stop();
  }

  Future<void> _startLoudAlert() async {
    FlutterRingtonePlayer().playAlarm(looping: true, volume: 1, asAlarm: true);
    _startStrobe();
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 350, 200, 350]);
    }
  }

  Future<void> _startSilentAlert() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 180, 120, 180]);
      await Future<void>.delayed(const Duration(seconds: 2));
      Vibration.cancel();
    }
  }

  void _startStrobe() {
    _strobeTimer?.cancel();
    _strobeEnabled = false;
    _strobeBusy = false;
    _strobeTimer = Timer.periodic(const Duration(milliseconds: 450), (_) async {
      if (_strobeBusy) {
        return;
      }
      _strobeBusy = true;
      try {
        if (_strobeEnabled) {
          await TorchLight.disableTorch();
        } else {
          await TorchLight.enableTorch();
        }
        _strobeEnabled = !_strobeEnabled;
      } catch (_) {
        _strobeTimer?.cancel();
      } finally {
        _strobeBusy = false;
      }
    });

    Timer(const Duration(seconds: 8), () async {
      _strobeTimer?.cancel();
      _strobeEnabled = false;
      try {
        await TorchLight.disableTorch();
      } catch (_) {}
      FlutterRingtonePlayer().stop();
    });
  }

  Future<Position?> _tryGetLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _captureRecordingWithDuration({
    required Duration duration,
  }) async {
    try {
      if (!await _recorder.hasPermission()) {
        return null;
      }

      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/${_generateId()}.m4a';
      await _recorder.start(const RecordConfig(), path: path);

      await Future<void>.delayed(duration);
      final recordedPath = await _recorder.stop();
      return recordedPath;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _startSilentEvidenceCollection() async {
    if (_evidenceCollectionRunning && _evidenceManifestPath != null) {
      return _evidenceManifestPath;
    }

    try {
      if (!await _evidenceRecorder.hasPermission()) {
        return null;
      }

      final sessionId = _stealthSessionId ?? _generateId();
      final dir = await getApplicationDocumentsDirectory();
      final evidenceDir = Directory('${dir.path}/stealth_evidence/$sessionId');
      if (!await evidenceDir.exists()) {
        await evidenceDir.create(recursive: true);
      }

      final manifestPath = '${evidenceDir.path}/manifest.json';
      await File(manifestPath).writeAsString('[]');
      _evidenceManifestPath = manifestPath;
      _evidenceCollectionRunning = true;

      unawaited(_collectEncryptedSegments(
        sessionId: sessionId,
        manifestPath: manifestPath,
        segmentDuration: const Duration(minutes: 2),
        maxSegments: 9,
      ));

      return manifestPath;
    } catch (_) {
      return null;
    }
  }

  Future<void> _collectEncryptedSegments({
    required String sessionId,
    required String manifestPath,
    required Duration segmentDuration,
    required int maxSegments,
  }) async {
    final key = _buildEncryptionKey(sessionId);
    final manifest = File(manifestPath);

    for (var i = 0; i < maxSegments; i++) {
      if (_stealthSessionId != sessionId) {
        break;
      }

      final rawPath = '${manifest.parent.path}/segment_$i.m4a';
      String? rawRecordedPath;
      try {
        await _evidenceRecorder.start(const RecordConfig(), path: rawPath);
        await Future<void>.delayed(segmentDuration);
        rawRecordedPath = await _evidenceRecorder.stop();
      } catch (_) {
        try {
          await _evidenceRecorder.stop();
        } catch (_) {}
        continue;
      }

      if (rawRecordedPath == null) {
        continue;
      }

      try {
        final encryptedPath = await _encryptEvidenceFile(
          filePath: rawRecordedPath,
          key: key,
          index: i,
        );
        await _appendManifestSegment(manifest, encryptedPath);
        await File(rawRecordedPath).delete();
      } catch (_) {}
    }

    _evidenceCollectionRunning = false;
  }

  Future<String> _encryptEvidenceFile({
    required String filePath,
    required encrypt.Key key,
    required int index,
  }) async {
    final inputFile = File(filePath);
    final bytes = await inputFile.readAsBytes();

    final iv = encrypt.IV.fromSecureRandom(16);
    final engine = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encryptedBytes = engine.encryptBytes(bytes, iv: iv).bytes;

    final outBytes = Uint8List.fromList(<int>[...iv.bytes, ...encryptedBytes]);
    final outputPath = '${inputFile.parent.path}/segment_$index.aes';
    await File(outputPath).writeAsBytes(outBytes, flush: true);
    return outputPath;
  }

  Future<void> _appendManifestSegment(File manifest, String encryptedPath) async {
    List<dynamic> current = <dynamic>[];
    try {
      current = jsonDecode(await manifest.readAsString()) as List<dynamic>;
    } catch (_) {}

    current.add(encryptedPath);
    await manifest.writeAsString(jsonEncode(current));
  }

  encrypt.Key _buildEncryptionKey(String sessionId) {
    final digest = sha256.convert(utf8.encode('safora-stealth-$sessionId-key'));
    return encrypt.Key(Uint8List.fromList(digest.bytes));
  }

  Future<void> _queueMessageForContacts({
    required List<String> recipients,
    required EmergencyLevel emergencyLevel,
    required Position? position,
  }) async {
    final fallback = _buildFallbackEmergencyMessage(
      position: position,
      level: emergencyLevel,
    );

    final message = _codeWordBuilder.build(
      settings: _settings,
      level: emergencyLevel,
      fallbackMessage: fallback,
    );

    for (final recipient in recipients.toSet()) {
      if (recipient.trim().isEmpty) {
        continue;
      }
      final queued = QueuedGuardianMessage(
        id: _generateId(),
        phone: recipient,
        message: message,
        createdAt: DateTime.now(),
      );
      await _storage.enqueueGuardianMessage(queued);
    }
  }

  String _buildFallbackEmergencyMessage({
    required Position? position,
    required EmergencyLevel level,
  }) {
    final lat = position?.latitude.toStringAsFixed(5) ?? 'unknown';
    final lng = position?.longitude.toStringAsFixed(5) ?? 'unknown';

    return 'Safora silent alert L${level.stage}. Location: $lat,$lng';
  }

  Future<void> _queueRepeatedMessages({
    required List<String> recipients,
    required EmergencyLevel level,
    required Position? position,
  }) async {
    _repeatSmsTimer?.cancel();
    var sentCount = 0;

    _repeatSmsTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (sentCount >= 3 || _currentStealthLevel == null) {
        timer.cancel();
        return;
      }

      sentCount += 1;
      await _queueMessageForContacts(
        recipients: recipients,
        emergencyLevel: level,
        position: position,
      );
      await flushQueuedMessages();
    });
  }

  Future<void> _triggerEmergencyCall() async {
    final emergencyNumber = _settings.emergencyNumber.trim().isEmpty
        ? '112'
        : _settings.emergencyNumber.trim();
    final uri = Uri.parse('tel:$emergencyNumber');

    try {
      await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
    } catch (_) {}
  }

  void _startSafetyConfirmationChecks() {
    _safetyCheckTimer?.cancel();
    _safetyCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final currentLevel = _currentStealthLevel;
      if (currentLevel == null) {
        return;
      }

      final isSafe = await _requestSafetyConfirmation();
      if (!isSafe) {
        final nextLevel = currentLevel.next();
        if (nextLevel.stage > currentLevel.stage) {
          await activateStealthLevel(
            level: nextLevel,
            delayedTriggerUsed: false,
            triggerSource: 'safety_check_timeout',
          );
        }
      }
    });
  }

  Future<bool> _requestSafetyConfirmation() async {
    final requestId = ++_safetyCheckCounter;
    final completer = Completer<bool>();
    _pendingSafetyChecks[requestId] = completer;
    _safetyCheckController.add(requestId);

    Timer(const Duration(seconds: 15), () {
      final pending = _pendingSafetyChecks.remove(requestId);
      if (pending != null && !pending.isCompleted) {
        pending.complete(false);
      }
    });

    return completer.future;
  }

  Future<void> _flushMovementHistory() async {
    final contacts = _allContacts();
    if (contacts.isEmpty) {
      return;
    }

    final prefix = _codeWordBuilder.build(
      settings: _settings,
      level: _currentStealthLevel ?? EmergencyLevel.level1,
      fallbackMessage: 'Safora route history update.',
    );

    await _locationService.flushHistoryIfNetworkAvailable(
      recipients: contacts,
      smsDispatcher: _smsDispatcher,
      messagePrefix: prefix,
    );
  }

  List<String> _allContacts() {
    return <String>{
      if (_settings.guardianPhone.trim().isNotEmpty) _settings.guardianPhone.trim(),
      ..._settings.trustedContacts.map((value) => value.trim()).where((value) => value.isNotEmpty),
    }.toList();
  }

  List<String> _level2Contacts() {
    final trusted = _settings.trustedContacts
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (trusted.length >= 3) {
      return trusted.take(3).toList();
    }

    final merged = <String>{...trusted};
    if (_settings.guardianPhone.trim().isNotEmpty) {
      merged.add(_settings.guardianPhone.trim());
    }

    return merged.take(3).toList();
  }

  List<String> _level1Contacts() {
    if (_settings.guardianPhone.trim().isEmpty) {
      return const <String>[];
    }
    return <String>[_settings.guardianPhone.trim()];
  }

  String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();
}

class _EscalationHandler {
  Future<void> handle({
    required EmergencyEngine engine,
    required EmergencyLevel level,
    required Position? position,
  }) async {
    switch (level) {
      case EmergencyLevel.level1:
        await engine._queueMessageForContacts(
          recipients: engine._level1Contacts(),
          emergencyLevel: level,
          position: position,
        );
        break;
      case EmergencyLevel.level2:
        await engine._locationService.startTracking(level);
        await engine._queueMessageForContacts(
          recipients: engine._level2Contacts(),
          emergencyLevel: level,
          position: position,
        );
        await engine._queueRepeatedMessages(
          recipients: engine._level2Contacts(),
          level: level,
          position: position,
        );
        break;
      case EmergencyLevel.level3:
        await engine._locationService.startTracking(level);
        await engine._queueMessageForContacts(
          recipients: engine._allContacts(),
          emergencyLevel: level,
          position: position,
        );
        await engine._triggerEmergencyCall();
        break;
    }
  }
}
