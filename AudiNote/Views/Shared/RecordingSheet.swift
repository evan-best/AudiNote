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

enum RecordingState {
    case idle, recording, paused, error
}

struct RecordingSheet: View {
    let recorder: AudioRecorder
    let onSave: ((Recording) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var state: RecordingState = .idle
    @State private var isSaving = false
    
    init(recorder: AudioRecorder, onSave: ((Recording) -> Void)? = nil) {
        self.recorder = recorder
        self.onSave = onSave
    }

    private var lastRecordingURL: URL? { recorder.getLastRecordingURL() }
    private var recordingDuration: TimeInterval { recorder.elapsed }

    var body: some View {
        VStack(spacing: 0) {
            // Waveform view - takes most of the space
            Group {
                if state == .recording || state == .paused {
                    LiveScrollWaveformView(
                        recorder: recorder,
                        onCancel: {
                            dismiss()
                        },
                        onDone: {
                            saveRecording()
                        }
                    )
                } else {
                    // Idle state - minimal placeholder
                    VStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .overlay(
                                Text("Tap record to start")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            )
                            .frame(height: 60)
                            .padding(.horizontal, 16)
                        
                        Button("Record", systemImage: "record.circle") {
                            guard state == .idle else { return }
                            recorder.startRecording()
                            state = .recording
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .padding(.top, 12)
                    }
                }
            }

            // Control buttons - compact bottom section
            if state == .error {
                VStack(spacing: 8) {
                    Text("An error occurred during recording.")
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    Button("Dismiss") { reset() }
                        .buttonStyle(.bordered)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            // Set state based on recorder's current state
            if recorder.isRecording {
                state = .recording
            } else if recorder.isPaused {
                state = .paused
            }
        }
        .onChange(of: recorder.isRecording) { isRecording in
            // Only update state if we're not currently saving
            if !isSaving {
                if isRecording {
                    state = .recording
                } else if recorder.isPaused {
                    state = .paused
                } else if state != .idle {
                    // Don't change to idle if we were recording (might be saving)
                    state = .idle
                }
            }
        }
        .onChange(of: recorder.isPaused) { isPaused in
            if !isSaving {
                if isPaused {
                    state = .paused
                } else if recorder.isRecording {
                    state = .recording
                }
            }
        }
    }


    // MARK: - Save Functionality
    
    private func saveRecording() {
        guard !isSaving else { return }
        
        isSaving = true
        
        // Create the recording object before stopping the recorder
        let newRecording = Recording(
            title: "New Recording",
            timestamp: Date(),
            duration: recordingDuration,
            audioFilePath: lastRecordingURL?.path ?? ""
        )
        
        // Stop recording
        recorder.stopRecording()
        
        // Insert and save immediately
        modelContext.insert(newRecording)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save recording: \(error)")
        }
        
        // Call the callback and dismiss immediately
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
        RecordButton(onRecordTapped: { showSheet = true })
            .matchedTransitionSource(id: "Record", in: animation)
            .sheet(isPresented: $showSheet) {
                    RecordingSheet(recorder: recorder)
                    .navigationTransition(.zoom(sourceID: "Record", in: animation))
                    .presentationDetents([.fraction(0.25)])
            }
    }
}

#Preview {
    SheetPreviewContainer()
}


