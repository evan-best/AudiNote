import Foundation
import SwiftData
import Combine

/// A single facade that centralizes all recording-related actions.
/// It composes `AudioRecorder` for capture and `ModelContext` for persistence.
final class RecordingManager: ObservableObject {
    @Published private(set) var recorder: AudioRecorder
    private let modelContext: ModelContext

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

        return newRecording
    }

    /// Deletes a recording from SwiftData.
    @MainActor
    func deleteRecording(_ recording: Recording) throws {
        modelContext.delete(recording)
        try modelContext.save()
    }
}
