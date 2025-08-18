import AVFoundation
import Combine
import UIKit

class AudioRecorder: ObservableObject {
    var audioRecorder: AVAudioRecorder?

    @Published var elapsed: TimeInterval = 0
    @Published var amplitudes: [CGFloat] = []
    @Published var isRecording = false
    @Published var isPaused = false
    private var timer: Timer?
    private(set) var lastRecordingURL: URL?
    private var frameCounter = 0
    
    var elapsedTimeFormatted: String {
        let totalSeconds = Int(elapsed)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func getLastRecordingURL() -> URL? { lastRecordingURL }

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)

        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100, // CD quality sample rate
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
            AVEncoderBitRateKey: 128000, // 128 kbps bit rate
            AVLinearPCMBitDepthKey: 16 // 16-bit depth
        ]

        let url = getDocumentsDirectory().appendingPathComponent("recording.m4a")

        audioRecorder = try? AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        self.lastRecordingURL = url
        self.elapsed = 0
        self.amplitudes = []
        self.isRecording = true
        self.isPaused = false
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            self.elapsed = recorder.currentTime
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0)
            let normalizedPower = max(0.0, (power + 55) / 45)
            
            let rawAmplitude = CGFloat(normalizedPower)
            let processedAmplitude = pow(rawAmplitude, 3.5)
            
            // Apply fast decay to prevent trailing
            let finalAmplitude: CGFloat
            if let lastAmplitude = self.amplitudes.last {
                if processedAmplitude > lastAmplitude {
                    finalAmplitude = processedAmplitude // Allow increases
                } else {
                    // Apply fast decay to decreases
                    finalAmplitude = max(0.0, lastAmplitude * 0.3) // 70% decay per sample
                }
            } else {
                finalAmplitude = processedAmplitude
            }
            
            // Dispatch UI updates to MainActor for smooth performance
            Task { @MainActor in
                self.amplitudes.append(finalAmplitude)
                if self.amplitudes.count > 200 { self.amplitudes.removeFirst() }
            }
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        isPaused = false
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false)
    }
    
    func pauseRecording() {
        audioRecorder?.pause()
        timer?.invalidate()
        timer = nil
        isPaused = true
    }

    func resumeRecording() {
        audioRecorder?.record()
        isPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            self.elapsed = recorder.currentTime
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0)
            let normalizedPower = max(0.0, (power + 55) / 45)
            
            let rawAmplitude = CGFloat(normalizedPower)
            let processedAmplitude = pow(rawAmplitude, 3.5)
            
            // Apply fast decay to prevent trailing
            let finalAmplitude: CGFloat
            if let lastAmplitude = self.amplitudes.last {
                if processedAmplitude > lastAmplitude {
                    finalAmplitude = processedAmplitude // Allow increases
                } else {
                    // Apply fast decay to decreases
                    finalAmplitude = max(0.0, lastAmplitude * 0.3) // 70% decay per sample
                }
            } else {
                finalAmplitude = processedAmplitude
            }
            
            // Dispatch UI updates to MainActor for smooth performance
            Task { @MainActor in
                self.amplitudes.append(finalAmplitude)
                if self.amplitudes.count > 200 { self.amplitudes.removeFirst() }
            }
        }
    }

    func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
