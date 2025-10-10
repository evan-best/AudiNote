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
    @State private var isNoiseReductionEnabled = false
    @EnvironmentObject private var session: SessionViewModel
    let isLargeMode: Bool
    var onCancel: (() -> Void)?
    var onDone: ((String, String) -> Void)?
    
    init(recorder: AudioRecorder, isLargeMode: Bool = false, onCancel: (() -> Void)? = nil, onDone: ((String, String) -> Void)? = nil) {
        self._recorder = ObservedObject(initialValue: recorder)
        self.isLargeMode = isLargeMode
        self.onCancel = onCancel
        self.onDone = onDone
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section - different layouts for large vs small mode
            if isLargeMode {
                // Large mode: centered time display
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


                    Spacer()
                    
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
                    onDone?(recordingTitle, "")
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

class WaveformRenderer: ObservableObject {
    @Published private(set) var shouldUpdate: Bool = false
    
    private var displayLink: CADisplayLink?
    private var isPaused = false
    private var amplitudes: [CGFloat] = []
    private var lastSize: CGSize = .zero
    
    // Pre-allocate arrays to avoid allocation overhead
    private var cachedBars: [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] = Array(repeating: (x: 0, y: 0, width: 2, height: 2), count: 200) // Fixed size for any screen
    private var barCount: Int = 0
    private let barWidth: CGFloat = 2
    private let barSpacing: CGFloat = 4
    private lazy var step: CGFloat = barWidth + barSpacing
    
    // Cached layout values to avoid recalculation
    private var centerStartX: CGFloat = 0
    private var midY: CGFloat = 0
    private let maxBarHeight: CGFloat = 20
    private let minBarHeight: CGFloat = 2
    
    // Ultra-simple scrolling
    private var scrollPosition: Double = 0  // Continuous scroll position
    
    
    func start(amplitudes: [CGFloat]) {
        updateAmplitudes(amplitudes)
        
        // Only start display link if not already running
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(frame))
            displayLink?.preferredFramesPerSecond = 120  // Keep smooth 120fps
            displayLink?.add(to: .current, forMode: .common)
        }
    }
    
    func updateAmplitudes(_ amplitudes: [CGFloat]) {
        // Just use the amplitudes as provided - no internal truncation
        self.amplitudes = amplitudes
    }
    
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    func setPaused(_ paused: Bool) {
        isPaused = paused
    }
    
    func updateSize(_ size: CGSize) {
        guard size != lastSize else { return }
        lastSize = size
        
        // Recalculate layout values when size changes
        let newBarCount = max(1, Int((size.width + barSpacing) / step))
        let totalBarWidth = CGFloat(newBarCount) * barWidth + CGFloat(newBarCount - 1) * barSpacing
        centerStartX = (size.width - totalBarWidth) / 2
        midY = size.height / 2
        
        // Just update barCount - array is pre-allocated
        barCount = min(newBarCount, 200) // Cap at pre-allocated size
    }
    
    @objc private func frame() {
        guard lastSize != .zero, barCount > 0 else { return }
        
        // Ultra-simple constant increment
        if !isPaused {
            scrollPosition += 0.25  // 0.125 * 120fps = 15 per second
        }
        
        // Update cached bars in-place - no allocations
        let fractionalPart = scrollPosition - floor(scrollPosition)
        let pixelOffset = CGFloat(fractionalPart) * step
        
        for i in 0..<barCount {
            let baseIndex = Int(scrollPosition) - (barCount - 1 - i)
            
            // Mock data: generate different bar heights based on position
            let mockAmplitude: CGFloat
            if baseIndex < 0 {
                mockAmplitude = 0.02  // Empty bars before start
            } else {
                // Create interesting pattern: sine wave + random variation
                let phase = Double(baseIndex) * 0.3
                let sineWave = sin(phase)
                let randomVariation = sin(Double(baseIndex) * 1.7) * 0.3
                mockAmplitude = CGFloat(abs(sineWave + randomVariation) * 0.8 + 0.2)
            }
            
            let normalizedAmplitude = min(1.0, mockAmplitude * 1.5)
            let barHeight = minBarHeight + (maxBarHeight - minBarHeight) * normalizedAmplitude
            
            let x = centerStartX + CGFloat(i) * step - pixelOffset
            let y = midY - barHeight
            
            cachedBars[i] = (x: x, y: y, width: barWidth, height: barHeight * 2)
        }
        
        // Trigger minimal UI update
        shouldUpdate.toggle()
    }
    
    func getBars() -> [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] {
        return cachedBars
    }
    
    deinit {
        stop()
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
                
                let normalizedAmplitude = min(1.0, amplitude * 1.5)
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

            // Only update if enough time has passed (33ms = ~30fps to reduce frame pressure)
            if timeSinceLastUpdate > 0.033 {
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
                onDone: { title, transcript in
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
