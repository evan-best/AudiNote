//
//  SettingsView.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(role: .destructive) {
                        session.signOut()
                    } label: {
                        Text("Sign Out")
                            .foregroundStyle(.red)
                    }
                }

                Section("Appearance") {
                    HStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 20, height: 20)
                        Text("Accent Color")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
