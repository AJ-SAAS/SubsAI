import SwiftUI
import RevenueCat

@MainActor
class PurchaseViewModel: ObservableObject {
    
    @Published var isPremium = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        checkSubscriptionStatus()
    }
    
    // MARK: - Check Current Subscription Status
    func checkSubscriptionStatus() {
        Purchases.shared.getCustomerInfo { [weak self] customerInfo, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error fetching customer info: \(error.localizedDescription)")
                return
            }
            
            self.isPremium = customerInfo?.entitlements["premium"]?.isActive == true
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.isPremium = customerInfo.entitlements["premium"]?.isActive == true
            
            if self.isPremium {
                print("✅ Restore successful - Premium unlocked")
            } else {
                print("Restore completed but no active premium entitlement found")
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Restore failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Optional: Refresh status (useful after purchase)
    func refreshStatus() {
        checkSubscriptionStatus()
    }
    
    // MARK: - NEW: Async refresh (better for use after paywall dismiss)
    func checkSubscriptionStatusAsync() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.isPremium = customerInfo.entitlements["premium"]?.isActive == true
        } catch {
            print("❌ Error refreshing subscription status: \(error.localizedDescription)")
        }
    }
}
