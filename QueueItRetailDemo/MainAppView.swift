//
//  MainAppView.swift
//  QueueItRetailDemo
//

import SwiftUI
import QueueItKit

// MARK: - AppScreen Enum
enum AppScreen: String, CaseIterable {
    case home        = "Home"
    case login       = "Log-in"
    case productList = "Product List"
    case settings    = "Settings"
    case userState   = "User State"
}

// MARK: - Main App View
struct MainAppView: View {
    @StateObject private var queueManager = QueueManager()
    @State private var currentScreen: AppScreen = .home
    @State private var showMenu = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main Content
                Group {
                    switch currentScreen {
                    case .home:        HomeView(currentScreen: $currentScreen)
                    case .login:       LogInRepresentable(queueManager: queueManager, currentScreen: $currentScreen)
                    case .productList: ProductListView(queueManager: queueManager)
                    case .settings:    SettingsView()
                    case .userState:   UserStateView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom Bar (Settings + User State only)
                VStack {
                    Spacer()
                    if queueManager.sessionActive {
                        Text(String(format: "%02d:%02d", queueManager.remainingTime / 60, queueManager.remainingTime % 60))
                            .font(.title2.bold())
                            .foregroundColor(Color(hex: "00C853"))
                            .padding(.bottom, 8)
                    }
                    CustomBottomBar(currentScreen: $currentScreen)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showMenu = true } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Queue-it Retail")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(Color(hex: "00C853"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $queueManager.showWebView) {
            if let manager = queueManager.viewManager {
                QueueWebViewContainer(viewManager: manager)
            }
        }
        .alert("Queue-it Error", isPresented: $queueManager.showError) {
            Button("OK") {}
        } message: {
            Text(queueManager.errorMessage)
        }
        .sheet(isPresented: $showMenu) {
            MenuView(currentScreen: $currentScreen)
        }
        .environmentObject(queueManager)
        .onChange(of: queueManager.navigateToHome) { newValue in
            if newValue {
                currentScreen = .home
                queueManager.navigateToHome = false
            }
        }
    }
}

// MARK: - Custom Bottom Bar
struct CustomBottomBar: View {
    @Binding var currentScreen: AppScreen
    
    var body: some View {
        HStack(spacing: 0) {
            BottomButton(title: "Settings", icon: "gear", screen: .settings, current: $currentScreen)
            BottomButton(title: "User State", icon: "person.text.rectangle", screen: .userState, current: $currentScreen)
        }
        .background(Color.white.shadow(radius: 8))
    }
}

struct BottomButton: View {
    let title: String
    let icon: String
    let screen: AppScreen
    @Binding var current: AppScreen
    
    var body: some View {
        Button {
            current = screen
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(current == screen ? Color(hex: "00C853") : .gray)
        }
    }
}

// MARK: - LogIn Wrapper
struct LogInRepresentable: UIViewControllerRepresentable {
    @ObservedObject var queueManager: QueueManager
    @Binding var currentScreen: AppScreen

    func makeUIViewController(context: Context) -> LogInViewController {
        let vc = LogInViewController()
        vc.queueManager = queueManager
        vc.goHomeClosure = { currentScreen = .home }
        return vc
    }

    func updateUIViewController(_ uiViewController: LogInViewController, context: Context) {}
}
