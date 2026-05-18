// QueueItViewModel.swift
// SwiftUI ViewModel demonstrating both integration patterns
// modelled on the Shop-it retail demo (retail.queue-it-demo.com).
//
// SIMPLE integration  → guards the login flow (one call to engine.run())
// HYBRID integration  → guards individual product/API calls (server-side KnownUser)

import SwiftUI
import Combine
import QueueItKit

// MARK: - Configuration

private enum QueueItConfig {
    // Replace these with your real Queue-it credentials from the GO platform.
    static let customerId       = "YOUR_CUSTOMER_ID"
    static let loginWaitingRoom = "login-waitingroom"          // Simple integration
    static let productWaitingRoom = "product-waitingroom"      // Hybrid integration
    static let apiBaseURL       = URL(string: "https://api.your-app.com")!
}

// MARK: - ViewModel

@MainActor
public final class QueueItViewModel: ObservableObject {

    // ── UI state ───────────────────────────────────────────────────────────
    @Published public var showWebView       = false
    @Published public var queueState: QueueState = .idle
    @Published public var loginComplete     = false
    @Published public var products: [Product] = []
    @Published public var errorMessage: String?
    @Published public var isLoading         = false

    // ── Queue-it managers ──────────────────────────────────────────────────

    /// SIMPLE integration manager (engine + listener) — for login
    private var simpleEngine: QueueItEngine?
    public private(set) var simpleViewManager: QueueItViewManager?
    private var simpleCancellables = Set<AnyCancellable>()

    /// HYBRID integration manager — for protected API calls
    public let hybridManager: QueueItHybridManager

    private var hybridCancellables = Set<AnyCancellable>()

    // MARK: Init

    public init() {
        hybridManager = QueueItHybridManager(
            apiClient: QueueItAPIClient(
                config: QueueItAPIClient.Config(
                    ajaxPageURL: "app://shop-it/products",
                    timeoutInterval: 30
                )
            )
        )
        bindHybridState()
        QueueItLogger.setLogLevel(.debug)
    }

    // MARK: - SIMPLE integration: Login

    /// Step 1 of the Shop-it demo: protect the login screen with a waiting room.
    /// Call this when the user taps "Sign In".
    public func runLoginQueue() {
        isLoading = true
        createSimpleEngine()
        Task { await simpleEngine?.run() }
    }

    @MainActor
    private func createSimpleEngine() {
        simpleEngine = QueueItEngine(
            customerId: QueueItConfig.customerId,
            waitingRoomOrAliasId: QueueItConfig.loginWaitingRoom,
            queueListener: SimpleQueueListener(viewModel: self)
        )
        simpleViewManager = simpleEngine?.viewManager

        simpleCancellables.removeAll()
        simpleViewManager?.$showWebView
            .receive(on: RunLoop.main)
            .assign(to: \.showWebView, on: self)
            .store(in: &simpleCancellables)
    }

    /// Called by SimpleQueueListener when login queue passes.
    fileprivate func loginQueuePassed(token: String) {
        simpleViewManager?.hideQueue()
        showWebView = false
        isLoading = false
        // Store token for session management as needed.
        Task { await completeLogin(queueToken: token) }
    }

    private func completeLogin(queueToken: String) async {
        // Your actual login API call goes here.
        // The queue token can be sent to your server for server-side validation.
        loginComplete = true
    }

    // MARK: - HYBRID integration: Product catalogue

    /// Step 2 of the Shop-it demo: load the product list through a Queue-it
    /// protected API endpoint. Cookies are automatically forwarded on every call.
    public func loadProducts() {
        guard loginComplete else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let request = URLRequest(url: QueueItConfig.apiBaseURL.appendingPathComponent("products"))
                let data = try await hybridManager.call(request)
                self.products = try JSONDecoder().decode([Product].self, from: data)
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    /// Fetch a single product detail — also protected.
    public func loadProduct(id: String) async throws -> ProductDetail {
        let url = QueueItConfig.apiBaseURL
            .appendingPathComponent("products")
            .appendingPathComponent(id)
        let data = try await hybridManager.call(URLRequest(url: url))
        return try JSONDecoder().decode(ProductDetail.self, from: data)
    }

    // MARK: - Hybrid state binding

    private func bindHybridState() {
        hybridManager.$queueState
            .receive(on: RunLoop.main)
            .assign(to: \.queueState, on: self)
            .store(in: &hybridCancellables)

        hybridManager.$showWebView
            .receive(on: RunLoop.main)
            .sink { [weak self] show in
                // Hybrid WebView overrides simple WebView flag
                if show { self?.showWebView = true }
            }
            .store(in: &hybridCancellables)
    }

    // MARK: - Logout

    public func logout() {
        loginComplete = false
        products = []
        hybridManager.resetSession()
        simpleEngine = nil
        simpleViewManager = nil
        simpleCancellables.removeAll()
    }
}

// MARK: - Simple integration listener (separate class to keep ViewModel clean)

private final class SimpleQueueListener: QueueListener {
    weak var viewModel: QueueItViewModel?

    init(viewModel: QueueItViewModel) {
        self.viewModel = viewModel
    }

    func onQueuePassed(_ info: QueuePassedInfo) {
        Task { @MainActor in
            viewModel?.loginQueuePassed(token: info.queueItToken)
        }
    }

    func onQueueViewWillOpen() {
        Task { @MainActor in viewModel?.isLoading = false }
    }

    func onQueueDisabled(_ info: QueueDisabledInfo) {
        // Queue disabled → let the user through immediately
        Task { @MainActor in viewModel?.loginQueuePassed(token: "") }
    }

    func onQueueItUnavailable() {
        Task { @MainActor in
            viewModel?.isLoading = false
            viewModel?.errorMessage = "Queue-it service unavailable. Please try again."
        }
    }

    func onError(_ error: QueueError, errorMessage: String) {
        Task { @MainActor in
            viewModel?.isLoading = false
            viewModel?.errorMessage = errorMessage
        }
    }

    func onWebViewClosed() {
        Task { @MainActor in viewModel?.showWebView = false }
    }
}

// MARK: - Model stubs (replace with your real models)

public struct Product: Identifiable, Decodable {
    public let id: String
    public let name: String
    public let price: Double
    public let imageURL: String?
}

public struct ProductDetail: Decodable {
    public let id: String
    public let name: String
    public let description: String
    public let price: Double
    public let stock: Int
}
