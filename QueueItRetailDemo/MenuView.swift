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
        ZStack {
            Color(hex: "262BED")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Header
                VStack(spacing: 8) {
                    Image("logo-white")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160)
                        .padding(.top, 80)
                    Text("Fair Access. Every Drop.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.65))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 40)

                // MARK: - Menu Items
                VStack(spacing: 12) {
                    MenuRow(icon: "house.fill", title: "Home") {
                        currentScreen = .home
                        dismiss()
                    }
                    MenuRow(icon: "gear", title: "Settings") {
                        currentScreen = .settings
                        dismiss()
                    }
                    MenuRow(icon: "person.text.rectangle", title: "User State") {
                        currentScreen = .userState
                        dismiss()
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // MARK: - Footer
                VStack(spacing: 4) {
                    Divider()
                        .background(Color.white.opacity(0.2))
                    Text("Powered by Queue-it")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.vertical, 24)
                }
            }
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
