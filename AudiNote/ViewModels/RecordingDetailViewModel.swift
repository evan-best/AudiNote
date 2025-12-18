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

    // MARK: - Dependencies
    private let recording: Recording

    // MARK: - Initialization
    init(recording: Recording) {
        self.recording = recording
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

        if recording.isTranscribed, let transcript = recording.transcript, !transcript.isEmpty {
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

        guard let url = recording.audioFileURL else {
            loadError = "Audio file not found. Filename: \(recording.audioFilePath)"
            isAudioLoaded = false
            return
        }

        audioPlayer.load(url: url)
        isAudioLoaded = audioPlayer.duration > 0
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

