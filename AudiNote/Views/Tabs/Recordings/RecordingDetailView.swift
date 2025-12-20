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
    @State private var viewModel: RecordingDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var session: SessionViewModel
    @State private var showDeleteAlert = false
    @State private var showTagSheet = false
    @State private var newTag = ""
    @State private var wasPlayingBeforeScrub = false

    init(recording: Recording) {
        self._recording = Bindable(recording)
		self._viewModel = State(wrappedValue: RecordingDetailViewModel(recording: recording))
    }
    
	var body: some View {
		VStack {
			ScrollView {
				VStack(spacing: 20) {
					// Transcript section
					Group {
						if recording.isTranscribing {
							TranscriptionStatusView(isTranscribing: true, isTranscribed: false)
						} else if !viewModel.transcriptSegments.isEmpty {
							TranscriptView(
								segments: viewModel.transcriptSegments,
								currentTime: viewModel.audioPlayer.currentTime,
								onTimestampTap: { timestamp in
									viewModel.seekAndPlay(to: timestamp)
								}
							)
							.frame(minHeight: 600)
						} else {
							TranscriptionStatusView(isTranscribing: false, isTranscribed: false)
						}
					}
					.padding(.top, 8)
				}
				.padding()
			}
			.scrollEdgeEffectStyle(.soft, for: .bottom)

			// Slider and playback controls
			if viewModel.isAudioLoaded {
				VStack(spacing: 20) {
					// Playback slider
					VStack(spacing: 8) {
							Text(viewModel.timeDisplay)
							.font(.system(size: 40, weight: .semibold))
							.bold()
							.monospacedDigit()

                        Slider(
                            value: viewModel.currentTimeBinding,
                            in: 0...max(1, viewModel.audioPlayer.duration),
                            onEditingChanged: { isEditing in
                                if isEditing {
                                    if viewModel.audioPlayer.isPlaying {
                                        wasPlayingBeforeScrub = true
                                        viewModel.audioPlayer.pause()
                                    } else {
                                        wasPlayingBeforeScrub = false
                                    }
                                } else if wasPlayingBeforeScrub {
                                    viewModel.audioPlayer.play()
                                }
                            }
                        )
					}
					.padding(.horizontal, 20)

					// Floating playback controls
					HStack(spacing: 12) {
						// Skip backward
						Button(action: {
							session.triggerHaptic(style: .light)
							viewModel.skipBackward()
						}) {
							Image(systemName: "gobackward.10")
								.font(.system(size: 24, weight: .semibold))
								.padding(8)
						}
						.buttonStyle(.glass)

						// Play/Pause
						Button(action: {
							session.triggerHaptic(style: .medium)
							viewModel.togglePlayPause()
						}) {
							Image(systemName: viewModel.audioPlayer.isPlaying ? "pause.fill" : "play.fill")
								.font(.system(size: 22, weight: .semibold))
								.padding(.horizontal, 42)
								.padding(.vertical, 12 )
						}
						.buttonStyle(.glassProminent)

						// Skip forward
						Button(action: {
							session.triggerHaptic(style: .light)
							viewModel.skipForward()
						}) {
							Image(systemName: "goforward.10")
								.font(.system(size: 22, weight: .semibold))
								.padding(8)
						}
						.buttonStyle(.glass)
					}
					.padding(.horizontal, 20)
				}
				.padding(.bottom)
			}
		}
		.navigationTitle(recording.title)
		.navigationSubtitle(Text(recording.timestamp, format: .dateTime.day().month().year().hour().minute()))
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			if let audioURL = recording.audioFileURL {
				ToolbarItem {
					ShareLink(item: audioURL, subject: Text(recording.title), message: Text(viewModel.shareMessage)) {
						Image(systemName: "square.and.arrow.up")
					}
				}
			}
			ToolbarItem {
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
					Image(systemName: "ellipsis")
				}
			}
		}
		.alert("Delete Recording", isPresented: $showDeleteAlert) {
			Button("Delete", role: .destructive) {
				viewModel.deleteRecording(modelContext: modelContext) {
					dismiss()
				}
			}
			Button("Cancel", role: .cancel) { }
		} message: {
			Text("Are you sure you want to delete this recording? This action cannot be undone.")
		}
		.sheet(isPresented: $showTagSheet) {
			TagEditorSheet(recording: recording, newTag: $newTag)
		}
		.onAppear {
			viewModel.loadAudioIfNeeded()
		}
        .onDisappear {
            viewModel.audioPlayer.stop()
        }
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
