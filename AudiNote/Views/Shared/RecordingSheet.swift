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

struct SheetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct RecordingSheet: View {
    @ObservedObject var recorder: AudioRecorder
    let onSave: ((Recording) -> Void)?
    let presentationDetent: PresentationDetent
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    
    private var isLargeMode: Bool {
        presentationDetent == .large
    }
    
    init(recorder: AudioRecorder, presentationDetent: PresentationDetent = .fraction(0.25), onSave: ((Recording) -> Void)? = nil) {
        self._recorder = ObservedObject(initialValue: recorder)
        self.presentationDetent = presentationDetent
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
						isLargeMode: isLargeMode,
						onCancel: {
							dismiss()
						},
						onDone: { title in
							saveRecording(title: title)
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
    private func saveRecording(title: String = "New Recording") {
        guard !isSaving else {
            print("Already saving, skipping...")
            return
        }
        isSaving = true

        print("Starting save process...")
        print("Recording duration: \(recordingDuration)")
        print("Last recording URL: \(lastRecordingURL?.path ?? "nil")")
        print("Model context in RecordingSheet: \(String(describing: modelContext))")
        
        // Stop recording first to finalize file and duration
        recorder.stopRecording()
        
        // Random tags for demo purposes
        let allTags = ["Meeting", "Interview", "Lecture", "Note", "Idea", "Memo", "Call", "Music", "Practice", "Important", "Work", "Personal", "Study", "Creative"]
        let randomTags = Array(allTags.shuffled().prefix(Int.random(in: 1...3)))
        
        // Create the recording object
        let newRecording = Recording(
            title: title,
            timestamp: Date(),
            duration: recordingDuration,
            audioFilePath: lastRecordingURL?.path ?? "",
            tags: randomTags
        )
        
        print("Created recording object: \(newRecording.id)")
        print("Recording details: title=\(newRecording.title), duration=\(newRecording.duration), path=\(newRecording.audioFilePath)")
        
        // Check if file actually exists
        if let url = lastRecordingURL, FileManager.default.fileExists(atPath: url.path) {
            print("Audio file exists at: \(url.path)")
        } else {
            print("WARNING: Audio file does not exist at: \(lastRecordingURL?.path ?? "nil")")
        }
        
        // Insert and save immediately
        modelContext.insert(newRecording)
        print("Inserted recording into context")
        
        do {
            try modelContext.save()
            print("Successfully saved recording to database")
            print("Model context after save: \(modelContext)")
            
            // Post notification to refresh the recordings list
            NotificationCenter.default.post(name: NSNotification.Name("RecordingSaved"), object: nil)
        } catch {
            print("Failed to save recording: \(error)")
            print("Save error details: \(error.localizedDescription)")
        }
        
        // Call the callback and dismiss with a small delay to ensure the save propagates
        print("Calling onSave callback and dismissing...")
        onSave?(newRecording)
        
        // Small delay to ensure SwiftData sync completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            dismiss()
        }
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
    @State private var detent: PresentationDetent = .fraction(0.25)

    var body: some View {
        Spacer()
		RecordButton(recorder: recorder, onRecordTapped: { showSheet = true })
            .matchedTransitionSource(id: "Record", in: animation)
            .sheet(isPresented: $showSheet) {
                RecordingSheet(recorder: recorder, presentationDetent: detent)
                    .navigationTransition(.zoom(sourceID: "Record", in: animation))
					.presentationDetents([.fraction(0.25), .large], selection: $detent)
            }
    }
}

#Preview {
    SheetPreviewContainer()
}
