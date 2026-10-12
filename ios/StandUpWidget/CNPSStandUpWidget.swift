import SwiftUI
import WidgetKit

/// The widget extension's entry point.
///
/// `CNPSStandUpWidget` is the name `WidgetBridge` passes to
/// `HomeWidget.updateWidget(iOSName:)`, so renaming this type breaks every
/// refresh on iOS without producing a build error.
@main
struct CNPSStandUpWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CNPSStandUpWidget", provider: StandUpProvider()) { entry in
            StandUpWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("StandUp")
        .description("Countdown to your movement break and a one-tap way to log it.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
