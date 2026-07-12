package com.otpbridge.otpbridge

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capabilities" -> result.success(
                        mapOf(
                            "canReadSms" to true,
                            "canSendSms" to true,
                            "canRunBackgroundService" to true,
                        ),
                    )

                    // Runtime permission prompts are driven from Dart via the
                    // permission_handler plugin; these two just report state.
                    "hasPermissions" -> result.success(hasSmsPermissions())
                    "requestPermissions" -> result.success(hasSmsPermissions())

                    "startListening" -> {
                        SmsListenerService.start(this)
                        result.success(true)
                    }

                    "stopListening" -> {
                        SmsListenerService.stop(this)
                        result.success(true)
                    }

                    "isListening" -> result.success(SmsListenerService.isRunning)

                    "readInbox" -> {
                        val limit = call.argument<Int>("limit") ?: 500
                        readInbox(limit, result)
                    }

                    "sendSms" -> {
                        val to = call.argument<String>("to")
                        val body = call.argument<String>("body")
                        if (to.isNullOrBlank() || body.isNullOrEmpty()) {
                            result.error(
                                "bad_args",
                                "Both 'to' and 'body' are required",
                                null,
                            )
                        } else {
                            sendSms(to, body, result)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    SmsListenerService.setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    SmsListenerService.setEventSink(null)
                }
            })
    }

    private fun hasSmsPermissions(): Boolean {
        val required = arrayOf(
            Manifest.permission.RECEIVE_SMS,
            Manifest.permission.READ_SMS,
            Manifest.permission.SEND_SMS,
        )
        return required.all {
            checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
        }
    }

    /// Queries the SMS inbox (content://sms/inbox) for the most recent
    /// [limit] messages. Requires READ_SMS; returns an empty list if the
    /// permission is missing so the caller degrades gracefully.
    private fun readInbox(limit: Int, result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.READ_SMS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }
        try {
            val messages = ArrayList<Map<String, Any?>>()
            val projection = arrayOf("address", "body", "date")
            val uri = android.net.Uri.parse("content://sms/inbox")
            contentResolver.query(
                uri, projection, null, null, "date DESC",
            )?.use { cursor ->
                val addressIdx = cursor.getColumnIndex("address")
                val bodyIdx = cursor.getColumnIndex("body")
                val dateIdx = cursor.getColumnIndex("date")
                var count = 0
                while (cursor.moveToNext() && count < limit) {
                    messages.add(
                        mapOf(
                            "sender" to (if (addressIdx >= 0) cursor.getString(addressIdx) else null),
                            "body" to (if (bodyIdx >= 0) cursor.getString(bodyIdx) else null),
                            "timestamp" to (if (dateIdx >= 0) cursor.getLong(dateIdx) else 0L),
                        ),
                    )
                    count++
                }
            }
            result.success(messages)
        } catch (e: Exception) {
            result.error("read_inbox_failed", e.message ?: "Could not read SMS inbox", null)
        }
    }

    private fun sendSms(to: String, body: String, result: MethodChannel.Result) {
        try {
            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            if (smsManager == null) {
                result.error("send_failed", "SmsManager is unavailable on this device", null)
                return
            }
            val parts = smsManager.divideMessage(body)
            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(to, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(to, null, body, null, null)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("send_failed", e.message ?: "Unknown error while sending SMS", null)
        }
    }

    private companion object {
        const val METHOD_CHANNEL = "com.otpbridge/sms"
        const val EVENT_CHANNEL = "com.otpbridge/sms_incoming"
    }
}
