package com.healthwellness.standup_app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.healthwellness.standup_app.MainActivity
import com.healthwellness.standup_app.R
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit

/**
 * Renders the StandUp home-screen widget.
 *
 * A launcher widget is drawn by the launcher process, not by Flutter, so this
 * class re-implements the small slice of the product rule it needs:
 *
 *  * The remaining time is recomputed from the stored window timestamps against
 *    the device clock on every draw, rather than rendered from a pre-computed
 *    string. That keeps the countdown honest between Dart pushes instead of
 *    freezing at whatever the last update said.
 *  * A clock that Dart has flagged as distrusted hides the action button rather
 *    than offering to log a break on numbers nobody can stand behind.
 *
 * The button never records the break itself. It hands the tap to a headless
 * Dart isolate, which re-applies the action window and the
 * one-per-window rule. That keeps a launcher tap and an in-app tap on exactly
 * the same code path.
 */
class StandUpWidgetProvider : AppWidgetProvider() {

    companion object {
        /**
         * Name of this provider as registered with `home_widget`, so Dart's
         * `HomeWidget.updateWidget` can find it.
         */
        const val PROVIDER = "StandUpWidgetProvider"

        /** Key under which [WidgetBridge] stores its serialised payload. */
        const val KEY_SNAPSHOT = "snapshot"

        /**
         * `home_widget` writes app-shared data here. The plugin exposes this
         * name as `internal`, so the literal is duplicated deliberately and
         * asserted against the plugin in the widget tests.
         */
        const val PREFS_NAME = "HomeWidgetPreferences"

        /** URI the button broadcasts. Mirrored by `WidgetActionCallback`. */
        const val URI_COMPLETE = "csphwidget://complete"

        private const val TAG = "StandUpWidget"

        private const val ISO = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

        /** Below this, show seconds so the last minute reads as a countdown. */
        private const val SECOND_PRECISION_BELOW_MS = 60_000L

    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { id ->
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?
    ) {
        appWidgetManager.updateAppWidget(appWidgetId, buildViews(context))
    }

    /** Snapshot access is shared with nothing else; kept internal to the widget. */
    internal fun snapshot(context: Context): Map<String, String> {
        val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_SNAPSHOT, null)
        return if (raw.isNullOrEmpty()) emptyMap() else parse(raw)
    }

    private fun buildViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.csph_standup_widget)
        val values = snapshot(context)
        val colors = Colors(values)

        val windowOpen = values["window_open"] == "1"
        val clockSuspect = values["clock_suspect"] == "1"
        val streak = values["streak"]?.toIntOrNull() ?: 0
        val level = values["level"]?.toIntOrNull() ?: 0
        val lang = values["lang"] ?: "en"

        // ── Colours ───────────────────────────────────────────────────────────
        //
        // RemoteViews exposes no supported way to set a *rounded* rectangle to a
        // runtime colour: setBackgroundColor / setBackground / setBackground-
        // Drawable are all @hide, and setInt only carries an Int, so a
        // GradientDrawable cannot be passed. The design therefore keeps the
        // rounded shapes static and carries the user's accent in the parts that
        // can be recoloured safely:
        //
        //   * the surface, chip and action pill stay neutral, which is also what
        //     looks right against an arbitrary wallpaper;
        //   * the streak, the level badge and the action label take the accent,
        //     which is where the user's choice is actually legible.
        //
        // The accent is a fill-for-text substitution rather than a compromise:
        // every accent in the palette clears 4.5:1 against the surface it lands
        // on, asserted in test/contrast_test.dart.
        views.setTextColor(R.id.widget_title, colors.onSurface)
        views.setTextColor(R.id.widget_level, colors.onSurfaceAlt)
        views.setTextColor(R.id.widget_countdown, colors.onSurface)
        views.setTextColor(R.id.widget_status, colors.muted)
        views.setTextColor(R.id.widget_streak, colors.accent)

        views.setTextViewText(
            R.id.widget_title,
            t(lang, "StandUp", "StandUp"),
        )
        views.setTextViewText(
            R.id.widget_level,
            if (level > 0) t(lang, "Lv $level", "Niv $level") else "",
        )

        // ── Countdown ────────────────────────────────────────────────────────
        val endsAt = values["window_ends_at"]?.let { parseIso(it) }
        val opensAt = values["window_opens_at"]?.let { parseIso(it) }
        val target = if (windowOpen) endsAt else opensAt
        val remainingMs = target?.let { it - System.currentTimeMillis() }

        val countdownText: String
        val statusText: String
        when {
            target == null || remainingMs == null -> {
                countdownText = "--:--"
                statusText = t(lang, "Open the app to start", "Ouvrez l’application")
            }

            windowOpen && remainingMs > 0L -> {
                countdownText = countdown(remainingMs)
                statusText = t(lang, "Window open - log your stand", "Fenêtre ouverte - enregistrez votre pause")
            }

            windowOpen -> {
                countdownText = "00:00"
                statusText = t(lang, "Window closed", "Fenêtre fermée")
            }

            remainingMs > 0L -> {
                countdownText = countdown(remainingMs)
                statusText = t(lang, "Until the movement window", "Avant la fenêtre de mouvement")
            }

            else -> {
                countdownText = "--:--"
                statusText = t(lang, "Open the app to start", "Ouvrez l’application")
            }
        }

        views.setTextViewText(R.id.widget_countdown, countdownText)
        views.setTextViewText(R.id.widget_status, statusText)

        // ── Streak ───────────────────────────────────────────────────────────
        views.setTextViewText(
            R.id.widget_streak,
            when {
                streak > 0 -> t(lang, "$streak day streak", "$streak jours de suite")
                else -> t(lang, "Start a streak today", "Lancez une série aujourd’hui")
            }
        )

        // ── Action ───────────────────────────────────────────────────────────
        if (windowOpen && !clockSuspect) {
            views.setViewVisibility(R.id.widget_action, View.VISIBLE)
            views.setTextViewText(R.id.widget_action, t(lang, "I stood up", "Pause validée"))
            views.setTextColor(R.id.widget_action, colors.accent)
            views.setOnClickPendingIntent(
                R.id.widget_action,
                HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(URI_COMPLETE))
            )
        } else {
            views.setViewVisibility(R.id.widget_action, View.GONE)
        }

        // Tapping the body opens the app for anything the button cannot do.
        views.setOnClickPendingIntent(
            R.id.widget_root,
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("csphwidget://open")
            )
        )

        return views
    }

    /** `MM:SS` under an hour, `H:MM` beyond it. */
    private fun countdown(millis: Long): String {
        val safe = if (millis < 0L) 0L else millis
        val totalSeconds = TimeUnit.MILLISECONDS.toSeconds(safe)
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return if (hours > 0L || safe >= SECOND_PRECISION_BELOW_MS) {
            String.format(Locale.US, "%d:%02d", hours, minutes)
        } else {
            String.format(Locale.US, "%02d:%02d", minutes, seconds)
        }
    }

    private fun parseIso(value: String): Long? = try {
        val format = SimpleDateFormat(ISO, Locale.US)
        format.timeZone = TimeZone.getTimeZone("UTC")
        format.parse(value)?.time
    } catch (e: Exception) {
        Log.w(TAG, "Unparseable timestamp: $value", e)
        null
    }

    /** Decodes the pipe-delimited payload written by `WidgetBridge` in Dart. */
    private fun parse(raw: String): Map<String, String> {
        val result = HashMap<String, String>()
        raw.split(";").forEach { pair ->
            if (pair.isEmpty()) return@forEach
            val index = pair.indexOf('=')
            if (index <= 0) return@forEach
            result[pair.substring(0, index)] = pair.substring(index + 1)
        }
        return result
    }

    private fun t(lang: String, en: String, fr: String) = if (lang == "fr") fr else en
}

/**
 * The widget's colours, read from the payload Dart published.
 *
 * These keys are resolved in Dart (`WidgetPaletteHex.forAccent`) and arrive as
 * `AARRGGBB` strings. Keeping the resolution on one side is deliberate: the
 * accent is a user choice, and a palette table duplicated here would drift from
 * the app the first time an option was added.
 *
 * Every accessor falls back to a neutral, so a widget that has never received a
 * publish — a fresh install, or a payload from an older build — still renders
 * legibly instead of throwing or showing black-on-black.
 */
private class Colors(values: Map<String, String>) {
    val surface: Int = values.color("c_surface", FALLBACK_SURFACE)
    val surfaceAlt: Int = values.color("c_surface_2", FALLBACK_SURFACE_ALT)
    val onSurface: Int = values.color("c_on_surface", FALLBACK_ON_SURFACE)
    val onSurfaceAlt: Int = values.color("c_on_surface", FALLBACK_ON_SURFACE)
    val muted: Int = values.color("c_muted", FALLBACK_MUTED)
    val accent: Int = values.color("c_accent", FALLBACK_ACCENT)
    val onAccent: Int = values.color("c_on_accent", FALLBACK_ON_ACCENT)
    val streak: Int = values.color("c_streak", FALLBACK_ACCENT)

    companion object {
        const val FALLBACK_SURFACE = 0xFFFFFFFF.toInt()
        const val FALLBACK_SURFACE_ALT = 0xFF3887BF.toInt()
        const val FALLBACK_ON_SURFACE = 0xFF0B0B0C.toInt()
        const val FALLBACK_MUTED = 0xFF6B6B70.toInt()
        const val FALLBACK_ACCENT = 0xFF0472B1.toInt()
        const val FALLBACK_ON_ACCENT = 0xFFFFFFFF.toInt()
    }
}

private fun Map<String, String>.color(key: String, fallback: Int): Int {
    val raw = this[key] ?: return fallback
    val hex = raw.trim().removePrefix("#")
    val padded = when (hex.length) {
        6 -> "FF$hex"
        8 -> hex
        else -> return fallback
    }
    return padded.toLongOrNull(16)?.let { if (it > Int.MAX_VALUE) (it - 0x100000000L).toInt() else it.toInt() }
        ?: fallback
}
