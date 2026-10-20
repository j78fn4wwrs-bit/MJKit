import Foundation

/// Pilot profile shared by Mike's drone apps.
/// `part107CertNumber` is deliberately NOT in CodingKeys: it lives only in the Keychain.
public struct PilotProfile: Codable, Equatable {
    public var name: String = ""
    public var part107CertNumber: String = ""
    public var part107IssueDate: Date?
    public var lastRecurrentTrainingDate: Date?
    public var trustCompletionDate: Date?
    public var faaRegistrationNumbers: [String] = []
    public var notes: String = ""

    enum CodingKeys: String, CodingKey {
        case name, part107IssueDate, lastRecurrentTrainingDate, trustCompletionDate, faaRegistrationNumbers, notes
    }

    public init(name: String = "",
                part107CertNumber: String = "",
                part107IssueDate: Date? = nil,
                lastRecurrentTrainingDate: Date? = nil,
                trustCompletionDate: Date? = nil,
                faaRegistrationNumbers: [String] = [],
                notes: String = "") {
        self.name = name
        self.part107CertNumber = part107CertNumber
        self.part107IssueDate = part107IssueDate
        self.lastRecurrentTrainingDate = lastRecurrentTrainingDate
        self.trustCompletionDate = trustCompletionDate
        self.faaRegistrationNumbers = faaRegistrationNumbers
        self.notes = notes
    }

    /// Part 107 currency ends at 23:59:59 on the last day of the 24th calendar
    /// month after the last test or training (14 CFR 107.65). Falls back to the
    /// initial issue date when no recurrent date is recorded.
    public var recurrentTrainingDue: Date? {
        guard let base = lastRecurrentTrainingDate ?? part107IssueDate else { return nil }
        return Self.recurrentTrainingDue(from: base, calendar: .current)
    }

    /// End of the calendar month 24 months after `base`'s month, at 23:59:59.
    /// Month arithmetic uses year and month only, so Jan 31 and Feb 29 do not
    /// spill into the following month.
    static func recurrentTrainingDue(from base: Date, calendar: Calendar) -> Date? {
        let parts = calendar.dateComponents([.year, .month], from: base)
        guard let year = parts.year, let month = parts.month else { return nil }
        var start = DateComponents()
        start.calendar = calendar
        start.year = year
        start.month = month + 24
        start.day = 1
        guard let firstOfMonth = calendar.date(from: start),
              let dayRange = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return nil }
        let normalized = calendar.dateComponents([.year, .month], from: firstOfMonth)
        var end = DateComponents()
        end.calendar = calendar
        end.year = normalized.year
        end.month = normalized.month
        end.day = dayRange.upperBound - 1
        end.hour = 23
        end.minute = 59
        end.second = 59
        return calendar.date(from: end)
    }

    /// JSON fields only. The certificate number is stored in the Keychain, not the file.
    var hasProtectedFileContent: Bool {
        !name.isEmpty
            || part107IssueDate != nil
            || lastRecurrentTrainingDate != nil
            || trustCompletionDate != nil
            || !faaRegistrationNumbers.isEmpty
            || !notes.isEmpty
    }
}
