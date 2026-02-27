//
//  MenuView.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 2/26/26.
//


import SwiftUI

struct MenuView: View {
    @Binding var currentScreen: AppScreen
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach([AppScreen.home, .login, .productList], id: \.self) { screen in
                    Button {
                        currentScreen = screen
                        dismiss()
                    } label: {
                        Label(screen.rawValue, systemImage: iconFor(screen))
                    }
                }
            }
            .navigationTitle("Menu")
        }
    }
    
    private func iconFor(_ screen: AppScreen) -> String {
        switch screen {
        case .home: return "house"
        case .login: return "arrow.right.square"
        case .productList: return "cart"
        default: return "square"
        }
    }
}