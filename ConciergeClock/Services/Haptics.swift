import UIKit

/// Light haptic feedback for buttons and toggles, respecting the Settings switch.
@MainActor
enum Haptics {
    static func tap(enabled: Bool) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func selection(enabled: Bool) {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success(enabled: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning(enabled: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
