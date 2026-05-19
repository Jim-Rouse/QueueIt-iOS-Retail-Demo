//
//  MainAppView.swift
//  QueueItRetailDemo
//

import SwiftUI

enum AppScreen: String, CaseIterable {
    case home      = "Home"
    case settings  = "Settings"
    case userState = "User State"
}

struct MainAppView: View {
    @StateObject private var queueManager = QueueManager()
    @State private var currentScreen: AppScreen = .home
    @State private var showMenu = false

    var body: some View {
        NavigationStack {
            Group {
                switch currentScreen {
                case .home:      HomeView()
                case .settings:  SettingsView()
                case .userState: UserStateView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .sheet(isPresented: $showMenu) {
            MenuView(currentScreen: $currentScreen)
        }
        .environmentObject(queueManager)
    }
}
