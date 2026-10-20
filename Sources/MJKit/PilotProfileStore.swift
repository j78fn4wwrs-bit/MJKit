#if canImport(Security) && canImport(Combine)
import Foundation
import Combine

/// Saves the profile as JSON in Application Support with complete file protection.
/// The Part 107 certificate number goes to MJSecureStore (Keychain), never to the JSON.
@MainActor
public final class PilotProfileStore: ObservableObject {
    @Published public private(set) var profile: PilotProfile

    private let fileURL: URL
    private let certKey = "mjkit.pilot.part107CertNumber"
    /// False when the Keychain could not be read (for example the device was locked).
    /// Save must not delete a certificate number that was never loaded.
    private var keychainReadable = false
    /// False when the profile file exists but could not be read. Save must not replace it
    /// with an empty in-memory profile.
    private var profileFileReadable = true

    public init(fileName: String = "pilot-profile.json") {
        let fm = FileManager.default
        let dir = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        let url = dir.appendingPathComponent(fileName)
        self.fileURL = url
        var loaded = PilotProfile()
        var fileReadable = true
        if fm.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(PilotProfile.self, from: data) {
                loaded = decoded
            } else {
                fileReadable = false
            }
        }
        switch MJSecureStore.read(certKey) {
        case .found(let cert):
            loaded.part107CertNumber = cert
            keychainReadable = true
        case .notFound:
            loaded.part107CertNumber = ""
            keychainReadable = true
        case .unavailable:
            loaded.part107CertNumber = ""
            keychainReadable = false
        }
        self.profileFileReadable = fileReadable
        self.profile = loaded
    }

    public func save(_ newProfile: PilotProfile) {
        profile = newProfile
        let cert = newProfile.part107CertNumber
        if keychainReadable || !cert.isEmpty {
            let wrote: Bool
            if cert.isEmpty {
                wrote = MJSecureStore.delete(certKey)
            } else {
                wrote = MJSecureStore.set(cert, for: certKey)
            }
            if wrote {
                keychainReadable = true
            }
        }
        writeProfileFileIfSafe(newProfile)
    }

    /// Re-read the Keychain value, and the protected profile file if the device was locked at launch.
    public func reloadSecureFields() {
        switch MJSecureStore.read(certKey) {
        case .found(let cert):
            keychainReadable = true
            if cert != profile.part107CertNumber {
                profile.part107CertNumber = cert
            }
        case .notFound:
            keychainReadable = true
            if !profile.part107CertNumber.isEmpty {
                profile.part107CertNumber = ""
            }
        case .unavailable:
            break
        }
        guard !profileFileReadable, !profile.hasProtectedFileContent else { return }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(PilotProfile.self, from: data) else { return }
        profileFileReadable = true
        var merged = decoded
        merged.part107CertNumber = profile.part107CertNumber
        profile = merged
    }

    private func writeProfileFileIfSafe(_ newProfile: PilotProfile) {
        // An empty profile must not replace a file we failed to read (device locked
        // or data protection). Once the user has entered JSON fields, try the write.
        if !profileFileReadable && !newProfile.hasProtectedFileContent {
            return
        }
        guard let data = try? JSONEncoder().encode(newProfile) else { return }
        do {
            try data.write(to: fileURL, options: Self.fileWriteOptions)
            profileFileReadable = true
        } catch {
            // Leave the previous file in place. Do not log the profile or the path.
        }
    }

    private static var fileWriteOptions: Data.WritingOptions {
        var options: Data.WritingOptions = [.atomic]
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
        options.insert(.completeFileProtection)
        #endif
        return options
    }
}
#endif
