//
//  LogInViewController.swift
//  QueueItRetailDemo
//
//  Updated by Grok (xAI) on 2026-03-06
//  Now uses the shared QueueManager to activate the waiting room
//  (no duplicate engine creation, no legacy delegate)
//  Timer starts automatically when the Queue-it web view closes (i.e. user passed the queue)
//  Session expiry modal + 5-second auto-return to Home
//

import UIKit
import Combine
import QueueItKit

class LogInViewController: UIViewController {
    
    // MARK: - Injected from SwiftUI (via LogInRepresentable)
    var queueManager: QueueManager?
    
    // Callback so we can switch back to .home in SwiftUI when session expires
    var goHomeClosure: (() -> Void)?
    
    // MARK: - UI Elements
    private var activatingLabel: UILabel!
    private var countdownLabel: UILabel!
    private var countdownTimer: Timer?
    private var remainingTime: Int = 60
    
    // Combine subscription to watch QueueManager's showWebView
    private var cancellables = Set<AnyCancellable>()
    private var wasShowingWebView = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        activateWaitingRoom()
        observeQueueWebViewState()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Activating label (shown while waiting room is active)
        activatingLabel = UILabel()
        activatingLabel.text = "Activating Queue-it Waiting Room..."
        activatingLabel.font = UIFont.boldSystemFont(ofSize: 20)
        activatingLabel.textAlignment = .center
        activatingLabel.textColor = UIColor(hex: "00C853") // Queue-it green
        activatingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activatingLabel)
        
        // Countdown label (hidden until queue passed)
        countdownLabel = UILabel()
        countdownLabel.text = "00:60"
        countdownLabel.font = UIFont.systemFont(ofSize: 48, weight: .bold)
        countdownLabel.textAlignment = .center
        countdownLabel.textColor = UIColor(hex: "00C853")
        countdownLabel.isHidden = true
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(countdownLabel)
        
        NSLayoutConstraint.activate([
            activatingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activatingLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            countdownLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            countdownLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Retail-feel welcome text (optional – appears with countdown)
        let welcomeLabel = UILabel()
        welcomeLabel.text = "Welcome back!\nYour session is now active."
        welcomeLabel.font = UIFont.systemFont(ofSize: 17)
        welcomeLabel.textAlignment = .center
        welcomeLabel.numberOfLines = 0
        welcomeLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(welcomeLabel)
        
        NSLayoutConstraint.activate([
            welcomeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            welcomeLabel.topAnchor.constraint(equalTo: countdownLabel.bottomAnchor, constant: 24)
        ])
    }
    
    private func activateWaitingRoom() {
        guard let manager = queueManager else {
            showMissingSettingsAlert()
            return
        }
        
        // Use the shared QueueManager (exactly as Settings → Login flow already does)
        // This triggers createEngine() + run() + fullScreenCover web view in MainAppView
        manager.activateWaitingRoom()
    }
    
    private func observeQueueWebViewState() {
        queueManager?.$showWebView
            .receive(on: RunLoop.main)
            .sink { [weak self] isShowing in
                guard let self = self else { return }
                
                // When the web view disappears → user has passed the queue (or queue disabled)
                if self.wasShowingWebView && !isShowing {
                    self.activatingLabel.isHidden = true
                    self.countdownLabel.isHidden = false
                    self.startCountdownTimer()
                }
                
                self.wasShowingWebView = isShowing
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Countdown Timer (exactly as you requested)
    private func startCountdownTimer() {
        remainingTime = 60
        updateCountdownLabel()
        
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingTime -= 1
            self.updateCountdownLabel()
            
            if self.remainingTime <= 0 {
                self.countdownTimer?.invalidate()
                self.countdownTimer = nil
                self.showSessionExpiredModal()
            }
        }
    }
    
    private func updateCountdownLabel() {
        let minutes = remainingTime / 60
        let seconds = remainingTime % 60
        countdownLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func showSessionExpiredModal() {
        let alert = UIAlertController(
            title: "Session Expired",
            message: "Your 60-second demo session has timed out.\nReturning to Home.",
            preferredStyle: .alert
        )
        present(alert, animated: true)
        
        // d. Wait 5 seconds then navigate back to Home
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            alert.dismiss(animated: true) {
                self?.goHomeClosure?()          // Switches currentScreen = .home in SwiftUI
                // Fallback for pure UIKit navigation
                self?.navigationController?.popToRootViewController(animated: true)
            }
        }
    }
    
    private func showMissingSettingsAlert() {
        let alert = UIAlertController(
            title: "Missing Settings",
            message: "Please configure Customer ID and Waiting Room ID in Settings first.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.goHomeClosure?()
        })
        present(alert, animated: true)
    }
    
    deinit {
        countdownTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - UIColor Hex Extension (already in your project, but included for completeness)
extension UIColor {
    convenience init(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
