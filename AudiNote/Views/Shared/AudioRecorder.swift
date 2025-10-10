import AVFoundation
import Combine
import UIKit

class AudioRecorder: ObservableObject {
    var audioRecorder: AVAudioRecorder?

    @Published var elapsed: TimeInterval = 0
    @Published var amplitudes: [CGFloat] = []
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var micPermission: AVAudioSession.RecordPermission = AVAudioSession.sharedInstance().recordPermission

    private var timer: Timer?
    private(set) var lastRecordingURL: URL?
    private var frameCounter = 0
    private var recordingStartTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var lastPauseTime: Date?
    private var noiseReductionEnabled: Bool = false
    public private(set) var isPreviewMode: Bool = false
    
    var elapsedTimeFormatted: String {
        let totalSeconds = Int(elapsed)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    init(previewMode: Bool = false) {
        self.isPreviewMode = previewMode
        if previewMode {
            micPermission = .granted
        }
    }
    
    func getLastRecordingURL() -> URL? { lastRecordingURL }

    // MARK: - Permission

    /// Ensures microphone permission. Returns true if authorized.
    @MainActor
    func ensureMicrophonePermission() async -> Bool {
        let session = AVAudioSession.sharedInstance()
        let current = session.recordPermission

        switch current {
        case .granted:
            micPermission = .granted
            return true

        case .denied, .undetermined:
            return await withCheckedContinuation { continuation in
                session.requestRecordPermission { [weak self] granted in
                    DispatchQueue.main.async {
                        self?.micPermission = granted ? .granted : .denied
                        continuation.resume(returning: granted)
                    }
                }
            }

        @unknown default:
            micPermission = current
            return false
        }
    }

    // MARK: - Recording

    func startRecording() {
        if isPreviewMode {
            startPreviewRecording()
            return
        }

        // Defensive: don't proceed if not authorized
        let permission = AVAudioSession.sharedInstance().recordPermission
        guard permission == .granted else {
            micPermission = permission
            print("Microphone permission not granted. Aborting startRecording().")
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
            return
        }

        // Prepare file URL (.m4a AAC)
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "recording_\(timestamp).m4a"
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
        self.lastRecordingURL = fileURL

        // High-quality AAC settings
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1, // iPhone mic is mono; use 2 if you have stereo input
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 192_000
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            let started = audioRecorder?.record() ?? false
            guard started else {
                print("❌ Failed to start recording")
                return
            }
            print("✅ Recording to: \(fileURL.path)")
        } catch {
            print("❌ Failed to create AVAudioRecorder: \(error)")
            return
        }

        // Reset state
        self.elapsed = 0
        self.recordingStartTime = Date()
        self.pausedDuration = 0
        self.lastPauseTime = nil
        self.amplitudes = []
        self.isRecording = true
        self.isPaused = false

        // Start metering/elapsed timer
        startMeteringTimer()
    }

    func setNoiseReduction(enabled: Bool) {
        noiseReductionEnabled = enabled
        // Apply noise reduction to the audio processing chain
        // This could involve adding/removing audio unit effects
        print("Noise reduction \(enabled ? "enabled" : "disabled")")
    }

    private func startMeteringTimer() {
        recordingStartTime = recordingStartTime ?? Date()

        // Update timer for elapsed time and amplitudes
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Update elapsed time
            self.updateElapsedTime()

            // Update metering-based amplitude
            if let recorder = self.audioRecorder {
                recorder.updateMeters()
                let avgPower = recorder.averagePower(forChannel: 0) // -160 .. 0 dB
                // Convert dB to linear 0...1
                let linear = max(0.0, pow(10.0, avgPower / 20.0))
                let amplitude = CGFloat(linear)
                self.amplitudes.append(amplitude)
            }
        }
    }

    private func updateElapsedTime() {
        guard let startTime = recordingStartTime else { return }

        let currentTime = Date()
        let totalElapsed = currentTime.timeIntervalSince(startTime)

        // Subtract any paused duration
        self.elapsed = totalElapsed - pausedDuration
    }

    private func startPreviewRecording() {
        // Create a mock URL for preview mode
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "preview_recording_\(timestamp).m4a"
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        self.lastRecordingURL = url
        self.elapsed = 0
        self.recordingStartTime = nil
        self.pausedDuration = 0
        self.lastPauseTime = nil
        self.amplitudes = []
        self.isRecording = true
        self.isPaused = false
        
        startPreviewTimer()
    }

    func stopRecording() {
        // Stop AVAudioRecorder
        audioRecorder?.stop()
        audioRecorder = nil

        // Stop timer
        timer?.invalidate()
        timer = nil

        isRecording = false
        isPaused = false

        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false)
    }
    
    func pauseRecording() {
        lastPauseTime = Date()

        if isPreviewMode {
            timer?.invalidate()
            timer = nil
            isPaused = true
            return
        }

        audioRecorder?.pause()
        timer?.invalidate()
        timer = nil
        isPaused = true
    }

    func resumeRecording() {
        // Add the paused duration to our total
        if let pauseTime = lastPauseTime {
            pausedDuration += Date().timeIntervalSince(pauseTime)
        }
        lastPauseTime = nil
        isPaused = false

        if isPreviewMode {
            startPreviewTimer()
            return
        }

        // Resume AVAudioRecorder
        if audioRecorder?.record() == true {
            // Restart the timer for elapsed time updates and metering
            startMeteringTimer()
        }
    }
    
    private func startPreviewTimer() {
        recordingStartTime = Date()
        pausedDuration = 0

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateElapsedTime()

            // Generate mock waveform data
            let time = self.elapsed
            let baseAmplitude = sin(time * 2.0) * 0.5 + 0.5
            let randomVariation = Double.random(in: -0.2...0.2)
            let mockAmplitude = CGFloat(max(0.1, min(1.0, baseAmplitude + randomVariation)))

            self.amplitudes.append(mockAmplitude)
        }
    }

    func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

