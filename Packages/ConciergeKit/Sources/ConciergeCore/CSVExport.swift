import Foundation

/// Spreadsheet exports (UTF-8 CSV with a header row, RFC 4180 quoting). Column names are
/// English and stable, so spreadsheets and scripts can rely on them; see docs/DATA_SCHEMA.md.
public enum CSVExport {
    /// One row per alarm cycle.
    public static func wakeLog(_ events: [WakeEvent], calendar: Calendar = .current) -> String {
        let header = [
            "date", "alarm", "scheduled", "woke", "variance_minutes", "snoozes", "snoozed_minutes",
            "dismissed_by", "awake_check", "score", "success", "nightstand_mode", "ambient_sound", "wake_sound", "volume",
        ]
        let rows = events.sorted { $0.scheduledAt < $1.scheduledAt }.map { event -> [String] in
            [
                event.dateKey.rawValue,
                event.alarmLabel,
                localTime(event.scheduledAt, calendar: calendar),
                event.dismissedAt.map { localTime($0, calendar: calendar) } ?? "",
                event.varianceMinutes.map { decimal($0) } ?? "",
                String(event.snoozeCount),
                String(event.snoozedMinutes),
                event.dismissMethod.rawValue,
                event.awakeCheck.rawValue,
                String(event.score),
                event.isSuccess ? "yes" : "no",
                event.nightstandMode ? "yes" : "no",
                event.ambientSoundID ?? "",
                event.wakeSoundID ?? "",
                event.volume.map { decimal($0 * 100) } ?? "",
            ]
        }
        return table(header: header, rows: rows)
    }

    /// One row per alarm.
    public static func alarms(_ alarms: [Alarm]) -> String {
        let header = ["label", "time", "repeats_on", "enabled", "snooze_minutes", "tone", "accent", "briefing", "sound", "ramp_up_seconds"]
        let dayNames = [1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"]
        let rows = alarms.sorted { $0.minuteOfDay < $1.minuteOfDay }.map { alarm -> [String] in
            [
                alarm.label,
                String(format: "%02d:%02d", alarm.hour, alarm.minute),
                Weekdays.all.filter { alarm.repeatDays.contains($0) }.compactMap { dayNames[$0] }.joined(separator: " "),
                alarm.isEnabled ? "yes" : "no",
                alarm.snoozeMinutes.map(String.init) ?? "default",
                alarm.toneOverride?.rawValue ?? "default",
                alarm.accentOverride?.rawValue ?? "default",
                alarm.lengthOverride?.rawValue ?? "default",
                alarm.soundID,
                String(alarm.rampUpSeconds),
            ]
        }
        return table(header: header, rows: rows)
    }

    // MARK: Helpers

    static func table(header: [String], rows: [[String]]) -> String {
        ([header] + rows).map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /// Quotes a field when it holds a comma, quote or line break; doubles inner quotes. A
    /// leading = + - @ is prefixed with an apostrophe so spreadsheets never run it as a formula.
    static func escape(_ field: String) -> String {
        var value = field
        if let first = value.first, "=+-@".contains(first), Double(value) == nil {
            value = "'" + value
        }
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// "2026-11-27 07:05" in the user's time zone.
    static func localTime(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(format: "%04d-%02d-%02d %02d:%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0)
    }

    /// Up to one decimal, with a dot ("8.5", "-2", "0").
    static func decimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(format: "%.1f", rounded)
    }
}
