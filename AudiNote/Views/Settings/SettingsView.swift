//
//  SettingsView.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showSignOutAlert = false
    @State private var notificationsEnabled = true
    @State private var recordingReminders = false
    @State private var transcriptionComplete = true
    
    @State private var autoDeleteAfterDays = 30
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("App") {
                        Picker("Appearance", selection: $session.appearanceMode) {
                            Text("System").tag("System")
                            Text("Light").tag("Light")
                            Text("Dark").tag("Dark")
                        }
                        .pickerStyle(.menu)
                        .onChange(of: session.appearanceMode) { _, newValue in
                            session.setAppearance(newValue)
                        }
                        
                        Toggle("Haptic Feedback", isOn: $session.hapticFeedbackEnabled)
                            .tint(.accentColor)
                            .onChange(of: session.hapticFeedbackEnabled) { _, newValue in
                                session.setHapticFeedback(newValue)
                            }
                        
                        HStack {
                            Text("Auto-delete after")
                            Spacer()
                            Picker("Days", selection: $autoDeleteAfterDays) {
                                Text("Never").tag(0)
                                Text("7 days").tag(7)
                                Text("30 days").tag(30)
                                Text("90 days").tag(90)
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    
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
                        Button(action: { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            dismiss() 
                        }) {
                            Image(systemName: "xmark")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            saveSettings()
                            dismiss()
                        }) {
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
            .preferredColorScheme(session.colorScheme)
        }
    }
    
    private func saveSettings() {
        print("Settings saved - Auto-delete: \(autoDeleteAfterDays) days")
    }
}

#Preview {
    SettingsView()
}
