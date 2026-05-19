//
//  SplashScreenView.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 2/26/26.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var showMain    = false
    @State private var logoOpacity = 0.0
    @State private var logoScale   = 0.8

    var body: some View {
        if showMain {
            ShopItRootView()
        } else {
            ZStack {
                Color(hex: "00C853").ignoresSafeArea()
                Text("QUEUE-IT")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .kerning(4)
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    logoOpacity = 1.0
                    logoScale   = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.4)) { showMain = true }
                }
            }
        }
    }
}
