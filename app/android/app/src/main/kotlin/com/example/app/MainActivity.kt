package com.example.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : FlutterActivity() {
    private val smsChannelName = "safora/sms"
    private val systemChannelName = "safora/system"
    private val smsPermissionRequestCode = 4101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, smsChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "sendSms") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val phone = call.argument<String>("phone")
                val message = call.argument<String>("message")

                if (phone.isNullOrBlank() || message.isNullOrBlank()) {
                    result.success(false)
                    return@setMethodCallHandler
                }

                val permissionGranted = ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.SEND_SMS
                ) == PackageManager.PERMISSION_GRANTED

                if (!permissionGranted) {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.SEND_SMS),
                        smsPermissionRequestCode
                    )
                    result.success(false)
                    return@setMethodCallHandler
                }

                try {
                    val manager = SmsManager.getDefault()
                    val parts = manager.divideMessage(message)
                    manager.sendMultipartTextMessage(phone, null, parts, null, null)
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, systemChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForegroundStealth" -> {
                        val intent = Intent(this, ForegroundStealthService::class.java)
                        ContextCompat.startForegroundService(this, intent)
                        result.success(null)
                    }
                    "stopForegroundStealth" -> {
                        val intent = Intent(this, ForegroundStealthService::class.java)
                        stopService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
