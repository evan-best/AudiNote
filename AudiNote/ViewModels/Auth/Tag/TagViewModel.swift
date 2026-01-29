//
//  TagViewModel.swift
//  AudiNote
//
//  Created by Evan Best on 2025-12-20.
//

import Foundation
import SwiftUI
import SwiftData

@Observable
final class TagViewModel {
	var tags: [Tag]
	var newTag: String = ""
	private let recording: Recording
	private var modelContext: ModelContext?

	init(recording: Recording) {
		self.recording = recording
		self.tags = recording.tags ?? []
	}

	func configure(modelContext: ModelContext) {
		self.modelContext = modelContext
	}

	func addTag(color: Color = .blue) {
		let trimmed = newTag.trimmingCharacters(in: .whitespaces)
		guard !trimmed.isEmpty, !tags.contains(where: { $0.name == trimmed }) else { return }
		let colorHex = color.toHexString() ?? "#007AFF"
		let tag = Tag(name: trimmed, colorHex: colorHex)

		// Insert tag into model context
		modelContext?.insert(tag)

		tags.append(tag)
		if recording.tags == nil {
			recording.tags = []
		}
		recording.tags?.append(tag)

		// Save context
		try? modelContext?.save()

		newTag = ""
	}

	func removeTag(named tagName: String) {
		tags.removeAll { $0.name == tagName }
		recording.tags?.removeAll { $0.name == tagName }
	}
}

