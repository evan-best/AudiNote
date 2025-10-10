//
//  RecordButton.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-15.
//

import SwiftUI
import SwiftData

struct RecordButton: View {
    @ObservedObject var recorder: AudioRecorder
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var session: SessionViewModel
    @Namespace private var animation

    var onRecordTapped: (() -> Void)? = nil
    var onSave: ((Recording) -> Void)? = nil

    // Permission alert state
    @State private var showMicAlert = false

    // Sample waveform data
    private let sampleAmplitudes: [CGFloat] = {
        (0..<50).map { i in
            let value = CGFloat(abs(sin(Double(i) * 0.3))) * 0.9 + 0.1
            return value
        }
    }()
    
    init(recorder: AudioRecorder, onRecordTapped: (() -> Void)? = nil, onSave: ((Recording) -> Void)? = nil) {
        self.recorder = recorder
        self.onRecordTapped = onRecordTapped
        self.onSave = onSave
    }
    
    var body: some View {
        Group {
            if recorder.isRecording || recorder.isPaused {
                // Show waveform in same button style
                Button(action: {
                    // Haptic feedback for waveform tap
                    session.triggerHaptic(style: .medium)
                    // Already recording; just present the sheet
                    onRecordTapped?()
                }) {
                    HStack(spacing: 12) {
                        // Waveform takes up most space
                        WaveformView(amplitudes: recorder.amplitudes, color: Color(.systemBackground), isPaused: recorder.isPaused)
                            .frame(height: 20)
                        
                        Spacer()
                        
                        // Timer and indicators on the right
                        HStack(spacing: 6) {
                            if recorder.isPaused {
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(.systemBackground))
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            }
                            
                            Text(recorder.elapsedTimeFormatted)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(.systemBackground))
                                .monospacedDigit()
                                .frame(minWidth: 50, alignment: .leading)
                        }
                    }
                    .padding(18)
                    .background(Color.primary)
                    .clipShape(Capsule())
                    .padding(.horizontal, 28)
                }
                .matchedTransitionSource(id: "Record", in: animation)
            } else {
                // Show record button when not recording
                Button(action: {
                    Task { @MainActor in
                        // Haptic feedback for record button tap
                        session.triggerHaptic(style: .heavy)
                        
                        let granted = await recorder.ensureMicrophonePermission()
                        if granted {
                            startRecording()
                            onRecordTapped?()
                        } else {
                            showMicAlert = true
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Spacer()
                        Image(systemName:"record.circle.fill")
                            .foregroundStyle(.red)
                        Text("Record")
                            .foregroundStyle(.background)
                        Spacer()
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .padding(18)
                    .background(Color.primary)
                    .clipShape(Capsule())
                    .padding(.horizontal, 28)
                }
                .matchedTransitionSource(id: "Record", in: animation)
                .alert("Microphone Access Needed", isPresented: $showMicAlert) {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("AudiNote needs access to your microphone to record audio. You can enable access in Settings.")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Actions
    private func startRecording() {
        recorder.startRecording()
    }
    
    private func cancelRecording() {
        recorder.stopRecording()
    }
    
    private func saveRecording() {
        let recordingDuration = recorder.elapsed
        let lastRecordingURL = recorder.getLastRecordingURL()
        
        // Create the recording object
        let newRecording = Recording(
            title: "New Recording",
            timestamp: Date(),
            duration: recordingDuration,
            audioFilePath: lastRecordingURL?.path ?? ""
        )
        
        // Stop recording
        recorder.stopRecording()
        
        // Insert and save to database
        modelContext.insert(newRecording)
        
        do {
            try modelContext.save()
            print("Successfully saved recording to database")
        } catch {
            print("Failed to save recording: \(error)")
        }
        
        // Call the callback if provided
        onSave?(newRecording)
    }
}

struct PreviewContainer: View {
    @StateObject private var recorder = AudioRecorder()
    var body: some View {
        RecordButton(recorder: recorder)
    }
}

#Preview {
	PreviewContainer()
		.environmentObject(SessionViewModel())
		.modelContainer(for: Recording.self)
}
