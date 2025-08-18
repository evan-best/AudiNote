//
//  RecordingSheet.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import SwiftUI
import AVFoundation
import Combine
import SwiftData

enum RecordingState {
    case idle, recording, paused, finished, error
}

struct RecordingSheet: View {
    let recorder: AudioRecorder
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var state: RecordingState = .idle
    @State private var playbackReady = false
    @State private var waveformAmplitudes: [CGFloat] = []

    private var lastRecordingURL: URL? { recorder.getLastRecordingURL() }
    private var recordingDuration: TimeInterval { recorder.elapsed }
    private var fileName: String { lastRecordingURL?.lastPathComponent ?? "" }
    private var fileIsReady: Bool {
        guard let url = lastRecordingURL,
              let attr = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attr[.size] as? UInt64 else { return false }
        return size > 128
    }

    var body: some View {
        VStack(spacing: 0) {
            // Waveform view - takes most of the space
            Group {
                if state == .recording || state == .paused {
                    LiveScrollWaveformView(
                        recorder: recorder,
                        onCancel: {
                            dismiss()
                        },
                        onDone: {
                            self.state = .finished
                            playbackReady = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { playbackReady = true }
                        }
                    )
                } else if let audioURL = lastRecordingURL, fileIsReady, state == .finished {
                    VStack(spacing: 12) {
                        if waveformAmplitudes.isEmpty {
                            ProgressView()
                                .frame(height: 60)
                                .task {
                                    if let amplitudes = await extractAudioAmplitudes(from: audioURL, sampleCount: 200) {
                                        waveformAmplitudes = amplitudes
                                    }
                                }
                        } else {
                            WaveformView(amplitudes: waveformAmplitudes)
                                .frame(height: 60)
                                .padding(.horizontal, 16)
                        }
                        
                        // Playback controls in compact layout
                        VStack(spacing: 8) {
                            HStack {
                                Text(fileName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text("Duration: \(formattedTime(recordingDuration))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 12) {
                                Button {
                                    if audioPlayer.isPlaying {
                                        audioPlayer.pause()
                                    } else if let url = lastRecordingURL {
                                        if audioPlayer.duration == 0 { audioPlayer.load(url: url) }
                                        audioPlayer.play()
                                    }
                                } label: {
                                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 20))
                                }
                                .disabled(!playbackReady || !fileIsReady)

                                VStack(spacing: 2) {
                                    Slider(value: $audioPlayer.currentTime, in: 0...audioPlayer.duration) { editing in
                                        if !editing { audioPlayer.seek(to: audioPlayer.currentTime) }
                                    }
                                    .disabled(audioPlayer.duration == 0)
                                    
                                    Text("\(formattedTime(audioPlayer.currentTime)) / \(formattedTime(audioPlayer.duration))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        if playbackReady && !fileIsReady {
                            Text("Audio file is not ready yet.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                } else {
                    // Idle state - minimal placeholder
                    VStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .overlay(
                                Text("Tap record to start")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            )
                            .frame(height: 60)
                            .padding(.horizontal, 16)
                        
                        Button("Record", systemImage: "record.circle") {
                            guard state == .idle else { return }
                            recorder.startRecording()
                            state = .recording
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .padding(.top, 12)
                    }
                }
            }

            // Control buttons - compact bottom section
            if state == .finished {
                controlButtons(for: state)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            } else if state == .error {
                VStack(spacing: 8) {
                    Text("An error occurred during recording.")
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    Button("Dismiss") { reset() }
                        .buttonStyle(.bordered)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            // Set state based on recorder's current state
            if recorder.isRecording {
                state = .recording
            } else if recorder.isPaused {
                state = .paused
            }
        }
        .onChange(of: state) { newState in
            if newState != .finished {
                waveformAmplitudes = []
            }
        }
    }

    // MARK: - Control Buttons

    @ViewBuilder
    private func controlButtons(for state: RecordingState) -> some View {
        switch state {
        case .recording:
            HStack(spacing: 20) {
                Button {
                    recorder.pauseRecording()
                    self.state = .paused
                } label: {
                    Label("Pause", systemImage: "pause.circle")
                }
                .buttonStyle(.bordered)
                .tint(.orange)

                Button {
                    recorder.stopRecording()
                    self.state = .finished
                    playbackReady = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { playbackReady = true }
                } label: {
                    Label("Stop", systemImage: "stop.circle")
                }
                .buttonStyle(.bordered)
            }

        case .paused:
            HStack(spacing: 20) {
                Button {
                    recorder.resumeRecording()
                    self.state = .recording
                } label: {
                    Label("", systemImage: "play.fill")
                }
                .buttonStyle(.plain)
                .tint(.green)

                Button {
                    recorder.stopRecording()
                    self.state = .finished
                    playbackReady = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { playbackReady = true }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.plain)
            }

        case .finished:
            HStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Spacer()

                Button {
                    let newRecording = Recording(
                        title: "New Recording",
                        timestamp: Date(),
                        duration: recordingDuration,
                        audioFilePath: lastRecordingURL?.path ?? ""
                    )
                    modelContext.insert(newRecording)
                    dismiss()
                } label: {
                    Label("Save", systemImage: "checkmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private func reset() {
        recorder.stopRecording()
        dismiss()
    }

    private func formattedTime(_ duration: TimeInterval) -> String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func scrollToLast(_ proxy: ScrollViewProxy, count: Int) {
        guard count > 0 else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(count - 1, anchor: .trailing)
        }
    }
    
    private func extractAudioAmplitudes(from url: URL, sampleCount: Int) async -> [CGFloat]? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                do {
                    let audioFile = try AVAudioFile(forReading: url)
                    let format = audioFile.processingFormat
                    let frameCount = Int(audioFile.length)
                    
                    guard frameCount > 0 else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
                    try audioFile.read(into: buffer)
                    
                    guard let channelData = buffer.floatChannelData?[0] else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let samplesPerBin = frameCount / sampleCount
                    var amplitudes: [CGFloat] = []
                    
                    for i in 0..<sampleCount {
                        let startIndex = i * samplesPerBin
                        let endIndex = min(startIndex + samplesPerBin, frameCount)
                        
                        var sum: Float = 0
                        for j in startIndex..<endIndex {
                            sum += abs(channelData[j])
                        }
                        
                        let average = sum / Float(endIndex - startIndex)
                        let normalized = min(1.0, average * 2.0) // Normalize and boost
                        amplitudes.append(CGFloat(normalized))
                    }
                    
                    continuation.resume(returning: amplitudes)
                } catch {
                    print("Error extracting audio amplitudes: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

struct SheetPreviewContainer: View {
    @State private var showSheet = false
    @StateObject private var recorder = AudioRecorder()
    @Namespace private var animation

    var body: some View {
        Spacer()
        RecordButton(onRecordTapped: { showSheet = true })
            .matchedTransitionSource(id: "Record", in: animation)
            .sheet(isPresented: $showSheet) {
                    RecordingSheet(recorder: recorder)
                    .navigationTransition(.zoom(sourceID: "Record", in: animation))
                    .presentationDetents([.fraction(0.25)])
            }
    }
}

#Preview {
    SheetPreviewContainer()
}

import AVFoundation

class AudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var currentTime: Double = 0.0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(url: URL) {
        stop()
        do {
            player = try AVAudioPlayer(contentsOf: url)
            duration = player?.duration ?? 0
            progress = 0
            currentTime = 0
        } catch {
            print("Failed to load audio: \(error)")
        }
    }

    func play() {
        guard let player else { return }
        player.play()
        isPlaying = true
        startTimer()
    }
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }
    func stop() {
        player?.stop()
        isPlaying = false
        stopTimer()
        progress = 0
        currentTime = 0
        player = nil
        duration = 0
    }
    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
        progress = duration > 0 ? time / duration : 0
    }
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player else { return }
            self.currentTime = player.currentTime
            self.duration = player.duration
            self.progress = player.duration > 0 ? player.currentTime / player.duration : 0
            if !player.isPlaying {
                self.isPlaying = false
                self.stopTimer()
            }
        }
    }
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    deinit { stop() }
}

