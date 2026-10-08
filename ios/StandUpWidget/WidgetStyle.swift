import SwiftUI

/// A countdown that keeps itself ticking between timeline refreshes.
///
/// `Text(timerInterval:countsDown:)` is driven by the system clock, so the
/// number stays correct even while the widget sits untouched on the home
/// screen. Recomputing a string from a snapshot would freeze it at whatever the
/// last timeline entry computed.
struct LiveCountdown: View {
    let target: Date?
    let countsDown: Bool
    let color: Color

    var body: some View {
        if let target {
            Text(timerInterval: Date()...max(target, Date()), countsDown: countsDown)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        } else {
            Text("--:--")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color.opacity(0.5))
        }
    }
}

/// The app logo on a white rounded chip.
///
/// The asset has a white ground, so the chip keeps the mark legible against any
/// surface colour and reads as a deliberate badge rather than a stray white
/// square.
struct LogoBadge: View {
    /// Size of the whole badge, logo included.
    let dimension: CGFloat

    var body: some View {
        Image("standup_logo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(dimension * 0.12)
            .frame(width: dimension, height: dimension)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: dimension * 0.3, style: .continuous))
            // The mark is decorative here: the widget's title already names the
            // app, so announcing the image too would be noise for VoiceOver.
            .accessibilityHidden(true)
    }
}

/// Progress towards the daily goal, shown on the medium and large families.
struct GoalBar: View {
    let completed: Int
    let goal: Int
    let language: String
    let accent: Color
    let muted: Color
    let track: Color

    private var met: Bool { goal > 0 && completed >= goal }

    private var fraction: Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(completed) / Double(goal))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(language == "fr" ? "Objectif" : "Goal")
                Text("\(completed)/\(goal)")
                    .fontWeight(.semibold)
                Spacer(minLength: 0)
                if met {
                    // The one celebratory moment in the widget: a filled bar is
                    // enough, and it costs no animation budget.
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accent)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(muted)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(track)
                    Capsule()
                        .fill(met ? accent : accent)
                        .frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 6)
        }
    }
}
