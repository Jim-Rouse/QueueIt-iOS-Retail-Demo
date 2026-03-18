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

class QueueManager: ObservableObject, QueueListener {
    @Published var showWebView = false
    @Published var viewManager: QueueItViewManager?
    @Published var showError = false
    @Published var errorMessage = ""

    // Session state management
    @Published var sessionActive: Bool = false
    @Published var remainingTime: Int = 0
    @Published var showSessionExpired: Bool = false
    @Published var navigateToHome: Bool = false

    private var engine: QueueItEngine?
    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private var isExplicitActivationInProgress = false

    /// Stored retry closure — set when a makeProtectedRequest call hits the waiting room.
    /// Fired automatically in handleQueuePassed so the original request is replayed.
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

    // MARK: - Engine Setup

    func createEngine() {
        guard !customerID.isEmpty, !waitingRoomID.isEmpty else { return }

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

        viewManager?.$showWebView
            .receive(on: RunLoop.main)
            .assign(to: \.showWebView, on: self)
            .store(in: &cancellables)
    }

    func markAsExplicitActivation() {
        isExplicitActivationInProgress = true
    }

    func resetExplicitActivation() {
        isExplicitActivationInProgress = false
    }

    func activateWaitingRoom() {
        createEngine()
        guard let engine = engine else { return }

        markAsExplicitActivation()

        Task { @MainActor in
            defer { self.resetExplicitActivation() }

            if !enqueueToken.isEmpty {
                await engine.runWithEnqueueToken(enqueueToken)
            } else if !enqueueKey.isEmpty {
                await engine.runWithEnqueueKey(enqueueKey)
            } else {
                await engine.run()
            }
        }
    }

    // MARK: - Protected Request (callback version)

    func makeProtectedRequest(to urlString: String, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            print("[QueueManager] ❌ makeProtectedRequest: invalid URL → \(urlString)")
            completion(.failure(NSError(domain: "Invalid URL", code: 0)))
            return
        }

        print("[QueueManager] 🌐 makeProtectedRequest: → \(urlString)")

        var request = URLRequest(url: url)

        // ── Outgoing headers ──────────────────────────────────────────────────
        request.addValue(url.absoluteString, forHTTPHeaderField: "x-queueit-ajaxpageurl")
        print("[QueueManager] 📤 Set header x-queueit-ajaxpageurl: \(url.absoluteString)")

        if let cookieHeader = CookieManager.shared.cookieHeaderValue() {
            request.addValue(cookieHeader, forHTTPHeaderField: "Cookie")
            print("[QueueManager] 📤 Set Cookie header: \(cookieHeader)")
        } else {
            print("[QueueManager] ℹ️  No cookies to attach to request")
        }

        if let queueItToken = UserDefaults.standard.string(forKey: "queueItToken") {
            request.addValue(queueItToken, forHTTPHeaderField: "x-queueittoken")
            print("[QueueManager] 📤 Set header x-queueittoken: \(queueItToken)")
        }
        // ─────────────────────────────────────────────────────────────────────

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[QueueManager] ❌ Request failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                print("[QueueManager] ❌ Invalid or nil response")
                completion(.failure(NSError(domain: "Invalid response", code: 0)))
                return
            }

            print("[QueueManager] 📥 Response status: \(httpResponse.statusCode) for \(urlString)")

            // ── Incoming cookies ──────────────────────────────────────────────
            CookieManager.shared.processResponseCookies(from: httpResponse, requestURL: url)
            // ─────────────────────────────────────────────────────────────────

            // ── Queue-it redirect handling ────────────────────────────────────
            print("[QueueManager] 📥 Response headers:")
            for (key, value) in httpResponse.allHeaderFields {
                print("[QueueManager]    \(key): \(value)")
            }
            if let redirectStr = httpResponse.value(forHTTPHeaderField: "x-queueit-redirect") {
                print("[QueueManager] 🔀 x-queueit-redirect header detected: \(redirectStr)")

                guard let decodedRedirectStr = redirectStr.removingPercentEncoding,
                      let redirectURL = URL(string: decodedRedirectStr) else {
                    print("[QueueManager] ❌ Could not decode redirect URL: \(redirectStr)")
                    completion(.failure(NSError(domain: "Invalid redirect URL", code: 0)))
                    return
                }

                let components = URLComponents(url: redirectURL, resolvingAgainstBaseURL: false)
                var params: [String: String] = [:]
                components?.queryItems?.forEach { params[$0.name] = $0.value }
                print("[QueueManager] 🔀 Redirect params: \(params)")

                let customerId           = params["c"]
                let waitingRoomOrAliasId = params["e"]
                let language             = params["language"]
                let layoutName           = params["layoutName"]
                let enqueueToken         = params["enqueuetoken"]
                let enqueueKey           = params["enqueuekey"]

                guard let customerId = customerId, let waitingRoomOrAliasId = waitingRoomOrAliasId else {
                    print("[QueueManager] ❌ Missing required redirect params (c or e)")
                    completion(.failure(NSError(domain: "Missing required parameters from redirect", code: 0)))
                    return
                }

                DispatchQueue.main.async {
                    // Store the original request so it can be replayed after the queue is passed
                    self.pendingRequest = { [weak self] in
                        self?.makeProtectedRequest(to: urlString, completion: completion)
                    }

                    let engine = QueueItEngine(
                        customerId: customerId,
                        waitingRoomOrAliasId: waitingRoomOrAliasId,
                        queueListener: self,
                        themeName: layoutName,
                        language: language ?? "en",
                        waitingRoomDomain: self.waitingRoomDomain.isEmpty ? nil : self.waitingRoomDomain,
                        queuePathPrefix: self.waitingRoomPrefix.isEmpty ? nil : self.waitingRoomPrefix
                    )

                    self.engine = engine
                    self.viewManager = engine.viewManager

                    self.viewManager?.$showWebView
                        .receive(on: RunLoop.main)
                        .assign(to: \.showWebView, on: self)
                        .store(in: &self.cancellables)

                    Task { @MainActor in
                        do {
                            let tryPassResult: QueueTryPassResult?
                            if let enqueueToken = enqueueToken, !enqueueToken.isEmpty {
                                print("[QueueManager] 🎟️  tryPass with enqueueToken")
                                tryPassResult = await engine.tryPass(enqueueToken: enqueueToken)
                            } else if let enqueueKey = enqueueKey, !enqueueKey.isEmpty {
                                print("[QueueManager] 🔑 tryPass with enqueueKey")
                                tryPassResult = await engine.tryPass(enqueueKey: enqueueKey)
                            } else {
                                print("[QueueManager] 🎟️  tryPass (no token/key)")
                                tryPassResult = await engine.tryPass()
                            }

                            if let result = tryPassResult {
                                print("[QueueManager] 🔀 tryPass redirectType: \(result.redirectType)")
                                if result.redirectType == .queue {
                                    engine.showQueue(queueTryPassResult: result)
                                } else if result.redirectType == .safetyNet {
                                    print("[QueueManager] 🛡️  safetyNet – treating as queue passed")
                                    self.handleQueuePassed(token: result.queueItToken)
                                }
                            }
                        } catch {
                            print("[QueueManager] ❌ tryPass error: \(error.localizedDescription)")
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                            completion(.failure(error))
                        }
                    }
                }

            } else {
                // No redirect — success path
                print("[QueueManager] ✅ Request succeeded, returning \(data.count) byte(s)")
                completion(.success(data))
                UserDefaults.standard.removeObject(forKey: "queueItToken")
                print("[QueueManager] 🗑️  Cleared stored queueItToken after successful request")
            }
        }.resume()
    }

    // MARK: - Protected Request (async convenience)

    func makeProtectedRequest(to urlString: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            makeProtectedRequest(to: urlString) { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - QueueListener

    func onQueuePassed(_ info: QueuePassedInfo) {
        print("[QueueManager] ✅ onQueuePassed – token: \(info.queueItToken ?? "nil")")
        handleQueuePassed(token: info.queueItToken)
    }

    private func handleQueuePassed(token: String?) {
        if let token = token {
            UserDefaults.standard.set(token, forKey: "queueItToken")
        }

        if isExplicitActivationInProgress {
            DispatchQueue.main.async { [weak self] in
                self?.startSessionTimer()
            }
        }

        resetExplicitActivation()

        if let retry = pendingRequest {
            pendingRequest = nil
            print("[QueueManager] 🔁 Replaying pending request after queue pass")
            DispatchQueue.main.async {
                retry()
            }
        }
    }

    func onError(_ error: QueueError, errorMessage: String) {
        print("[QueueManager] ❌ onError – \(errorMessage)")
        pendingRequest = nil
        self.errorMessage = errorMessage
        self.showError = true
    }

    func onQueueItUnavailable() {
        print("[QueueManager] ⚠️  onQueueItUnavailable")
        pendingRequest = nil
        errorMessage = "Queue-it service is currently unavailable"
        showError = true
    }

    func onQueueDisabled(_ info: QueueDisabledInfo) {
        print("[QueueManager] ℹ️  onQueueDisabled – treating as passed")

        if isExplicitActivationInProgress {
            DispatchQueue.main.async { [weak self] in
                self?.startSessionTimer()
            }
        }

        resetExplicitActivation()
    }

    func onQueueViewWillOpen() { print("[QueueManager] ℹ️  onQueueViewWillOpen") }
    func onWebViewClosed() { print("[QueueManager] ℹ️  onWebViewClosed") }
    func onSessionRestart() { print("[QueueManager] ℹ️  onSessionRestart") }
    func onQueueUrlChanged(url: URL) { print("[QueueManager] ℹ️  onQueueUrlChanged – \(url.absoluteString)") }
    func onSSLError(errorMessage: String) { print("[QueueManager] ⚠️  onSSLError – \(errorMessage)") }

    // MARK: - Session Timer

    private func startSessionTimer() {
        print("[QueueManager] ⏱️  startSessionTimer – 60s session started")
        sessionActive = true
        remainingTime = 60
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingTime -= 1
            if self.remainingTime <= 0 {
                self.sessionTimer?.invalidate()
                self.sessionTimer = nil
                print("[QueueManager] ⏱️  Session timer expired")
                self.handleSessionExpiry()
            }
        }
    }

    private func handleSessionExpiry() {
        print("[QueueManager] 🔒 handleSessionExpiry – clearing token and navigating home in 5s")
        sessionActive = false
        showSessionExpired = true
        UserDefaults.standard.removeObject(forKey: "queueItToken")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.showSessionExpired = false
            self?.navigateToHome = true
        }
    }
}
