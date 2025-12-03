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
            // .spokenAudio mode optimizes for speech and provides better echo cancellation
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth, .duckOthers])

            // Set preferred input to built-in mic (bottom mic for better speech capture)
            if let availableInputs = session.availableInputs,
               let builtInMic = availableInputs.first(where: { $0.portType == .builtInMic }) {
                try session.setPreferredInput(builtInMic)
            }

            // Optimize for speech - 16kHz is optimal for voice
            try session.setPreferredSampleRate(16000)
            try session.setPreferredIOBufferDuration(0.005) // 5ms for low latency

            try session.setActive(true)

            print("✅ Audio session configured: mode=\(session.mode.rawValue), category=\(session.category.rawValue)")
            print("✅ Current input: \(session.currentRoute.inputs.first?.portName ?? "unknown")")
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
            return
        }

        // Prepare file URL
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "recording_\(timestamp).m4a"
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
        self.lastRecordingURL = fileURL

        // Create audio engine
        let engine = AVAudioEngine()
        self.audioEngine = engine

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create audio file for recording
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100,
            channels: 1,
            interleaved: false
        )!

        do {
            audioFile = try AVAudioFile(
                forWriting: fileURL,
                settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderBitRateKey: 192000
                ]
            )
        } catch {
            print("Failed to create audio file: \(error)")
            return
        }

        // Install tap for recording AND transcription
        // Note: converter and transcriptionFormat will be set after transcription starts
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            guard let self = self, let file = self.audioFile else { return }

            // Write to file
            do {
                try file.write(from: buffer)
            } catch {
                print("Failed to write buffer: \(error)")
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
            var sum: Float = 0
            if let data = channelData {
                for i in 0..<channelDataCount {
                    sum += abs(data[i])
                }
            }
            let avgPower = sum / Float(channelDataCount)
            let amplitude = CGFloat(avgPower)

            DispatchQueue.main.async {
                self.amplitudes.append(amplitude)
            }
        }

        // Start engine
        do {
            try engine.start()
            print("✅ Recording to: \(fileURL.path)")
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

        // Stop audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        audioFile = nil

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

    func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Live Transcription

    @MainActor
    private func startLiveTranscription() {
        transcriptionService = TranscriptionService()

        Task {
            do {
                guard await transcriptionService?.requestAuthorization() == true else {
                    print("Speech recognition not authorized")
                    return
                }

                // Start the transcription service and get optimal format
                guard let optimalFormat = try await transcriptionService?.startStreamingTranscription() else {
                    print("❌ Failed to get optimal audio format")
                    return
                }

                // Now set up the converter with the correct format
                guard let inputNode = audioEngine?.inputNode else {
                    print("❌ No input node available")
                    return
                }

                let inputFormat = inputNode.outputFormat(forBus: 0)
                guard let converter = AVAudioConverter(from: inputFormat, to: optimalFormat) else {
                    print("❌ Failed to create audio converter from \(inputFormat.sampleRate)Hz to \(optimalFormat.sampleRate)Hz")
                    return
                }

                self.audioConverter = converter
                self.transcriptionFormat = optimalFormat

                print("✅ Live transcription started with SpeechAnalyzer")
                print("✅ Audio converter ready: \(inputFormat.sampleRate)Hz → \(optimalFormat.sampleRate)Hz")

                // Observe current (partial) transcript updates
                currentTranscriptCancellable = transcriptionService?.$currentTranscript
                    .receive(on: DispatchQueue.main)
                    .assign(to: \.currentTranscript, on: self)

                // Observe finalized segments (committed conversation pieces)
                finalizedSegmentsCancellable = transcriptionService?.$finalizedSegments
                    .receive(on: DispatchQueue.main)
                    .assign(to: \.finalizedSegments, on: self)
            } catch {
                print("Failed to start live transcription: \(error)")
            }
        }
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

