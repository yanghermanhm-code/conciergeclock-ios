import Foundation

/// Values shared by the app and the widget extension. If you change the App Group, change it in
/// Config/ConciergeClock.entitlements and Config/ConciergeClockWidgets.entitlements too.
enum SharedConfig {
    /// The app writes the next-alarm snapshot here; the widgets read it. On this iPhone only.
    static let appGroup = "group.com.greatergoodsoftware.conciergeclock"

    /// The shared folder, or nil when the App Groups capability is missing (free Personal Team).
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    /// WidgetKit kind of the next-alarm widget.
    static let nextAlarmWidgetKind = "NextAlarmWidget"
}
