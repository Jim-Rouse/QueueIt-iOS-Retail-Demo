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
    
    // NEW: Session state management
    @Published var sessionActive: Bool = false
    @Published var remainingTime: Int = 0
    @Published var showSessionExpired: Bool = false
    @Published var navigateToHome: Bool = false
    
    private var engine: QueueItEngine?
    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    
    // MARK: - Config from UserDefaults
    var customerID: String { UserDefaults.standard.string(forKey: "customerID") ?? "" }
    var waitingRoomID: String { UserDefaults.standard.string(forKey: "waitingRoomID") ?? "" }
    var layoutName: String { UserDefaults.standard.string(forKey: "layoutName") ?? "" }
    var language: String { UserDefaults.standard.string(forKey: "language") ?? "en" }
    var enqueueToken: String { UserDefaults.standard.string(forKey: "enqueueToken") ?? "" }
    var enqueueKey: String { UserDefaults.standard.string(forKey: "enqueueKey") ?? "" }
    var waitingRoomDomain: String { UserDefaults.standard.string(forKey: "waitingRoomDomain") ?? "" }
    var waitingRoomPrefix: String { UserDefaults.standard.string(forKey: "waitingRoomPrefix") ?? "" }
    
    // Response cookies variable
    var responseCookies: String = ""
    
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
        
        // Bind SDK's showWebView
        viewManager?.$showWebView
            .receive(on: RunLoop.main)
            .assign(to: \.showWebView, on: self)
            .store(in: &cancellables)
    }
    
    func activateWaitingRoom() {
        createEngine()
        guard let engine = engine else { return }
        
        Task { @MainActor in
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
            completion(.failure(NSError(domain: "Invalid URL", code: 0)))
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue(url.absoluteString, forHTTPHeaderField: "x-queueit-ajaxpageurl")
        if !responseCookies.isEmpty {
            request.addValue(responseCookies, forHTTPHeaderField: "Cookie")
        }
        if let queueItToken = UserDefaults.standard.string(forKey: "queueItToken") {
            request.addValue(queueItToken, forHTTPHeaderField: "x-queueittoken")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "Invalid response", code: 0)))
                return
            }
            
            // Save Set-Cookie header
            if let setCookie = httpResponse.value(forHTTPHeaderField: "Set-Cookie") {
                self.responseCookies = setCookie
            }
            
            // Check for x-queueit-redirect header
            if let redirectStr = httpResponse.value(forHTTPHeaderField: "x-queueit-redirect") {
                guard let decodedRedirectStr = redirectStr.removingPercentEncoding,
                      let redirectURL = URL(string: decodedRedirectStr) else {
                    completion(.failure(NSError(domain: "Invalid redirect URL", code: 0)))
                    return
                }
                
                // Parse URL querystring parameters
                let components = URLComponents(url: redirectURL, resolvingAgainstBaseURL: false)
                var params: [String: String] = [:]
                components?.queryItems?.forEach { params[$0.name] = $0.value }
                
                let customerId = params["c"]
                let waitingRoomOrAliasId = params["e"]
                let language = params["language"]
                let layoutName = params["layoutName"]
                let enqueueToken = params["enqueuetoken"]
                let enqueueKey = params["enqueuekey"]
                
                guard let customerId = customerId, let waitingRoomOrAliasId = waitingRoomOrAliasId else {
                    completion(.failure(NSError(domain: "Missing required parameters from redirect", code: 0)))
                    return
                }
                
                DispatchQueue.main.async {
                    // Create QueueItEngine with parsed parameters
                    let engine = QueueItEngine(
                        customerId: customerId,
                        waitingRoomOrAliasId: waitingRoomOrAliasId,
                        queueListener: self,
                        themeName: layoutName,
                        language: language ?? "en",
                        waitingRoomDomain: self.waitingRoomDomain.isEmpty ? nil : self.waitingRoomDomain,
                        queuePathPrefix: self.waitingRoomPrefix.isEmpty ? nil : self.waitingRoomPrefix
                    )
                    
                    // Temporarily set engine and viewManager for this operation
                    self.engine = engine
                    self.viewManager = engine.viewManager
                    
                    // Bind showWebView
                    self.viewManager?.$showWebView
                        .receive(on: RunLoop.main)
                        .assign(to: \.showWebView, on: self)
                        .store(in: &self.cancellables)
                    
                    Task { @MainActor in
                        do {
                            let tryPassResult: QueueTryPassResult?
                            if let enqueueToken = enqueueToken, !enqueueToken.isEmpty {
                                tryPassResult = await engine.tryPass(enqueueToken: enqueueToken)
                            } else if let enqueueKey = enqueueKey, !enqueueKey.isEmpty {
                                tryPassResult = await engine.tryPass(enqueueKey: enqueueKey)
                            } else {
                                tryPassResult = await engine.tryPass()
                            }
                            
                            if let result = tryPassResult {
                                if result.redirectType == .queue {
                                    engine.showQueue(queueTryPassResult: result)
                                }
                                // Other cases are handled by the listener callbacks
                            }
                        } catch {
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                            completion(.failure(error))
                        }
                    }
                }
            } else {
                // No redirect, return the response data
                completion(.success(data))
                // Clear the persisted token after successful request
                UserDefaults.standard.removeObject(forKey: "queueItToken")
            }
        }.resume()
    }
    
    // MARK: - Protected Request (async version for convenience)
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
        print("✅ Queue passed! Token: \(String(describing: info.queueItToken))")
        if let token = info.queueItToken {
            UserDefaults.standard.set(token, forKey: "queueItToken")
        }
        // Start session timer
        DispatchQueue.main.async { [weak self] in
            self?.startSessionTimer()
        }
    }
    
    func onError(_ error: QueueError, errorMessage: String) {
        self.errorMessage = errorMessage
        self.showError = true
    }
    
    func onQueueItUnavailable() {
        errorMessage = "Queue-it service is currently unavailable"
        showError = true
    }
    
    func onQueueDisabled(_ info: QueueDisabledInfo) {
        // Treat as passed for demo (proceed with session)
        DispatchQueue.main.async { [weak self] in
            self?.startSessionTimer()
        }
    }
    
    // Default empty implementations for the rest
    func onQueueViewWillOpen() {
        print("Stub: onQueueViewWillOpen")
    }
    func onWebViewClosed() {
        print("Stub: onWebViewClosed")
    }
    
    func onSessionRestart() {
        print("Stub: onSessionRestart")
    }
    
    func onQueueUrlChanged(url: URL) {
        print("Stub: onQueueUrlChanged - URL: \(url.absoluteString)")
    }
    
    func onSSLError(errorMessage: String) {
        print("Stub: onSSLError - Message: \(errorMessage)")
    }
    
    
    
    
    // NEW: Session Timer Logic
    private func startSessionTimer() {
        sessionActive = true
        remainingTime = 60
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingTime -= 1
            if self.remainingTime <= 0 {
                self.sessionTimer?.invalidate()
                self.sessionTimer = nil
                self.handleSessionExpiry()
            }
        }
    }
    
    private func handleSessionExpiry() {
        sessionActive = false
        showSessionExpired = true
        UserDefaults.standard.removeObject(forKey: "queueItToken")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.showSessionExpired = false
            self?.navigateToHome = true
        }
    }
}
