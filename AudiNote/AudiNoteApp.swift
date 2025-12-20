//
//  AudiNoteApp.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import SwiftUI
import SwiftData
import CloudKit

@main
struct AudiNoteApp: App {
    @StateObject private var session = SessionViewModel()
    
    // Create a CloudKit-backed SwiftData container using your container ID.
    // Ensure the iCloud capability is enabled and the container "iCloud.AudiNote" is checked for this target.
    private static var cloudContainer: ModelContainer = {
        let schema = Schema([Recording.self])

        // Use a versioned database name to allow fresh starts when schema changes
        let dbName = "AudiNote_v3"

        // First, try simple local storage (most reliable for development)
        do {
            let localConfig = ModelConfiguration(
                dbName,
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            // If local storage fails, use in-memory as absolute fallback
            do {
                let memoryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                fatalError("Cannot create ModelContainer even with in-memory storage: \(error)")
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if session.isAuthenticated {
                    MainTabView()
                        .environmentObject(session)
                        .preferredColorScheme(session.colorScheme)
                } else {
                    OnboardingView()
                        .environmentObject(session)
                        .preferredColorScheme(session.colorScheme)
                }
            }
            .toast()
        }
        .modelContainer(Self.cloudContainer)
    }
}
