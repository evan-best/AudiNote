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
        // IMPORTANT: Capture transcript segments BEFORE stopping recording
        let segmentsToSave = recorder.finalizedSegments
        let currentPartial = recorder.currentTranscript

        recorder.stopRecording()

        // Ensure we have a valid recording URL
        guard let recordingURL = recorder.getLastRecordingURL() else {
            throw NSError(domain: "RecordingManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No recording URL available"])
        }

        // Save ONLY the filename (not full path) for persistence across app launches
        let filename = recordingURL.lastPathComponent
        _ = AudioStorage.ensureUbiquitousCopy(from: recordingURL, fileName: filename)
        let hasTranscript = !segmentsToSave.isEmpty

        let audioData = try? Data(contentsOf: recordingURL)

        let newRecording = Recording(
            title: title,
            timestamp: Date(),
            duration: recorder.elapsed,
            audioFilePath: filename,
            audioData: audioData,
            transcriptSegments: hasTranscript ? segmentsToSave : nil,
            isTranscribed: hasTranscript
        )

        modelContext.insert(newRecording)
        try modelContext.save()

        // Show success toast
        ToastManager.shared.show(type: .success, message: "Recording saved")

        // Start transcription in background if not already captured
        if !hasTranscript {
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
            recording.isTranscribing = false
            try? modelContext.save()
            return
        }

        // Get audio file URL using the helper that reconstructs the path
        guard let audioURL = recording.audioFileURL else {
            recording.isTranscribing = false
            try? modelContext.save()
            return
        }

        // Verify file exists and is not empty
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            recording.isTranscribing = false
            try? modelContext.save()
            return
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            if let fileSize = attributes[.size] as? UInt64, fileSize == 0 {
                recording.isTranscribing = false
                try? modelContext.save()
                return
            }
        } catch {
            return
        }

        recording.isTranscribing = true
        try? modelContext.save()

        do {
            // Perform transcription with timeout
            let segments = try await withThrowingTaskGroup(of: [TranscriptSegment].self) { group in
                group.addTask {
                    return try await self.transcriptionService.transcribe(audioURL: audioURL)
                }

                // Add timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                    throw TranscriptionError.timeout
                }

                // Return first completed task (either transcription or timeout)
                guard let result = try await group.next() else {
                    throw TranscriptionError.unknown
                }
                group.cancelAll()
                return result
            }

            // Update recording with segments
            if !segments.isEmpty {
                recording.updateTranscriptSegments(segments)
                try modelContext.save()
            } else {
                recording.isTranscribing = false
                try modelContext.save()
            }
        } catch is CancellationError {
            recording.isTranscribing = false
            try? modelContext.save()
        } catch let error as TranscriptionError {
            recording.isTranscribing = false
            try? modelContext.save()
        } catch {
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
