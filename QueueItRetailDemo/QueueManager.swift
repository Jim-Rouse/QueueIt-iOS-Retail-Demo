//
//  QueueManager.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 2/26/26.
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

    // MARK: - Protected Request
    func makeProtectedRequest(to urlString: String, completion: @escaping (Result<Data, Error>) -> Void) {
        logger.info("🌐 [PROTECTED REQUEST] → \(urlString)")

        guard let url = URL(string: urlString) else {
            logger.error("❌ Invalid URL: \(urlString)")
            completion(.failure(NSError(domain: "Invalid URL", code: 0)))
            return
        }

        var request = URLRequest(url: url)

        // Queue-it headers
        request.addValue(url.absoluteString, forHTTPHeaderField: "x-queueit-ajaxpageurl")
        logger.info("📤 Added x-queueit-ajaxpageurl")

        if let cookieHeader = CookieManager.shared.cookieHeaderValue() {
            request.addValue(cookieHeader, forHTTPHeaderField: "Cookie")
            logger.info("📤 Added Cookie header")
        }

        if let queueItToken = UserDefaults.standard.string(forKey: "queueItToken") {
            request.addValue(queueItToken, forHTTPHeaderField: "x-queueittoken")
            logger.info("📤 Added x-queueittoken")
            UserDefaults.standard.removeObject(forKey: "queueItToken")
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                logger.error("❌ Request failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                logger.error("❌ Invalid or nil response")
                completion(.failure(NSError(domain: "Invalid response", code: 0)))
                return
            }

            logger.info("📥 [RESPONSE] Status: \(httpResponse.statusCode)")

            // Log all x-queue* response headers
            logger.info("🔍 x-queue* Response Headers:")
            var found = false
            for (key, value) in httpResponse.allHeaderFields {
                if let k = key as? String, k.lowercased().hasPrefix("x-queue") {
                    let safeValue = String(describing: value)
                    logger.info("   🔑 \(k): \(safeValue)")
                    found = true
                }
            }
            if !found {
                logger.info("   (No x-queue* headers found)")
            }

            // Process cookies
            CookieManager.shared.processResponseCookies(from: httpResponse, requestURL: url)

            // Check for redirect
            if let redirect = httpResponse.value(forHTTPHeaderField: "x-queueit-redirect") {
                logger.info("🔀 x-queueit-redirect detected: \(redirect)")
                // Add your redirect handling here
            } else {
                logger.info("✅ Request succeeded")
                completion(.success(data))
            }
        }.resume()
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
