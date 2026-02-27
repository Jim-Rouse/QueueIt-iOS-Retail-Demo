//
//  LoginView.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 2/26/26.
//


import SwiftUI

struct LoginView: View {
    @ObservedObject var queueManager: QueueManager
    
    var body: some View {
        VStack(spacing: 40) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 120))
                .foregroundColor(Color(hex: "00C853"))
            
            Text("Log-in")
                .font(.largeTitle.bold())
            
            Text("Activating Queue-it Waiting Room...")
                .font(.title3)
            
            if queueManager.customerID.isEmpty || queueManager.waitingRoomID.isEmpty {
                Text("Please configure Customer ID and Waiting Room ID in Settings first")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            if !queueManager.customerID.isEmpty && !queueManager.waitingRoomID.isEmpty {
                queueManager.activateWaitingRoom()
            }
        }
    }
}