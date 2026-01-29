//
//  Recording.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import Foundation
import SwiftData

@Model
final class Recording {
    var title: String = ""
    var timestamp: Date = Date()
    var duration: Double = 0.0
    var audioFilePath: String = ""
    @Attribute(.externalStorage) var audioData: Data?
    var transcript: String?
    var transcriptSegments: Data? // Store TranscriptSegment array as JSON
    var notes: String?
    var isTranscribed: Bool = false
    var isTranscribing: Bool = false
    var isUploaded: Bool = false
    var isStarred: Bool = false

    var tags: [Tag]? = []

    init(
        title: String = "",
        timestamp: Date = Date(),
        duration: Double = 0.0,
        audioFilePath: String = "",
        audioData: Data? = nil,
        transcript: String? = nil,
        transcriptSegments: [TranscriptSegment]? = nil,
        notes: String? = nil,
        isTranscribed: Bool = false,
        isTranscribing: Bool = false,
        isUploaded: Bool = false,
        isStarred: Bool = false,
        tags: [Tag]? = []
    ) {
        self.title = title
        self.timestamp = timestamp
        self.duration = duration
        self.audioFilePath = audioFilePath
        self.audioData = audioData
        self.notes = notes
        self.isTranscribed = isTranscribed
        self.isTranscribing = isTranscribing
        self.isUploaded = isUploaded
        self.isStarred = isStarred
        self.tags = tags

        // Encode transcript segments to Data and set transcript string
        if let segments = transcriptSegments {
            self.transcriptSegments = try? JSONEncoder().encode(segments)
            // Generate transcript string from segments if not explicitly provided
            self.transcript = transcript ?? segments.map { $0.text }.joined(separator: " ")
        } else {
            self.transcript = transcript
        }
    }

    // Computed property to decode transcript segments
    var decodedTranscriptSegments: [TranscriptSegment] {
        guard let data = transcriptSegments else { return [] }
        return (try? JSONDecoder().decode([TranscriptSegment].self, from: data)) ?? []
    }

    // Computed property to get transcript, generating from segments if needed
    var displayTranscript: String? {
        // If we have an explicit transcript, use it
        if let transcript = transcript, !transcript.isEmpty {
            return transcript
        }

        // Otherwise, generate from segments if they exist
        let segments = decodedTranscriptSegments
        guard !segments.isEmpty else { return nil }

        return segments.map { $0.text }.joined(separator: " ")
    }

    // Update transcript segments
    func updateTranscriptSegments(_ segments: [TranscriptSegment]) {
        self.transcriptSegments = try? JSONEncoder().encode(segments)
        self.transcript = segments.map { $0.text }.joined(separator: " ")
        self.isTranscribed = !segments.isEmpty
        self.isTranscribing = false
    }
    
    // MARK: - Computed Helpers
    
    /// Short display title (falls back to date if title is empty)
    var shortTitle: String {
        title.isEmpty ? formattedDate : title
    }
    
    /// Formatted date for UI display with relative dates
    var formattedDate: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(timestamp) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: timestamp))"
        } else if calendar.isDateInYesterday(timestamp) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Yesterday at \(formatter.string(from: timestamp))"
        } else {
            // Compute difference in full days between timestamp and now
            let dayDiff = calendar.dateComponents([.day], from: timestamp, to: now).day ?? 0
            if dayDiff > 0 && dayDiff < 7 {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                let dayWord = dayDiff == 1 ? "day" : "days"
                return "\(dayDiff) \(dayWord) ago at \(formatter.string(from: timestamp))"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return formatter.string(from: timestamp)
            }
        }
    }
    
    /// Human-readable duration (e.g. "1h 05m" or "12m 32s")
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm %02ds", minutes, seconds)
        }
    }
    
    /// Returns up to 2 tag names for display in the list
    var displayTags: [String] {
        return tags?.prefix(3).map { $0.name } ?? []
    }

    // MARK: - File Path Helpers

    /// Get the full URL for the audio file, reconstructing from Documents directory
    var audioFileURL: URL? {
        guard !audioFilePath.isEmpty else { return nil }

        let fileName = (audioFilePath as NSString).lastPathComponent
        let localURL = AudioStorage.localFileURL(fileName: fileName)

        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }

        if let data = audioData {
            do {
                try data.write(to: localURL, options: .atomic)
                return localURL
            } catch {
                return nil
            }
        }

        return AudioStorage.resolveAudioURL(from: audioFilePath)
    }
}

