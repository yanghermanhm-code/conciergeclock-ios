import ConciergeCore
import GGSBrand
import SwiftUI

/// Concierge tab: the butler himself. Phase 1a introduces him and his settings; Phase 2 adds
/// "Brief me now" (the spoken schedule), Phase 3 the conversation and Nightstand Mode, and
/// Phase 6 "Ask me about my day".
struct ConciergeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingButlerSettings = false

    var body: some View {
        let persona = model.persona
        ScrollView {
            VStack(spacing: 16) {
                greeting(persona)
                TodayCard()
                nextAlarmCard
                calendarsCard
                offlineAICard
                ComingSoonCard(
                    systemImage: "text.bubble",
                    title: l10n["concierge.soon.title"],
                    message: l10n["concierge.soon.message"],
                    items: [
                        l10n["concierge.soon.talk"],
                        l10n["concierge.soon.nightstand"],
                        l10n["concierge.soon.ask"],
                        l10n["concierge.soon.reminders"],
                    ]
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.background)
        .task { await model.briefings.refresh() }
        .refreshable { await model.briefings.refresh() }
        .sheet(isPresented: $showingButlerSettings) {
            NavigationStack {
                ButlerSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(l10n["common.done"]) { showingButlerSettings = false }
                        }
                    }
            }
            .tint(ConciergeStyle.tint)
        }
    }

    private func greeting(_ persona: Persona) -> some View {
        VStack(spacing: 14) {
            ButlerNetworkMark(style: colorScheme == .dark ? .onDark : .standard)
                .frame(height: 120)
                .padding(.top, 4)
            Text(greetingText)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(l10n("concierge.introduction", persona.displayName))
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Text(l10n.toneSample(persona.tone, name: persona.displayName))
                .font(.callout.italic())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            FlowChips(chips: personaChips(persona))
            Button {
                showingButlerSettings = true
            } label: {
                Label(l10n["concierge.customize"], systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("concierge.customize")

            Button {
                model.briefMeNow()
            } label: {
                Label(
                    model.speech.state == .speaking ? l10n["concierge.stop"] : l10n["concierge.briefMe"],
                    systemImage: model.speech.state == .speaking ? "stop.fill" : "speaker.wave.2"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("concierge.briefMe")
            if let briefing = model.speech.current {
                TranscriptView(briefing: briefing, currentLineID: model.speech.currentLineID)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    /// Voice (English only: accents apply to English), tone, briefing length and language.
    private func personaChips(_ persona: Persona) -> [(String, String)] {
        var chips: [(String, String)] = []
        if persona.usesAccent {
            chips.append((l10n.accentName(persona.accent), "person.wave.2"))
        }
        chips.append((l10n.toneName(persona.tone), "theatermasks"))
        chips.append((l10n.lengthName(persona.length), "text.alignleft"))
        chips.append((l10n.languageName(code: persona.languageCode), "globe"))
        return chips
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return l10n["concierge.greeting.morning"]
        case 12..<17: return l10n["concierge.greeting.afternoon"]
        case 17..<22: return l10n["concierge.greeting.evening"]
        default: return l10n["concierge.greeting.night"]
        }
    }

    private var nextAlarmCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "alarm")
                .font(.title2)
                .foregroundStyle(ConciergeStyle.brass)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n["concierge.nextAlarm"])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                if let next = model.nextAlarm() {
                    Text(l10n.dateTime(next.date))
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    Text(l10n["concierge.noAlarm"])
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            Spacer()
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    /// Which calendars the concierge reads, with a way to connect more (Google, Outlook…).
    private var calendarsCard: some View {
        let calendars = model.calendars
        return NavigationLink {
            CalendarAccountsView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundStyle(ConciergeStyle.brass)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n["calendars.title"])
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    if calendars.eventAccess == .granted {
                        Text(l10n("calendars.connectedSummary", calendars.calendarAccounts.count,
                                  calendars.eventCountToday(excluding: Set(model.settings.settings.excludedCalendarIDs)) ?? 0))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                    } else {
                        Text(l10n["calendars.connectPrompt"])
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("concierge.calendars")
    }

    private var offlineAICard: some View {
        let models = model.models
        return HStack(spacing: 14) {
            Image(systemName: "cpu")
                .font(.title2)
                .foregroundStyle(ConciergeStyle.brass)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n["ai.title"])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                if let spec = models.activeSpec {
                    Text(l10n("concierge.ai.ready", spec.displayName))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                } else if models.isSupported {
                    Text(l10n["concierge.ai.setup"])
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    Text(l10n["concierge.ai.unsupported"])
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            Spacer()
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

/// Chips that wrap onto as many lines as they need.
private struct FlowChips: View {
    let chips: [(String, String)]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                InfoChip(text: chip.0, systemImage: chip.1)
            }
        }
    }
}

/// A minimal wrapping layout: places subviews left to right and starts a new row when the
/// next one does not fit. Rows are centred.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, width: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// The briefing as text while it is spoken, with the current sentence highlighted.
private struct TranscriptView: View {
    let briefing: Briefing
    let currentLineID: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(briefing.lines) { line in
                Text(line.text)
                    .font(.callout)
                    .foregroundStyle(line.id == currentLineID ? Theme.textPrimary : Theme.textSecondary)
                    .fontWeight(line.id == currentLineID ? .semibold : .regular)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(Theme.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .environment(\.layoutDirection, AppLanguage(rawValue: briefing.languageCode)?.isRightToLeft == true ? .rightToLeft : .leftToRight)
        .accessibilityElement(children: .combine)
    }
}

/// Today's events and due reminders with their importance, as the butler will read them.
private struct TodayCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.l10n) private var l10n

    var body: some View {
        let briefings = model.briefings
        let items = briefings.items.filter { !($0.item.kind == .event && $0.item.isAllDay && $0.importance == .low) }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(l10n["today.title"])
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if briefings.isRanking {
                    ProgressView()
                        .controlSize(.small)
                    Text(l10n["today.ranking"])
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            if model.calendars.eventAccess != .granted && model.calendars.reminderAccess != .granted {
                Text(l10n["today.noAccess"])
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else if items.isEmpty {
                Text(l10n["today.empty"])
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(items) { ranked in
                    TodayRow(ranked: ranked)
                }
                Text(briefings.usesOfflineAI ? l10n["today.source.ai"] : l10n["today.source.rules"])
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

private struct TodayRow: View {
    let ranked: RankedItem
    @Environment(\.l10n) private var l10n

    var body: some View {
        let item = ranked.item
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: item.kind == .event ? "calendar" : "checklist")
                .foregroundStyle(ConciergeStyle.brass)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title.nonBlank ?? l10n["today.untitled"])
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail(item))
                    .font(.caption)
                    .foregroundStyle(item.isOverdue ? Color.orange : Theme.textSecondary)
            }
            Spacer(minLength: 0)
            if ranked.importance == .high {
                Text(l10n["today.important"])
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(ConciergeStyle.brass.opacity(0.18), in: Capsule())
                    .foregroundStyle(ConciergeStyle.brass)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func detail(_ item: BriefingItem) -> String {
        if item.kind == .reminder {
            if item.isOverdue { return l10n["today.overdue"] }
            return item.date.map { l10n("today.due", l10n.time($0)) } ?? l10n["today.dueToday"]
        }
        if item.isAllDay { return l10n["today.allDay"] }
        return [item.date.map { l10n.time($0) }, item.location].compactMap { $0 }.joined(separator: " · ")
    }
}
