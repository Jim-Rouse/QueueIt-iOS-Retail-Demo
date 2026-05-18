// QueueItHybridManager.swift  v1.1
//
// FIX NOTES:
//   • Removed @MainActor from class level. @Published updates go via
//     DispatchQueue.main.async so they're always on the main thread.
//   • init() is now nonisolated — safe for @StateObject default-value evaluation.
//   • queueItToken safely unwrapped as `?? ""` (it's String? in SDK v1.0.0).
//   • presentQueue() and resetSession() are @MainActor where engine/viewManager
//     mutations must happen on the main thread.

import Foundation
import Combine
import QueueItKit

// MARK: - Queue state

public enum QueueState: Equatable {
    case idle
    case checking
    case queuing
    case passed
    case disabled
    case unavailable
    case error(String)
}

// MARK: - Manager

public final class QueueItHybridManager: ObservableObject, QueueListener {

    // MARK: Published state

    @Published public private(set) var queueState: QueueState = .idle
    @Published public private(set) var showWebView: Bool = false

    // MARK: Dependencies

    public let apiClient: QueueItAPIClient
    private let cookieManager: QueueItCookieManager

    // MARK: Engine (main-thread only)

    private var engine: QueueItEngine?
    @Published public private(set) var viewManager: QueueItViewManager?
    private var cancellables = Set<AnyCancellable>()

    // MARK: Pending continuations

    private var pendingContinuations: [CheckedContinuation<String, Error>] = []
    private var currentRedirectInfo: QueueItRedirectInfo?

    // MARK: Init — nonisolated, no actor isolation required

    public init(
        apiClient: QueueItAPIClient = QueueItAPIClient(),
        cookieManager: QueueItCookieManager = QueueItCookieManager.shared
    ) {
        self.apiClient = apiClient
        self.cookieManager = cookieManager
    }

    // MARK: - Public: Protected API call

    /// Performs a protected API call with full hybrid flow:
    /// injects cookies → detects queue intercept → shows WebView → retries.
    public func call(_ request: URLRequest) async throws -> Data {
        publishState(.checking)
        let result = await apiClient.perform(request)

        switch result {
        case .success(let data, _):
            publishState(.idle)
            return data

        case .queueRequired(let info):
            let token = try await waitForQueuePass(info: info)
            publishState(.passed)
            let retryResult = await apiClient.retryAfterQueue(request, token: token)

            switch retryResult {
            case .success(let data, _):
                return data
            case .httpError(let code, _):
                throw QueueItHybridError.httpError(code)
            case .networkError(let error):
                throw error
            case .queueRequired:
                throw QueueItHybridError.reIntercepted
            }

        case .httpError(let code, _):
            publishState(.error("HTTP \(code)"))
            throw QueueItHybridError.httpError(code)

        case .networkError(let error):
            publishState(.error(error.localizedDescription))
            throw error
        }
    }

    // MARK: - Private helpers

    private func waitForQueuePass(info: QueueItRedirectInfo) async throws -> String {
        if currentRedirectInfo == nil {
            currentRedirectInfo = info
            await presentQueue(customerId: info.customerId, waitingRoomId: info.waitingRoomId)
        }
        return try await withCheckedThrowingContinuation { continuation in
            pendingContinuations.append(continuation)
        }
    }

    @MainActor
    private func presentQueue(customerId: String, waitingRoomId: String) {
        publishState(.queuing)
        engine = QueueItEngine(
            customerId: customerId,
            waitingRoomOrAliasId: waitingRoomId,
            queueListener: self
        )
        viewManager = engine?.viewManager

        cancellables.removeAll()
        viewManager?.$showWebView
            .receive(on: DispatchQueue.main)
            .assign(to: \.showWebView, on: self)
            .store(in: &cancellables)

        Task { await engine?.run() }
    }

    /// Dispatch @Published mutations to main thread.
    private func publishState(_ state: QueueState) {
        DispatchQueue.main.async { [weak self] in self?.queueState = state }
    }

    // MARK: - QueueListener

    public func onQueuePassed(_ queuePassedInfo: QueuePassedInfo) {
        // queueItToken is String? in SDK 1.0.0
        let token = queuePassedInfo.queueItToken ?? ""
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.viewManager?.hideQueue()
            self.queueState = .passed
            self.currentRedirectInfo = nil
            let waiting = self.pendingContinuations
            self.pendingContinuations = []
            waiting.forEach { $0.resume(returning: token) }
        }
    }

    public func onQueueViewWillOpen() {
        publishState(.queuing)
    }

    public func onQueueDisabled(_ queueDisabledInfo: QueueDisabledInfo) {
        publishState(.disabled)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let waiting = self.pendingContinuations
            self.pendingContinuations = []
            waiting.forEach { $0.resume(returning: "") }
        }
    }

    public func onQueueItUnavailable() {
        publishState(.unavailable)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let waiting = self.pendingContinuations
            self.pendingContinuations = []
            waiting.forEach { $0.resume(throwing: QueueItHybridError.unavailable) }
        }
    }

    public func onError(_ error: QueueError, errorMessage: String) {
        publishState(.error(errorMessage))
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let waiting = self.pendingContinuations
            self.pendingContinuations = []
            waiting.forEach { $0.resume(throwing: QueueItHybridError.engineError(errorMessage)) }
        }
    }

    public func onWebViewClosed() {
        DispatchQueue.main.async { [weak self] in self?.showWebView = false }
    }

    // MARK: - Session management

    @MainActor
    public func resetSession() {
        cookieManager.clearAll()
        engine = nil
        viewManager = nil
        queueState = .idle
        showWebView = false
        let waiting = pendingContinuations
        pendingContinuations = []
        currentRedirectInfo = nil
        cancellables.removeAll()
        waiting.forEach { $0.resume(throwing: QueueItHybridError.sessionReset) }
    }
}

// MARK: - Errors

public enum QueueItHybridError: LocalizedError {
    case httpError(Int)
    case unavailable
    case engineError(String)
    case reIntercepted
    case sessionReset

    public var errorDescription: String? {
        switch self {
        case .httpError(let code):  return "HTTP error \(code)"
        case .unavailable:          return "Queue-it service is unavailable"
        case .engineError(let msg): return "Queue engine error: \(msg)"
        case .reIntercepted:        return "Re-intercepted after queue token — check server config"
        case .sessionReset:         return "Session was reset while waiting"
        }
    }
}

