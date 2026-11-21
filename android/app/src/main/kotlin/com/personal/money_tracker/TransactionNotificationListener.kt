package com.personal.money_tracker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

class TransactionNotificationListener : NotificationListenerService() {

    companion object {
        private const val DETECTION_CHANNEL_ID = "smart_detection_alerts"
        private const val DETECTION_CHANNEL_NAME = "Detected Bank Alerts"
        private const val DETECTION_NOTIFICATION_ID = 27001

        private val OTP_OR_FAILURE_PATTERNS = listOf(
            Regex("\\b(otp|one[\\s-]?time\\s*password|verification\\s*code|security\\s*code|passcode|declined|rejected|failed|insufficient\\s*funds)\\b", RegexOption.IGNORE_CASE),
            Regex("(رمز\\s*التحقق|كود\\s*التحقق|كلمة\\s*المرور|الرقم\\s*السري|لا\\s*تشارك|تم\\s*رفض|مرفوض|رصيد\\s*غير\\s*كاف)")
        )

        private val TRANSACTION_KEYWORDS = listOf(
            // Arabic debit/credit/currency keywords
            "خصم", "سحب", "دفع", "سداد", "تحويل", "شراء", "معاملة", "عملية",
            "إضافة", "اضافة", "إيداع", "ايداع", "استلام", "حوالة", "رصيد", "مبلغ",
            "شبكة المدفوعات اللحظية", "جم", "ج.م", "جنيه", "ر.س", "ريال", "د.إ", "درهم", "بطاقة",
            // English debit/credit/currency keywords
            "debited", "deducted", "withdrawn", "withdrawal", "transfer", "transferred",
            "credited", "deposited", "purchase", "spent", "payment", "paid", "received",
            "sent", "used at", "was used", "ipn", "instapay", "card", "account",
            "egp", "sar", "aed", "usd", "eur", "gbp"
        )

        private val DIGIT_REGEX = Regex("[0-9٠-٩۰-۹]")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        if (sbn.packageName == packageName) return

        val notification = sbn.notification ?: return
        // Skip ongoing foreground service notifications (e.g. music player, timers)
        if ((notification.flags and Notification.FLAG_ONGOING_EVENT) != 0) return

        if (!SmartDetectionStorage.isEnabled(applicationContext)) return

        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val bodyText = extractBestBodyText(extras)

        if (bodyText.isEmpty()) return

        // Skip empty Android group summary shells unless they hold actual text lines/messages
        val isGroupSummary = (notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0
        if (isGroupSummary && !hasMessagingOrLinesExtras(extras)) return

        val combined = "$title $bodyText".trim()
        val pkg = sbn.packageName.orEmpty()

        if (OTP_OR_FAILURE_PATTERNS.any { it.containsMatchIn(combined) }) {
            SmartDetectionStorage.appendDiagnosticLog(
                context = applicationContext,
                packageName = pkg,
                preview = combined,
                status = "ignored_otp_or_failed",
                timestampMs = sbn.postTime
            )
            return
        }

        val looksFinancial = looksLikeFinancialAlert(combined)
        val sourceKind = SourceAppPolicy.classify(applicationContext, pkg)

        val rejection: String? = when {
            !looksFinancial -> "ignored_non_financial"
            sourceKind == SourceAppPolicy.SourceKind.OTHER -> "ignored_unwatched_app"
            sourceKind == SourceAppPolicy.SourceKind.SMS &&
                !SourceAppPolicy.passesStrictCheck(combined) -> "ignored_sms_not_bank"
            else -> null
        }

        if (rejection != null) {
            if (rejection == "ignored_unwatched_app") {
                // Let the user discover and opt in to their bank/wallet app.
                SmartDetectionStorage.recordSuggestedApp(
                    context = applicationContext,
                    packageName = pkg,
                    label = SourceAppPolicy.resolveAppLabel(applicationContext, pkg),
                    preview = combined,
                    timestampMs = sbn.postTime
                )
            }
            SmartDetectionStorage.appendDiagnosticLog(
                context = applicationContext,
                packageName = pkg,
                preview = combined,
                status = rejection,
                timestampMs = sbn.postTime
            )
            return
        }

        val alertMap = SmartDetectionStorage.enqueueAlert(
            context = applicationContext,
            packageName = pkg,
            title = title,
            text = bodyText,
            timestampMs = sbn.postTime,
            sourceKind = sourceKind.wireName
        )
        if (alertMap == null) {
            SmartDetectionStorage.appendDiagnosticLog(
                context = applicationContext,
                packageName = pkg,
                preview = combined,
                status = "ignored_duplicate",
                timestampMs = sbn.postTime
            )
            return
        }

        SmartDetectionStorage.appendDiagnosticLog(
            context = applicationContext,
            packageName = pkg,
            preview = combined,
            status = "queued",
            timestampMs = sbn.postTime
        )

        val deliveredLive = MainActivity.notifyLiveAlertIfActive(alertMap)
        if (!deliveredLive) {
            showReviewPromptNotification(title, bodyText)
        }
    }

    private fun hasMessagingOrLinesExtras(extras: Bundle): Boolean {
        val hasLines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.isNotEmpty() == true
        val hasMessages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)?.isNotEmpty() == true
        return hasLines || hasMessages
    }

    private fun extractBestBodyText(extras: Bundle): String {
        val candidates = mutableListOf<String>()

        extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim()?.let {
            if (it.isNotEmpty()) candidates.add(it)
        }
        extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim()?.let {
            if (it.isNotEmpty()) candidates.add(it)
        }

        // Google Messages / Samsung Messages often place the actual message text inside EXTRA_MESSAGES (MessagingStyle)
        @Suppress("DEPRECATION")
        val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
        if (messages != null && messages.isNotEmpty()) {
            val latestBundle = messages.lastOrNull() as? Bundle
            latestBundle?.getCharSequence("text")?.toString()?.trim()?.let {
                if (it.isNotEmpty()) candidates.add(it)
            }
        }

        // InboxStyle notifications store lines in EXTRA_TEXT_LINES
        val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
        if (lines != null && lines.isNotEmpty()) {
            lines.lastOrNull()?.toString()?.trim()?.let {
                if (it.isNotEmpty()) candidates.add(it)
            }
        }

        return candidates.maxByOrNull { it.length }.orEmpty()
    }

    private fun looksLikeFinancialAlert(text: String): Boolean {
        if (!DIGIT_REGEX.containsMatchIn(text)) return false
        val lower = text.lowercase()
        return TRANSACTION_KEYWORDS.any { keyword -> lower.contains(keyword) }
    }

    private fun showReviewPromptNotification(title: String, bodyText: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val hasPostPermission = ContextCompat.checkSelfPermission(
                applicationContext,
                android.Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!hasPostPermission) return
        }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                DETECTION_CHANNEL_ID,
                DETECTION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications when SpendWise detects a bank or wallet alert for review"
            }
            manager.createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        } ?: return

        val pendingIntent = PendingIntent.getActivity(
            applicationContext,
            DETECTION_NOTIFICATION_ID,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val isArabicText = bodyText.any { it in '\u0600'..'\u06FF' }
        val notifTitle = if (isArabicText) {
            "سبيند وايز • تم رصد معاملة مالية"
        } else {
            "SpendWise • Transaction Detected"
        }
        val preview = if (title.isNotEmpty() && !bodyText.contains(title)) {
            "$title: $bodyText"
        } else {
            bodyText
        }

        val notif = NotificationCompat.Builder(applicationContext, DETECTION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(notifTitle)
            .setContentText(preview)
            .setStyle(NotificationCompat.BigTextStyle().bigText(preview))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        try {
            NotificationManagerCompat.from(applicationContext).notify(DETECTION_NOTIFICATION_ID, notif)
        } catch (_: SecurityException) {
            // Permission revoked mid-flight
        }
    }
}
