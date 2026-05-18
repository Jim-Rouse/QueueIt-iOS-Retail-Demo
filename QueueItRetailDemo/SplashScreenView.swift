//
//  SplashScreenView.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 2/26/26.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var showMain = false
    @State private var logoOpacity = 0.0
    @State private var logoScale = 0.8

    var body: some View {
        if showMain {
            MainAppView()
        } else {
            ZStack {
                // Electric Blue background
                Color(hex: "262BED")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Logo / wordmark
                    VStack(spacing: 16) {
                        Image("logo-white")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 280)

                        Text("Fair Access. Every Drop.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    Spacer()

                    // Footer
                    VStack(spacing: 4) {
                        Divider()
                            .background(Color.white.opacity(0.2))
                        Text("Powered by Queue-it")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.45))
                            .padding(.bottom, 32)
                    }
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    logoOpacity = 1.0
                    logoScale = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showMain = true
                    }
                }
            }
        }
    }
}
