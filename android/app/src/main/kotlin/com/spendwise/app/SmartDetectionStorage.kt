package com.spendwise.app

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
    /** Removed feature; key kept only so old data can be purged. */
    private const val KEY_DIAGNOSTIC_LOGS = "detection_diagnostic_logs"
    private const val KEY_WATCHED_APPS = "watched_source_apps"
    private const val KEY_DISMISSED_SUGGESTIONS = "dismissed_source_suggestions"
    private const val KEY_SUGGESTED_APPS = "suggested_source_apps"
    private const val MAX_SUGGESTED_APPS = 20
    private const val KEY_PREVIEWS_SCRUBBED = "privacy_previews_scrubbed_v1"
    private const val KEY_LEGACY_PURGED = "legacy_diagnostics_purged_v1"
    private const val MAX_QUEUED_ALERTS = 50
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

    /**
     * Queues a candidate alert if it is not an immediate duplicate (within 30s)
     * and returns the serialized map when newly added, or null if skipped.
     */
    fun enqueueAlert(
        context: Context,
        packageName: String,
        title: String,
        text: String,
        timestampMs: Long,
        sourceKind: String
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
                put("sourceKind", sourceKind)
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
                "timestampMs" to timestampMs,
                "sourceKind" to sourceKind
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
                            "timestampMs" to obj.optLong("timestampMs", 0L),
                            // Alerts queued before source gating existed have no kind:
                            // the Dart side treats a missing kind strictly.
                            "sourceKind" to obj.optString("sourceKind", "")
                        )
                    )
                }
            } catch (_: Exception) {
                // Ignore malformed JSON
            }
            return result
        }
    }

    // --- Source app policy (mirrored from Flutter's app_settings) ---

    /** Replaces the watched-app and dismissed-suggestion lists pushed from Flutter. */
    fun setSourcePolicy(context: Context, watched: List<String>, dismissed: List<String>) {
        synchronized(lock) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val suggestions = readSuggestions(prefs.getString(KEY_SUGGESTED_APPS, null))
            for (pkg in watched + dismissed) suggestions.remove(pkg)
            prefs.edit()
                .putStringSet(KEY_WATCHED_APPS, watched.toSet())
                .putStringSet(KEY_DISMISSED_SUGGESTIONS, dismissed.toSet())
                .putString(KEY_SUGGESTED_APPS, suggestions.toString())
                .apply()
        }
    }

    fun isWatchedApp(context: Context, packageName: String): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getStringSet(KEY_WATCHED_APPS, emptySet())?.contains(packageName) == true
    }

    private fun isDismissedSuggestion(prefs: android.content.SharedPreferences, packageName: String): Boolean {
        return prefs.getStringSet(KEY_DISMISSED_SUGGESTIONS, emptySet())?.contains(packageName) == true
    }

    /**
     * Records that an unwatched app posted a financial-looking notification so
     * the user can choose to watch it. Ignored for dismissed apps.
     */
    fun recordSuggestedApp(
        context: Context,
        packageName: String,
        label: String,
        timestampMs: Long
    ) {
        synchronized(lock) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (isDismissedSuggestion(prefs, packageName)) return

            val suggestions = readSuggestions(prefs.getString(KEY_SUGGESTED_APPS, null))
            val existing = suggestions.optJSONObject(packageName)
            val entry = JSONObject().apply {
                put("label", label)
                put("count", (existing?.optInt("count", 0) ?: 0) + 1)
                put("lastSeenMs", timestampMs)
            }
            suggestions.put(packageName, entry)

            // Keep only the most recently seen apps
            if (suggestions.length() > MAX_SUGGESTED_APPS) {
                var oldestKey: String? = null
                var oldestTs = Long.MAX_VALUE
                for (key in suggestions.keys()) {
                    val ts = suggestions.optJSONObject(key)?.optLong("lastSeenMs", 0L) ?: 0L
                    if (ts < oldestTs) {
                        oldestTs = ts
                        oldestKey = key
                    }
                }
                oldestKey?.let { suggestions.remove(it) }
            }

            prefs.edit().putString(KEY_SUGGESTED_APPS, suggestions.toString()).apply()
        }
    }

    fun getSuggestedApps(context: Context): List<Map<String, Any>> {
        synchronized(lock) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val suggestions = readSuggestions(prefs.getString(KEY_SUGGESTED_APPS, null))
            val result = mutableListOf<Map<String, Any>>()
            for (key in suggestions.keys()) {
                val obj = suggestions.optJSONObject(key) ?: continue
                result.add(
                    mapOf(
                        "packageName" to key,
                        "label" to obj.optString("label", key),
                        "count" to obj.optInt("count", 1),
                        "lastSeenMs" to obj.optLong("lastSeenMs", 0L)
                    )
                )
            }
            return result.sortedByDescending { it["lastSeenMs"] as Long }
        }
    }

    private fun readSuggestions(raw: String?): JSONObject {
        if (raw.isNullOrEmpty()) return JSONObject()
        return try {
            JSONObject(raw)
        } catch (_: Exception) {
            JSONObject()
        }
    }

    /**
     * Removes data kept by older versions: the detection diagnostic log
     * (dropped entirely) and any message previews stored with suggestions.
     * Idempotent and cheap; safe to call on every app start.
     */
    fun purgeLegacyDiagnostics(context: Context) {
        synchronized(lock) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (prefs.getBoolean(KEY_LEGACY_PURGED, false)) return

            val suggestions = readSuggestions(prefs.getString(KEY_SUGGESTED_APPS, null))
            for (key in suggestions.keys()) {
                suggestions.optJSONObject(key)?.remove("preview")
            }

            prefs.edit()
                .remove(KEY_DIAGNOSTIC_LOGS)
                .remove(KEY_PREVIEWS_SCRUBBED)
                .putString(KEY_SUGGESTED_APPS, suggestions.toString())
                .putBoolean(KEY_LEGACY_PURGED, true)
                .apply()
        }
    }
}
