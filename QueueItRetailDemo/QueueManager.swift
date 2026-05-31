//
//  QueueManager.swift
//  QueueItRetailDemo
//

import SwiftUI
import Combine
import QueueItKit
import WebKit
import os.log

private let logger = Logger(subsystem: "com.QueueItRetailDemo", category: "Network")

class QueueManager: ObservableObject, QueueListener {
    
    @Published var showWebView = false
    @Published var viewManager: QueueItViewManager?
    @Published var showError = false
    @Published var errorMessage = ""

    @Published var sessionActive: Bool = false
    @Published var remainingTime: Int = 0
    @Published var showSessionExpired: Bool = false
    @Published var navigateToHome: Bool = false
    @Published var queuePassed: Bool = false

    private var engine: QueueItEngine?
    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private var isExplicitActivationInProgress = false
    private var pendingRequest: (() -> Void)?

    // MARK: - Config from UserDefaults
    var customerID: String { UserDefaults.standard.string(forKey: "customerID") ?? "" }
    var waitingRoomID: String { UserDefaults.standard.string(forKey: "waitingRoomID") ?? "" }
    var layoutName: String { UserDefaults.standard.string(forKey: "layoutName") ?? "" }
    var language: String { UserDefaults.standard.string(forKey: "language") ?? "en" }
    var enqueueToken: String { UserDefaults.standard.string(forKey: "enqueueToken") ?? "" }
    var enqueueKey: String { UserDefaults.standard.string(forKey: "enqueueKey") ?? "" }
    var waitingRoomDomain: String { UserDefaults.standard.string(forKey: "waitingRoomDomain") ?? "" }
    var waitingRoomPrefix: String { UserDefaults.standard.string(forKey: "waitingRoomPrefix") ?? "" }

    init() {
        logger.info("🚀 QueueManager initialized")
    }

    // MARK: - Engine Setup
    func createEngine() {
        logger.info("🔧 createEngine() called")
        guard !customerID.isEmpty, !waitingRoomID.isEmpty else {
            logger.warning("⚠️ Missing customerID or waitingRoomID")
            return
        }

        engine = QueueItEngine(
            customerId: customerID,
            waitingRoomOrAliasId: waitingRoomID,
            queueListener: self,
            themeName: layoutName.isEmpty ? nil : layoutName,
            language: language,
            waitingRoomDomain: waitingRoomDomain.isEmpty ? nil : waitingRoomDomain,
            queuePathPrefix: waitingRoomPrefix.isEmpty ? nil : waitingRoomPrefix
        )

        viewManager = engine?.viewManager
    }

    func activateWaitingRoom() {
        logger.info("🚪 activateWaitingRoom() called")
        createEngine()
        guard let engine = engine else { return }

        isExplicitActivationInProgress = true

        Task { @MainActor in
            defer { self.isExplicitActivationInProgress = false }

            if !enqueueToken.isEmpty {
                await engine.runWithEnqueueToken(enqueueToken)
            } else if !enqueueKey.isEmpty {
                await engine.runWithEnqueueKey(enqueueKey)
            } else {
                await engine.run()
            }
        }
    }

    // MARK: - QueueListener
    func onQueuePassed(_ info: QueuePassedInfo) {
        logger.info("✅ onQueuePassed – token: \(info.queueItToken ?? "nil")")
        handleQueuePassed(token: info.queueItToken)
    }

    private func handleQueuePassed(token: String?) {
        if let token = token {
            UserDefaults.standard.set(token, forKey: "queueItToken")
        }
    }

    func onError(_ error: QueueError, errorMessage: String) {
        logger.error("❌ onError: \(errorMessage)")
        self.errorMessage = errorMessage
        self.showError = true
    }

    func onQueueItUnavailable() { logger.warning("⚠️ onQueueItUnavailable") }
    func onQueueDisabled(_ info: QueueDisabledInfo) { logger.info("ℹ️ onQueueDisabled") }
    func onQueueViewWillOpen() { logger.info("ℹ️ onQueueViewWillOpen") }
    func onWebViewClosed() { logger.info("ℹ️ onWebViewClosed") }
    func onSessionRestart() { logger.info("ℹ️ onSessionRestart") }
    func onQueueUrlChanged(url: URL) { logger.info("ℹ️ onQueueUrlChanged: \(url.absoluteString)") }
    func onSSLError(errorMessage: String) { logger.warning("⚠️ onSSLError: \(errorMessage)") }
}
