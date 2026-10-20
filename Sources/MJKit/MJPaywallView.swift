#if canImport(SwiftUI) && canImport(StoreKit)
import SwiftUI

/// Honest one-time-unlock paywall. No timers, no fake discounts, no dark patterns.
public struct MJPaywallView: View {
    @ObservedObject private var store: MJStore
    private let appName: String
    private let features: [String]
    private let privacyURL: URL
    private let termsURL: URL
    @Environment(\.dismiss) private var dismiss

    public init(store: MJStore, appName: String, features: [String], privacyURL: URL, termsURL: URL) {
        self._store = ObservedObject(wrappedValue: store)
        self.appName = appName
        self.features = features
        self.privacyURL = privacyURL
        self.termsURL = termsURL
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                        .padding(.top, 24)
                    Text("\(appName) Pro")
                        .font(.largeTitle.bold())
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(features, id: \.self) { feature in
                            Label(feature, systemImage: "checkmark.circle.fill")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    Text("One-time purchase. No subscription, no account, no ads, no tracking. The free features stay free.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if store.isPro {
                        Label("Pro is unlocked. Thank you!", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                    } else {
                        Button {
                            Task { await store.purchase() }
                        } label: {
                            Text(unlockTitle)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.isBusy)
                    }

                    Button("Restore Purchases") {
                        Task { await store.restore() }
                    }
                    .disabled(store.isBusy)

                    if store.isBusy {
                        ProgressView()
                    }

                    if let message = store.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 24) {
                        Link("Privacy Policy", destination: privacyURL)
                        Link("Terms of Use", destination: termsURL)
                    }
                    .font(.footnote)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            store.errorMessage = nil
            if store.products.isEmpty { await store.loadProducts() }
        }
    }

    private var unlockTitle: String {
        if let product = store.proProduct {
            return "Unlock for \(product.displayPrice)"
        }
        return "Unlock Pro"
    }
}
#endif
