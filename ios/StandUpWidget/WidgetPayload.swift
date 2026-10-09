import Foundation

/// Reads the payload that the Flutter app publishes through the shared App Group.
///
/// The encoding is deliberately identical to `WidgetBridge._encode` on the Dart
/// side and `StandUpWidgetProvider.parse` on Android: a pipe-delimited list of
/// `key=value` pairs. Any change on one side must be mirrored on the other two,
/// because a mismatch here degrades to a blank widget rather than an error.
///
/// Only the user's own figures cross this boundary. There is no identifier, no
/// location and no team data in the payload; see `WidgetSnapshot`'s privacy note.
struct WidgetPayload {
    let windowEndsAt: Date?
    let windowOpensAt: Date?
    let windowOpen: Bool
    let windowMinutes: Int
    let cadenceMinutes: Int
    let streak: Int
    let totalXp: Int
    let level: Int
    let todayCompleted: Int
    let dailyGoal: Int
    let goalMet: Bool
    let clockSuspect: Bool
    let language: String

    /// Colours published by the Dart side, already resolved from the user's
    /// accent. See `WidgetPaletteHex.forAccent` in the app for why the palette
    /// is resolved once in Dart rather than duplicated here.
    let palette: WidgetPalette

    /// Absolute instants are only meaningful for a bounded stretch of time, so a
    /// payload older than this is treated as stale rather than rendered. Without
    /// it, a device that has been off for a week would show a countdown to a
    /// window that closed days ago.
    private static let maxAge: TimeInterval = 6 * 60 * 60

    static let appGroup = "group.com.healthwellness.standupApp"
    static let snapshotKey = "snapshot"

    static func load(now: Date = Date()) -> WidgetPayload {
        let defaults = UserDefaults(suiteName: appGroup)
        let raw = defaults?.string(forKey: snapshotKey)

        guard let raw, !raw.isEmpty else { return .empty }
        let fields = Self.decode(raw)

        // Fall back to an empty payload rather than rendering stale numbers.
        if let published = fields["published_at"].flatMap(Self.parseDate),
           now.timeIntervalSince(published) > maxAge {
            return .empty
        }

        let windowOpen = fields["window_open"] == "1"
        // While open, count down to the close. While shut, count down to the open.
        let targetKey = windowOpen ? "window_ends_at" : "window_opens_at"
        let target = fields[targetKey].flatMap(Self.parseDate)

        return WidgetPayload(
            windowEndsAt: fields["window_ends_at"].flatMap(Self.parseDate),
            windowOpensAt: fields["window_opens_at"].flatMap(Self.parseDate),
            windowOpen: windowOpen,
            windowMinutes: Self.int(fields["window_minutes"]) ?? 5,
            cadenceMinutes: Self.int(fields["cadence_minutes"]) ?? 60,
            streak: Self.int(fields["streak"]) ?? 0,
            totalXp: Self.int(fields["total_xp"]) ?? 0,
            level: Self.int(fields["level"]) ?? 1,
            todayCompleted: Self.int(fields["today_completed"]) ?? 0,
            dailyGoal: Self.int(fields["daily_goal"]) ?? 8,
            goalMet: fields["goal_met"] == "1",
            clockSuspect: fields["clock_suspect"] == "1",
            language: fields["lang"] ?? "en",
            palette: WidgetPalette(fields: fields)
        )
    }

    /// The instant the countdown should aim at, or nil when there is none.
    var countdownTarget: Date? {
        windowOpen ? windowEndsAt : windowOpensAt
    }

    /// Whether the action button may be offered.
    ///
    /// Mirrors the Android gate exactly: an open window and a clock that has not
    /// been distrusted.
    var canAct: Bool { windowOpen && !clockSuspect }

    var isFrench: Bool { language == "fr" }

    func t(_ en: String, _ fr: String) -> String { isFrench ? fr : en }

    static let empty = WidgetPayload(
        windowEndsAt: nil,
        windowOpensAt: nil,
        windowOpen: false,
        windowMinutes: 5,
        cadenceMinutes: 60,
        streak: 0,
        totalXp: 0,
        level: 1,
        todayCompleted: 0,
        dailyGoal: 8,
        goalMet: false,
        clockSuspect: false,
        language: "en",
        palette: .fallback
    )

    private static func decode(_ raw: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in raw.split(separator: ";", omittingEmptySubsequences: true) {
            guard let index = pair.firstIndex(of: "="), index != pair.startIndex else { continue }
            let key = String(pair[pair.startIndex..<index])
            result[key] = String(pair[pair.index(after: index)...])
        }
        return result
    }

    private static func int(_ value: String?) -> Int? { value.flatMap(Int.init) }

    /// Matches the `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'` format the Dart side emits.
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let fallbackFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ value: String) -> Date? {
        formatter.date(from: value) ?? fallbackFormatter.date(from: value)
    }
}

/// Colours published by the Dart side as `AARRGGBB` strings.
///
/// The widget must follow the user's chosen accent, and the accent is resolved
/// once in Dart (`WidgetPaletteHex.forAccent`). Keeping a second copy of the
/// palette table in Swift would drift from the app the first time an option was
/// added, so the values are read from the shared payload instead.
///
/// Every accessor falls back to a neutral, so a widget that has never received a
/// publish still renders legibly.
struct WidgetPalette {
    let surface: Color
    let surfaceAlt: Color
    let onSurface: Color
    let muted: Color
    let accent: Color
    let onAccent: Color

    init(
        surface: Color,
        surfaceAlt: Color,
        onSurface: Color,
        muted: Color,
        accent: Color,
        onAccent: Color
    ) {
        self.surface = surface
        self.surfaceAlt = surfaceAlt
        self.onSurface = onSurface
        self.muted = muted
        self.accent = accent
        self.onAccent = onAccent
    }

    init(fields: [String: String]) {
        func read(_ key: String, _ fallback: UInt32) -> Color {
            Color(argb: fields[key], fallback: fallback)
        }
        self.init(
            surface: read("c_surface", 0xFFFFFFFF),
            surfaceAlt: read("c_surface_2", 0xFF3887BF),
            onSurface: read("c_on_surface", 0xFF0B0B0C),
            muted: read("c_muted", 0xFF6B6B70),
            accent: read("c_accent", 0xFF0472B1),
            onAccent: read("c_on_accent", 0xFFFFFFFF)
        )
    }

    /// Matches the app's light palette, not the retired evergreen.
    static let fallback = WidgetPalette(
        surface: Color(white: 1.0),
        surfaceAlt: Color(red: 0.220, green: 0.529, blue: 0.749),
        onSurface: Color(red: 0.043, green: 0.043, blue: 0.047),
        muted: Color(red: 0.420, green: 0.420, blue: 0.439),
        accent: Color(red: 0.016, green: 0.447, blue: 0.694),
        onAccent: Color(white: 1.0)
    )
}

extension Color {
    /// Parses `#AARRGGBB`, `#RRGGBB` or a bare hex string.
    ///
    /// Returns [fallback] for anything unparseable rather than trapping: a
    /// corrupt payload must not take down the widget host.
    init(argb: String?, fallback: UInt32) {
        guard var hex = argb?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            self = Color(argbValue: fallback)
            return
        }
        if hex.hasPrefix("#") { hex.removeFirst() }
        if hex.count == 6 { hex = "FF" + hex }
        guard hex.count == 8, let value = UInt32(hex, radix: 16) else {
            self = Color(argbValue: fallback)
            return
        }
        self = Color(argbValue: value)
    }

    init(argbValue: UInt32) {
        self.init(
            .sRGB,
            red: Double((argbValue >> 16) & 0xFF) / 255,
            green: Double((argbValue >> 8) & 0xFF) / 255,
            blue: Double(argbValue & 0xFF) / 255,
            opacity: Double((argbValue >> 24) & 0xFF) / 255
        )
    }
}
