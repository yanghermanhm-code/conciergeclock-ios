import ConciergeCore
import Foundation
import GRDB

// GRDB record conformances live here (not in ConciergeCore) so the core models stay
// Foundation-only and portable. Column names match the Swift property names; nested
// Codable values (repeat days, parameters) are stored as JSON text.

extension Alarm: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "alarm"
}

extension WakeEvent: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "wakeEvent"
}

extension Recommendation: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "recommendation"
}

extension AlarmOccurrence: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "alarmOccurrence"
}
