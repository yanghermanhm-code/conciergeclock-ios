import GGSBrand
import SwiftUI

/// A card that says what a screen will do once its phase is built, so every tab is useful to
/// look at from the first build. Removed screen by screen as the phases land.
struct ComingSoonCard: View {
    let systemImage: String
    let title: String
    let message: String
    let items: [String]

    @Environment(\.l10n) private var l10n

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(ConciergeStyle.brass)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
            }
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        Label {
                            Text(item)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(ConciergeStyle.tint)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

/// A small rounded label ("British Male", "Professional").
struct InfoChip: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(ConciergeStyle.tint.opacity(0.12), in: Capsule())
            .foregroundStyle(ConciergeStyle.tint)
    }
}
