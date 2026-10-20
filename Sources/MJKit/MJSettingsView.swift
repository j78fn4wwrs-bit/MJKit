import SwiftUI

/// Standard settings sections: about, restore, privacy/terms, version.
/// Place inside a `Form` or `List`.
public struct MJSettingsView: View {
    @ObservedObject private var store: MJStore
    private let appName: String
    private let aboutText: String
    private let privacyURL: URL
    private let termsURL: URL

    public init(store: MJStore, appName: String, aboutText: String, privacyURL: URL, termsURL: URL) {
        self._store = ObservedObject(wrappedValue: store)
        self.appName = appName
        self.aboutText = aboutText
        self.privacyURL = privacyURL
        self.termsURL = termsURL
    }

    public var body: some View {
        Section("About \(appName)") {
            Text(aboutText)
                .font(.footnote)
            LabeledContent("Version", value: Self.versionString)
        }
        Section("Purchases") {
            if store.isPro {
                Label("Pro unlocked", systemImage: "checkmark.seal.fill")
            }
            Button("Restore Purchases") {
                Task { await store.restore() }
            }
            .disabled(store.isBusy)
            if let message = store.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        Section("Legal") {
            Link("Privacy Policy", destination: privacyURL)
            Link("Terms of Use", destination: termsURL)
        }
    }

    public static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
