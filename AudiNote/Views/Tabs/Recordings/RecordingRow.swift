import SwiftUI

extension String {
    func tagColor() -> (foreground: Color, background: Color) {
        let colors: [(Color, Color)] = [
            (.blue, .blue),
            (.green, .green),
            (.purple, .purple),
            (.orange, .orange),
            (.pink, .pink),
            (.red, .red),
            (.teal, .teal),
            (.indigo, .indigo),
            (.accentColor, .accentColor)
        ]
        
        let hash = abs(self.hashValue)
        let colorPair = colors[hash % colors.count]
        return (foreground: colorPair.0, background: colorPair.1)
    }
}

struct RecordingRow: View {
    let recording: Recording
    
    var body: some View {
		HStack {
            
            VStack(alignment: .leading, spacing: 2) {
                Text(recording.title.isEmpty ? "Untitled" : recording.title)
                    .font(.headline)
                    .lineLimit(1)
				
                Text(recording.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                // Tags
                if !recording.displayTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(recording.displayTags, id: \.self) { tag in
                            let colors = tag.tagColor()
                            Text(tag)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(colors.foreground == .accentColor ? .primary : colors.foreground)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(colors.background.opacity(colors.background == .accentColor ? 0.15 : 0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        
                        if recording.tags.count > 2 {
                            Text("+\(recording.tags.count - 2)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
					.padding(.top, 2)
                }
            }
            
            Spacer()
            
            VStack {
                Spacer()
                Text(recording.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        }
    }
}

struct RecordingRowPreview: View {
	@State private var selectedRecording: Recording?
	
	let sampleRecording = Recording(
		title: "Sample Meeting",
		timestamp: Date(),
		duration: 110,
		audioFilePath: "sample.m4a",
		tags: ["Meeting", "Work", "Important"]
	)
	
	var body: some View {
		List {
			Button {
				selectedRecording = sampleRecording
			} label: {
				RecordingRow(recording: sampleRecording)
					.frame(maxWidth: .infinity, alignment: .leading)
					.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
		}
		.padding(10)
		.listStyle(.plain)
		.listRowInsets(EdgeInsets())
		.fullScreenCover(item: $selectedRecording) { recording in
			RecordingDetailView(recording: recording)
		}
	}
}

#Preview {
	RecordingRowPreview()
}
