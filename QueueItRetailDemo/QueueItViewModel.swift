// QueueItViewModel.swift
import SwiftUI
import Combine
import QueueItKit

// MARK: - Configuration

private enum QueueItConfig {
    static let customerId         = "YOUR_CUSTOMER_ID"
    static let loginWaitingRoom   = "login-waitingroom"
    static let productWaitingRoom = "product-waitingroom"
    static let apiBaseURL         = URL(string: "https://api.your-app.com")!
}

// MARK: - ViewModel

@MainActor
public final class QueueItViewModel: ObservableObject {

    @Published public var showWebView    = false
    @Published public var queueState: QueueState = .idle
    @Published public var loginComplete  = false
    @Published public var products: [Product] = []
    @Published public var errorMessage: String?
    @Published public var isLoading      = false

    private var simpleEngine: QueueItEngine?
    public private(set) var simpleViewManager: QueueItViewManager?
    private var simpleCancellables = Set<AnyCancellable>()

    public let hybridManager: QueueItHybridManager
    private var hybridCancellables = Set<AnyCancellable>()

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
    }

    // MARK: - Simple integration: Login

    public func runLoginQueue() {
        isLoading = true
        createSimpleEngine()
        Task { await simpleEngine?.run() }
    }

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

    fileprivate func loginQueuePassed(token: String) {
        simpleViewManager?.hideQueue()
        showWebView = false
        isLoading = false
        Task { await completeLogin(queueToken: token) }
    }

    private func completeLogin(queueToken: String) async {
        loginComplete = true
    }

    // MARK: - Hybrid integration: Products

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

    private func bindHybridState() {
        hybridManager.$queueState
            .receive(on: RunLoop.main)
            .assign(to: \.queueState, on: self)
            .store(in: &hybridCancellables)

        hybridManager.$showWebView
            .receive(on: RunLoop.main)
            .sink { [weak self] show in if show { self?.showWebView = true } }
            .store(in: &hybridCancellables)
    }

    public func logout() {
        loginComplete = false
        products = []
        hybridManager.resetSession()
        simpleEngine = nil
        simpleViewManager = nil
        simpleCancellables.removeAll()
    }
}

// MARK: - Simple queue listener

private final class SimpleQueueListener: QueueListener {
    weak var viewModel: QueueItViewModel?

    init(viewModel: QueueItViewModel) { self.viewModel = viewModel }

    func onQueuePassed(_ info: QueuePassedInfo) {
        Task { @MainActor in viewModel?.loginQueuePassed(token: info.queueItToken ?? "") }
    }
    func onQueueViewWillOpen() {
        Task { @MainActor in viewModel?.isLoading = false }
    }
    func onQueueDisabled(_ info: QueueDisabledInfo) {
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
