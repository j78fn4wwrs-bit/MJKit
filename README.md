# MJKit

Shared Swift package for Mike Johnson's iOS apps (iOS 18+, swift-tools 5.10).

| Piece | What it does |
|---|---|
| `MJStore` | StoreKit 2 one-time unlock: `init(proProductIDs:)`, `isPro`, `products`, `loadProducts()`, `purchase()`, `restore()`, listens to `Transaction.updates`. |
| `MJPaywallView` | Honest paywall: features, price, Unlock, Restore, Privacy/Terms links. |
| `MJSecureStore` | Keychain `set/get/delete`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, never synchronizable. |
| `MJBiometricGate` | `authenticate(reason:) async -> Bool`, Face ID with passcode fallback. |
| `PilotProfile` / `PilotProfileStore` | Pilot data as JSON with `.completeFileProtection`. Part 107 cert number stored only in Keychain. `recurrentTrainingDue` = end of 24th month. |
| `MJSettingsView` | About, version, restore, privacy/terms sections for a `Form`. |

`MJSecureStore.wipeIfFreshInstall()` — call at app start: deletes leftover Keychain items after a reinstall (uses UserDefaults `hasLaunched`; apps must declare UserDefaults CA92.1 in PrivacyInfo.xcprivacy).

Rules: no networking except StoreKit, no analytics, never log user values.

## Use (XcodeGen)
```yaml
packages:
  MJKit:
    url: https://github.com/j78fn4wwrs-bit/MJKit
    branch: main
targets:
  MyApp:
    dependencies:
      - package: MJKit
```
Apps using Face ID must add `NSFaceIDUsageDescription` to their Info.plist.
