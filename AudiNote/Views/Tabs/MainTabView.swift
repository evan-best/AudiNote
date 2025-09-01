//
//  MainTabView.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import SwiftUI

struct MainTabGateView: View {
    @StateObject private var session = SessionViewModel()

    var body: some View {
        if session.isAuthenticated {
            MainTabView().environmentObject(session)
        } else {
            OnboardingView().environmentObject(session)
        }
    }
}

enum Tabs {
    case recordings, favourites, capture
}

struct MainTabView: View {
    @State private var selection: Tabs = .recordings
    @State private var showSheet: Bool = false
    @State private var showRecordingDetail = false
    @State private var recordingToShow: Recording? = nil
    @Namespace private var animation
    @StateObject private var recorder = AudioRecorder() // Single shared recorder
    
    private let sampleAmplitudes: [CGFloat] = (0..<50).map { i in
        let value = CGFloat(abs(sin(Double(i) * 0.3))) * 0.9 + 0.1
        return value
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom){
                RecordingsView()
                RecordButton(
                    recorder: recorder,
                    onRecordTapped: {
                        // The button will call startRecording() before this,
                        // so by the time we present, the sheet will see recording == true.
                        showSheet = true
                    },
                    onSave: { recording in
                        print("MainTabView: onSave called with recording: \(recording.id.uuidString)")
                        recordingToShow = recording
                        print("MainTabView: recordingToShow set to: \(recordingToShow?.id.uuidString ?? "nil")")
                        // Small delay to allow the recording sheet to fully dismiss
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            print("MainTabView: About to show detail. recordingToShow: \(recordingToShow?.id.uuidString ?? "nil")")
                            showRecordingDetail = true
                            print("MainTabView: showRecordingDetail set to true after delay")
                        }
                    }
                )
				.matchedTransitionSource(id: "Record", in: animation)
            }
            .sheet(isPresented: $showSheet) {
                // Use the same shared recorder instance
                RecordingSheet(recorder: recorder)
                    .navigationTransition(.zoom(sourceID: "Record", in: animation))
                    .presentationDetents([.fraction(0.25), .large])
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled(false)
            }
            .fullScreenCover(isPresented: $showRecordingDetail) {
                Group {
                    if let recording = recordingToShow {
                        RecordingDetailView(recording: recording)
                    } else {
                        Text("Error: No recording selected")
                    }
                }
            }
        }
    }
}

#Preview {
    MainTabGateView()
}
