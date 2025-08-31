//
//  SettingsView.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOutAlert = false
    @State private var notificationsEnabled = true
    @State private var recordingReminders = false
    @State private var transcriptionComplete = true
    @State private var cloudSyncEnabled = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                Form {
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .tint(.accentColor)
                    
                    Toggle("Recording Reminders", isOn: $recordingReminders)
                        .tint(.accentColor)
                        .disabled(!notificationsEnabled)
                    
                    Toggle("Transcription Complete", isOn: $transcriptionComplete)
                        .tint(.accentColor)
                        .disabled(!notificationsEnabled)
                }
                
                Section("Data & Sync") {
                    Toggle("iCloud Sync", isOn: $cloudSyncEnabled)
                        .tint(.accentColor)
                    
                    HStack {
                        Text("Storage Used")
                        Spacer()
                        Text("2.3 GB")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Support") {
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                    Link("Contact Support", destination: URL(string: "mailto:support@example.com")!)
                }

                Section {
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        Text("Sign Out")
                            .foregroundStyle(.red)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveSettings) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    session.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out? You'll need to sign in again to access your recordings.")
            }
            }
        }
    }
    
    private func saveSettings() {
        print("Settings saved")
    }
}

#Preview {
    SettingsView()
}
