import XCTest
@testable import MJKit

final class FreshInstallTests: XCTestCase {
    func testNeedsWipeOnlyWhenHasLaunchedIsMissing() {
        let suite = "mjkit.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertTrue(MJFreshInstall.needsWipe(defaults: defaults))

        defaults.set(false, forKey: MJFreshInstall.defaultsKey)
        XCTAssertFalse(MJFreshInstall.needsWipe(defaults: defaults))

        defaults.removeObject(forKey: MJFreshInstall.defaultsKey)
        XCTAssertNil(defaults.object(forKey: MJFreshInstall.defaultsKey))
        XCTAssertTrue(MJFreshInstall.needsWipe(defaults: defaults))

        MJFreshInstall.markLaunched(defaults: defaults)
        XCTAssertFalse(MJFreshInstall.needsWipe(defaults: defaults))
        XCTAssertEqual(defaults.bool(forKey: MJFreshInstall.defaultsKey), true)
        XCTAssertEqual(MJFreshInstall.defaultsKey, "hasLaunched")
    }
}
