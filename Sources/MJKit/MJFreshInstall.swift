import Foundation

/// Distinguishes a reinstall: Keychain items survive deletion, UserDefaults do not.
/// The flag name is part of the contract with apps that call `wipeIfFreshInstall()`.
enum MJFreshInstall {
    static let defaultsKey = "hasLaunched"

    /// True only when the flag has never been written. An explicit `false` is present
    /// and must not be treated as a fresh install.
    static func needsWipe(defaults: UserDefaults) -> Bool {
        defaults.object(forKey: defaultsKey) == nil
    }

    static func markLaunched(defaults: UserDefaults) {
        defaults.set(true, forKey: defaultsKey)
    }
}
