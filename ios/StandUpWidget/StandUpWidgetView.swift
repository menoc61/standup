import SwiftUI
import WidgetKit

/// Renders the countdown, the app logo and the action, in every family size.
///
/// The small family is the one that matters most: it is the size people put on
/// a home screen and then glance at, so it carries the logo, the countdown and
/// the button. Motivation sits in the larger families where there is room.
///
/// Every colour comes from `entry.payload.palette`, so the widget follows the
/// user's chosen accent.
struct StandUpWidgetView: View {
    let entry: StandUpEntry
    @Environment(\.widgetFamily) private var family

    private var payload: WidgetPayload { entry.payload }
    private var palette: WidgetPalette { payload.palette }

    var body: some View {
        ZStack {
            palette.surface
            content
                .padding(family == .systemSmall ? 12 : 14)
        }
        .widgetURL(URL(string: "csphwidget://open"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        default: large
        }
    }

    private var statusLine: some View {
        Text(entry.status)
            .font(.system(size: 11))
            .foregroundStyle(palette.muted)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var streakLabel: some View {
        Text(payload.streak > 0
             ? payload.t("\(payload.streak) day streak", "\(payload.streak) jours de suite")
             : payload.t("Start a streak today", "Lancez une série aujourd’hui"))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var header: some View {
        HStack(spacing: 6) {
            LogoBadge(dimension: family == .systemSmall ? 18 : 20)
            Text("StandUp")
                .font(.system(size: family == .systemSmall ? 11 : 12, weight: .bold))
                .foregroundStyle(palette.onSurface)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            LiveCountdown(
                target: payload.countdownTarget,
                countsDown: payload.windowOpen,
                color: palette.onSurface
            )
            statusLine
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                ActionButton(payload: payload, compact: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                LiveCountdown(
                    target: payload.countdownTarget,
                    countsDown: payload.windowOpen,
                    color: palette.onSurface
                )
                VStack(alignment: .leading, spacing: 2) {
                    statusLine
                    streakLabel
                }
                Spacer(minLength: 0)
                ActionButton(payload: payload, compact: false)
            }
            GoalBar(
                completed: payload.todayCompleted,
                goal: payload.dailyGoal,
                language: payload.language,
                accent: palette.accent,
                muted: palette.muted,
                track: palette.onSurface.opacity(0.12)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            LiveCountdown(
                target: payload.countdownTarget,
                countsDown: payload.windowOpen,
                color: palette.onSurface
            )
            statusLine
            streakLabel
            Spacer(minLength: 0)
            GoalBar(
                completed: payload.todayCompleted,
                goal: payload.dailyGoal,
                language: payload.language,
                accent: palette.accent,
                muted: palette.muted,
                track: palette.onSurface.opacity(0.12)
            )
            HStack {
                Text(payload.t("Level", "Niveau"))
                    .font(.system(size: 11))
                    .foregroundStyle(palette.muted)
                Spacer()
                Text("\(payload.level)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.onSurface)
                Spacer()
                ActionButton(payload: payload, compact: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The widget's one button.
///
/// On iOS 17 and later this is a real [AppIntent], so a stand-up can be logged
/// without the app being opened. On earlier systems interactive widgets do not
/// exist, so the button is simply absent and the widget body opens the app.
/// The gate itself — an open window and a clock that has not been distrusted —
/// matches the Android provider exactly.
struct ActionButton: View {
    let payload: WidgetPayload
    let compact: Bool

    var body: some View {
        Group {
            if payload.canAct {
                if #available(iOS 17.0, *) {
                    Button(intent: LogStandUpIntent()) {
                        label
                    }
                    .buttonStyle(.plain)
                } else {
                    // No interactive widgets before iOS 17; the surrounding
                    // widgetURL opens the app instead.
                    label
                }
            }
        }
    }

    private var label: some View {
        Text(payload.t("I stood up", "Pause validée"))
            .font(.system(size: compact ? 12 : 13, weight: .bold))
            .foregroundStyle(payload.palette.accent)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 6 : 8)
            .background(
                Capsule()
                    .fill(payload.palette.accent.opacity(0.10))
                    .overlay(
                        Capsule().strokeBorder(payload.palette.accent.opacity(0.35), lineWidth: 1)
                    )
            )
            .fixedSize()
    }
}
