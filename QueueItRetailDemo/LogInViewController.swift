//
//  LogInViewController.swift
//  QueueItRetailDemo
//
//  Now uses the shared QueueManager to activate the waiting room
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
    private var usernameField: UITextField!
    private var passwordField: UITextField!
    private var logInButton: UIButton!
    
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
        
        // Username field (hidden until active session)
        usernameField = UITextField()
        usernameField.placeholder = "User Name"
        usernameField.borderStyle = .roundedRect
        usernameField.autocapitalizationType = .none
        usernameField.autocorrectionType = .no
        usernameField.translatesAutoresizingMaskIntoConstraints = false
        usernameField.isHidden = true
        view.addSubview(usernameField)
        
        // Password field (hidden until active session)
        passwordField = UITextField()
        passwordField.placeholder = "Password"
        passwordField.borderStyle = .roundedRect
        passwordField.isSecureTextEntry = true
        passwordField.translatesAutoresizingMaskIntoConstraints = false
        passwordField.isHidden = true
        view.addSubview(passwordField)
        
        // Log In button (hidden until active session, styled with Queue-it green)
        logInButton = UIButton(type: .system)
        logInButton.setTitle("Log In", for: .normal)
        logInButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        logInButton.backgroundColor = UIColor(hex: "00C853")
        logInButton.setTitleColor(.white, for: .normal)
        logInButton.layer.cornerRadius = 8
        logInButton.translatesAutoresizingMaskIntoConstraints = false
        logInButton.isHidden = true
        logInButton.addTarget(self, action: #selector(handleLogInTap), for: .touchUpInside)
        view.addSubview(logInButton)
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),  // Shift up for fields/button
            
            usernameField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            usernameField.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 40),
            usernameField.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            
            passwordField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            passwordField.topAnchor.constraint(equalTo: usernameField.bottomAnchor, constant: 20),
            passwordField.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            
            logInButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logInButton.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 20),
            logInButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6),
            logInButton.heightAnchor.constraint(equalToConstant: 50)
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
            usernameField.isHidden = true
            passwordField.isHidden = true
            logInButton.isHidden = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.statusLabel.text = "Activating Queue-it Waiting Room..."
                manager.activateWaitingRoom()
            }
        }
    }
    
    private func observeQueueState() {
        queueManager?.$queuePassed
            .receive(on: RunLoop.main)
            .sink { [weak self] passed in
                if passed { self?.updateStatusToWelcome() }
            }
            .store(in: &cancellables)

        queueManager?.$showWebView
            .receive(on: RunLoop.main)
            .sink { [weak self] isShowing in
                self?.statusLabel.isHidden = isShowing
            }
            .store(in: &cancellables)
    }
    
    private func updateStatusToWelcome() {
        UIView.animate(withDuration: 0.3) {
            self.statusLabel.alpha = 0
        } completion: { _ in
            self.statusLabel.isHidden = true
        }
        usernameField.isHidden = false
        passwordField.isHidden = false
        logInButton.isHidden = false
    }
    
    @objc private func handleLogInTap() {
        // For demo purposes: Show a simple alert or print credentials
        // In a real app, this would trigger auth with backend using queue token
        guard let username = usernameField.text, !username.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            showAlert(title: "Error", message: "Please enter username and password.")
            return
        }
        
        print("Demo Log In: Username - \(username), Password - \(password)")
        showAlert(title: "Success", message: "Logged in successfully! (Demo)")
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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
