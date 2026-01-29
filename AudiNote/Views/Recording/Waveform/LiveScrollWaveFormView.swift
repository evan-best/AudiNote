//
//  LiveScrollWaveFormView.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-16.
//

import SwiftUI
import SwiftData
import Combine

struct LiveScrollWaveformView: View {
    @ObservedObject var recorder: AudioRecorder
    @State private var isRedDotVisible = true
    @State private var showCancelConfirm = false
    @State private var recordingTitle = "New Recording"
    @State private var isEditingTitle = false
    @FocusState private var isTitleFocused: Bool
    @EnvironmentObject private var session: SessionViewModel
    let isLargeMode: Bool
    var onCancel: (() -> Void)?
    var onDone: ((String) -> Void)?

    init(recorder: AudioRecorder, isLargeMode: Bool = false, onCancel: (() -> Void)? = nil, onDone: ((String) -> Void)? = nil) {
        self._recorder = ObservedObject(initialValue: recorder)
        self.isLargeMode = isLargeMode
        self.onCancel = onCancel
        self.onDone = onDone
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section - different layouts for large vs small mode
            if isLargeMode {
                // Large mode: centered time display with transcription above
                VStack(spacing: 8) {
                    // Tappable title
                    if isEditingTitle {
                        TextField("Recording name", text: $recordingTitle)
                            .font(.title.bold())
                            .focused($isTitleFocused)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .onSubmit {
                                isEditingTitle = false
                            }
                    } else {
                        Text(recordingTitle)
                            .font(.title.bold())
                            .lineLimit(1)
                            .onTapGesture {
                                isEditingTitle = true
                                isTitleFocused = true
                            }
                    }

                    // Live transcription - shows last few segments with effects
                    TranscriptionStackView(
                        finalizedSegments: recorder.finalizedSegments,
                        currentTranscript: recorder.currentTranscript
                    )

                    // Timer
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)

                        Text(recorder.elapsedTimeFormatted)
                            .font(.system(size: 48, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 0)
                .padding(.bottom, 20)
            } else {
                // Small mode: original layout
                HStack {
                    Text("Recording...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(recorder.elapsedTimeFormatted)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .monospacedDigit()
                            .frame(minWidth: 50, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            
            // Waveform section
            if isLargeMode {
                // Waveform for large mode
                WaveformView(amplitudes: recorder.amplitudes, isPaused: recorder.isPaused)
                    .frame(height: 120)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
            } else {
                // Small mode: waveform
                WaveformView(amplitudes: recorder.amplitudes, isPaused: recorder.isPaused)
                    .frame(height: 80)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
            }

            Spacer()

            // Bottom buttons
            HStack(spacing: 16) {
                // Cancel button
                Button(action: {
                    // Haptic feedback for cancel
                    session.triggerHaptic(style: .light)
                    // Ask for confirmation before canceling
                    showCancelConfirm = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .buttonStyle(ProminentTranslucentButtonStyle(foreground: .red, background: .red, backgroundOpacity: 0.18))
                .confirmationDialog(
                    "Discard recording?",
                    isPresented: $showCancelConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Discard Recording", role: .destructive) {
                        recorder.stopRecording()
                        onCancel?()
                    }
                    Button("Keep Recording", role: .cancel) { }
                } message: {
                    Text("Are you sure you want to cancel? This will discard the current recording.")
                }
                
                // Pause/Resume button
                Button(action: {
                    // Haptic feedback for pause/resume
                    session.triggerHaptic(style: .medium)
                    
                    if recorder.isPaused {
                        recorder.resumeRecording()
                    } else {
                        recorder.pauseRecording()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(recorder.isPaused ? "Resume" : "Pause")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .buttonStyle(ProminentTranslucentButtonStyle(foreground: .gray, background: .gray, backgroundOpacity: 0.2))
                
                // Done button
                Button(action: {
                    // Haptic feedback for done
                    session.triggerHaptic(style: .heavy)

                    recorder.stopRecording()
                    onDone?(recordingTitle)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .buttonStyle(ProminentTranslucentButtonStyle(foreground: .green, background: .green, backgroundOpacity: 0.18))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        .padding(.horizontal, 4)
        .onAppear {
            isRedDotVisible = true
        }
    }
}

struct ProminentTranslucentButtonStyle: ButtonStyle {
    var foreground: Color
    var background: Color
    var backgroundOpacity: Double = 0.22
    @Environment(\.colorScheme) private var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        let resolvedBackground: Color = resolvedBackgroundColor()
        let resolvedOpacity: Double = colorScheme == .light ? 1 : backgroundOpacity
        return configuration.label
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(resolvedBackground.opacity(resolvedOpacity))
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
    
    private func resolvedBackgroundColor() -> Color {
        if colorScheme == .light {
            if background == .green {
                return Color(red: 0.82, green: 1.0, blue: 0.85) // pastel green
            } else if background == .red {
                return Color(red: 1.0, green: 0.89, blue: 0.89) // pastel red
            } else if background == .gray {
                return Color(red: 0.95, green: 0.95, blue: 0.97) // pale gray
            }
        }
        return background
    }
}

struct WaveformView: View {
    let amplitudes: [CGFloat]
    let color: Color
    let isPaused: Bool
    @State private var animationOffset: Double = 0
    @State private var timer: Timer?
    @State private var waveformData: [CGFloat] = Array(repeating: 0.02, count: 10000)
    @State private var lastAmplitudeUpdate: Date = Date()
    @State private var pendingAmplitude: CGFloat?
    
    // Stable layout constants - back to original
    private let barWidth: CGFloat = 2
    private let barSpacing: CGFloat = 4
    private var step: CGFloat { barWidth + barSpacing }
    private let maxBarHeight: CGFloat = 20
    private let minBarHeight: CGFloat = 2
    
    init(amplitudes: [CGFloat], color: Color = .primary, isPaused: Bool = false) {
        self.amplitudes = amplitudes
        self.color = color
        self.isPaused = isPaused
    }
    
    var body: some View {
        Canvas { ctx, size in
            // Back to original layout calculation - don't cache, just calculate
            let barCount = max(1, Int((size.width + barSpacing) / step))
            let totalBarWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
            let centerStartX = (size.width - totalBarWidth) / 2
            let midY = size.height / 2
            
            // Back to original simple pixel offset
            let pixelOffset = CGFloat(animationOffset.truncatingRemainder(dividingBy: 1.0)) * step
            
            // Back to original simple rendering loop
            for i in 0..<barCount {
                let baseIndex = Int(animationOffset) - (barCount - 1 - i)
                
                // Back to original data access pattern
                let amplitude: CGFloat
                if baseIndex >= 0 && baseIndex < waveformData.count {
                    amplitude = waveformData[baseIndex]
                } else {
                    amplitude = 0.02  // Default for out of bounds
                }
                
                let normalizedAmplitude = min(1.0, amplitude * 3.5)
                let barHeight = minBarHeight + (maxBarHeight - minBarHeight) * normalizedAmplitude
                
                let x = centerStartX + CGFloat(i) * step - pixelOffset
                let y = midY - barHeight
                
                let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight * 2)
                let path = Path(roundedRect: rect, cornerRadius: 1)
                ctx.fill(path, with: .color(color))
            }
        }
        .mask(gradientMask)
        .accessibilityHidden(true)
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .onChange(of: isPaused) { _, paused in
            if paused {
                timer?.invalidate()
                timer = nil
            } else {
                startAnimation()
            }
        }
        .onChange(of: amplitudes) { _, newAmplitudes in
            // Debounce amplitude updates to prevent multiple updates per frame
            guard let latestAmplitude = newAmplitudes.last else { return }

            let now = Date()
            let timeSinceLastUpdate = now.timeIntervalSince(lastAmplitudeUpdate)

            // Only update if enough time has passed (20ms = ~50fps)
            if timeSinceLastUpdate > 0.02 {
                updateWaveformData(with: latestAmplitude)
                lastAmplitudeUpdate = now
                pendingAmplitude = nil
            } else {
                // Store pending amplitude for next update cycle
                pendingAmplitude = latestAmplitude
            }
        }
    }
    
    private func startAnimation() {
        timer?.invalidate()
        // Use 30fps for better performance and less frame pressure
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            if !isPaused {
                animationOffset += 0.30

                // Process any pending amplitude updates
                if let pending = pendingAmplitude {
                    updateWaveformData(with: pending)
                    pendingAmplitude = nil
                    lastAmplitudeUpdate = Date()
                }
            }
        }
    }
    
    private func updateWaveformData(with amplitude: CGFloat) {
        let currentWriteIndex = Int(animationOffset)
        if currentWriteIndex >= 0 && currentWriteIndex < waveformData.count {
            waveformData[currentWriteIndex] = amplitude
        }
    }
}


extension WaveformView {
    private var gradientMask: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.1),
                .init(color: .black, location: 0.9),
                .init(color: .clear, location: 1)
            ]),
            startPoint: .leading, endPoint: .trailing
        )
    }
    
    

}

private extension CGFloat {
    func clamped(to r: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, r.lowerBound), r.upperBound)
    }
}

// MARK: - Transcription Stack View
// Shows finalized segments and current transcript with alternating left/right alignment

struct TranscriptionStackView: View {
	let finalizedSegments: [TranscriptSegment]
	let currentTranscript: String
	
	var body: some View {
		GeometryReader { geometry in
			ScrollViewReader { proxy in
				ScrollView(showsIndicators: false) {
					VStack(alignment: .leading, spacing: 16) {
						// All finalized segments (full opacity)
						ForEach(Array(finalizedSegments.enumerated()), id: \.element.id) { index, segment in
							TranscriptTextRow(
								text: segment.text,
								timestamp: segment.formattedTimestamp,
								isStreaming: false,
								alignment: .leading
							)
							.id(segment.id)
						}
						
						// Current in-progress transcript
						if !currentTranscript.isEmpty {
							TranscriptTextRow(
								text: currentTranscript,
								timestamp: nil,
								isStreaming: true,
								alignment: .leading
							)
							.id("streaming")
						}
					}
					.frame(maxWidth: .infinity)
					.padding(.horizontal, 8)
					.padding(.top, 50)
					.padding(.bottom, 80) // Extra padding at bottom to prevent cutoff
				}
				.scrollEdgeEffectStyle(.soft, for: .top)
				.scrollEdgeEffectStyle(.soft, for: .bottom)
				.frame(width: geometry.size.width, height: geometry.size.height)
				.onChange(of: finalizedSegments.count) { _, _ in
					// Auto-scroll to second-to-last segment so the new one appears at the bottom
					if finalizedSegments.count >= 2 {
						let secondToLast = finalizedSegments[finalizedSegments.count - 2]
						withAnimation(.easeOut(duration: 0.3)) {
							proxy.scrollTo(secondToLast.id, anchor: .center)
						}
					} else if let lastSegment = finalizedSegments.last {
						withAnimation(.easeOut(duration: 0.3)) {
							proxy.scrollTo(lastSegment.id, anchor: .center)
						}
					}
				}
				.onChange(of: currentTranscript) { _, newValue in
					// Auto-scroll to show streaming text
					if !newValue.isEmpty, let lastSegment = finalizedSegments.last {
						withAnimation(.easeOut(duration: 0.3)) {
							proxy.scrollTo(lastSegment.id, anchor: .center)
						}
					}
				}
			}
		}
	}
	
	// Individual transcript text row with typewriter/streaming effect
	struct TranscriptTextRow: View {
		let text: String
		let timestamp: String?
		let isStreaming: Bool
		let alignment: HorizontalAlignment
		
		@State private var animationTime: Double = 0
		@State private var lastText: String = ""
		
		var body: some View {
			VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: 4) {
				// Timestamp (if available)
				if let timestamp = timestamp {
					HStack {
						if alignment == .trailing {
							Spacer()
						}
						
						Text(timestamp)
							.font(.system(size: 11, weight: .medium))
							.foregroundColor(.secondary.opacity(0.6))
						
						if alignment == .leading {
							Spacer()
						}
					}
				}
				
				// Transcript text
				HStack {
					if alignment == .trailing {
						Spacer()
					}
					
					if isStreaming {
						// Streaming animation
						Text(text)
							.font(.system(size: 16))
							.foregroundColor(.secondary)
							.multilineTextAlignment(alignment == .leading ? .leading : .trailing)
							.fixedSize(horizontal: false, vertical: true)
					} else {
						// Finalized text - animate when it appears
						Text(text)
							.font(.system(size: 24))
							.fontWeight(.medium)
							.foregroundColor(.primary)
							.multilineTextAlignment(alignment == .leading ? .leading : .trailing)
							.fixedSize(horizontal: false, vertical: true)
							.textRenderer(StreamingTextRenderer(elapsedTime: animationTime))
							.task(id: text) {
								// Animate when sentence is finalized
								animationTime = 0
								
								// Faster animation over text length
								let totalDuration = Double(text.count) * 0.008 + 0.1
								let steps = 60
								let increment = totalDuration / Double(steps)
								
								for _ in 0..<steps {
									try? await Task.sleep(nanoseconds: UInt64(increment * 1_000_000_000))
									animationTime += increment
								}
							}
					}
					
					if alignment == .leading {
						Spacer()
					}
				}
			}
			.frame(maxWidth: .infinity)
		}
	}
	
	// Streaming text renderer with per-character fade-in effect
	struct StreamingTextRenderer: TextRenderer, Animatable {
		var elapsedTime: Double = 0
		
		var animatableData: Double {
			get { elapsedTime }
			set { elapsedTime = newValue }
		}
		
		func draw(layout: Text.Layout, in context: inout GraphicsContext) {
			var charIndex = 0
			
			for line in layout {
				for run in line {
					for (index, slice) in run.enumerated() {
						// Calculate opacity based on character index and elapsed time
						// Faster animation: 8ms delay per character, 50ms fade
						let delay = Double(charIndex) * 0.008
						let progress = max(0, min(1, (elapsedTime - delay) / 0.05))
						
						var copy = context
						copy.opacity = progress
						copy.draw(slice)
						
						charIndex += 1
					}
				}
			}
		}
	}
}

#Preview("Live Transcription Stack") {
	struct TranscriptionPreview: View {
		@State private var currentTranscript = "and we're planning to expand"
		@State private var segments: [TranscriptSegment] = [
			TranscriptSegment(text: "Welcome to today's meeting", timestamp: 0, duration: 2.5),
			TranscriptSegment(text: "Let's review the quarterly results", timestamp: 2.5, duration: 2.8),
			TranscriptSegment(text: "Revenue is up fifteen percent", timestamp: 5.3, duration: 2.2)
		]

		var body: some View {
			VStack(spacing: 0) {
				// Title
				Text("Preview Recording")
					.font(.title.bold())
					.padding(.top, 20)

				// Transcription area
				TranscriptionStackView(
					finalizedSegments: segments,
					currentTranscript: currentTranscript
				)
				.frame(height: 500) // Give it explicit height

				// Timer for context
				HStack(spacing: 10) {
					Circle()
						.fill(Color.red)
						.frame(width: 12, height: 12)

					Text("00:47")
						.font(.system(size: 48, weight: .medium, design: .rounded))
						.foregroundColor(.primary)
						.monospacedDigit()
				}
				.padding(.bottom, 20)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background(Color(.systemBackground))
			.onAppear {
				// Simulate live transcription updates
				Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
					// Cycle through different current transcripts
					let samples = [
						"and we're planning to expand",
						"our team is working hard on",
						"the new features will be released",
						"customer feedback has been positive"
					]
					currentTranscript = samples.randomElement() ?? ""

					// Occasionally add a new finalized segment
					if Bool.random() {
						let newSegment = TranscriptSegment(
							text: samples.randomElement() ?? "",
							timestamp: Double(segments.count) * 2.5,
							duration: 2.5
						)
						segments.append(newSegment)
					}
				}
			}
		}
	}

	return TranscriptionPreview()
}

#Preview("Live Waveform") {
	struct PreviewContainer: View {
		@StateObject private var recorder = AudioRecorder(previewMode: true)
		@StateObject private var session = SessionViewModel()

		var body: some View {
			LiveScrollWaveformView(
				recorder: recorder,
				isLargeMode: true,
				onCancel: {
					// Handle cancel
				},
				onDone: { title in
					print("Done with title: \(title)")
				}
			)
			.onAppear {
				// Start mock recording
				recorder.isRecording = true
				recorder.elapsed = 0

				// Simulate elapsed time
				Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
					recorder.elapsed += 1
				}
			}
			.environmentObject(session)
		}
	}

	return PreviewContainer()
		.modelContainer(for: Recording.self)
}
