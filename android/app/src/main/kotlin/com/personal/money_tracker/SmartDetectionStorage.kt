package com.personal.money_tracker

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

object SmartDetectionStorage {
    private const val PREFS_NAME = "spendwise_smart_detection"
    private const val KEY_ENABLED = "smart_detection_enabled"
    private const val KEY_PENDING_ALERTS = "pending_native_alerts"
    private const val KEY_SHARED_TEXT = "pending_shared_text"
    private const val KEY_LAST_SIGNATURE = "last_alert_signature"
    private const val KEY_LAST_SIGNATURE_TS = "last_alert_signature_ts"
    private const val KEY_DIAGNOSTIC_LOGS = "detection_diagnostic_logs"
    private const val MAX_QUEUED_ALERTS = 50
    private const val MAX_DIAGNOSTIC_LOGS = 15
    private const val SHORT_DEDUP_WINDOW_MS = 30_000L

    private val lock = Any()

    fun isEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_ENABLED, false)
    }

    fun setEnabled(context: Context, enabled: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    fun saveSharedText(context: Context, text: String) {
        synchronized(lock) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_SHARED_TEXT, text).apply()
        }
    }

    fun consumeSharedText(context: Context): String? {
        synchronized(lock) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val text = prefs.getString(KEY_SHARED_TEXT, null)
            if (text != null) {
                prefs.edit().remove(KEY_SHARED_TEXT).apply()
            }
            return text
        }
    }

    fun appendDiagnosticLog(
        context: Context,
        packageName: String,
        preview: String,
        status: String,
        timestampMs: Long
    ) {
        synchronized(lock) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_DIAGNOSTIC_LOGS, "[]") ?: "[]"
            val array = try {
                JSONArray(raw)
            } catch (_: Exception) {
                JSONArray()
            }

            val obj = JSONObject().apply {
                put("packageName", packageName)
                put("preview", preview.take(160))
                put("status", status)
                put("timestampMs", timestampMs)
            }

            val updated = JSONArray()
            updated.put(obj)
            for (i in 0 until minOf(array.length(), MAX_DIAGNOSTIC_LOGS - 1)) {
                updated.put(array.get(i))
            }

            prefs.edit().putString(KEY_DIAGNOSTIC_LOGS, updated.toString()).apply()
        }
    }

    fun getDiagnosticLogs(context: Context): List<Map<String, Any>> {
        synchronized(lock) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_DIAGNOSTIC_LOGS, "[]") ?: "[]"
            val result = mutableListOf<Map<String, Any>>()
            try {
                val array = JSONArray(raw)
                for (i in 0 until array.length()) {
                    val obj = array.optJSONObject(i) ?: continue
                    result.add(
                        mapOf(
                            "packageName" to obj.optString("packageName", ""),
                            "preview" to obj.optString("preview", ""),
                            "status" to obj.optString("status", ""),
                            "timestampMs" to obj.optLong("timestampMs", 0L)
                        )
                    )
                }
            } catch (_: Exception) {
                // Ignore malformed JSON
            }
            return result
        }
    }

    fun clearDiagnosticLogs(context: Context) {
        synchronized(lock) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().remove(KEY_DIAGNOSTIC_LOGS).apply()
        }
    }

    /**
     * Queues a candidate alert if it is not an immediate duplicate (within 30s)
     * and returns the serialized map when newly added, or null if skipped.
     */
    fun enqueueAlert(
        context: Context,
        packageName: String,
        title: String,
        text: String,
        timestampMs: Long
    ): Map<String, Any>? {
        synchronized(lock) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val signature = "${title.trim()}|${text.trim()}"
            val lastSig = prefs.getString(KEY_LAST_SIGNATURE, null)
            val lastTs = prefs.getLong(KEY_LAST_SIGNATURE_TS, 0L)

            if (signature == lastSig && (timestampMs - lastTs) < SHORT_DEDUP_WINDOW_MS) {
                return null
            }

            val existingRaw = prefs.getString(KEY_PENDING_ALERTS, "[]") ?: "[]"
            val array = try {
                JSONArray(existingRaw)
            } catch (_: Exception) {
                JSONArray()
            }

            val id = UUID.randomUUID().toString()
            val obj = JSONObject().apply {
                put("id", id)
                put("packageName", packageName)
                put("title", title)
                put("text", text)
                put("timestampMs", timestampMs)
            }

            val updated = JSONArray()
            updated.put(obj)
            for (i in 0 until minOf(array.length(), MAX_QUEUED_ALERTS - 1)) {
                updated.put(array.get(i))
            }

            prefs.edit()
                .putString(KEY_PENDING_ALERTS, updated.toString())
                .putString(KEY_LAST_SIGNATURE, signature)
                .putLong(KEY_LAST_SIGNATURE_TS, timestampMs)
                .apply()

            return mapOf(
                "id" to id,
                "packageName" to packageName,
                "title" to title,
                "text" to text,
                "timestampMs" to timestampMs
            )
        }
    }

    fun consumeAlerts(context: Context): List<Map<String, Any>> {
        synchronized(lock) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_PENDING_ALERTS, "[]") ?: "[]"
            prefs.edit().remove(KEY_PENDING_ALERTS).apply()

            val result = mutableListOf<Map<String, Any>>()
            try {
                val array = JSONArray(raw)
                for (i in 0 until array.length()) {
                    val obj = array.optJSONObject(i) ?: continue
                    result.add(
                        mapOf(
                            "id" to obj.optString("id", ""),
                            "packageName" to obj.optString("packageName", ""),
                            "title" to obj.optString("title", ""),
                            "text" to obj.optString("text", ""),
                            "timestampMs" to obj.optLong("timestampMs", 0L)
                        )
                    )
                }
            } catch (_: Exception) {
                // Ignore malformed JSON
            }
            return result
        }
    }
}
