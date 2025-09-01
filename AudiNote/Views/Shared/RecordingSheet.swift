//
//  RecordingSheet.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import SwiftUI
import AVFoundation
import Combine
import SwiftData

struct RecordingSheet: View {
    @ObservedObject var recorder: AudioRecorder
    let onSave: ((Recording) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    
    init(recorder: AudioRecorder, onSave: ((Recording) -> Void)? = nil) {
        self._recorder = ObservedObject(initialValue: recorder)
        self.onSave = onSave
    }

    private var lastRecordingURL: URL? { recorder.getLastRecordingURL() }
    private var recordingDuration: TimeInterval { recorder.elapsed }

    var body: some View {
        VStack(spacing: 0) {
            // Waveform view - takes most of the space
            Group {
                if recorder.isRecording || recorder.isPaused {
					Spacer()
                    LiveScrollWaveformView(
                        recorder: recorder,
                        onCancel: {
                            dismiss()
                        },
                        onDone: {
                            saveRecording()
                        }
                    )
                }
            }
        }
        .onAppear {
            // No local state to sync; UI reacts to recorder directly.
        }
    }

    // MARK: - Save Functionality
    private func saveRecording() {
        guard !isSaving else {
            print("Already saving, skipping...")
            return
        }
        isSaving = true

        print("Starting save process...")
        print("Recording duration: \(recordingDuration)")
        print("Last recording URL: \(lastRecordingURL?.path ?? "nil")")
        
        // Stop recording first to finalize file and duration
        recorder.stopRecording()
        
        // Create the recording object
        let newRecording = Recording(
            title: "New Recording",
            timestamp: Date(),
            duration: recordingDuration,
            audioFilePath: lastRecordingURL?.path ?? ""
        )
        
        print("Created recording object: \(newRecording.id)")
        
        // Insert and save immediately
        modelContext.insert(newRecording)
        print("Inserted recording into context")
        
        do {
            try modelContext.save()
            print("Successfully saved recording to database")
        } catch {
            print("Failed to save recording: \(error)")
        }
        
        // Call the callback and dismiss
        print("Calling onSave callback and dismissing...")
        onSave?(newRecording)
        dismiss()
    }

    // MARK: - Helpers
    private func reset() {
        recorder.stopRecording()
        dismiss()
    }

    private func formattedTime(_ duration: TimeInterval) -> String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct SheetPreviewContainer: View {
    @State private var showSheet = false
    @StateObject private var recorder = AudioRecorder()
    @Namespace private var animation

    var body: some View {
        Spacer()
		RecordButton(recorder: recorder, onRecordTapped: { showSheet = true })
            .matchedTransitionSource(id: "Record", in: animation)
            .sheet(isPresented: $showSheet) {
                RecordingSheet(recorder: recorder)
                    .navigationTransition(.zoom(sourceID: "Record", in: animation))
					.presentationDetents([.fraction(0.25), .large])
            }
    }
}

#Preview {
    SheetPreviewContainer()
}
