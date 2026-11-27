import SwiftUI
import WidgetKit

/// Concierge Clock's widgets: the next alarm (Home Screen, Lock Screen, StandBy) and the Live
/// Activity of a ringing or snoozing alarm (Lock Screen, Dynamic Island).
@main
struct ConciergeClockWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextAlarmWidget()
        AlarmLiveActivity()
    }
}
