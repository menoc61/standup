import WidgetKit

/// One rendered state of the widget.
struct StandUpEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload

    /// The sentence under the countdown, resolved once per entry rather than in
    /// the view so it stays stable across a re-render.
    var status: String {
        guard payload.countdownTarget != nil else {
            return payload.t("Open the app to start", "Ouvrez l'application")
        }
        if payload.windowOpen {
            return payload.date <= (payload.windowEndsAt ?? payload.date)
                ? payload.t("Window open - log your stand", "Fenêtre ouverte - enregistrez votre pause")
                : payload.t("Window closed", "Fenêtre fermée")
        }
        return payload.t("Until the movement window", "Avant la fenêtre de mouvement")
    }
}

/// Supplies widget content.
///
/// The timeline is short and dense on purpose. The countdown itself is drawn by
/// [LiveCountdown] from the absolute timestamps, so the timeline does not have to
/// be per-minute to stay accurate; it only has to be frequent enough that a
/// window opening, closing, or being acted upon is reflected promptly.
struct StandUpProvider: TimelineProvider {
    /// How often the system is asked for a fresh entry.
    private static let refreshInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> StandUpEntry {
        StandUpEntry(date: Date(), payload: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (StandUpEntry) -> Void) {
        let payload = WidgetPayload.load()
        completion(StandUpEntry(date: Date(), payload: payload))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StandUpEntry>) -> Void) {
        let now = Date()
        let payload = WidgetPayload.load(now: now)

        var entries: [StandUpEntry] = [StandUpEntry(date: now, payload: payload)]
        for step in 1...4 {
            entries.append(
                StandUpEntry(
                    date: now.addingTimeInterval(Self.refreshInterval * Double(step)),
                    payload: payload
                )
            )
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
