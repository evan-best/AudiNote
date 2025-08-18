//
//  LiveScrollWaveFormView.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-16.
//

import SwiftUI

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
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Waveform
            WaveformView(amplitudes: recorder.amplitudes)
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
                .buttonStyle(ProminentTranslucentButtonStyle(foreground: .white, background: .gray, backgroundOpacity: 0.2))
                
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
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(background.opacity(backgroundOpacity))
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

struct WaveformView: View {
    let amplitudes: [CGFloat]
    
    var body: some View {
        Canvas { ctx, size in
            let barWidth: CGFloat = 2
            let barSpacing: CGFloat = 3.5
            let availableWidth = size.width
            let barCount = max(1, Int((availableWidth + barSpacing) / (barWidth + barSpacing)))
            let totalBarWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
            let startX = (size.width - totalBarWidth) / 2
            let midY = size.height / 4
            let maxBarHeight = size.height / 3
            let minBarHeight: CGFloat = 2

            for i in 0..<barCount {
                let amplitude: CGFloat
                if amplitudes.count >= barCount {
                    let amplitudeIndex = amplitudes.count - barCount + i
                    if amplitudeIndex >= 0 && amplitudeIndex < amplitudes.count {
                        let rawAmplitude = amplitudes[amplitudeIndex]
                        amplitude = min(1.0, rawAmplitude * 1.5)
                    } else {
                        amplitude = 0.02
                    }
                } else {
                    amplitude = 0.02
                }
                
                let barHeight = minBarHeight + (maxBarHeight - minBarHeight) * amplitude
                let rect = CGRect(
                    x: startX + CGFloat(i) * (barWidth + barSpacing),
                    y: midY - barHeight,
                    width: barWidth,
                    height: barHeight * 2
                )
                let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                ctx.fill(path, with: .color(.primary))
            }
        }
        .animation(.easeOut(duration: 0.033), value: amplitudes.count)
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.1),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1)
                ]),
                startPoint: .leading, endPoint: .trailing
            )
        )
        .accessibilityHidden(true)
    }
}

private extension CGFloat {
    func clamped(to r: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.min(Swift.max(self, r.lowerBound), r.upperBound)
    }
}

#Preview {
    SheetPreviewContainer()
}
