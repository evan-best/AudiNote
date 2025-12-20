//
//  RecordingDetailViewModel.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import Foundation
import SwiftUI
import SwiftData
import AVFoundation

@MainActor
@Observable final class RecordingDetailViewModel {
    // MARK: - Published Properties
	var audioPlayer = AudioPlayer()
    var loadError: String?
    var showTranscript = false
    var isAudioLoaded = false
    var transcriptSegments: [TranscriptSegment] = []
    var isDownloadingAudio = false
    var downloadProgress: Double = 0
    private let fileCoordinator = NSFileCoordinator(filePresenter: nil)

    // MARK: - Dependencies
    private let recording: Recording
    private let recordingID: PersistentIdentifier
    private var modelContext: ModelContext?

    // MARK: - Initialization
    init(recording: Recording) {
        self.recording = recording
        self.recordingID = recording.persistentModelID
        // Load transcript segments immediately
        self.transcriptSegments = recording.decodedTranscriptSegments
    }
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public Methods
    func loadAudioIfNeeded() {
        if audioPlayer.duration == 0 {
            loadAudio()
        }
    }

    func togglePlayPause() {
        if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else {
            if audioPlayer.duration == 0 {
                loadAudio()
            }
            audioPlayer.play()
        }
    }

    func seekToTime(_ time: TimeInterval) {
        audioPlayer.seek(to: time)
    }

    func seekAndPlay(to timestamp: TimeInterval) {
        audioPlayer.seek(to: timestamp)
        audioPlayer.play()
    }

    func skipBackward() {
        let newTime = max(0, audioPlayer.currentTime - 10)
        audioPlayer.seek(to: newTime)
    }

    func skipForward() {
        let newTime = min(audioPlayer.duration, audioPlayer.currentTime + 10)
        audioPlayer.seek(to: newTime)
    }

    func deleteRecording(modelContext: ModelContext, onDismiss: @escaping () -> Void) {
        audioPlayer.stop()
        modelContext.delete(recording)

        do {
            try modelContext.save()
            ToastManager.shared.show(type: .delete, message: "Recording deleted")
        } catch {
            print("Failed to delete: \(error)")
            ToastManager.shared.show(type: .error, message: "Failed to delete recording")
        }

        onDismiss()
    }


    // MARK: - Computed Properties
    var shareMessage: String {
        var message = "\(recording.title)\nRecorded: \(recording.formattedDate)\nDuration: \(recording.formattedDuration)"

        if recording.isTranscribed, let transcript = recording.displayTranscript, !transcript.isEmpty {
            message += "\n\nTranscript:\n\(transcript)"
        }

        return message
    }

    var playButtonIcon: String {
        audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill"
    }

    var timeDisplay: String {
        "\(formatTime(audioPlayer.currentTime))"
    }

    var shouldShowControls: Bool {
        !recording.audioFilePath.isEmpty
    }

    var isCloudAudio: Bool {
        guard !recording.audioFilePath.isEmpty else { return false }
        let fileName = (recording.audioFilePath as NSString).lastPathComponent
        let localURL = AudioStorage.localFileURL(fileName: fileName)
        let hasLocal = FileManager.default.fileExists(atPath: localURL.path)
        return !hasLocal && AudioStorage.ubiquityFileURL(fileName: fileName) != nil
    }

    var shouldShowLoadError: Bool {
        loadError != nil
    }
    
    var currentTimeBinding: Binding<Double> {
        Binding(
            get: { self.audioPlayer.currentTime },
            set: { newValue in self.seekToTime(newValue) }
        )
    }

    // MARK: - Private Methods
    private func loadAudio() {
        loadError = nil

        let currentRecording = latestRecording()
        guard !currentRecording.audioFilePath.isEmpty else {
            loadError = "Audio file not found. Filename: \(recording.audioFilePath)"
            isAudioLoaded = false
            print("Audio load: missing audioFilePath")
            return
        }

        isDownloadingAudio = true
        downloadProgress = 0

        let fileName = (currentRecording.audioFilePath as NSString).lastPathComponent
        let localURL = AudioStorage.localFileURL(fileName: fileName)

        if FileManager.default.fileExists(atPath: localURL.path) {
            print("Audio load: local file exists at \(localURL.path)")
            if recording.audioData == nil, let data = try? Data(contentsOf: localURL) {
                recording.audioData = data
                try? modelContext?.save()
                print("Audio load: backfilled audioData from local file, size \(data.count) bytes")
            }
            audioPlayer.load(url: localURL)
            isAudioLoaded = audioPlayer.duration > 0
            isDownloadingAudio = false
            downloadProgress = 1
            return
        }

        if let data = currentRecording.audioData {
            do {
                try data.write(to: localURL, options: .atomic)
                print("Audio load: restored audio from synced data to \(localURL.path)")
                print("Audio load: synced data size \(data.count) bytes")
                audioPlayer.load(url: localURL)
                isAudioLoaded = audioPlayer.duration > 0
                isDownloadingAudio = false
                downloadProgress = 1
                return
            } catch {
                print("Audio load: failed to write synced data: \(error)")
            }
        } else {
            print("Audio load: synced data missing, waiting")
        }

        print("Audio load: waiting for synced audio data")
        scheduleDataRetry(to: localURL)
    }

    private func scheduleDataRetry(to localURL: URL) {
        Task { @MainActor in
            for attempt in 0..<120 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let refreshed = latestRecording()
                if let data = refreshed.audioData {
                    do {
                        try data.write(to: localURL, options: .atomic)
                        print("Audio load: synced data arrived, wrote to \(localURL.path)")
                        print("Audio load: synced data size \(data.count) bytes")
                        audioPlayer.load(url: localURL)
                        isAudioLoaded = audioPlayer.duration > 0
                        if isAudioLoaded {
                            isDownloadingAudio = false
                            downloadProgress = 1
                            break
                        }
                    } catch {
                        print("Audio load: failed to write synced data: \(error)")
                    }
                } else if attempt == 0 {
                    print("Audio load: still waiting for synced data")
                }
            }
            if !isAudioLoaded {
                isDownloadingAudio = false
                print("Audio load: timed out waiting for synced data")
            }
        }
    }

    private func latestRecording() -> Recording {
        if let modelContext,
           let refreshed = modelContext.model(for: recordingID) as? Recording {
            return refreshed
        }
        return recording
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private final class DownloadMonitor {
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []

    func start(url: URL, onUpdate: @escaping (Double, Bool) -> Void) {
        stop()

        let query = NSMetadataQuery()
        query.searchScopes = [
            NSMetadataQueryUbiquitousDocumentsScope,
            url.deletingLastPathComponent()
        ]
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemURLKey, url as NSURL)
        self.query = query

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { _ in
            self.handle(query: query, onUpdate: onUpdate)
        })
        observers.append(center.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { _ in
            self.handle(query: query, onUpdate: onUpdate)
        })

        query.start()
    }

    func stop() {
        if let query {
            query.stop()
        }
        query = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func handle(query: NSMetadataQuery, onUpdate: (Double, Bool) -> Void) {
        guard let item = query.results.first as? NSMetadataItem else { return }

        let percent = (item.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double) ?? 0
        let progress = min(1, max(0, percent / 100))
        let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
        let isComplete = status == NSMetadataUbiquitousItemDownloadingStatusCurrent || progress >= 1

        onUpdate(progress, isComplete)

        if isComplete {
            stop()
        }
    }
}
