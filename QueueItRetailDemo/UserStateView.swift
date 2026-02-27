//
//  UserStateView.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 2/26/26.
//


import SwiftUI
import WebKit

struct UserStateView: View {
    @State private var showingCleared = false
    
    var body: some View {
        List {
            Section("Current Shared Preferences") {
                ForEach(UserDefaultsKeys.allCases, id: \.self) { key in
                    HStack {
                        Text(key.rawValue)
                        Spacer()
                        Text(UserDefaults.standard.string(forKey: key.rawValue) ?? "—")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                Button(role: .destructive) {
                    clearPreferences()
                } label: {
                    Label("Clear Shared Preferences", systemImage: "trash")
                }
                
                Button(role: .destructive) {
                    clearCookies()
                } label: {
                    Label("Clear Cookies (WebView & Default Browser simulation)", systemImage: "globe")
                }
            }
        }
        .navigationTitle("User State")
        .alert("Cleared", isPresented: $showingCleared) {
            Button("OK") {}
        }
    }
    
    private func clearPreferences() {
        UserDefaultsKeys.allCases.forEach {
            UserDefaults.standard.removeObject(forKey: $0.rawValue)
        }
        showingCleared = true
    }
    
    private func clearCookies() {
        let dataStore = WKWebsiteDataStore.default()
        dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                             modifiedSince: .distantPast) {
            showingCleared = true
        }
    }
}

enum UserDefaultsKeys: String, CaseIterable {
    case customerID, waitingRoomID, layoutName, language,
         enqueueToken, enqueueKey, waitingRoomDomain, waitingRoomPrefix
}