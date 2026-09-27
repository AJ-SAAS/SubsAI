// Models/PremiumStatus.swift
// One place to ask "does this person have Premium?"
// Reads the "premium" entitlement from RevenueCat, and updates by itself
// the moment a purchase, restore or renewal happens.
import Foundation
import RevenueCat

@MainActor
final class PremiumStatus: ObservableObject {
    static let shared = PremiumStatus()

    @Published private(set) var isPremium = false

    private var listener: Task<Void, Never>?

    private init() {
        // RevenueCat sends new customer info after every purchase, restore or renewal
        listener = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.update(from: info)
            }
        }
    }

    /// Call when a screen appears, and after the paywall closes.
    func refresh() async {
        do {
            update(from: try await Purchases.shared.customerInfo())
        } catch {
            print("⚠️ Premium check failed:", error)
        }
    }

    private func update(from info: CustomerInfo) {
        isPremium = info.entitlements["premium"]?.isActive == true
    }
}
