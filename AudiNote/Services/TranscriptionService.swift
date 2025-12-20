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

struct WordTiming: Codable {
    let word: String
    let timestamp: TimeInterval // Relative to segment start
    let duration: TimeInterval
}

struct TranscriptSegment: Codable, Identifiable {
    let id: UUID
    let text: String
    let timestamp: TimeInterval
    let duration: TimeInterval
    let wordTimings: [WordTiming]? // Word-level timing from Speech API

    init(text: String, timestamp: TimeInterval, duration: TimeInterval, wordTimings: [WordTiming]? = nil) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
        self.wordTimings = wordTimings
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
    private var baseTimeOffset: TimeInterval = 0

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
    func startStreamingTranscription(timeOffset: TimeInterval = 0) async throws -> AVAudioFormat {
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
        baseTimeOffset = max(0, timeOffset)

        // Use en_US explicitly to avoid locale allocation warnings
        let locale = Locale(identifier: "en_US")

        // Create transcriber module for live progressive transcription with timing info
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
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

                        // Extract word-level timing from AttributedString runs
                        var wordTimings: [WordTiming] = []
                        var segmentStartTime: TimeInterval = 0
                        var segmentEndTime: TimeInterval = 0

                        // Access timing attributes from the AttributedString
                        for run in response.text.runs {
                            let runText = String(response.text[run.range].characters)

                            // Get timing from audioTimeRange attribute using keypath
                            if let timeRange = run[keyPath: \.audioTimeRange] {
                                let startTime = CMTimeGetSeconds(timeRange.start)
                                let duration = CMTimeGetSeconds(timeRange.duration)

                                // Track overall segment bounds
                                if wordTimings.isEmpty {
                                    segmentStartTime = startTime
                                }
                                segmentEndTime = max(segmentEndTime, startTime + duration)

                                // Map actual timed range proportionally across words based on character share
                                let words = runText.split(separator: " ", omittingEmptySubsequences: false).map(String.init)

                                // Include trailing space per word (except last) so timing matches spacing in the run
                                let wordLengths: [Int] = words.enumerated().map { index, word in
                                    word.count + (index < words.count - 1 ? 1 : 0)
                                }
                                let totalLength = wordLengths.reduce(0, +)

                                guard totalLength > 0 else { continue }

                                var offset: TimeInterval = 0

                                for (index, word) in words.enumerated() {
                                    guard !word.isEmpty else { continue }

                                    let portion = Double(wordLengths[index]) / Double(totalLength)
                                    let wordDuration = duration * portion

                                    wordTimings.append(WordTiming(
                                        word: word,
                                        timestamp: (startTime + offset) - segmentStartTime, // Relative to segment
                                        duration: wordDuration
                                    ))

                                    offset += duration * portion
                                }
                            }
                        }

                        // Calculate overall segment timing
                        var timestamp: TimeInterval
                        var duration: TimeInterval

                        // If we successfully extracted timing from runs, use it
                        if segmentEndTime > segmentStartTime {
                            timestamp = segmentStartTime
                            duration = segmentEndTime - segmentStartTime
                        } else {
                            // Fallback to resultsFinalizationTime if audioTimeRange not available
                            let finalizationTime = response.resultsFinalizationTime

                            if finalizationTime.isValid && !finalizationTime.isIndefinite {
                                timestamp = CMTimeGetSeconds(finalizationTime)
                                duration = Double(plainText.split(separator: " ").count) * 0.3
                            } else {
                                // Last fallback: calculate from previous segments
                                timestamp = self.finalizedSegments.last.map { $0.timestamp + $0.duration } ?? 0
                                duration = 1.0
                            }
                        }

                        timestamp += baseTimeOffset

                        // Ensure monotonic timestamps; if analyzer resets within an utterance, clamp forward.
                        if let last = self.finalizedSegments.last {
                            let lastEnd = last.timestamp + last.duration
                            if timestamp < lastEnd {
                                let shift = lastEnd - timestamp
                                timestamp += shift
                            }
                        }

                        let segment = TranscriptSegment(
                            text: plainText,
                            timestamp: timestamp,
                            duration: duration,
                            wordTimings: wordTimings.isEmpty ? nil : wordTimings
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

    func updateTimeOffset(_ timeOffset: TimeInterval) {
        baseTimeOffset = max(0, timeOffset)
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
