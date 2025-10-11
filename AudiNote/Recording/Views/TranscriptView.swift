//
//  TranscriptView.swift
//  AudiNote
//
//  Displays timestamped transcript segments
//

import SwiftUI

struct TranscriptView: View {
    let segments: [TranscriptSegment]
    let onTimestampTap: ((TimeInterval) -> Void)?

    init(segments: [TranscriptSegment], onTimestampTap: ((TimeInterval) -> Void)? = nil) {
        self.segments = segments
        self.onTimestampTap = onTimestampTap
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(segments) { segment in
                    TranscriptSegmentRow(
                        segment: segment,
                        onTimestampTap: onTimestampTap
                    )
                }
            }
            .padding()
        }
    }
}

struct TranscriptSegmentRow: View {
    let segment: TranscriptSegment
    let onTimestampTap: ((TimeInterval) -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp button
            Button {
                onTimestampTap?(segment.timestamp)
            } label: {
                Text(segment.formattedTimestamp)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)

            // Transcript text
            Text(segment.text)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TranscriptionStatusView: View {
    let isTranscribing: Bool
    let isTranscribed: Bool

    var body: some View {
        if isTranscribing {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Transcribing...")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
        } else if !isTranscribed {
            VStack(spacing: 12) {
                Image(systemName: "waveform.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("No transcript available")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)

                Text("Transcription will start automatically after recording")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview("Transcript View") {
    let sampleSegments = [
        TranscriptSegment(
            text: "Welcome to today's meeting. We'll be discussing the quarterly results and our plans for the next phase of development.",
            timestamp: 0.0,
            duration: 5.2
        ),
        TranscriptSegment(
            text: "First, let's review the numbers from Q3. Revenue was up 15% year over year, which exceeded our projections.",
            timestamp: 5.2,
            duration: 6.8
        ),
        TranscriptSegment(
            text: "The engineering team has made significant progress on the mobile app redesign. We're on track for a beta release next month.",
            timestamp: 12.0,
            duration: 7.1
        ),
        TranscriptSegment(
            text: "Customer feedback has been overwhelmingly positive about the new features we launched in September.",
            timestamp: 19.1,
            duration: 5.3
        ),
        TranscriptSegment(
            text: "Looking ahead to Q4, our main priorities are scaling infrastructure and expanding the sales team.",
            timestamp: 24.4,
            duration: 6.2
        ),
        TranscriptSegment(
            text: "We're also planning to launch a comprehensive marketing campaign targeting enterprise customers.",
            timestamp: 30.6,
            duration: 5.8
        ),
        TranscriptSegment(
            text: "Any questions before we dive deeper into the technical roadmap?",
            timestamp: 36.4,
            duration: 3.9
        ),
        TranscriptSegment(
            text: "Great. Let's move on to the product updates and feature requests we've received from our power users.",
            timestamp: 40.3,
            duration: 6.5
        )
    ]

    return TranscriptView(segments: sampleSegments) { timestamp in
        print("Tapped timestamp: \(timestamp)")
    }
}

#Preview("Empty State") {
    TranscriptionStatusView(isTranscribing: false, isTranscribed: false)
}

#Preview("Transcribing") {
    TranscriptionStatusView(isTranscribing: true, isTranscribed: false)
}
