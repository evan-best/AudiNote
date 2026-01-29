//
//  TranscriptView.swift
//  AudiNote
//
//  Displays timestamped transcript segments
//

import SwiftUI

// Preference key to track scroll offset changes
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TranscriptView: View {
    let segments: [TranscriptSegment]
    let currentTime: TimeInterval
    let onTimestampTap: ((TimeInterval) -> Void)?

    @State private var isAutoScrollEnabled = true
    @State private var isUserScrolling = false
    @State private var scrollDisableTimer: Timer?

    init(segments: [TranscriptSegment], currentTime: TimeInterval = 0, onTimestampTap: ((TimeInterval) -> Void)? = nil) {
        self.segments = segments
        self.currentTime = currentTime
        self.onTimestampTap = onTimestampTap
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(segments) { segment in
                                TranscriptSegmentRow(
                                    segment: segment,
                                    isActive: isSegmentActive(segment),
                                    onTimestampTap: onTimestampTap,
                                    currentTime: currentTime
                                )
                                .id(segment.id)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.top, 20)
                        .padding(.bottom, 200)
                        .background(
                            GeometryReader { contentGeometry in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: contentGeometry.frame(in: .named("scroll")).origin.y)
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { _ in
                                handleUserScroll()
                            }
                    )
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { _ in
                        // Reset timer when scroll position changes
                        if isUserScrolling {
                            scrollDisableTimer?.invalidate()
                            scrollDisableTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                                isUserScrolling = false
                            }
                        }
                    }
                    .onChange(of: currentTime) { _, newTime in
                        // Auto-scroll to active segment only if enabled and user isn't actively scrolling
                        if isAutoScrollEnabled && !isUserScrolling {
                            if let activeSegment = segments.first(where: { isSegmentActive($0) }) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(activeSegment.id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }

            // Follow button when auto-scroll is disabled
            if !isAutoScrollEnabled {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isAutoScrollEnabled = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Follow")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func handleUserScroll() {
        isUserScrolling = true

        // Disable auto-scroll when user manually scrolls
        if isAutoScrollEnabled {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isAutoScrollEnabled = false
            }
        }

        // Reset the timer
        scrollDisableTimer?.invalidate()
        scrollDisableTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            isUserScrolling = false
        }
    }

    private func isSegmentActive(_ segment: TranscriptSegment) -> Bool {
        let endTime = segment.timestamp + segment.duration
        return currentTime >= segment.timestamp && currentTime < endTime
    }
}

struct TranscriptSegmentRow: View {
    let segment: TranscriptSegment
    let isActive: Bool
    let onTimestampTap: ((TimeInterval) -> Void)?
    let currentTime: TimeInterval

    var body: some View {
        Button {
            onTimestampTap?(segment.timestamp)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                // Timestamp
                HStack {
                    Text(segment.formattedTimestamp)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))

                    Spacer()
                }

                // Transcript text with word-by-word reveal
                HStack {
                    Text(segment.text)
                        .font(.system(size: 24))
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .textRenderer(WordRevealRenderer(
                            text: segment.text,
                            wordTimings: segment.wordTimings,
                            elapsedTime: currentTime - segment.timestamp
                        ))

                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// Word-by-word shimmer reveal renderer matching live transcription effect
struct WordRevealRenderer: TextRenderer, Animatable {
    let text: String
    private let wordTimings: [WordTiming]?
    var elapsedTime: TimeInterval // Time elapsed in current segment

    var animatableData: Double {
        get { elapsedTime }
        set { elapsedTime = newValue }
    }

    init(text: String, wordTimings: [WordTiming]?, elapsedTime: TimeInterval) {
        self.text = text
        self.wordTimings = wordTimings
        self.elapsedTime = elapsedTime
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        guard let timings = wordTimings, !timings.isEmpty else {
            // No word timings - render all black (for old recordings)
            for line in layout {
                for run in line {
                    for slice in run {
                        context.draw(slice)
                    }
                }
            }
            return
        }

        // Split text into words to identify boundaries
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        let wordTimingMap = alignWordTimings(words: words, timings: timings)

        // Build character-to-word index mapping and track character positions within words
        var charToWord: [Int] = []
        var charIndexInWord: [Int] = []

        for (wordIndex, word) in words.enumerated() {
            for charIndex in 0..<word.count {
                charToWord.append(wordIndex)
                charIndexInWord.append(charIndex)
            }
            // Add mapping for space (assign to current word)
            if wordIndex < words.count - 1 {
                charToWord.append(wordIndex)
                charIndexInWord.append(0)
            }
        }

        // Render each character with shimmer effect using actual word timing
        var charIndex = 0

        for line in layout {
            for run in line {
                for slice in run {
                    // Get word index for this character
                    let wordIndex = charIndex < charToWord.count ? charToWord[charIndex] : 0
                    let charPosInWord = charIndex < charIndexInWord.count ? charIndexInWord[charIndex] : 0

                    // Use actual word timing from Speech API
                    guard let timingIndex = wordTimingMap[wordIndex], timingIndex < timings.count else {
                        context.draw(slice)
                        charIndex += 1
                        continue
                    }

                    let wordTiming = timings[timingIndex]
                    let wordStart = wordTiming.timestamp
                    let wordEnd = wordTiming.timestamp + wordTiming.duration

                    // Reveal over the full word duration so the fill finishes as the audio ends
                    let baseReveal = max(0.05, wordTiming.duration)
                    let charDelay = Double(charPosInWord) * min(0.02, baseReveal / 8)

                    let opacity: Double

                    if elapsedTime < wordStart {
                        // Haven't reached this word yet - gray
                        opacity = 0.35
                    } else {
                        // Progress through reveal using a smoothstep curve
                        let progress = max(0, min(1, (elapsedTime - wordStart - charDelay) / baseReveal))
                        let eased = progress * progress * (3 - 2 * progress) // smoothstep

                        if elapsedTime < wordEnd {
                            opacity = 0.35 + (0.65 * eased)
                        } else {
                            // Keep at full opacity once word audio is complete
                            opacity = 1.0
                        }
                    }

                    var copy = context
                    copy.opacity = opacity
                    copy.draw(slice)

                    charIndex += 1
                }
            }
        }
    }

    private func alignWordTimings(words: [Substring], timings: [WordTiming]) -> [Int: Int] {
        var map: [Int: Int] = [:]
        var timingIndex = 0

        for (wordIndex, word) in words.enumerated() {
            let normalizedWord = normalizeWord(String(word))
            guard !normalizedWord.isEmpty else { continue }
            guard timingIndex < timings.count else { break }

            let normalizedTiming = normalizeWord(timings[timingIndex].word)
            if normalizedWord == normalizedTiming {
                map[wordIndex] = timingIndex
                timingIndex += 1
            }
        }

        return map
    }

    private func normalizeWord(_ value: String) -> String {
        let lowered = value.lowercased()
        let trimmed = lowered.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.trimmingCharacters(in: .punctuationCharacters.union(.symbols))
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

    return TranscriptView(segments: sampleSegments, currentTime: 5.0) { timestamp in
        print("Tapped timestamp: \(timestamp)")
    }
}

#Preview("Empty State") {
    TranscriptionStatusView(isTranscribing: false, isTranscribed: false)
}

#Preview("Transcribing") {
    TranscriptionStatusView(isTranscribing: true, isTranscribed: false)
}
