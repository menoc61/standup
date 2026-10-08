import AppIntents
import WidgetKit

/// The iOS 17+ equivalent of the Android widget's action button.
///
/// The tap is written straight into the shared App Group as a pending action and
/// then the widget is reloaded. The Flutter side drains that pending action the
/// next time the app runs — or immediately, if the app happens to be alive,
/// through the same route the Android broadcast uses.
///
/// This is a deliberate trade. The alternative, spinning up a full Dart isolate
/// from an App Intent, is not supported by the platform and would make the
/// button either unreliable or far slower to respond. Deferring the write by a
/// few seconds is invisible to someone who tapped a movement reminder, and it
/// keeps the rule enforcement — the action window and the one-per-window check —
/// in exactly one place: the app.
@available(iOS 17.0, *)
struct LogStandUpIntent: AppIntent {
    /// Widgets need a stable identifier; renaming this breaks the button.
    static var title: LocalizedStringResource = "Log stand-up"

    static var description = IntentDescription(
        "Records a movement break from the home screen."
    )

    /// Keeps the intent out of the Shortcuts gallery, where it would be
    /// confusing: it only makes sense pressed from the widget itself.
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        PendingWidgetAction.write(.logStandUp)

        // Reloading is what makes the streak and goal update under the user's
        // finger; the underlying analytics update happens when the app next runs.
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}

/// A widget action that has been requested but not yet applied by the app.
enum PendingWidgetAction: String {
    case logStandUp

    static func write(_ action: PendingWidgetAction) {
        guard let defaults = UserDefaults(suiteName: WidgetPayload.appGroup) else { return }
        // `home_widget` reads this key straight out of the App Group on the Dart
        // side, so writing it here is what makes the action visible to the app.
        defaults.set(action.rawValue, forKey: key)
    }

    /// The key the Dart side reads through `HomeWidget.getWidgetData`.
    static let key = "home_widget_pending_action"

    /// Consumes a pending action, returning it only once.
    ///
    /// Reading and clearing together is what stops the same tap being applied
    /// twice: the app drains this on every resume, and a second resume with
    /// nothing new must not replay an action already counted.
    static func take() -> PendingWidgetAction? {
        guard let defaults = UserDefaults(suiteName: WidgetPayload.appGroup),
              let raw = defaults.string(forKey: key),
              let action = PendingWidgetAction(rawValue: raw)
        else { return nil }
        defaults.removeObject(forKey: key)
        return action
    }
}
