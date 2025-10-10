import Foundation
import SwiftData

final class RecordingSaveCoordinator {
    private let modelContext: ModelContext
    private let recorder: AudioRecorder

    init(modelContext: ModelContext, recorder: AudioRecorder) {
        self.modelContext = modelContext
        self.recorder = recorder
    }

    @MainActor
    func save(title: String, transcript: String?) throws -> Recording {
        // Stop recording first to finalize file and duration
        recorder.stopRecording()

        // Build tags (demo behavior retained)
        let allTags: [String] = [
            "Meeting", "Interview", "Lecture", "Note", "Idea", "Call",
            "Music", "Important", "Work", "Personal", "Study"
        ]
        let tagCount = Int.random(in: 1...3)
        let randomTags = Array(allTags.shuffled().prefix(tagCount))

        // Construct the Recording model from the recorder state
        let newRecording = Recording(
            title: title,
            timestamp: Date(),
            duration: recorder.elapsed,
            audioFilePath: recorder.getLastRecordingURL()?.path ?? "",
            transcript: transcript,
            tags: randomTags
        )

        // Insert and persist
        modelContext.insert(newRecording)
        try modelContext.save()

        // Notify interested views (kept for compatibility)
        NotificationCenter.default.post(name: NSNotification.Name("RecordingSaved"), object: nil)

        return newRecording
    }
}
