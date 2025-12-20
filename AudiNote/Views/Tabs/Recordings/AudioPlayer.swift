//
//  AudioPlayer.swift
//  AudiNote
//
//  Created by Assistant on 2025-08-23.
//

import Foundation
import AVFoundation
import Observation
import QuartzCore

@Observable
class AudioPlayer: NSObject {
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0

    private var playbackAnchorDeviceTime: TimeInterval?
    private var playbackAnchorMediaTime: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var displayLink: CADisplayLink?

    func load(url: URL) {
        stop()

        guard FileManager.default.fileExists(atPath: url.path) else {
            player = nil
            duration = 0
            currentTime = 0
            return
        }

        do {
            // Configure audio session for playback (allows audio even when silent switch is on)
            let audioSession = AVAudioSession.sharedInstance()
			try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP])
            try audioSession.setActive(true)

            if !isBluetoothOutputActive(audioSession) {
                try audioSession.overrideOutputAudioPort(.speaker)
            }

            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            currentTime = 0
        } catch {
            print("AudioPlayer load error: \(error.localizedDescription)")
            player = nil
            duration = 0
            currentTime = 0
        }
    }
    
    func play() {
        guard let player = player else { return }
        if !player.isPlaying {
            player.play()
            isPlaying = true
            playbackAnchorDeviceTime = player.deviceCurrentTime
            playbackAnchorMediaTime = player.currentTime
            startDisplayLink()
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        playbackAnchorDeviceTime = nil
        stopDisplayLink()
    }
    
    func stop() {
        player?.stop()
        isPlaying = false
        stopDisplayLink()
        currentTime = 0
        playbackAnchorDeviceTime = nil
        playbackAnchorMediaTime = 0
    }
    
    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
        playbackAnchorMediaTime = time
        playbackAnchorDeviceTime = player?.deviceCurrentTime
    }
    
    private func startDisplayLink() {
        stopDisplayLink()

        let link = CADisplayLink(target: self, selector: #selector(updateProgress))
        link.preferredFramesPerSecond = 30
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updateProgress() {
        guard let player = player else { return }

        if let anchor = playbackAnchorDeviceTime {
            let elapsed = player.deviceCurrentTime - anchor
            currentTime = max(0, playbackAnchorMediaTime + elapsed)
        } else {
            currentTime = player.currentTime
        }
        duration = player.duration

        if !player.isPlaying {
            isPlaying = false
            stopDisplayLink()
        }
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
    
    deinit {
        stopDisplayLink()
    }
}
