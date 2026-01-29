//
//  Tag.swift
//  AudiNote
//
//  Created by Evan Best on 2025-12-20.
//

import Foundation
import SwiftUI
import SwiftData

@Model
final class Tag: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#007AFF" // Default to system blue

    @Relationship(deleteRule: .nullify, inverse: \Recording.tags)
    var recordings: [Recording]? = []

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    init(name: String, colorHex: String = "#007AFF") {
        self.name = name
        self.colorHex = colorHex
    }
    
    func updateColor(from color: Color) {
        if let hex = color.toHexString() {
            colorHex = hex
        }
    }
}
