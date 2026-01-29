//
//  WaveformRingBuffer.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-16.
//

import Foundation

struct WaveformRingBuffer {
    private var storage: [Float]
    private(set) var capacity: Int
    private var writeIndex: Int = 0

    init(capacity: Int) {
        self.capacity = max(8, capacity)
        self.storage = Array(repeating: 0, count: self.capacity)
    }

    mutating func resize(_ newCapacity: Int) {
        let newCap = max(8, newCapacity)
        if newCap == capacity { return }
        var newStore = Array(repeating: Float(0), count: newCap)

        // Keep as many of the newest samples as will fit
        let keep = min(capacity, newCap)
        let start = (writeIndex - keep + capacity) % capacity
        if start + keep <= capacity {
            newStore.replaceSubrange(0..<keep, with: storage[start..<start+keep])
        } else {
            let first = capacity - start
            newStore.replaceSubrange(0..<first, with: storage[start..<capacity])
            newStore.replaceSubrange(first..<keep, with: storage[0..<(keep - first)])
        }

        storage = newStore
        capacity = newCap
        writeIndex = keep % capacity
    }

    mutating func push(_ value: Float, repeat count: Int = 1) {
        guard capacity > 0, count > 0 else { return }
        for _ in 0..<count {
            storage[writeIndex] = value
            writeIndex = (writeIndex + 1) % capacity
        }
    }

    func snapshot(count: Int) -> [Float] {
        let c = min(capacity, max(0, count))
        guard c > 0 else { return [] }
        var out = Array(repeating: Float(0), count: c)
        let start = (writeIndex - c + capacity) % capacity

        if start + c <= capacity {
            out.replaceSubrange(0..<c, with: storage[start..<start+c])
        } else {
            let first = capacity - start
            out.replaceSubrange(0..<first, with: storage[start..<capacity])
            out.replaceSubrange(first..<c, with: storage[0..<(c-first)])
        }
        return out
    }
}
