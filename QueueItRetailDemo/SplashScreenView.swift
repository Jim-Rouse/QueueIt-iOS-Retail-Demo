//
//  SplashScreenView.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 2/26/26.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var showMain = false
    
    var body: some View {
        if showMain {
            MainAppView()
        } else {
            ZStack {
                Color(hex: "00C853")
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    
                    
                    Text("QUEUE-IT")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .kerning(4)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showMain = true
                    }
                }
            }
        }
    }
}
