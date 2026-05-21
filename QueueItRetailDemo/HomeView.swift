//
//  HomeView.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 2/26/26.
//

import SwiftUI

struct HomeView: View {
    @Binding var currentScreen: AppScreen

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // MARK: - Hero Section
                ZStack {
                    Color(hex: "262BED")
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        // Badge
                        Text("QUEUE-IT PROTECTED EXPERIENCE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())

                        // Hero headline
                        Text("Fair Access.\nEvery Drop.")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .minimumScaleFactor(0.7)
                            .lineLimit(2)

                        // Subheading
                        Text("The Shop-it demo showcases seamless virtual waiting room integration — Simple and Hybrid — so every customer gets a fair shot.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)

                        // CTA Buttons
                        HStack(spacing: 12) {
                            Button(action: { currentScreen = .productList }) {
                                Text("Browse Products")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "262BED"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }

                            Button(action: { currentScreen = .login }) {
                                Text("Sign In")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                                    )
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.top, 100)
                    .padding(.bottom, 24)
                    .padding(.horizontal, 24)
                }

                // MARK: - Feature Cards
                VStack(spacing: 1) {
                    Text("NEW ARRIVALS")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "262BED"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 12)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        FeatureCard(icon: "lock.shield.fill",   title: "Queue-it Protected",  subtitle: "Bot control built in")
                        FeatureCard(icon: "person.fill.checkmark", title: "Simple Integration", subtitle: "Protect your login")
                        FeatureCard(icon: "cart.fill.badge.plus",  title: "Hybrid Integration", subtitle: "Gate product pages")
                        FeatureCard(icon: "chart.line.uptrend.xyaxis", title: "Real-time Queue", subtitle: "Live position updates")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Feature Card Component
struct FeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(Color(hex: "262BED"))
                .frame(width: 44, height: 44)
                .background(Color(hex: "262BED").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Text(subtitle)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
