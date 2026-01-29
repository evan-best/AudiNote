//
//  LiveTranscriptionView.swift
//  AudiNote
//
//  Shows live streaming transcription during recording with timestamped conversation pieces
//

import SwiftUI

struct LiveTranscriptionView: View {
    let finalizedSegments: [TranscriptSegment]
    let currentTranscript: String
    let isTranscribing: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)

                Text("Live Transcription")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                if isTranscribing {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .opacity(0.8)

                        Text("LIVE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
            }

            // Transcript content - conversation pieces
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 12) {
                        // Show placeholder if nothing yet
                        if finalizedSegments.isEmpty && currentTranscript.isEmpty && isTranscribing {
                            Text("Start speaking...")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(12)
                        } else if finalizedSegments.isEmpty && currentTranscript.isEmpty {
                            Text("Transcription will appear here")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(12)
                        }

                        // Finalized conversation pieces
                        ForEach(finalizedSegments) { segment in
                            TranscriptBubbleView(segment: segment, colorScheme: colorScheme)
                        }

                        // Current in-progress text
                        if !currentTranscript.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                // Timestamp placeholder
                                Text("...")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 44, alignment: .leading)
                                    .padding(.top, 2)

                                // In-progress text
                                Text(currentTranscript)
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .lineSpacing(4)
                                    .textSelection(.enabled)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                                    .id("currentTranscript")
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .onChange(of: finalizedSegments.count) { _, _ in
                        // Auto-scroll when new segment is added
                        if let lastSegment = finalizedSegments.last {
                            withAnimation {
                                proxy.scrollTo(lastSegment.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: currentTranscript) { _, _ in
                        // Auto-scroll as current text updates
                        if !currentTranscript.isEmpty {
                            withAnimation {
                                proxy.scrollTo("currentTranscript", anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

// Individual conversation bubble
struct TranscriptBubbleView: View {
    let segment: TranscriptSegment
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(segment.formattedTimestamp)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 44, alignment: .leading)
                .padding(.top, 2)

            // Text bubble
            Text(segment.text)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .lineSpacing(4)
                .textSelection(.enabled)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                )
        }
        .padding(.horizontal, 12)
        .id(segment.id)
    }
}

#Preview {
    VStack(spacing: 20) {
        LiveTranscriptionView(
            finalizedSegments: [
                TranscriptSegment(text: "Hello, this is the first sentence.", timestamp: 0.0, duration: 2.5),
                TranscriptSegment(text: "And here's another completed phrase.", timestamp: 3.0, duration: 2.0)
            ],
            currentTranscript: "This is being spoken right now and not finalized yet",
            isTranscribing: true
        )

        LiveTranscriptionView(
            finalizedSegments: [],
            currentTranscript: "",
            isTranscribing: true
        )

        LiveTranscriptionView(
            finalizedSegments: [
                TranscriptSegment(text: "Recording completed.", timestamp: 5.5, duration: 1.0)
            ],
            currentTranscript: "",
            isTranscribing: false
        )
    }
    .padding()
}
