//
//  RecordButton.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-15.
//

import SwiftUI

struct RecordButton: View {
    @StateObject private var recorder = AudioRecorder()
    @State private var showSheet = false
    @Namespace private var animation
    
    var onRecordTapped: (() -> Void)? = nil
    
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
                        // Waveform takes up most space
                        WaveformView(amplitudes: recorder.amplitudes, color: Color(.systemBackground))
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
            RecordingSheet(recorder: recorder)
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

#Preview { PreviewContainer() }

