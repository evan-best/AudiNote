import AVFoundation
import Combine
import UIKit
import Speech

class AudioRecorder: ObservableObject {
    @Published var elapsed: TimeInterval = 0
    @Published var amplitudes: [CGFloat] = []
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var micPermission: AVAudioSession.RecordPermission = AVAudioSession.sharedInstance().recordPermission

    // Transcription - conversation pieces
    @Published var currentTranscript: String = ""
    @Published var finalizedSegments: [TranscriptSegment] = []

    private var timer: Timer?
    private(set) var lastRecordingURL: URL?
    private var recordingStartTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var lastPauseTime: Date?
    public private(set) var isPreviewMode: Bool = false

    // AVAudioEngine for unified recording + transcription
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var transcriptionService: TranscriptionService?
    private var audioConverter: AVAudioConverter?
    private var transcriptionFormat: AVAudioFormat?
    private var recordingConverter: AVAudioConverter?
    private var currentTranscriptCancellable: AnyCancellable?
    private var finalizedSegmentsCancellable: AnyCancellable?

    
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

        // Check permission
        let permission = AVAudioSession.sharedInstance().recordPermission
        guard permission == .granted else {
            micPermission = permission
            print("Microphone permission not granted")
            return
        }

        // Configure audio session for voice recording
        let session = AVAudioSession.sharedInstance()
        do {
            // Use .playAndRecord to support speaker output
            // .spokenAudio mode favors speech playback/recording without chat constraints
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth, .duckOthers])

            // Don't force a specific mic - let the system choose the best one
            // When .defaultToSpeaker is set, iOS will use the speakerphone mic which is clearer

            try session.setPreferredSampleRate(44100)
            try session.setPreferredIOBufferDuration(0.002) // Lower latency for faster transcription updates

            try session.setActive(true)

            if session.isInputGainSettable {
                try session.setInputGain(1.0)
            }

            if !isBluetoothOutputActive(session) {
                try session.overrideOutputAudioPort(.speaker)
            }

        } catch {
            print("Failed to configure AVAudioSession: \(error)")
            return
        }

        // Prepare file URL - use .caf for reliable recording
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "recording_\(timestamp).caf"
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
        self.lastRecordingURL = fileURL

        // Create audio engine
        let engine = AVAudioEngine()
        self.audioEngine = engine

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create high-quality CAF file with LPCM format
        // CAF container with PCM is lossless and works reliably with AVAudioFile
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 1,
            interleaved: false
        )!

        do {
            audioFile = try AVAudioFile(
                forWriting: fileURL,
                settings: recordingFormat.settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
        } catch {
            return
        }

        // Create converter from input to recording format
        recordingConverter = AVAudioConverter(from: inputFormat, to: recordingFormat)
        guard recordingConverter != nil else {
            return
        }

        // Install tap for recording AND transcription
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            guard let self = self, let file = self.audioFile, let converter = self.recordingConverter else { return }

            // Convert input buffer to recording format
            guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

            let frameCapacity = AVAudioFrameCount(recordingFormat.sampleRate * Double(pcmBuffer.frameLength) / inputFormat.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: recordingFormat, frameCapacity: frameCapacity) else { return }

            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return pcmBuffer
            }

            if error == nil {
                applyAutoGain(to: convertedBuffer)
                try? file.write(from: convertedBuffer)
            }

            // Convert and feed to transcription if format is ready
            if let pcmBuffer = buffer as? AVAudioPCMBuffer,
               let converter = self.audioConverter,
               let transcriptionFormat = self.transcriptionFormat {

                // Calculate output buffer size based on sample rate conversion ratio
                let ratio = transcriptionFormat.sampleRate / pcmBuffer.format.sampleRate
                let outputFrameCapacity = AVAudioFrameCount(Double(pcmBuffer.frameLength) * ratio)

                guard let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: transcriptionFormat,
                    frameCapacity: outputFrameCapacity
                ) else { return }

                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return pcmBuffer
                }

                converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

                if error == nil {
                    Task { @MainActor in
                        self.transcriptionService?.feedAudioBuffer(convertedBuffer)
                    }
                }
            }

            // Calculate amplitude for waveform
            let channelData = buffer.floatChannelData?[0]
            let channelDataCount = Int(buffer.frameLength)
            var sumSquares: Float = 0
            var peak: Float = 0
            if let data = channelData {
                for i in 0..<channelDataCount {
                    let value = abs(data[i])
                    sumSquares += value * value
                    if value > peak {
                        peak = value
                    }
                }
            }
            let rms = sqrt(sumSquares / Float(max(1, channelDataCount)))
            let blended = (0.7 * peak) + (0.3 * rms)
            let amplitude = CGFloat(blended)

            DispatchQueue.main.async {
                self.amplitudes.append(amplitude)
            }
        }

        // Start engine
        do {
            try engine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
            return
        }

        // Reset state
        self.elapsed = 0
        self.recordingStartTime = Date()
        self.pausedDuration = 0
        self.lastPauseTime = nil
        self.amplitudes = []
        self.currentTranscript = ""
        self.finalizedSegments = []
        self.isRecording = true
        self.isPaused = false

        // Start timer
        startTimer()

        // Start live transcription
        startLiveTranscription()
    }

    private func startTimer() {
        recordingStartTime = recordingStartTime ?? Date()

        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateElapsedTime()
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
        // Stop transcription
        stopLiveTranscription()

        // Stop audio engine and remove tap BEFORE closing file
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        audioFile = nil
        audioEngine = nil
        recordingConverter = nil

        timer?.invalidate()
        timer = nil

        isRecording = false
        isPaused = false

        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    func pauseRecording() {
        lastPauseTime = Date()

        if isPreviewMode {
            timer?.invalidate()
            timer = nil
            isPaused = true
            return
        }

        audioEngine?.pause()
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

        // Resume audio engine
        do {
            try audioEngine?.start()
            startTimer()
        } catch {
            print("Failed to resume audio engine: \(error)")
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

    private func applyAutoGain(to buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        var peak: Float = 0

        for channel in 0..<channelCount {
            let data = channelData[channel]
            for frame in 0..<frameLength {
                let value = abs(data[frame])
                if value > peak {
                    peak = value
                }
            }
        }

        guard peak > 0 else { return }

        let targetPeak: Float = 0.98
        let maxGain: Float = 8.0
        let gain = min(maxGain, targetPeak / peak)

        if gain <= 1.0 {
            return
        }

        for channel in 0..<channelCount {
            let data = channelData[channel]
            for frame in 0..<frameLength {
                var value = data[frame] * gain
                if value > 1.0 { value = 1.0 }
                if value < -1.0 { value = -1.0 }
                data[frame] = value
            }
        }
    }

    func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func isBluetoothOutputActive(_ session: AVAudioSession) -> Bool {
        session.currentRoute.outputs.contains { output in
            switch output.portType {
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Live Transcription

    @MainActor
    private func startLiveTranscription() {
        transcriptionService = TranscriptionService()

        Task {
            do {
                guard await transcriptionService?.requestAuthorization() == true else {
                        return
                }

                // Start the transcription service and get optimal format
                guard let optimalFormat = try await transcriptionService?.startStreamingTranscription(timeOffset: 0) else {
                    return
                }

                transcriptionService?.updateTimeOffset(currentRecordingOffset())

                // Now set up the converter with the correct format
                guard let inputNode = audioEngine?.inputNode else {
                    return
                }

                let inputFormat = inputNode.outputFormat(forBus: 0)
                guard let converter = AVAudioConverter(from: inputFormat, to: optimalFormat) else {
                    return
                }

                self.audioConverter = converter
                self.transcriptionFormat = optimalFormat

                // Observe current (partial) transcript updates
                currentTranscriptCancellable = transcriptionService?.$currentTranscript
                    .receive(on: DispatchQueue.main)
                    .assign(to: \.currentTranscript, on: self)

                // Observe finalized segments (committed conversation pieces)
                finalizedSegmentsCancellable = transcriptionService?.$finalizedSegments
                    .receive(on: DispatchQueue.main)
                    .assign(to: \.finalizedSegments, on: self)
            } catch {
            }
        }
    }

    private func currentRecordingOffset() -> TimeInterval {
        if let startTime = recordingStartTime {
            let raw = Date().timeIntervalSince(startTime) - pausedDuration
            return max(0, raw)
        }
        return max(0, elapsed)
    }

    @MainActor
    private func stopLiveTranscription() {
        // Stop the transcription service (will finalize the analyzer)
        transcriptionService?.stopTranscription()
        transcriptionService = nil

        // Cancel all observers
        currentTranscriptCancellable?.cancel()
        currentTranscriptCancellable = nil
        finalizedSegmentsCancellable?.cancel()
        finalizedSegmentsCancellable = nil
    }
}
