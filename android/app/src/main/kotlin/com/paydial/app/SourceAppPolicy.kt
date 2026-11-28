package com.paydial.app

import android.content.Context
import android.provider.Telephony

/**
 * Decides whether notifications from a given app may be read as transactions.
 *
 * Generic by design (no bank-specific package list):
 * - [SourceKind.WATCHED]: apps the user explicitly approved (e.g. their bank or
 *   wallet app). Read with the normal keyword filter.
 * - [SourceKind.SMS]: the device's default SMS app and well-known messaging
 *   apps. They also carry personal texts, so they must pass [passesStrictCheck].
 * - [SourceKind.OTHER]: everything else (chat, email, shopping, news...).
 *   Never queued; financial-looking ones are only recorded as suggestions.
 *
 * Keep [passesStrictCheck] in sync with `BankMessageParser.parse(strict: true)`.
 */
object SourceAppPolicy {

    enum class SourceKind(val wireName: String) {
        WATCHED("watched"),
        SMS("sms"),
        OTHER("other"),
    }

    private val KNOWN_SMS_PACKAGES = setOf(
        "com.google.android.apps.messaging", // Google Messages
        "com.samsung.android.messaging",     // Samsung Messages
        "com.android.mms",                   // AOSP / many OEM builds
        "com.android.messaging",             // AOSP Messaging
    )

    private val CURRENCY_ANCHORED_AMOUNT = listOf(
        Regex(
            // Letter codes must not start inside a word ("LE" in "SALE 50").
            "(?:(?<![A-Za-z])(?:EGP|SAR|AED|USD|EUR|GBP|LE|L\\.E\\.)|\\$|€|£)\\s*[0-9]",
            RegexOption.IGNORE_CASE
        ),
        Regex(
            "[0-9][0-9,]*(?:\\.[0-9]{1,2})?\\s*(?:EGP|SAR|AED|USD|EUR|GBP|LE|L\\.E\\.|ج\\.م|جم|جنيه(?:ات)?|ر\\.س|ريال|د\\.إ|درهم|\\$|€|£)(?![A-Za-z\\u0600-\\u06FF])",
            RegexOption.IGNORE_CASE
        ),
    )

    private val INSTRUMENT_MARKERS = listOf(
        Regex(
            "(?<![A-Za-z])(?:card|account|a/c|acct|ref(?:erence)?|balance|avl|bal|ipn|instapay|wallet|pos|atm)(?![A-Za-z])",
            RegexOption.IGNORE_CASE
        ),
        Regex("(بطاق|حساب|مرجع|رصيد|محفظ|شبكة\\s*المدفوعات\\s*اللحظية|(?:إ|ا)نستا\\s*باي)"),
    )

    fun classify(context: Context, packageName: String): SourceKind {
        if (SmartDetectionStorage.isWatchedApp(context, packageName)) return SourceKind.WATCHED
        if (packageName in KNOWN_SMS_PACKAGES) return SourceKind.SMS
        val defaultSms = try {
            Telephony.Sms.getDefaultSmsPackage(context)
        } catch (_: Exception) {
            null
        }
        if (defaultSms != null && defaultSms == packageName) return SourceKind.SMS
        return SourceKind.OTHER
    }

    /** True when [text] carries a currency-tied amount and an account/instrument marker. */
    fun passesStrictCheck(text: String): Boolean {
        val normalized = normalizeDigits(text)
        return CURRENCY_ANCHORED_AMOUNT.any { it.containsMatchIn(normalized) } &&
            INSTRUMENT_MARKERS.any { it.containsMatchIn(normalized) }
    }

    fun resolveAppLabel(context: Context, packageName: String): String {
        return try {
            val pm = context.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
        } catch (_: Exception) {
            packageName
        }
    }

    private fun normalizeDigits(input: String): String {
        val sb = StringBuilder(input.length)
        for (ch in input) {
            sb.append(
                when (ch) {
                    in '٠'..'٩' -> '0' + (ch - '٠')
                    in '۰'..'۹' -> '0' + (ch - '۰')
                    else -> ch
                }
            )
        }
        return sb.toString()
    }
}
