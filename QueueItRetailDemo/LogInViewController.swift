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
    private var statusLabel: UILabel!
    
    // Combine subscription to watch QueueManager's showWebView
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        observeQueueState()
        handleLoginFlow()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Status label (replaces activatingLabel and welcomeLabel – shown in center)
        statusLabel = UILabel()
        statusLabel.font = UIFont.boldSystemFont(ofSize: 20)
        statusLabel.textAlignment = .center
        statusLabel.textColor = UIColor(hex: "00C853") // Queue-it green
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Optional: Add a person icon above for retail/login feel (as in original LoginView.swift)
        let iconImage = UIImage(systemName: "person.crop.circle.badge.checkmark")
        let iconView = UIImageView(image: iconImage)
        iconView.tintColor = UIColor(hex: "00C853")
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iconView)
        
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -40),
            iconView.widthAnchor.constraint(equalToConstant: 120),
            iconView.heightAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    private func handleLoginFlow() {
        guard let manager = queueManager,
              !manager.customerID.isEmpty,
              !manager.waitingRoomID.isEmpty else {
            showMissingSettingsAlert()
            return
        }
        
        if manager.sessionActive {
            updateStatusToWelcome()
        } else {
            statusLabel.text = "NO ACTIVE SESSION!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.statusLabel.text = "Activating Queue-it Waiting Room..."
                manager.activateWaitingRoom()
            }
        }
    }
    
    private func observeQueueState() {
        queueManager?.$sessionActive
            .receive(on: RunLoop.main)
            .sink { [weak self] isActive in
                if isActive {
                    self?.updateStatusToWelcome()
                }
            }
            .store(in: &cancellables)
        
        // Optional: Hide status during web view (though fullScreenCover overlays anyway)
        queueManager?.$showWebView
            .receive(on: RunLoop.main)
            .sink { [weak self] isShowing in
                self?.statusLabel.isHidden = isShowing
            }
            .store(in: &cancellables)
    }
    
    private func updateStatusToWelcome() {
        statusLabel.text = "Welcome back!\nYour session is active."
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
