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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text(recording.title.isEmpty ? "Untitled" : recording.title)
                    .font(.title2).bold()
                Text(recording.timestamp, format: .dateTime.day().month().year().hour().minute())
                    .foregroundStyle(.secondary)
                Text("Duration: \(Int(recording.duration))s")
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        Button(action: {
                            if audioPlayer.isPlaying {
                                audioPlayer.pause()
                            } else {
                                if audioPlayer.duration == 0 {
                                    audioPlayer.load(url: URL(fileURLWithPath: recording.audioFilePath))
                                }
                                audioPlayer.play()
                            }
                        }) {
                            Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 36))
                        }
                        Text("\(formatTime(audioPlayer.currentTime)) / \(formatTime(audioPlayer.duration))")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $audioPlayer.currentTime, in: 0...audioPlayer.duration, onEditingChanged: { editing in
                        if !editing {
                            audioPlayer.seek(to: audioPlayer.currentTime)
                        }
                    })
                    .disabled(audioPlayer.duration == 0)
                }
                .padding(.vertical, 6)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: 600)
            .navigationTitle("Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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

