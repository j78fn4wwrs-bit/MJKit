#if canImport(StoreKit) && canImport(Combine)
import Foundation
import StoreKit
import Combine

/// StoreKit 2 one-time unlock store. No accounts, no server, no analytics.
@MainActor
public final class MJStore: ObservableObject {
    public let proProductIDs: Set<String>

    @Published public private(set) var isPro: Bool = false
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var isBusy: Bool = false
    @Published public var errorMessage: String?

    private nonisolated(unsafe) var updatesTask: Task<Void, Never>?

    public init(proProductIDs: Set<String>) {
        self.proProductIDs = proProductIDs
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if Task.isCancelled { break }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task { [weak self] in
            await self?.refreshEntitlements()
            await self?.loadProducts()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// The first Pro product (most apps have exactly one).
    public var proProduct: Product? { products.first }

    public func loadProducts() async {
        do {
            let loaded = try await Product.products(for: proProductIDs)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Couldn't reach the App Store. Try again later."
        }
    }

    public func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               proProductIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isPro = owned
    }

    public func purchase(_ product: Product? = nil) async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        if products.isEmpty { await loadProducts() }
        guard let target = product ?? proProduct else {
            errorMessage = "The upgrade isn't available right now. Try again later."
            return
        }
        do {
            let result = try await target.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                case .unverified(_, _):
                    // Do not surface the verification error; it can echo StoreKit details.
                    errorMessage = "Purchase couldn't be verified. Please try again."
                }
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase didn't complete. Please try again."
        }
    }

    public func restore() async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = "Restore didn't complete. Please try again."
        }
        await refreshEntitlements()
        if isPro {
            errorMessage = nil
        } else if errorMessage == nil {
            errorMessage = "No previous purchase found for this Apple Account."
        }
    }
}
#endif
