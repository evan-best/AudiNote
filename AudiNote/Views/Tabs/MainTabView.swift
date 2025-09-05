//
//  MainTabView.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import SwiftUI
import SwiftData


enum Tabs {
    case recordings, favourites, capture
}

struct MainTabView: View {
	@Environment(\.modelContext) private var modelContext
	@State private var selection: Tabs = .recordings
	@State private var showSheet: Bool = false
	@Namespace private var animation
	@StateObject private var recorder = AudioRecorder() // Single shared recorder
	@State private var detent: PresentationDetent = .fraction(0.25)
	
	private let sampleAmplitudes: [CGFloat] = (0..<50).map { i in
		let value = CGFloat(abs(sin(Double(i) * 0.3))) * 0.9 + 0.1
		return value
	}
	
	var body: some View {
		ZStack(alignment: .bottom) {
			RecordingsView()
			
			RecordButton(
				recorder: recorder,
				onRecordTapped: {
					showSheet = true
				},
				onSave: { recording in
					print("MainTabView: onSave called with recording: \(recording.id.uuidString)")
				}
			)
			.matchedTransitionSource(id: "Record", in: animation)
		}
		.sheet(isPresented: $showSheet) {
			// Use the same shared recorder instance
			RecordingSheet(recorder: recorder, presentationDetent: detent) { recording in
				print("MainTabView: RecordingSheet onSave called with recording: \(recording.id.uuidString)")
			}
			.environment(\.modelContext, modelContext)
			.navigationTransition(.zoom(sourceID: "Record", in: animation))
			.presentationDetents([.fraction(0.25), .large], selection: $detent)
			.presentationDragIndicator(.visible)
			.interactiveDismissDisabled(false)
		}
	}
}

#Preview {
    MainTabView()
        .modelContainer(for: Recording.self, inMemory: true)
}
