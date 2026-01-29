//
//  DisplayLinkDriver.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-16.
//

import QuartzCore
import UIKit

final class DisplayLinkDriver {
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var handler: ((Double) -> Void)?

    /// Detect SwiftUI/Xcode Previews to avoid API paths that can throw in injection.
    private var isRunningInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// Runtime check because certain Simulator/Previews builds expose availability
    /// in headers but the selector isn't backed at runtime, causing an Obj-C exception.
    private func canUsePreferredFrameRateRange(on dl: CADisplayLink) -> Bool {
        if isRunningInPreviews { return false } // keep Previews simple = safe
        guard #available(iOS 15.0, *) else { return false }
        return dl.responds(to: Selector(("setPreferredFrameRateRange:")))
    }

    func start(_ onTick: @escaping (Double) -> Void) {
        stop()
        handler = onTick

        let dl = CADisplayLink(target: self, selector: #selector(tick(_:)))

        // Determine target FPS:
        // - Use device max when possible
        // - Cap to 60 in Previews to avoid instability and excess work
        let maxFPS = UIScreen.main.maximumFramesPerSecond
        let targetFPS = isRunningInPreviews ? min(60, maxFPS) : maxFPS

        if canUsePreferredFrameRateRange(on: dl) {
            if #available(iOS 15.0, *) {
                // Runtime-safe path
                dl.preferredFrameRateRange = CAFrameRateRange(
                    minimum: Float(Float64(min(60, targetFPS))),   // >60 smoothness on ProMotion
                    maximum: Float(Float64(targetFPS)),
                    preferred: Float(Float64(targetFPS))
                )
            }
        } else {
            // Legacy / safe fallback (works in Previews & older simulators)
            dl.preferredFramesPerSecond = targetFPS
        }

        // Use .common so it keeps ticking during UI interactions/scroll, etc.
        dl.add(to: .main, forMode: .common)
        link = dl
    }

    func stop() {
        link?.invalidate()
        link = nil
        lastTimestamp = nil
        handler = nil
    }

    @objc private func tick(_ dl: CADisplayLink) {
        let ts = dl.timestamp
        defer { lastTimestamp = ts }

        guard let last = lastTimestamp else {
            // First tick: provide a reasonable dt
            let fps = max(30, UIScreen.main.maximumFramesPerSecond)
            handler?(1.0 / Double(fps))
            return
        }

        handler?(ts - last)
    }

    deinit { stop() }
}
