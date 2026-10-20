import XCTest

/// Guards the package rules that Linux can check without Apple frameworks:
/// no logging of values, no networking besides StoreKit, and the Keychain
/// attributes the iOS code must use.
final class SourcePolicyTests: XCTestCase {
    private var sourceFiles: [URL] {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sources = testsDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MJKit")
        let files = (try? FileManager.default.contentsOfDirectory(
            at: sources,
            includingPropertiesForKeys: nil
        )) ?? []
        return files.filter { $0.pathExtension == "swift" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func testSourcesExist() {
        XCTAssertFalse(sourceFiles.isEmpty)
    }

    func testNoLoggingOrNonStoreKitNetworking() throws {
        let forbidden = [
            "print(",
            "debugPrint(",
            "dump(",
            "NSLog(",
            "os_log(",
            "Logger(",
            "URLSession",
            "URLRequest",
            "dataTask",
            "NWConnection",
            "import Network",
            "CFNetwork"
        ]
        for url in sourceFiles {
            let text = try String(contentsOf: url, encoding: .utf8)
            for token in forbidden {
                XCTAssertFalse(
                    text.contains(token),
                    "\(url.lastPathComponent) contains \(token)"
                )
            }
        }
    }

    func testKeychainItemsAreDeviceOnlyAndWipeCoversEveryClass() throws {
        let url = try XCTUnwrap(sourceFiles.first { $0.lastPathComponent == "MJSecureStore.swift" })
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("kSecAttrAccessibleWhenUnlockedThisDeviceOnly"))
        XCTAssertFalse(text.contains("kSecAttrAccessibleWhenUnlocked,"))
        XCTAssertFalse(text.contains("kSecAttrAccessibleAfterFirstUnlock"))
        XCTAssertFalse(text.contains("kSecAttrAccessibleAlways"))
        XCTAssertTrue(text.contains("kCFBooleanFalse"))
        XCTAssertTrue(text.contains("kSecAttrSynchronizableAny"))
        XCTAssertTrue(text.contains("kSecClassGenericPassword"))
        XCTAssertTrue(text.contains("kSecClassInternetPassword"))
        XCTAssertTrue(text.contains("kSecClassCertificate"))
        XCTAssertTrue(text.contains("kSecClassKey"))
        XCTAssertTrue(text.contains("kSecClassIdentity"))
        XCTAssertTrue(text.contains("hasLaunched"))
        XCTAssertTrue(text.contains("#if canImport(Security)"))
    }

    func testAppleOnlyEntrypointsAreGuarded() throws {
        let guards: [String: String] = [
            "MJStore.swift": "canImport(StoreKit)",
            "MJPaywallView.swift": "canImport(SwiftUI)",
            "MJSettingsView.swift": "canImport(SwiftUI)",
            "MJBiometricGate.swift": "canImport(LocalAuthentication)",
            "PilotProfileStore.swift": "canImport(Security)"
        ]
        for (name, token) in guards {
            let url = try XCTUnwrap(sourceFiles.first { $0.lastPathComponent == name })
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertTrue(text.contains(token), "\(name) should be guarded by \(token)")
        }
    }

    func testBiometricGateUsesCompletionHandler() throws {
        let url = try XCTUnwrap(sourceFiles.first { $0.lastPathComponent == "MJBiometricGate.swift" })
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("@preconcurrency import LocalAuthentication"))
        XCTAssertTrue(text.contains("withCheckedContinuation"))
        XCTAssertTrue(text.contains(".deviceOwnerAuthentication"))
        XCTAssertFalse(text.contains("await context.evaluatePolicy"))
    }
}
