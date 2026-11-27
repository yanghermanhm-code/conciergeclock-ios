import ConciergeCore
import Foundation

/// Runs the Stop and Snooze buttons of a ringing alarm (Shared/AlarmIntents.swift) against the
/// app's own scheduler. iOS may launch the app in the background just for this, so the model
/// comes from `LaunchState.shared`, which exists as soon as the process starts.
@MainActor
enum AlarmIntentRouter {
    static func perform(_ action: AlarmIntentAction, ringID: String) async {
        guard case let .ready(model) = LaunchState.shared, !ringID.isEmpty else { return }
        switch action {
        case .stop:
            await model.scheduler.didStop(ringID: ringID)
        case .snooze:
            model.scheduler.didSnooze(ringID: ringID)
        }
    }
}
