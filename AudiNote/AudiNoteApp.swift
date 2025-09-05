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
        // CloudKit-backed configuration
        let config = ModelConfiguration(
            "iCloud.AudiNote",
            cloudKitDatabase: .automatic // Uses the private database by default
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Fallback: If CloudKit container cannot be created (e.g., in Previews), fall back to local
            assertionFailure("Failed to create CloudKit-backed ModelContainer: \(error)")
            return try! ModelContainer(for: schema)
        }
    }()
    
    var body: some Scene {
        WindowGroup {
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
        .modelContainer(Self.cloudContainer)
    }
}
