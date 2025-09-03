import Foundation
import StoreKit

// MARK: - Subscription Service
class SubscriptionService: ObservableObject {
    @Published var isProVersion = false
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published var availableProducts: [Product] = []
    
    private var updateListenerTask: Task<Void, Error>?
    
    enum SubscriptionStatus {
        case unknown
        case notSubscribed
        case subscribed
        case expired
        case inGracePeriod
    }
    
    init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await requestProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func requestProducts() async {
        do {
            let products = try await Product.products(for: [
                Constants.Subscription.monthlyProductID,
                Constants.Subscription.yearlyProductID
            ])
            
            availableProducts = products.sorted { product1, product2 in
                product1.price < product2.price
            }
        } catch {
            print("Failed to request products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            return transaction
            
        case .userCancelled, .pending:
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            print("Failed to restore purchases: \(error)")
        }
    }
    
    @MainActor
    func updateSubscriptionStatus() async {
        var currentEntitlements: [String] = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                switch transaction.productType {
                case .autoRenewable:
                    if (try await subscription(for: transaction.productID)) != nil {
                        currentEntitlements.append(transaction.productID)
                    }
                default:
                    break
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }
        
        isProVersion = !currentEntitlements.isEmpty
        subscriptionStatus = isProVersion ? .subscribed : .notSubscribed
        
        // UserDefaultsに保存
        UserDefaults.standard.set(isProVersion, forKey: Constants.UserDefaultsKeys.isProVersion)
    }
    
    // MARK: - Private Methods
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "SubscriptionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed verification"])
        case .verified(let safe):
            return safe
        }
    }
    
    private func subscription(for productID: String) async throws -> Product.SubscriptionInfo? {
        guard let product = availableProducts.first(where: { $0.id == productID }) else {
            return nil
        }
        
        return product.subscription
    }
    
    // MARK: - Helpers
    
    func displayPrice(for product: Product) -> String {
        return product.displayPrice
    }
    
    func displayName(for product: Product) -> String {
        return product.displayName
    }
    
    func isMonthlyProduct(_ product: Product) -> Bool {
        return product.id == Constants.Subscription.monthlyProductID
    }
    
    func isYearlyProduct(_ product: Product) -> Bool {
        return product.id == Constants.Subscription.yearlyProductID
    }
}