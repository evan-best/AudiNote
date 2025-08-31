//
//  AudiNoteApp.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import SwiftUI
import SwiftData

@main
struct AudiNoteApp: App {
    @StateObject private var session = SessionViewModel()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(session)
        }
        .modelContainer(for: Recording.self)
    }
}

