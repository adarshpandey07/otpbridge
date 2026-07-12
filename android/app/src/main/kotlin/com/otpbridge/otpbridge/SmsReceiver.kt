package com.otpbridge.otpbridge

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * KotlinNotes: Google Play restricts the RECEIVE_SMS / READ_SMS permissions to
 * apps that are the default SMS handler or fall under an approved exception
 * use-case (see the Play "SMS and Call Log" policy). Shipping this build to the
 * Play Store therefore requires a permissions declaration approval — that is a
 * publishing concern only; the technical layer below is standard Android.
 *
 * Receives android.provider.Telephony.SMS_RECEIVED broadcasts, reassembles
 * multipart messages into a single body and hands the result to
 * [SmsListenerService.dispatch], which forwards it to the Flutter EventChannel
 * sink (when one is attached).
 */
class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = try {
            Telephony.Sms.Intents.getMessagesFromIntent(intent)
        } catch (e: Exception) {
            null
        } ?: return
        if (messages.isEmpty()) return

        // A long SMS arrives as several PDUs from the same originating address,
        // in order — concatenate the bodies to rebuild the full message.
        val first = messages.firstOrNull() ?: return
        val sender = first.displayOriginatingAddress ?: first.originatingAddress ?: ""
        val body = messages.joinToString(separator = "") { it.messageBody ?: "" }
        val timestamp = first.timestampMillis

        SmsListenerService.dispatch(
            sender = sender,
            body = body,
            timestamp = timestamp,
            simSlot = extractSimSlot(intent),
        )
    }

    /** SIM slot index, or -1 when the platform did not attach one. */
    private fun extractSimSlot(intent: Intent): Int {
        val extras = intent.extras ?: return -1
        for (key in SLOT_KEYS) {
            if (extras.containsKey(key)) {
                val value = extras.getInt(key, -1)
                if (value >= 0) return value
            }
        }
        return -1
    }

    private companion object {
        /** OEMs attach the slot index under a variety of extra keys. */
        val SLOT_KEYS = arrayOf(
            "android.telephony.extra.SLOT_INDEX", // SubscriptionManager.EXTRA_SLOT_INDEX
            "slot",
            "simSlot",
            "slot_id",
            "simId",
        )
    }
}
