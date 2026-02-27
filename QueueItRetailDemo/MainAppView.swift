//
//  MainAppView.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 2/26/26.
//



import SwiftUI
import QueueItKit

enum AppScreen: String, CaseIterable {
    case home = "Home"
    case login = "Log-in"
    case productList = "Product List"
    case settings = "Settings"
    case userState = "User State"
}

struct MainAppView: View {
    @StateObject private var queueManager = QueueManager()
    @State private var currentScreen: AppScreen = .home
    @State private var showMenu = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                Group {
                    switch currentScreen {
                    case .home:        HomeView()
                    case .login:       LoginView(queueManager: queueManager)
                    case .productList: ProductListView(queueManager: queueManager)
                    case .settings:    SettingsView()
                    case .userState:   UserStateView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Custom bottom bar (only 2 buttons as requested)
                VStack {
                    Spacer()
                    CustomBottomBar(currentScreen: $currentScreen)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showMenu = true }) {
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
    }
}

// MARK: - Custom Bottom Bar (only Settings + User State)
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
