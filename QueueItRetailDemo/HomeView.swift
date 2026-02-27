//
//  HomeView.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 2/26/26.
//


import SwiftUI

struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Image("queueit-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .opacity(0.15)
                
                Text("Welcome to Queue-it Retail Demo")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                
                Text("To use this app:\n\n• Enter your Queue-it details in Settings\n• Browse products\n• Tap Log-in to experience the real waiting room")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Text("Retail feel with real Queue-it protection")
                    .font(.headline)
                    .foregroundColor(Color(hex: "00C853"))
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}