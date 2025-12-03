//
//  RecordingDetailView.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import SwiftUI
import SwiftData
import AVFoundation

struct RecordingDetailView: View {
    @Bindable var recording: Recording
    @StateObject private var audioPlayer = AudioPlayer()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var session: SessionViewModel
    @State private var loadError: String?
    @State private var showTranscript = false
    @State private var showDeleteAlert = false
    @State private var showTagSheet = false
    @State private var newTag = ""

    init(recording: Recording) {
        self._recording = Bindable(recording)
        print("RecordingDetailView: Initializing with recording: \(recording.id)")
    }
    
	var body: some View {
		ScrollView {
			VStack(spacing: 20) {
				// Header info
				VStack(spacing: 8) {
					Text(recording.timestamp, format: .dateTime.day().month().year().hour().minute())
						.foregroundStyle(.secondary)
					Text("Duration: \(recording.formattedDuration)")
						.foregroundStyle(.secondary)
				}
				.padding(.top)
				
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
								.font(.system(size: 48, weight: .regular))
						}
						
						VStack(alignment: .leading, spacing: 4) {
							Text("\(formatTime(audioPlayer.currentTime)) / \(formatTime(audioPlayer.duration))")
								.font(.footnote)
								.foregroundColor(.secondary)
								.monospacedDigit()
						}
					}
					
					Slider(value: $audioPlayer.currentTime, in: 0...(audioPlayer.duration > 0 ? audioPlayer.duration : 1), onEditingChanged: { editing in
						if !editing {
							audioPlayer.seek(to: audioPlayer.currentTime)
						}
					})
					.disabled(audioPlayer.duration == 0)
				}
				.padding()
				.background(Color.secondary.opacity(0.1))
				.cornerRadius(12)
				
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
				
				// Transcript section
				VStack(alignment: .leading, spacing: 12) {
					HStack {
						Text("Transcript")
							.font(.system(size: 20, weight: .semibold))
						Spacer()
					}
					
					if recording.isTranscribing {
						TranscriptionStatusView(isTranscribing: true, isTranscribed: false)
					} else if recording.isTranscribed && !recording.decodedTranscriptSegments.isEmpty {
						if showTranscript {
							TranscriptView(segments: recording.decodedTranscriptSegments) { timestamp in
								audioPlayer.seek(to: timestamp)
								audioPlayer.play()
							}
							.transition(.move(edge: .top).combined(with: .opacity))
						} else {
							ProgressView()
								.padding()
						}
					} else {
						TranscriptionStatusView(isTranscribing: false, isTranscribed: false)
					}
				}
				.padding(.top, 8)
				.task {
					// Animate transcript reveal after a brief delay
					if recording.isTranscribed && !recording.decodedTranscriptSegments.isEmpty {
						try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
						withAnimation(.easeOut(duration: 0.5)) {
							showTranscript = true
						}
					}
				}
			}
			.padding()
		}
		.navigationTitle(recording.title)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				HStack(spacing: 16) {
					if let audioURL = recording.audioFileURL {
						ShareLink(item: audioURL, subject: Text(recording.title), message: Text(shareMessage)) {
							Image(systemName: "square.and.arrow.up")
						}
					}

					Menu {
						Button {
							showTagSheet = true
						} label: {
							Label("Add Tags", systemImage: "tag")
						}

						Divider()

						Button(role: .destructive) {
							showDeleteAlert = true
						} label: {
							Label("Delete Recording", systemImage: "trash")
						}
					} label: {
						Image(systemName: "ellipsis.circle")
					}
				}
			}
		}
		.alert("Delete Recording", isPresented: $showDeleteAlert) {
			Button("Delete", role: .destructive) {
				deleteRecording()
			}
			Button("Cancel", role: .cancel) { }
		} message: {
			Text("Are you sure you want to delete this recording? This action cannot be undone.")
		}
		.sheet(isPresented: $showTagSheet) {
			TagEditorSheet(recording: recording, newTag: $newTag)
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

        // Use the helper to get the full URL (handles both old full paths and new filenames)
        guard let url = recording.audioFileURL else {
            loadError = "Audio file not found. Filename: \(recording.audioFilePath)"
            print("❌ Could not locate audio file: \(recording.audioFilePath)")
            return
        }

        print("Loading audio from: \(url.path)")
        audioPlayer.load(url: url)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var shareMessage: String {
        var message = "\(recording.title)\nRecorded: \(recording.formattedDate)\nDuration: \(recording.formattedDuration)"

        if recording.isTranscribed, let transcript = recording.transcript, !transcript.isEmpty {
            message += "\n\nTranscript:\n\(transcript)"
        }

        return message
    }

    private func deleteRecording() {
        // Stop playback first
        audioPlayer.stop()

        // Delete the recording
        modelContext.delete(recording)
        do {
            try modelContext.save()
            ToastManager.shared.show(type: .delete, message: "Recording deleted")
        } catch {
            print("Failed to delete: \(error)")
            ToastManager.shared.show(type: .error, message: "Failed to delete recording")
        }

        // Dismiss the detail view
        dismiss()
    }
}

// MARK: - Tag Editor Sheet

struct TagEditorSheet: View {
    @Bindable var recording: Recording
    @Binding var newTag: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("New tag", text: $newTag)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                addTag()
                            }

                        Button {
                            addTag()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Add Tag")
                }

                if !recording.tags.isEmpty {
                    Section {
                        ForEach(recording.tags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                Button {
                                    removeTag(tag)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Current Tags")
                    }
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
        .presentationDetents([.medium])
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !recording.tags.contains(trimmed) else { return }
        recording.tags.append(trimmed)
        newTag = ""
    }

    private func removeTag(_ tag: String) {
        recording.tags.removeAll { $0 == tag }
    }
}

#Preview {
	NavigationStack {
		RecordingDetailView(
			recording: Recording(
				title: "Team Sync — Aug 11",
				timestamp: Date(),
				duration: 312,
				audioFilePath: "preview.m4a"
			)
		)
	}
}
