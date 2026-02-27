//
//  SettingsView.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 2/26/26.
//


import SwiftUI

struct SettingsView: View {
    @AppStorage("customerID") private var customerID = ""
    @AppStorage("waitingRoomID") private var waitingRoomID = ""
    @AppStorage("layoutName") private var layoutName = ""
    @AppStorage("language") private var language = "en"
    @AppStorage("enqueueToken") private var enqueueToken = ""
    @AppStorage("enqueueKey") private var enqueueKey = ""
    @AppStorage("waitingRoomDomain") private var waitingRoomDomain = ""
    @AppStorage("waitingRoomPrefix") private var waitingRoomPrefix = ""
    
    var body: some View {
        Form {
            Section("Queue-it Configuration") {
                TextField("Customer ID", text: $customerID)
                TextField("Waiting Room or Alias ID", text: $waitingRoomID)
                TextField("Layout Name (Theme)", text: $layoutName)
                TextField("Language (en, da, etc.)", text: $language)
                TextField("Enqueue Token", text: $enqueueToken)
                TextField("Enqueue Key", text: $enqueueKey)
                TextField("Waiting Room Domain", text: $waitingRoomDomain)
                TextField("Waiting Room Prefix", text: $waitingRoomPrefix)
            }
        }
        .navigationTitle("Settings")
    }
}
