//
//  LiveScrollWaveFormView.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-16.
//

import SwiftUI
import Combine

/// Centered, classic, fixed-bar live waveform display.
/// Displays a fixed number of bars centered horizontally.
/// Only a few bars near the center react to the most recent amplitude.
struct LiveScrollWaveformView: View {
    @ObservedObject var recorder: AudioRecorder
    @State private var isRedDotVisible = true
    var onCancel: (() -> Void)?
    var onDone: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section with "Recording..." and timer
            HStack {
                Text("Recording...")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 6) {
                    // Blinking red dot
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(isRedDotVisible ? 1.0 : 0.3)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isRedDotVisible)
                    
                    Text(recorder.elapsedTimeFormatted)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                        .frame(minWidth: 50, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Waveform (using the simple centered view)
            WaveformView(amplitudes: recorder.amplitudes, isPaused: recorder.isPaused)
                .frame(height: 80)
                .padding(.horizontal, 20)
                .padding(.top, 30)
            
            // Bottom buttons
            HStack(spacing: 16) {
                // Cancel button
                Button(action: {
                    recorder.stopRecording()
                    onCancel?()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .buttonStyle(ProminentTranslucentButtonStyle(foreground: .red, background: .red, backgroundOpacity: 0.18))
                
                // Pause/Resume button
                Button(action: {
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
                    recorder.stopRecording()
                    onDone?()
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
    private var cachedBars: [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] = []
    private var barCount: Int = 0
    private let barWidth: CGFloat = 2
    private let barSpacing: CGFloat = 4
    private lazy var step: CGFloat = barWidth + barSpacing
    
    // Cached layout values to avoid recalculation
    private var centerStartX: CGFloat = 0
    private var midY: CGFloat = 0
    private let maxBarHeight: CGFloat = 20
    private let minBarHeight: CGFloat = 2
    
    // Smooth scrolling variables
    private var displayIndex: Double = 0.0  // Smooth floating-point index
    private var targetIndex: Int = 0       // Where we want to be based on data
	private let scrollSpeed: Double = 0.25   // How fast to catch up to new data
    
    
    func start(amplitudes: [CGFloat]) {
        updateAmplitudes(amplitudes)
        
        // Only start display link if not already running
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(frame))
            displayLink?.preferredFramesPerSecond = 120
            displayLink?.add(to: .current, forMode: .common)
        }
    }
    
    func updateAmplitudes(_ amplitudes: [CGFloat]) {
        // Just use the amplitudes as provided - no internal truncation
        self.amplitudes = amplitudes
        self.targetIndex = max(0, amplitudes.count - 1)
        
        // Initialize displayIndex to current target if starting fresh
        if displayIndex == 0.0 {
            displayIndex = Double(targetIndex)
        }
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
        
        // Resize cached array if needed
        if newBarCount != barCount {
            barCount = newBarCount
            cachedBars = Array(repeating: (x: 0, y: 0, width: barWidth, height: minBarHeight), count: barCount)
        }
    }
    
    @objc private func frame() {
        guard lastSize != .zero, barCount > 0, !amplitudes.isEmpty else { return }
        
        // Update target based on latest data
        targetIndex = max(0, amplitudes.count - 1)
        
        // Smoothly move displayIndex toward targetIndex when not paused
        if !isPaused {
            let distance = Double(targetIndex) - displayIndex
            
            
            displayIndex += distance * scrollSpeed
            // Clamp displayIndex to valid range
            displayIndex = max(0, min(displayIndex, Double(amplitudes.count - 1)))
        }
        
        // Update cached bars in-place - no allocations
        let fractionalPart = displayIndex - floor(displayIndex)
        let pixelOffset = CGFloat(fractionalPart) * step
        
        for i in 0..<barCount {
            let wholeBarsFromRight = barCount - 1 - i
            let baseIndex = Int(floor(displayIndex)) - wholeBarsFromRight
            let amplitude: CGFloat
            
            if baseIndex >= 0 && baseIndex < amplitudes.count {
                amplitude = amplitudes[baseIndex]
            } else {
                amplitude = 0.02
            }
            
            let normalizedAmplitude = min(1.0, amplitude * 1.5)
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
    @StateObject private var renderer = WaveformRenderer()
    
    init(amplitudes: [CGFloat], color: Color = .primary, isPaused: Bool = false) {
        self.amplitudes = amplitudes
        self.color = color
        self.isPaused = isPaused
    }
    
    var body: some View {
        Canvas { ctx, size in
            // Ultra-minimal UI thread work - access pre-allocated cached data
            let bars = renderer.getBars()
            for bar in bars {
                let rect = CGRect(x: bar.x, y: bar.y, width: bar.width, height: bar.height)
                let path = Path(roundedRect: rect, cornerRadius: 1)
                ctx.fill(path, with: .color(color))
            }
        }
        .mask(gradientMask)
        .accessibilityHidden(true)
        .onAppear {
            renderer.start(amplitudes: amplitudes)
        }
        .onDisappear {
            renderer.stop()
        }
        .onChange(of: isPaused) { _, paused in
            renderer.setPaused(paused)
        }
        .onChange(of: amplitudes) { _, newAmplitudes in
            renderer.updateAmplitudes(newAmplitudes)
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            renderer.updateSize(size)
        }
        .onReceive(renderer.$shouldUpdate) { _ in
            // Minimal update trigger for Canvas
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

#Preview {
    SheetPreviewContainer()
}
