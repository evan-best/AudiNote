//
//  RecordButton.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-15.
//

import SwiftUI
import DSWaveformImageViews

struct RecordButton: View {
    @StateObject private var recorder = AudioRecorder()
    @State private var showSheet = false
    @Namespace private var animation
    
    var onRecordTapped: (() -> Void)? = nil
    var onSave: ((Recording) -> Void)? = nil
    
    // Sample waveform data
    private let sampleAmplitudes: [CGFloat] = {
        (0..<50).map { i in
            let value = CGFloat(abs(sin(Double(i) * 0.3))) * 0.9 + 0.1
            return value
        }
    }()
    
    var body: some View {
        Group {
            if recorder.isRecording || recorder.isPaused {
                // Show waveform in same button style
                Button(action: {
                    showSheet = true
                }) {
                    HStack(spacing: 12) {
                        // Custom bar waveform takes up most space
                        CustomCompactWaveformView(samples: recorder.amplitudes.map { Float($0) })
                        .frame(height: 20)
                        
                        Spacer()
                        
                        // Timer and indicators on the right
                        HStack(spacing: 6) {
                            if recorder.isPaused {
                                Image(systemName: "pause.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(.systemBackground))
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            }
                            
                            Text(recorder.elapsedTimeFormatted)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(.systemBackground))
                                .monospacedDigit()
                                .frame(minWidth: 50, alignment: .leading)
                        }
                    }
                    .padding(18)
                    .background(Color.primary)
                    .clipShape(Capsule())
                    .padding(.horizontal, 28)
                }
                .buttonStyle(PlainButtonStyle())
                .matchedTransitionSource(id: "Record", in: animation)
            } else {
                // Show record button when not recording
                Button(action: startRecording) {
                    HStack(spacing: 4) {
                        Spacer()
                        Image(systemName:"record.circle.fill")
                            .foregroundStyle(.red)
                        Text("Record")
                            .foregroundStyle(.background)
                        Spacer()
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .padding(18)
                    .background(Color.primary)
                    .clipShape(Capsule())
                    .padding(.horizontal, 28)
                }
                .buttonStyle(PlainButtonStyle())
                .matchedTransitionSource(id: "Record", in: animation)
            }
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showSheet) {
            RecordingSheet(recorder: recorder) { savedRecording in
                onSave?(savedRecording)
            }
            .navigationTransition(.zoom(sourceID: "Record", in: animation))
            .presentationDetents([.fraction(0.25)])
        }
    }
    
    // MARK: - Actions
    private func startRecording() {
        recorder.startRecording()
        showSheet = true
        onRecordTapped?()
    }
}

struct PreviewContainer: View {
    var body: some View {
        Spacer()
        RecordButton()
    }
}

struct CustomCompactWaveformView: View {
    let samples: [Float]
    
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<40, id: \.self) { index in
                let amplitude = getAmplitude(for: index)
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(.systemBackground))
                    .frame(
                        width: 2,
                        height: amplitude == 0 ? 2 : max(3, CGFloat(amplitude) * 16)
                    )
                    .opacity(amplitude == 0 ? 0.3 : 1.0)
                    .animation(.easeOut(duration: 0.2), value: amplitude)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func getAmplitude(for index: Int) -> Float {
        guard !samples.isEmpty else { return 0.0 }
        
        // Show most recent samples on the right side
        let totalBars = 40
        let sampleIndex = samples.count - (totalBars - index)
        
        if sampleIndex >= 0 && sampleIndex < samples.count {
            let rawAmplitude = samples[sampleIndex]
            return rawAmplitude > 0.0 ? rawAmplitude : 0.0
        } else {
            return 0.0 // Complete silence for empty bars
        }
    }
}

#Preview { PreviewContainer() }
