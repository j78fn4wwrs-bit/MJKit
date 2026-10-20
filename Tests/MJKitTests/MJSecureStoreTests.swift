#if canImport(Security)
import XCTest
import Security
@testable import MJKit

final class MJSecureStoreTests: XCTestCase {
    func testAddQueryIsDeviceOnlyAndNotSynchronizable() {
        let query = MJSecureStore.addQuery(data: Data("secret".utf8), account: "acct", service: "svc")
        XCTAssertTrue(cfEqual(query[kSecAttrAccessible as String], kSecAttrAccessibleWhenUnlockedThisDeviceOnly))
        XCTAssertTrue(cfEqual(query[kSecAttrSynchronizable as String], kCFBooleanFalse))
        XCTAssertEqual(query[kSecClass as String] as? String, kSecClassGenericPassword as String)
        XCTAssertEqual(query[kSecAttrAccount as String] as? String, "acct")
        XCTAssertEqual(query[kSecAttrService as String] as? String, "svc")
    }

    func testLookupDoesNotMatchSynchronizableItems() {
        let query = MJSecureStore.lookupQuery(account: "acct", service: "svc", returnData: true)
        XCTAssertTrue(cfEqual(query[kSecAttrSynchronizable as String], kCFBooleanFalse))
        XCTAssertTrue(cfEqual(query[kSecReturnData as String], kCFBooleanTrue))
        XCTAssertTrue(cfEqual(query[kSecMatchLimit as String], kSecMatchLimitOne))
    }

    func testDeleteMatchesSynchronizableAndLocalItems() {
        let query = MJSecureStore.deleteQuery(account: "acct", service: "svc")
        XCTAssertTrue(cfEqual(query[kSecAttrSynchronizable as String], kSecAttrSynchronizableAny))
    }

    func testWipeQueriesCoverEveryClass() {
        let queries = MJSecureStore.wipeAllItemsQueries()
        let classes = Set(queries.compactMap { $0[kSecClass as String] as? String })
        XCTAssertEqual(classes, Set([
            kSecClassGenericPassword as String,
            kSecClassInternetPassword as String,
            kSecClassCertificate as String,
            kSecClassKey as String,
            kSecClassIdentity as String
        ]))
        for query in queries {
            let itemClass = query[kSecClass as String] as? String
            if itemClass == kSecClassGenericPassword as String || itemClass == kSecClassInternetPassword as String {
                XCTAssertTrue(cfEqual(query[kSecAttrSynchronizable as String], kSecAttrSynchronizableAny))
            } else {
                XCTAssertNil(query[kSecAttrSynchronizable as String])
            }
            XCTAssertNil(query[kSecAttrAccount as String], "wipe must not be limited to one account")
            XCTAssertNil(query[kSecAttrService as String], "wipe must not be limited to one service")
        }
    }

    private func cfEqual(_ lhs: Any?, _ rhs: AnyObject) -> Bool {
        guard let lhs = lhs as AnyObject? else { return false }
        return CFEqual(lhs, rhs)
    }
}
#endif
