import ConciergeCore
import GGSBrand
import SwiftUI

/// Trends tab. Phase 1a explains the wake score with the current rules (already used to score
/// every logged morning); Phase 5 adds the charts and the Wake Optimization Advisor.
struct TrendsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n

    var body: some View {
        let rules = model.settings.settings.wakeScoreRules
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(l10n["trends.score.title"])
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(l10n["trends.score.intro"])
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ruleRow("clock.badge.exclamationmark", l10n("trends.score.late", rules.pointsPerLateMinute, rules.graceMinutes, rules.maxLatePenalty))
                    ruleRow("zzz", l10n("trends.score.snooze", rules.pointsPerSnooze))
                    ruleRow("person.wave.2", l10n("trends.score.check", rules.missedCheckPenalty))
                    ruleRow("checkmark.seal", l10n("trends.score.success", rules.successThreshold))
                    Text(l10n["trends.score.change"])
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                Text(l10n("trends.logged", model.wakeEventCount))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ComingSoonCard(
                    systemImage: "chart.xyaxis.line",
                    title: l10n["trends.soon.title"],
                    message: l10n["trends.soon.message"],
                    items: [
                        l10n["trends.soon.chart"],
                        l10n["trends.soon.metrics"],
                        l10n["trends.soon.advisor"],
                        l10n["trends.soon.experiments"],
                        l10n["trends.soon.health"],
                    ]
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.background)
    }

    private func ruleRow(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(ConciergeStyle.brass)
        }
    }
}
