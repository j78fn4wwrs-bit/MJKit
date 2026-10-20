#if canImport(LocalAuthentication)
import Foundation
// LAContext is not Sendable. The async evaluatePolicy overlay captures it in a
// @Sendable closure and warns under Swift 6. @preconcurrency keeps that SDK gap
// from failing the build; the call below is the completion-handler API.
@preconcurrency import LocalAuthentication

/// Face ID / Touch ID with device-passcode fallback.
/// `.deviceOwnerAuthentication` tries biometrics first, then the device passcode.
public enum MJBiometricGate {
    public static func authenticate(reason: String) async -> Bool {
        // Create the context inside the continuation closure so it is not captured
        // from an outer scope. The reply resumes with a Bool and does not touch
        // the context or the error.
        await withCheckedContinuation { continuation in
            let context = LAContext()
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                continuation.resume(returning: false)
                return
            }
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
#endif
