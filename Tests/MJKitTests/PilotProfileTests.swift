import XCTest
@testable import MJKit

final class PilotProfileTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testRecurrentTrainingDueIsEndOf24thCalendarMonth() {
        let calendar = utc
        // FAA example shape: a test on May 1 is current through the end of May, 24 months later.
        let base = calendar.date(from: DateComponents(year: 2021, month: 5, day: 1, hour: 15))!
        let due = PilotProfile.recurrentTrainingDue(from: base, calendar: calendar)!
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: due)
        XCTAssertEqual(parts.year, 2023)
        XCTAssertEqual(parts.month, 5)
        XCTAssertEqual(parts.day, 31)
        XCTAssertEqual(parts.hour, 23)
        XCTAssertEqual(parts.minute, 59)
        XCTAssertEqual(parts.second, 59)
    }

    func testMonthEndUsesTheCalendarMonthNotTheDay() {
        let calendar = utc
        let january31 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 31))!
        let due = PilotProfile.recurrentTrainingDue(from: january31, calendar: calendar)!
        let parts = calendar.dateComponents([.year, .month, .day], from: due)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 1)
        XCTAssertEqual(parts.day, 31)
    }

    func testLeapDayStaysInFebruary() {
        let calendar = utc
        let leapDay = calendar.date(from: DateComponents(year: 2024, month: 2, day: 29))!
        let due = PilotProfile.recurrentTrainingDue(from: leapDay, calendar: calendar)!
        let parts = calendar.dateComponents([.year, .month, .day], from: due)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 2)
        XCTAssertEqual(parts.day, 28)
    }

    func testDecemberRollsTheYear() {
        let calendar = utc
        let base = calendar.date(from: DateComponents(year: 2024, month: 12, day: 2))!
        let due = PilotProfile.recurrentTrainingDue(from: base, calendar: calendar)!
        let parts = calendar.dateComponents([.year, .month, .day], from: due)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 12)
        XCTAssertEqual(parts.day, 31)
    }

    func testPropertyPrefersRecurrentDateAndFallsBackToIssueDate() {
        let calendar = Calendar.current
        let recurrent = calendar.date(from: DateComponents(year: 2024, month: 7, day: 15))!
        let issued = calendar.date(from: DateComponents(year: 2020, month: 1, day: 4))!
        var profile = PilotProfile(part107IssueDate: issued, lastRecurrentTrainingDate: recurrent)
        XCTAssertEqual(profile.recurrentTrainingDue, PilotProfile.recurrentTrainingDue(from: recurrent, calendar: calendar))
        profile.lastRecurrentTrainingDate = nil
        XCTAssertEqual(profile.recurrentTrainingDue, PilotProfile.recurrentTrainingDue(from: issued, calendar: calendar))
        profile.part107IssueDate = nil
        XCTAssertNil(profile.recurrentTrainingDue)
    }

    func testCodableOmitsCertificateNumber() throws {
        let profile = PilotProfile(
            name: "Alex Rivera",
            part107CertNumber: "CERT-SHOULD-NOT-LEAK-998877",
            part107IssueDate: Date(timeIntervalSince1970: 1_700_000_000),
            faaRegistrationNumbers: ["FA12345678"],
            notes: "Night waiver notes"
        )
        let data = try JSONEncoder().encode(profile)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains("CERT-SHOULD-NOT-LEAK-998877"))
        XCTAssertFalse(json.contains("part107CertNumber"))
        XCTAssertTrue(json.contains("Alex Rivera"))
        XCTAssertTrue(json.contains("FA12345678"))
        XCTAssertTrue(json.contains("Night waiver notes"))

        let decoded = try JSONDecoder().decode(PilotProfile.self, from: data)
        XCTAssertEqual(decoded.part107CertNumber, "")
        XCTAssertEqual(decoded.name, profile.name)
        XCTAssertEqual(decoded.faaRegistrationNumbers, profile.faaRegistrationNumbers)
        XCTAssertEqual(decoded.notes, profile.notes)
        XCTAssertEqual(decoded.part107IssueDate, profile.part107IssueDate)
    }

    func testProtectedFileContentIgnoresCertificateNumber() {
        XCTAssertFalse(PilotProfile().hasProtectedFileContent)
        XCTAssertFalse(PilotProfile(part107CertNumber: "998877").hasProtectedFileContent)
        XCTAssertTrue(PilotProfile(name: "Alex").hasProtectedFileContent)
        XCTAssertTrue(PilotProfile(notes: "waiver").hasProtectedFileContent)
        XCTAssertTrue(PilotProfile(faaRegistrationNumbers: ["FA1"]).hasProtectedFileContent)
        XCTAssertTrue(PilotProfile(part107IssueDate: Date(timeIntervalSince1970: 0)).hasProtectedFileContent)
    }
}
