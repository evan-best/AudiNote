//
//  TranscriptionService.swift
//  AudiNote
//
//  On-device speech recognition using Apple's SpeechAnalyzer (iOS 26+)
//

import Foundation
import Speech
import AVFoundation
import Combine
import CoreMedia

struct TranscriptSegment: Codable, Identifiable {
    let id: UUID
    let text: String
    let timestamp: TimeInterval
    let duration: TimeInterval

    init(text: String, timestamp: TimeInterval, duration: TimeInterval) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
    }

    var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

@MainActor
class TranscriptionService: ObservableObject {
    @Published var isTranscribing = false
    @Published var progress: Double = 0.0
    @Published var error: String?

    // Partial/in-progress text (constantly updating as user speaks)
    @Published var currentTranscript: String = ""

    // Finalized conversation pieces (committed after pauses in speech)
    @Published var finalizedSegments: [TranscriptSegment] = []

    private var speechAnalyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var transcriptionStartTime: Date?
    private var transcriptionTask: Task<Void, Never>?

    // Stream for feeding audio buffers
    private var audioStream: AsyncStream<AnalyzerInput>?
    private var audioContinuation: AsyncStream<AnalyzerInput>.Continuation?

    // Track last finalized text to prevent duplicates
    private var lastFinalizedText: String = ""

    init() {
        // Initialization happens when starting transcription
    }

    // Stop any ongoing transcription
    func stopTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil

        Task {
            try? await speechAnalyzer?.finalizeAndFinishThroughEndOfInput()
        }

        audioContinuation?.finish()
        audioContinuation = nil
        audioStream = nil

        speechAnalyzer = nil
        transcriber = nil

        isTranscribing = false
        transcriptionStartTime = nil
    }

    // Feed audio buffer to the analyzer
    func feedAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        let input = AnalyzerInput(buffer: buffer)
        audioContinuation?.yield(input)
    }

    // Start streaming transcription from audio buffers (for live recording)
    // Returns the optimal audio format to use for buffers
    func startStreamingTranscription() async throws -> AVAudioFormat {
        // Check authorization
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw TranscriptionError.notAuthorized
        }

        // Reset state
        currentTranscript = ""
        finalizedSegments = []
        lastFinalizedText = ""
        isTranscribing = true
        transcriptionStartTime = Date()

        // Use en_US explicitly to avoid locale allocation warnings
        let locale = Locale(identifier: "en_US")

        // Create transcriber module for live progressive transcription
        let transcriber = SpeechTranscriber(
            locale: locale,
            preset: .progressiveTranscription
        )
        self.transcriber = transcriber

        // Check if language assets need to be downloaded
		if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            do {
                try await downloader.downloadAndInstall()
            } catch {
                // Continue anyway - might already be partially installed
            }
        }

        // Get the best audio format for this transcriber
        guard let optimalFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw TranscriptionError.recognizerNotAvailable
        }

        // Create audio input stream
        audioStream = AsyncStream<AnalyzerInput> { continuation in
            self.audioContinuation = continuation
        }

        guard let audioStream = audioStream else {
            throw TranscriptionError.recognizerNotAvailable
        }

        // Create analyzer with the audio stream
        let analyzer = SpeechAnalyzer(
            inputSequence: audioStream,
            modules: [transcriber]
        )
        self.speechAnalyzer = analyzer

        // Start listening to transcription results in background
        transcriptionTask = Task { @MainActor in
            do {
                for try await response in transcriber.results {
                    // Handle cancellation
                    if Task.isCancelled {
                        break
                    }

                    if response.isFinal {
                        // Final utterance - create a new chat segment!
                        let plainText = String(response.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)

                        // Skip if this is empty or duplicate of last finalized text
                        guard !plainText.isEmpty, plainText != self.lastFinalizedText else {
                            continue
                        }

                        self.lastFinalizedText = plainText

                        // Use actual timestamps from response
                        let timestamp: TimeInterval
                        let duration: TimeInterval

                        let finalizationTime = response.resultsFinalizationTime

                        // Check if CMTime is valid
                        if finalizationTime.isValid && !finalizationTime.isIndefinite {
                            // resultsFinalizationTime is a CMTime, convert to seconds
                            timestamp = CMTimeGetSeconds(finalizationTime)
                            // Duration is unknown from single time point, estimate based on text length
                            duration = Double(plainText.split(separator: " ").count) * 0.3 // ~0.3s per word
                        } else {
                            // Fallback to calculated timestamps if CMTime is invalid
                            timestamp = self.finalizedSegments.last.map { $0.timestamp + $0.duration } ?? 0
                            duration = 1.0
                        }

                        let segment = TranscriptSegment(
                            text: plainText,
                            timestamp: timestamp,
                            duration: duration
                        )

                        self.finalizedSegments.append(segment)

                        // Clear current transcript since it's finalized
                        self.currentTranscript = ""
                    } else {
                        // Partial result - show as in-progress
                        self.currentTranscript = String(response.text.characters)
                    }
                }
            } catch {
                self.error = error.localizedDescription
                self.isTranscribing = false
            }
        }

        return optimalFormat
    }

    // Request authorization for speech recognition
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // Transcribe audio file and return timestamped segments
    func transcribe(audioURL: URL) async throws -> [TranscriptSegment] {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw TranscriptionError.notAuthorized
        }

        isTranscribing = true
        progress = 0.0
        error = nil

        defer {
            isTranscribing = false
        }

        let transcriber = SpeechTranscriber(
            locale: Locale.current,
            preset: .timeIndexedTranscriptionWithAlternatives
        )

        let audioFile = try AVAudioFile(forReading: audioURL)
        let analyzer = try await SpeechAnalyzer(
            inputAudioFile: audioFile,
            modules: [transcriber],
            finishAfterFile: true
        )

        var segments: [TranscriptSegment] = []

        for try await response in transcriber.results {
            if response.isFinal {
                let plainText = String(response.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !plainText.isEmpty else { continue }

                let timestamp = segments.last.map { $0.timestamp + $0.duration } ?? 0
                let duration: TimeInterval = 2.0

                let segment = TranscriptSegment(
                    text: plainText,
                    timestamp: timestamp,
                    duration: duration
                )
                segments.append(segment)
            }
        }

        return segments
    }
}

enum TranscriptionError: LocalizedError {
    case notAuthorized
    case recognizerNotAvailable
    case onDeviceNotSupported
    case timeout
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please enable it in Settings."
        case .recognizerNotAvailable:
            return "Speech recognizer is not available."
        case .onDeviceNotSupported:
            return "On-device recognition is not supported on this device."
        case .timeout:
            return "Transcription timed out after 60 seconds."
        case .unknown:
            return "An unknown error occurred during transcription."
        }
    }
}
