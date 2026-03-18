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
                ForEach([AppScreen.settings, .userState], id: \.self) { screen in
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
        case .settings: return "gear"
        case .userState: return "person.text.rectangle"
        default: return "square"
        }
    }
}
