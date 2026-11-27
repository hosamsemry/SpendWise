package com.paydial.app

import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.notification.NotificationListenerService
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL_NAME = "com.paydial.app/smart_detection"
        private const val PRIVACY_CHANNEL_NAME = "com.paydial.app/privacy"

        @Volatile
        private var activeChannel: MethodChannel? = null

        @Volatile
        private var isForeground: Boolean = false

        fun notifyLiveAlertIfActive(alertMap: Map<String, Any>): Boolean {
            val channel = activeChannel ?: return false
            if (!isForeground) return false
            Handler(Looper.getMainLooper()).post {
                channel.invokeMethod("onAlertDetected", alertMap)
            }
            return true
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Keep balances out of the recent-apps thumbnail while still allowing
        // the user's own screenshots (unlike FLAG_SECURE). Android 13+ only;
        // older versions rely on the Flutter-side privacy cover.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
        extractSharedTextFromIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        isForeground = true
        rebindListenerIfEnabled()
    }

    override fun onPause() {
        isForeground = false
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val shared = extractSharedTextFromIntent(intent)
        if (shared != null) {
            Handler(Looper.getMainLooper()).post {
                activeChannel?.invokeMethod("onSharedText", shared)
            }
        }
    }

    private fun rebindListenerIfEnabled() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(applicationContext)
            if (enabledPackages.contains(packageName)) {
                try {
                    NotificationListenerService.requestRebind(
                        ComponentName(applicationContext, TransactionNotificationListener::class.java)
                    )
                } catch (_: Exception) {
                    // Safe fallback
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        activeChannel = channel
        SmartDetectionStorage.purgeLegacyDiagnostics(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRIVACY_CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isRecentsPreviewHiddenNatively" ->
                        result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
                    else -> result.notImplemented()
                }
            }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationAccessEnabled" -> {
                    val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(applicationContext)
                    val isGranted = enabledPackages.contains(packageName)
                    if (isGranted) rebindListenerIfEnabled()
                    result.success(isGranted)
                }
                "openNotificationAccessSettings" -> {
                    try {
                        val settingsIntent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(settingsIntent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "setSmartDetectionEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    SmartDetectionStorage.setEnabled(applicationContext, enabled)
                    if (enabled) rebindListenerIfEnabled()
                    result.success(null)
                }
                "setSourcePolicy" -> {
                    val watched = call.argument<List<String>>("watched") ?: emptyList()
                    val dismissed = call.argument<List<String>>("dismissed") ?: emptyList()
                    SmartDetectionStorage.setSourcePolicy(applicationContext, watched, dismissed)
                    result.success(null)
                }
                "getSuggestedApps" -> {
                    result.success(SmartDetectionStorage.getSuggestedApps(applicationContext))
                }
                "consumePendingNativeAlerts" -> {
                    val alerts = SmartDetectionStorage.consumeAlerts(applicationContext)
                    result.success(alerts)
                }
                "consumeSharedText" -> {
                    val shared = SmartDetectionStorage.consumeSharedText(applicationContext)
                    result.success(shared)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        activeChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun extractSharedTextFromIntent(intent: Intent?): String? {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val shared = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()
            if (!shared.isNullOrEmpty()) {
                SmartDetectionStorage.saveSharedText(applicationContext, shared)
                return shared
            }
        }
        return null
    }
}
