import Foundation

/// A deliberately small, side-effect-free model of the tip purchase lifecycle.
struct TipPurchaseStateMachine: Equatable {
    enum State: Equatable {
        case idle
        case loading
        case ready
        case purchasing
        case pending
        case succeeded
        case failed
        case cancelled
    }

    private(set) var state: State = .idle

    var isBusy: Bool {
        state == .loading || state == .purchasing || state == .pending
    }

    mutating func beginLoading() -> Bool {
        guard !isBusy else { return false }
        state = .loading
        return true
    }

    mutating func finishLoading(hasProducts: Bool) {
        guard state == .loading else { return }
        state = hasProducts ? .ready : .failed
    }

    /// Returns false when an in-flight purchase or pending approval must remain exclusive.
    mutating func beginPurchase() -> Bool {
        guard state == .ready || state == .succeeded || state == .failed || state == .cancelled else {
            return false
        }
        state = .purchasing
        return true
    }

    mutating func markPending() { guard state == .purchasing else { return }; state = .pending }
    /// StoreKit can confirm a pending purchase later through `Transaction.updates`.
    mutating func markSucceeded() {
        guard state == .purchasing || state == .pending else { return }
        state = .succeeded
    }
    mutating func markFailed() { guard state == .loading || state == .purchasing else { return }; state = .failed }
    mutating func markCancelled() { guard state == .purchasing else { return }; state = .cancelled }
}
