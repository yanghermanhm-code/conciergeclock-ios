import AlarmKit
import Foundation

/// What ConciergeClock attaches to every AlarmKit alarm: which of its alarms rang. Read by the
/// Live Activity (Lock Screen, Dynamic Island) and by the app when the alarm is stopped.
/// Compiled into the app and the widget extension.
struct ConciergeAlarmMetadata: AlarmMetadata {
    var alarmID: String
    var label: String
}
