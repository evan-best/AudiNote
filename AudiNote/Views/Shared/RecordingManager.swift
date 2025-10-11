import Foundation
import SwiftData
import Combine

/// A single facade that centralizes all recording-related actions.
/// It composes `AudioRecorder` for capture and `ModelContext` for persistence.
final class RecordingManager: ObservableObject {
    @Published private(set) var recorder: AudioRecorder
    private let modelContext: ModelContext
    private let transcriptionService = TranscriptionService()

    init(modelContext: ModelContext, recorder: AudioRecorder) {
        self.modelContext = modelContext
        self.recorder = recorder
    }

    // MARK: - Permission
    @MainActor
    func ensureMicrophonePermission() async -> Bool {
        await recorder.ensureMicrophonePermission()
    }

    // MARK: - Recording Controls (pass-throughs)
    func startRecording() {
        recorder.startRecording()
    }

    func pauseRecording() {
        recorder.pauseRecording()
    }

    func resumeRecording() {
        recorder.resumeRecording()
    }

    func stopRecording() {
        recorder.stopRecording()
    }

    func setNoiseReduction(enabled: Bool) {
        recorder.setNoiseReduction(enabled: enabled)
    }

    // MARK: - Persistence
    @MainActor
    func saveRecording(title: String, transcript: String?) throws -> Recording {
        recorder.stopRecording()

        let newRecording = Recording(
            title: title,
            timestamp: Date(),
            duration: recorder.elapsed,
            audioFilePath: recorder.getLastRecordingURL()?.path ?? ""
        )

        modelContext.insert(newRecording)
        try modelContext.save()

        // Start transcription in background
        Task {
            await transcribeRecording(newRecording)
        }

        return newRecording
    }

    // MARK: - Transcription
    @MainActor
    func transcribeRecording(_ recording: Recording) async {
        // Check authorization first
        let authorized = await transcriptionService.requestAuthorization()
        guard authorized else {
            print("Speech recognition not authorized")
            return
        }

        // Get audio file URL
        guard let audioURL = URL(string: "file://" + recording.audioFilePath) else {
            print("Invalid audio file path")
            return
        }

        // Mark as transcribing
        recording.isTranscribing = true
        try? modelContext.save()

        do {
            // Perform transcription
            let segments = try await transcriptionService.transcribe(audioURL: audioURL)

            // Update recording with segments
            recording.updateTranscriptSegments(segments)
            try? modelContext.save()

            print("✅ Transcription complete: \(segments.count) segments")
        } catch {
            print("❌ Transcription failed: \(error.localizedDescription)")
            recording.isTranscribing = false
            try? modelContext.save()
        }
    }

    /// Deletes a recording from SwiftData.
    @MainActor
    func deleteRecording(_ recording: Recording) throws {
        modelContext.delete(recording)
        try modelContext.save()
    }
}
