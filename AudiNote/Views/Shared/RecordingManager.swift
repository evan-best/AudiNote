import Foundation
import SwiftData
import Combine
import SwiftUI

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

    // MARK: - Persistence
    @MainActor
    func saveRecording(title: String) throws -> Recording {
        recorder.stopRecording()

        // Ensure we have a valid recording URL
        guard let recordingURL = recorder.getLastRecordingURL() else {
            throw NSError(domain: "RecordingManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No recording URL available"])
        }

        // Save ONLY the filename (not full path) for persistence across app launches
        let filename = recordingURL.lastPathComponent
        let hasTranscript = !recorder.finalizedSegments.isEmpty
        let newRecording = Recording(
            title: title,
            timestamp: Date(),
            duration: recorder.elapsed,
            audioFilePath: filename, // Store only filename, not full path
            transcriptSegments: hasTranscript ? recorder.finalizedSegments : nil,
            isTranscribed: hasTranscript
        )

        modelContext.insert(newRecording)
        try modelContext.save()

        print("✅ Saved recording filename: \(filename)")
        print("✅ Full path: \(recordingURL.path)")
        print("✅ File exists: \(FileManager.default.fileExists(atPath: recordingURL.path))")

        // Show success toast
        ToastManager.shared.show(type: .success, message: "Recording saved")

        // Start transcription in background if not already captured
        if recorder.finalizedSegments.isEmpty {
            Task {
                await transcribeRecording(newRecording)
            }
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

        // Get audio file URL using the helper that reconstructs the path
        guard let audioURL = recording.audioFileURL else {
            print("❌ Audio file not found. Filename: \(recording.audioFilePath)")
            recording.isTranscribing = false
            try? modelContext.save()
            return
        }

        print("🎤 Starting transcription for: \(audioURL.path)")

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

        // Show deletion toast
        ToastManager.shared.show(type: .delete, message: "Recording deleted")
    }
}
