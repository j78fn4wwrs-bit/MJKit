#if canImport(Security)
import Foundation
import Security

/// Tiny Keychain wrapper. Items are this-device-only, never iCloud-synced,
/// and readable only while the device is unlocked. Never logs values.
public enum MJSecureStore {
    public static let defaultService: String = Bundle.main.bundleIdentifier ?? "MJKit"

    enum ReadResult {
        case found(String)
        case notFound
        case unavailable
    }

    @discardableResult
    public static func set(_ value: String, for key: String, service: String = defaultService) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let lookup = lookupQuery(account: key, service: service, returnData: false)
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(lookup as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return true }
        // Device locked, or some other failure: leave the existing item in place.
        if status != errSecItemNotFound { return false }
        let addStatus = SecItemAdd(addQuery(data: data, account: key, service: service) as CFDictionary, nil)
        if addStatus == errSecSuccess { return true }
        if addStatus == errSecDuplicateItem {
            // A synchronizable item can occupy the same account. Replace it
            // with a device-only, non-synchronizable item.
            guard delete(key, service: service) else { return false }
            return SecItemAdd(addQuery(data: data, account: key, service: service) as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    public static func get(_ key: String, service: String = defaultService) -> String? {
        if case .found(let value) = read(key, service: service) {
            return value
        }
        return nil
    }

    static func read(_ key: String, service: String = defaultService) -> ReadResult {
        let query = lookupQuery(account: key, service: service, returnData: true)
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
                return .notFound
            }
            return .found(string)
        case errSecItemNotFound:
            return .notFound
        default:
            return .unavailable
        }
    }

    @discardableResult
    public static func delete(_ key: String, service: String = defaultService) -> Bool {
        let status = SecItemDelete(deleteQuery(account: key, service: service) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Keychain items survive app deletion. When UserDefaults `hasLaunched` is missing,
    /// delete every item in the app's default access group, then set the flag.
    /// If the device is locked and deletion fails, the flag stays unset so the next
    /// launch can try again.
    public static func wipeIfFreshInstall(defaults: UserDefaults = .standard) {
        guard MJFreshInstall.needsWipe(defaults: defaults) else { return }
        guard deleteAllItems() else { return }
        MJFreshInstall.markLaunched(defaults: defaults)
    }

    @discardableResult
    static func deleteAllItems() -> Bool {
        for query in wipeAllItemsQueries() {
            let status = SecItemDelete(query as CFDictionary)
            if status == errSecSuccess || status == errSecItemNotFound {
                continue
            }
            if status == errSecParam, query[kSecAttrSynchronizable as String] != nil {
                var fallback = query
                fallback.removeValue(forKey: kSecAttrSynchronizable as String)
                let retry = SecItemDelete(fallback as CFDictionary)
                if retry == errSecSuccess || retry == errSecItemNotFound {
                    continue
                }
            }
            return false
        }
        return true
    }

    static func addQuery(data: Data, account: String, service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
    }

    static func lookupQuery(account: String, service: String, returnData: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        if returnData {
            query[kSecReturnData as String] = kCFBooleanTrue as Any
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }
        return query
    }

    static func deleteQuery(account: String, service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
    }

    /// One query per item class so a reinstall removes every item the app owns.
    /// Password classes match synchronizable and non-synchronizable items.
    static func wipeAllItemsQueries() -> [[String: Any]] {
        let passwordClasses: [CFString] = [kSecClassGenericPassword, kSecClassInternetPassword]
        let otherClasses: [CFString] = [kSecClassCertificate, kSecClassKey, kSecClassIdentity]
        var queries: [[String: Any]] = []
        for itemClass in passwordClasses {
            queries.append([
                kSecClass as String: itemClass,
                kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
            ])
        }
        for itemClass in otherClasses {
            queries.append([
                kSecClass as String: itemClass
            ])
        }
        return queries
    }
}
#endif
