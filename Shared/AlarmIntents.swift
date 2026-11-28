import AlarmKit
import AppIntents
import Foundation

// Buttons of a ringing alarm. `LiveActivityIntent` makes iOS run `perform()` inside the app's
// process (launching it in the background if needed), never in the widget extension, so the
// app writes the wake log and plans the next ring. The alarm itself is stopped or snoozed by
// iOS whether or not this code runs: AlarmKit stays in charge of the sound.
//
// This file is compiled into both targets. The widget extension defines WIDGET_EXTENSION and
// only needs the intent types.

enum AlarmIntentAction: String, Sendable {
    case stop, snooze, respond
}

struct StopAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop"
    static let isDiscoverable = false

    @Parameter(title: "Ring")
    var ringID: String

    init() {
        ringID = ""
    }

    init(ringID: String) {
        self.ringID = ringID
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: ringID) {
            // iOS normally stops it already; stopping twice is harmless.
            try? AlarmManager.shared.stop(id: id)
        }
        await AlarmIntentPerformer.perform(.stop, ringID: ringID)
        return .result()
    }
}

struct SnoozeAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Snooze"
    static let isDiscoverable = false

    @Parameter(title: "Ring")
    var ringID: String

    init() {
        ringID = ""
    }

    init(ringID: String) {
        self.ringID = ringID
    }

    func perform() async throws -> some IntentResult {
        await AlarmIntentPerformer.perform(.snooze, ringID: ringID)
        return .result()
    }
}

/// The alarm's "Respond" button: opens ConciergeClock, which silences the ring, speaks the
/// announcement (dismiss or remind again?) on the loudspeaker and listens for the answer.
struct RespondToAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Respond"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @Parameter(title: "Ring")
    var ringID: String

    init() {
        ringID = ""
    }

    init(ringID: String) {
        self.ringID = ringID
    }

    func perform() async throws -> some IntentResult {
        await AlarmIntentPerformer.perform(.respond, ringID: ringID)
        return .result()
    }
}

enum AlarmIntentPerformer {
    static func perform(_ action: AlarmIntentAction, ringID: String) async {
        #if !WIDGET_EXTENSION
        await AlarmIntentRouter.perform(action, ringID: ringID)
        #endif
    }
}
