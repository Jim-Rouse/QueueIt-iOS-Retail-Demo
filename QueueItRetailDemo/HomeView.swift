//
//  HomeView.swift
//  QueueItRetailDemo
//

import SwiftUI

struct HomeView: View {
    @Binding var currentScreen: AppScreen
    
    var body: some View {
        ZStack {
            Color(hex: "00C853").opacity(0.95).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    Text("QUEUE-IT PROTECTED EXPERIENCE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                    
                    Text("Fair Access.\nEvery Drop.")
                        .font(.system(size: 36, weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                    
                    Text("The Shop-it demo showcases seamless virtual waiting room integration.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        Button { currentScreen = .productList } label: {
                            Text("Browse Products")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: "#262B2D"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        
                        Button { currentScreen = .login } label: {
                            Text("Try Login Flow")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.2))
                                .overlay(Capsule().stroke(Color.white, lineWidth: 1.5))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 60)
            }
        }
    }
}
