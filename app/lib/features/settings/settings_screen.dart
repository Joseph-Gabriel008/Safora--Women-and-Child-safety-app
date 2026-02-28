import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_settings.dart';
import '../../services/emergency_engine.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _guardianController;
  late final TextEditingController _trustedContactsController;
  late final TextEditingController _codeWordController;
  late final TextEditingController _emergencyNumberController;

  bool _initializedFromSettings = false;

  @override
  void initState() {
    super.initState();
    _guardianController = TextEditingController();
    _trustedContactsController = TextEditingController();
    _codeWordController = TextEditingController();
    _emergencyNumberController = TextEditingController();
  }

  @override
  void dispose() {
    _guardianController.dispose();
    _trustedContactsController.dispose();
    _codeWordController.dispose();
    _emergencyNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EmergencyEngine>(
      builder: (context, engine, _) {
        if (!_initializedFromSettings) {
          _guardianController.text = engine.settings.guardianPhone;
          _trustedContactsController.text = engine.settings.trustedContacts.join(', ');
          _codeWordController.text = engine.settings.codeWordMessage;
          _emergencyNumberController.text = engine.settings.emergencyNumber;
          _initializedFromSettings = true;
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Guardian Contact', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _guardianController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Primary Guardian Number',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        onChanged: engine.updateGuardianPhone,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _trustedContactsController,
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          labelText: 'Trusted Contacts (comma separated)',
                          prefixIcon: Icon(Icons.group),
                        ),
                        onChanged: engine.updateTrustedContactsFromCsv,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Stealth Messaging', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Code Word Messaging'),
                        value: engine.settings.codeWordEnabled,
                        onChanged: engine.updateCodeWordEnabled,
                      ),
                      TextField(
                        controller: _codeWordController,
                        decoration: const InputDecoration(
                          labelText: 'Safe Code Word Message',
                          hintText: 'I forgot my charger',
                          prefixIcon: Icon(Icons.message),
                        ),
                        onChanged: engine.updateCodeWordMessage,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _emergencyNumberController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Emergency Number',
                          prefixIcon: Icon(Icons.local_hospital),
                        ),
                        onChanged: engine.updateEmergencyNumber,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mode', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      SegmentedButton<UserMode>(
                        segments: const [
                          ButtonSegment<UserMode>(
                            value: UserMode.women,
                            label: Text('Women Mode'),
                            icon: Icon(Icons.shield),
                          ),
                          ButtonSegment<UserMode>(
                            value: UserMode.child,
                            label: Text('Child Mode'),
                            icon: Icon(Icons.child_care),
                          ),
                        ],
                        selected: <UserMode>{engine.settings.mode},
                        onSelectionChanged: (selection) {
                          engine.updateMode(selection.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Sync queued notifications now'),
                  subtitle: const Text('Attempts to deliver pending guardian alerts.'),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      await engine.flushQueuedMessages();
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sync attempt completed.')),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
