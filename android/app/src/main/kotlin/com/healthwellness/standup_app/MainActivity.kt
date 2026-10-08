package com.healthwellness.standup_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "standup/background_run"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isExempt" -> result.success(isExemptFromBatteryOptimizations())
                    "requestExemption" -> result.success(requestExemption())
                    else -> result.notImplemented()
                }
            }
    }

    private fun isExemptFromBatteryOptimizations(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return "allowed"
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return if (powerManager.isIgnoringBatteryOptimizations(packageName)) {
            "allowed"
        } else {
            "restricted"
        }
    }

    /**
     * Sends the user to the system battery-optimisation screen so they can grant
     * the exemption themselves. The OS always requires this explicit step, so we
     * report the state after the intent instead of assuming success.
     */
    private fun requestExemption(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (powerManager.isIgnoringBatteryOptimizations(packageName)) return true

        val directIntent = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:$packageName"),
        )
        val settingsIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)

        return try {
            startActivity(directIntent)
            false
        } catch (_: Exception) {
            try {
                startActivity(settingsIntent)
                false
            } catch (_: Exception) {
                false
            }
        }
    }
}
