//
//  RecordingDetailView.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import SwiftUI
import AVFoundation

struct RecordingDetailView: View {
    let recording: Recording
    @StateObject private var audioPlayer = AudioPlayer()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionViewModel
    @State private var loadError: String?

    init(recording: Recording) {
        self.recording = recording
        print("RecordingDetailView: Initializing with recording: \(recording.id)")
    }
    
    var body: some View {
        VStack(spacing: 12) {
                Text(recording.timestamp, format: .dateTime.day().month().year().hour().minute())
                    .foregroundStyle(.secondary)
                Text("Duration: \(recording.formattedDuration)")
                    .foregroundStyle(.secondary)
                
                // Player UI
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Button(action: {
                            session.triggerHaptic(style: .light)
                            if audioPlayer.isPlaying {
                                audioPlayer.pause()
                            } else {
                                if audioPlayer.duration == 0 {
                                    attemptLoadAudio()
                                }
                                audioPlayer.play()
                            }
                        }) {
                            Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 36, weight: .regular))
                        }
                        Text("\(formatTime(audioPlayer.currentTime)) / \(formatTime(audioPlayer.duration))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    Slider(value: $audioPlayer.currentTime, in: 0...(audioPlayer.duration > 0 ? audioPlayer.duration : 1), onEditingChanged: { editing in
                        if !editing {
                            audioPlayer.seek(to: audioPlayer.currentTime)
                        }
                    })
                    .disabled(audioPlayer.duration == 0)
                }
                .padding(.vertical, 6)
                
                if let loadError {
                    Text(loadError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                } else if audioPlayer.duration == 0 {
                    Text("Audio not loaded")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
			.navigationTitle(recording.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        session.triggerHaptic(style: .light)
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Try to load the audio once when the view appears
                if audioPlayer.duration == 0 {
                    attemptLoadAudio()
                }
            }
        }
    
    private func attemptLoadAudio() {
        loadError = nil
        let path = recording.audioFilePath
        guard !path.isEmpty else {
            loadError = "No audio file path."
            return
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            loadError = "Audio file not found at path."
            return
        }
        audioPlayer.load(url: url)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    RecordingDetailView(
        recording: Recording(
            title: "Team Sync — Aug 11",
            timestamp: Date(),
            duration: 312,
            audioFilePath: "preview.m4a"
        )
    )
}
