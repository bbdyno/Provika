//
//  TipStore.swift
//  Provika
//
//  StoreKit 2로 개발자 후원(소비성 IAP) 플로우를 담당한다.
//

import Foundation
import StoreKit
import os

@MainActor
@Observable
final class TipStore {
    enum Tier: String, CaseIterable, Identifiable {
        case small  = "com.provika.tip.item.small"
        case medium = "com.provika.tip.item.medium"
        case large  = "com.provika.tip.item.large"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .small:  return "☕"
            case .medium: return "🍚"
            case .large:  return "🙏"
            }
        }
    }

    private(set) var products: [Product] = []
    private(set) var purchaseState = TipPurchaseStateMachine()
    var isLoading: Bool { purchaseState.state == .loading }
    var isBusy: Bool { purchaseState.isBusy }
    private(set) var purchasingProductID: String?
    private(set) var lastError: String?
    var showThankYou = false

    private let logger = Logger(subsystem: "com.bbdyno.app.provika", category: "TipStore")
    // Observation 추적 대상 아님 + Task 자체가 thread-safe — deinit에서 cancel만 호출.
    @ObservationIgnored
    private nonisolated(unsafe) var updatesTask: Task<Void, Never>?

    init() {
        // 오프라인 중 결제가 뒤늦게 검증되어 들어오는 트랜잭션도 즉시 finish
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.finishIfVerified(result)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        guard purchaseState.beginLoading() else { return }
        lastError = nil

        do {
            let ids = Tier.allCases.map(\.rawValue)
            let fetched = try await Product.products(for: ids)
            let order = Dictionary(
                uniqueKeysWithValues: Tier.allCases.enumerated().map { ($1.rawValue, $0) }
            )
            products = fetched.sorted { (order[$0.id] ?? .max) < (order[$1.id] ?? .max) }
            purchaseState.finishLoading(hasProducts: !products.isEmpty)
            if products.isEmpty { lastError = ProvikaStrings.Localizable.Support.Error.generic }
        } catch {
            purchaseState.markFailed()
            lastError = ProvikaStrings.Localizable.Support.Error.generic
            logger.error("Tip product loading failed")
        }
    }

    func purchase(_ product: Product) async {
        guard purchaseState.beginPurchase() else { return }
        purchasingProductID = product.id
        lastError = nil
        defer { purchasingProductID = nil }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                try await completePurchase(verification)
            case .userCancelled:
                purchaseState.markCancelled()
            case .pending:
                purchaseState.markPending()
            @unknown default:
                purchaseState.markFailed()
                lastError = ProvikaStrings.Localizable.Support.Error.generic
            }
        } catch {
            purchaseState.markFailed()
            lastError = ProvikaStrings.Localizable.Support.Error.generic
            logger.error("Tip purchase failed")
        }
    }

    private func completePurchase(_ result: VerificationResult<Transaction>) async throws {
        switch result {
        case .verified(let transaction):
            await transaction.finish()
            purchaseState.markSucceeded()
            showThankYou = true
        case .unverified:
            throw TipStoreError.unverifiedTransaction
        }
    }

    private func finishIfVerified(_ result: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = result {
            await transaction.finish()
            // A purchase awaiting approval completes on this stream rather than
            // in the original `purchase()` call. Do not leave the UI busy once
            // StoreKit has supplied a verified transaction.
            if purchaseState.state == .pending {
                purchaseState.markSucceeded()
                showThankYou = true
            }
        }
    }

    private enum TipStoreError: Error { case unverifiedTransaction }
}
