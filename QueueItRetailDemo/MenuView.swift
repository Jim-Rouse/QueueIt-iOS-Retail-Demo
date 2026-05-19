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
                ForEach([AppScreen.home, .login, .productList, .settings, .userState], id: \.self) { screen in
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
        case .home:        return "house"
        case .login:       return "arrow.right.square"
        case .productList: return "cart"
        case .settings:    return "gear"
        case .userState:   return "person.text.rectangle"
        }
    }
}

// MARK: - Menu Row
struct MenuRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
