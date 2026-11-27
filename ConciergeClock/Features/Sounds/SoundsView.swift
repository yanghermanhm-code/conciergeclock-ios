import GGSBrand
import SwiftUI

/// Sounds tab. Phase 4 adds the offline sound generator (white, pink and brown noise, rain,
/// a soft pad and chimes), the sleep timer, separate volumes and the gradual ramp-up.
struct SoundsView: View {
    @Environment(\.l10n) private var l10n

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ComingSoonCard(
                    systemImage: "waveform",
                    title: l10n["sounds.soon.title"],
                    message: l10n["sounds.soon.message"],
                    items: [
                        l10n["sounds.soon.noise"],
                        l10n["sounds.soon.ambient"],
                        l10n["sounds.soon.wake"],
                        l10n["sounds.soon.timer"],
                        l10n["sounds.soon.ramp"],
                    ]
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.background)
    }
}
