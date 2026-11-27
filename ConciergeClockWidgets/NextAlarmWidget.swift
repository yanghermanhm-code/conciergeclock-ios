import ConciergeCore
import GGSBrand
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct NextAlarmEntry: TimelineEntry {
    let date: Date
    let snapshot: NextAlarmSnapshot?
}

struct NextAlarmProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextAlarmEntry {
        NextAlarmEntry(date: Date(), snapshot: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextAlarmEntry) -> Void) {
        let snapshot = Self.load()
        completion(NextAlarmEntry(date: Date(), snapshot: context.isPreview && snapshot?.fireDate == nil ? Self.sample : snapshot))
    }

    /// One entry now; the app reloads the timeline whenever the next alarm changes, and the
    /// widget refreshes itself just after the alarm time.
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextAlarmEntry>) -> Void) {
        let snapshot = Self.load()
        let refresh = snapshot?.fireDate.map { $0.addingTimeInterval(60) } ?? Date().addingTimeInterval(6 * 3600)
        completion(Timeline(entries: [NextAlarmEntry(date: Date(), snapshot: snapshot)], policy: .after(refresh)))
    }

    static func load() -> NextAlarmSnapshot? {
        SharedConfig.containerURL.flatMap(NextAlarmSnapshot.read(from:))
    }

    static let sample = NextAlarmSnapshot(
        fireDate: Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date().addingTimeInterval(86_400)),
        label: "", enabledAlarmCount: 1, languageCode: nil
    )
}

// MARK: - Widget

struct NextAlarmWidget: Widget {
    var body: some WidgetConfiguration {
        let strings = WidgetStrings(languageCode: NextAlarmProvider.load()?.languageCode)
        return StaticConfiguration(kind: SharedConfig.nextAlarmWidgetKind, provider: NextAlarmProvider()) { entry in
            NextAlarmView(entry: entry)
        }
        .configurationDisplayName(strings["widget.name"])
        .description(strings["widget.description"])
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

// MARK: - Views

struct NextAlarmView: View {
    let entry: NextAlarmEntry
    @Environment(\.widgetFamily) private var family

    private var strings: WidgetStrings { WidgetStrings(languageCode: entry.snapshot?.languageCode) }
    private var fireDate: Date? { entry.snapshot?.fireDate.flatMap { $0 > entry.date ? $0 : nil } }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .systemSmall {
                    LinearGradient(colors: [Color(hex: 0x0D3B5C), Color(hex: 0x051A2B)], startPoint: .topTrailing, endPoint: .bottomLeading)
                } else {
                    Color.clear
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            if let fireDate {
                Label(time(fireDate), systemImage: "alarm")
            } else {
                Label(strings["widget.none"], systemImage: "alarm")
            }
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "alarm")
                    .font(.caption)
                Text(fireDate.map { time($0) } ?? "—")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .minimumScaleFactor(0.6)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label(strings["widget.next"], systemImage: "alarm")
                    .font(.caption)
                if let fireDate {
                    Text(time(fireDate))
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                    Text(subtitle(fireDate))
                        .font(.caption2)
                        .lineLimit(1)
                } else {
                    Text(strings["widget.none"])
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ButlerNetworkMark(style: .onDark)
                        .frame(width: 30, height: 28)
                    Spacer()
                    Image(systemName: "alarm")
                        .foregroundStyle(Brand.brassOnDark)
                }
                Spacer(minLength: 0)
                Text(strings["widget.next"])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
                if let fireDate {
                    Text(time(fireDate))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(.white)
                    Text(subtitle(fireDate))
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(Brand.tealOnDark)
                } else {
                    Text(strings["widget.none"])
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(strings.locale))
    }

    /// "Tomorrow · Gym", "Monday", …
    private func subtitle(_ date: Date) -> String {
        let day: String
        if Calendar.current.isDateInToday(date) {
            day = strings["widget.today"]
        } else if Calendar.current.isDateInTomorrow(date) {
            day = strings["widget.tomorrow"]
        } else {
            day = date.formatted(Date.FormatStyle().weekday(.wide).locale(strings.locale))
        }
        return [day, entry.snapshot?.label.nonBlank].compactMap { $0 }.joined(separator: " · ")
    }
}
