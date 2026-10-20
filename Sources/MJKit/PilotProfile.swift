import Foundation
import Combine

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

    /// Part 107 recurrent training is due within 24 calendar months of the last
    /// test/training (FAA: by the end of the 24th calendar month).
    public var recurrentTrainingDue: Date? {
        guard let base = lastRecurrentTrainingDate ?? part107IssueDate else { return nil }
        let calendar = Calendar.current
        guard let plus24 = calendar.date(byAdding: .month, value: 24, to: base),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: plus24)),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
              let endOfMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth) else { return nil }
        return endOfMonth
    }
}

/// Saves the profile as JSON in Application Support with complete file protection.
/// The Part 107 certificate number goes to MJSecureStore (Keychain), never to the JSON.
@MainActor
public final class PilotProfileStore: ObservableObject {
    @Published public private(set) var profile: PilotProfile

    private let fileURL: URL
    private let certKey = "mjkit.pilot.part107CertNumber"

    public init(fileName: String = "pilot-profile.json") {
        let fm = FileManager.default
        let dir = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        let url = dir.appendingPathComponent(fileName)
        self.fileURL = url
        var loaded = PilotProfile()
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(PilotProfile.self, from: data) {
            loaded = decoded
        }
        loaded.part107CertNumber = MJSecureStore.get("mjkit.pilot.part107CertNumber") ?? ""
        self.profile = loaded
    }

    public func save(_ newProfile: PilotProfile) {
        profile = newProfile
        if newProfile.part107CertNumber.isEmpty {
            MJSecureStore.delete(certKey)
        } else {
            MJSecureStore.set(newProfile.part107CertNumber, for: certKey)
        }
        if let data = try? JSONEncoder().encode(newProfile) {
            try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        }
    }

    /// Re-read the Keychain value (e.g. after the device was locked at launch).
    public func reloadSecureFields() {
        let cert = MJSecureStore.get(certKey) ?? ""
        if cert != profile.part107CertNumber { profile.part107CertNumber = cert }
    }
}
