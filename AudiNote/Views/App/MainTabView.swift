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
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@State private var selection: Tabs = .recordings
	@State private var showSheet: Bool = false
	@State private var navigationPath = NavigationPath()
	@Namespace private var animation
	@StateObject private var recorder = AudioRecorder()
	@State private var detent: PresentationDetent = .fraction(0.25)

	private var recordButtonAlignment: Alignment {
		horizontalSizeClass == .regular ? .bottomLeading : .bottom
	}

	private var recordButtonWidth: CGFloat? {
		horizontalSizeClass == .regular ? 320 : nil
	}

	private var availableDetents: Set<PresentationDetent> {
		horizontalSizeClass == .regular ? [.large] : [.fraction(0.25), .large]
	}

	var body: some View {
		ZStack(alignment: recordButtonAlignment) {
			RecordingsView(
				navigationPath: $navigationPath,
				recordButton: horizontalSizeClass == .regular ? AnyView(
					RecordButton(
						recorder: recorder,
						onRecordTapped: {
							showSheet = true
						},
						maxWidth: recordButtonWidth
					)
					.padding(.horizontal, 16)
					.padding(.bottom, 12)
					.buttonStyle(.plain)
					.tint(.primary)
				) : nil
			)

			if navigationPath.isEmpty && horizontalSizeClass != .regular {
				RecordButton(
					recorder: recorder,
					onRecordTapped: {
						showSheet = true
					},
					maxWidth: recordButtonWidth
				)
				.padding(.leading, horizontalSizeClass == .regular ? 12 : 0)
				.padding(.bottom, horizontalSizeClass == .regular ? 12 : 0)
				.matchedTransitionSource(id: "Record", in: animation)
			}
		}
		.sheet(isPresented: Binding(
			get: { showSheet && horizontalSizeClass != .regular },
			set: { showSheet = $0 }
		)) {
			RecordingSheet(recorder: recorder, presentationDetent: detent) { recording in
				navigationPath.append(recording)
			}
			.environment(\.modelContext, modelContext)
			.navigationTransition(.zoom(sourceID: "Record", in: animation))
			.presentationDetents(availableDetents, selection: $detent)
			.presentationDragIndicator(.visible)
			.interactiveDismissDisabled(false)
		}
		.fullScreenCover(isPresented: Binding(
			get: { showSheet && horizontalSizeClass == .regular },
			set: { showSheet = $0 }
		)) {
			RecordingSheet(recorder: recorder, presentationDetent: .large) { recording in
				navigationPath.append(recording)
			}
			.environment(\.modelContext, modelContext)
		}
		.onChange(of: horizontalSizeClass) { _, newValue in
			if newValue == .regular {
				detent = .large
			} else if detent != .large {
				detent = .fraction(0.25)
			}
		}
	}
}

#Preview {
    MainTabView()
        .modelContainer(for: Recording.self, inMemory: true)
		.environmentObject(SessionViewModel())
}
