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
	@State private var navigationPath = NavigationPath()
	@Namespace private var animation
	@StateObject private var recorder = AudioRecorder()
	@State private var detent: PresentationDetent = .fraction(0.25)

	var body: some View {
		ZStack(alignment: .bottom) {
			RecordingsView(navigationPath: $navigationPath)

			if navigationPath.isEmpty {
				RecordButton(
					recorder: recorder,
					onRecordTapped: {
						showSheet = true
					}
				)
				.matchedTransitionSource(id: "Record", in: animation)
			}
		}
		.sheet(isPresented: $showSheet) {
			RecordingSheet(recorder: recorder, presentationDetent: detent) { recording in
				navigationPath.append(recording)
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
		.environmentObject(SessionViewModel())
}
