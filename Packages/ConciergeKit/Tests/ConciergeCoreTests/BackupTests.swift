@testable import ConciergeCore
import XCTest

final class BackupTests: XCTestCase {
    /// Whole milliseconds, so ISO-8601 round trips compare equal.
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func samplePayload() -> BackupPayload {
        var settings = AppSettings()
        settings.butlerName = ButlerName(formal: "Barrington", familiar: "Barry")
        settings.tone = .unhinged
        let alarm = Alarm(id: "A1", label: "Work, \"early\"", hour: 6, minute: 45, createdAt: t0)
        let event = WakeEvent(
            id: "E1", alarmID: "A1", alarmLabel: "Work", scheduledAt: t0, dismissedAt: t0.addingTimeInterval(300),
            dismissMethod: .voice, snoozeCount: 1, snoozedMinutes: 5, calendar: utc, createdAt: t0
        )
        let recommendation = Recommendation(id: "R1", kind: .addRampUp, alarmID: "A1", parameters: ["seconds": "60"], createdAt: t0)
        return BackupPayload(createdAt: t0, appVersion: "1.0", settings: settings, alarms: [alarm], wakeEvents: [event], recommendations: [recommendation])
    }

    func testRoundTrip() throws {
        let payload = samplePayload()
        let data = try payload.encoded()
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"schemaVersion\" : 1"))
        XCTAssertTrue(text.contains("\"format\" : \"conciergeclock-backup\""))
        XCTAssertTrue(text.contains("Z\""), "dates are ISO-8601 UTC")
        XCTAssertEqual(try BackupPayload.decode(data), payload)
    }

    func testRejectsOtherFilesAndNewerVersions() throws {
        XCTAssertThrowsError(try BackupPayload.decode(Data("hello".utf8))) { XCTAssertEqual($0 as? BackupError, .notABackup) }
        XCTAssertThrowsError(try BackupPayload.decode(Data(#"{"format":"preppilot-backup","schemaVersion":1}"#.utf8))) {
            XCTAssertEqual($0 as? BackupError, .notABackup)
        }
        var object = try JSONSerialization.jsonObject(with: samplePayload().encoded()) as! [String: Any]
        object["schemaVersion"] = SchemaVersion.backup + 1
        let newer = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try BackupPayload.decode(newer)) { XCTAssertEqual($0 as? BackupError, .newerVersion) }
    }

    func testIntegrityFindsDuplicates() {
        var payload = samplePayload()
        XCTAssertTrue(payload.integrityIssues.isEmpty)
        payload.alarms.append(payload.alarms[0])
        XCTAssertEqual(payload.integrityIssues, ["duplicate alarm"])
    }

    func testFileName() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(BackupPayload.fileName(at: t0, calendar: calendar), "ConciergeClock Backup 2026-09-21 1413.conciergeclock")
    }

    func testCSVQuotingAndFormulaGuard() {
        XCTAssertEqual(CSVExport.escape("plain"), "plain")
        XCTAssertEqual(CSVExport.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(CSVExport.escape("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(CSVExport.escape("=SUM(A1)"), "'=SUM(A1)")
        XCTAssertEqual(CSVExport.escape("-2"), "-2")
        XCTAssertEqual(CSVExport.decimal(8), "8")
        XCTAssertEqual(CSVExport.decimal(-2.25), "-2.3")
    }

    func testWakeLogCSV() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let csv = CSVExport.wakeLog(samplePayload().wakeEvents, calendar: calendar)
        let lines = csv.components(separatedBy: "\r\n")
        XCTAssertEqual(lines[0], "date,alarm,scheduled,woke,variance_minutes,snoozes,snoozed_minutes,dismissed_by,awake_check,score,success,nightstand_mode,ambient_sound,wake_sound,volume")
        XCTAssertTrue(lines[1].hasPrefix("2026-09-21,Work,2026-09-21 14:13,2026-09-21 14:18,5,1,5,voice,notAsked,"))
    }
}
