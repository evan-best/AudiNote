//
//  RecordButton.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-15.
//

import SwiftUI

struct RecordButton: View {
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var onRecordTapped: (() -> Void)? = nil
    
    // Sample waveform data
    private let sampleAmplitudes: [CGFloat] = {
        (0..<50).map { i in
            let value = CGFloat(abs(sin(Double(i) * 0.3))) * 0.9 + 0.1
            return value
        }
    }()
    
    var body: some View {
        Button(action: toggleRecording) {
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
        .frame(maxWidth: .infinity)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    // MARK: - Actions
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        recordingTime = 0
        onRecordTapped?()
    }
    
    private func stopRecording() {
        isRecording = false
    }
    
    // MARK: - Timer
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            recordingTime += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct PreviewContainer: View {
    @State private var showSheet = false
    private let sampleAmplitudes: [CGFloat] = (0..<50).map { i in
        let value = CGFloat(abs(sin(Double(i) * 0.3))) * 0.9 + 0.1
        return value
    }
    var body: some View {
        Spacer()
        RecordButton(onRecordTapped: { showSheet = true })
            .sheet(isPresented: $showSheet) {
                RecordingSheet()
                .frame(height: 80)
                .presentationDetents([])
            }
    }
}

#Preview { PreviewContainer() }
