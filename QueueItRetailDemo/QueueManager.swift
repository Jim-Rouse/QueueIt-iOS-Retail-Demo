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
    
    // MARK: - QueueListener
    func onQueuePassed(_ info: QueuePassedInfo) {
        print("✅ Queue passed! Token: \(String(describing: info.queueItToken))")
        // You can persist the token here if needed for future API calls
        
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
    func onQueueViewWillOpen() {}
    func onWebViewClosed() {}
    func onSessionRestart() {}
    func onQueueUrlChanged(url: URL) {}
    func onSSLError(errorMessage: String) {}
    
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.showSessionExpired = false
            self?.navigateToHome = true
        }
    }
}
