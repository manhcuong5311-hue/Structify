//
//  Untitled.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//

import SwiftUI
import StoreKit
import Combine

// MARK: - Limits
enum PremiumLimit {
    static let maxFreeEvents = 50
    static let maxFreeHabits = 50
    static let maxFreeIconsPerCategory = 5
}

// MARK: - PremiumStore
class PremiumStore: ObservableObject {
    static let shared = PremiumStore()

    @Published private(set) var isPremium: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    private var transactionListener: Task<Void, Never>? = nil
    
    
    private let premiumKey = "structify_is_premium"
    private let productID = "com.structify.premium.lifetime"

    init() {
        isPremium = UserDefaults.standard.bool(forKey: premiumKey)
        transactionListener = listenForTransactions()
        Task { await refreshPurchaseStatus() }
    }
    
    func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    if transaction.productID == self.productID {
                        await MainActor.run { self.unlock() }
                    }
                    await transaction.finish()
                case .unverified:
                    break
                }
            }
        }
    }

    // THÊM deinit để cancel task khi deallocate:
    deinit {
        transactionListener?.cancel()
    }
    
    

    // MARK: - Purchase
    func purchase() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let products = try await Product.products(for: [productID])
            guard let product = products.first else {
                await MainActor.run {
                    errorMessage = String(localized: "purchase.error.product_not_found")
                    isLoading = false
                }
                return
            }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified:
                    await MainActor.run { unlock() }
                case .unverified:
                    await MainActor.run {
                        errorMessage = String(localized: "purchase.error.verification_failed")
                    }
                }
            case .userCancelled:
                break
            case .pending:
                await MainActor.run {
                    errorMessage = String(localized: "purchase.error.pending")
                }
            @unknown default:
                break
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    // MARK: - Restore
    func restore() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            try await AppStore.sync()
            await refreshPurchaseStatus()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    // MARK: - Refresh
    func refreshPurchaseStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID {
                await MainActor.run { unlock() }
                return
            }
        }
    }

    // MARK: - Unlock (dùng cho testing)
    func unlock() {
        isPremium = true
        UserDefaults.standard.set(true, forKey: premiumKey)
        objectWillChange.send()
    }

    // MARK: - Gating helpers
    func canAddEvent(currentCount: Int) -> Bool {
        isPremium || currentCount < PremiumLimit.maxFreeEvents
    }

    func canAddHabit(currentCount: Int) -> Bool {
        isPremium || currentCount < PremiumLimit.maxFreeHabits
    }

    func visibleIconCount(total: Int) -> Int {
        isPremium ? total : min(total, PremiumLimit.maxFreeIconsPerCategory)
    }
}
