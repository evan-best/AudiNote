import SwiftUI

struct RecordingRow: View {
    let recording: Recording
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(recording.title.isEmpty ? "Untitled" : recording.title)
                .font(.headline)
            Text(recording.formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(recording.formattedDuration)
                .font(.caption2)
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.vertical, 6)
    }
}

struct RecordingRowPreview: View {
	@State private var selectedRecording: Recording?
	
	let sampleRecording = Recording(
		title: "Sample Meeting",
		timestamp: Date(),
		duration: 110,
		audioFilePath: "sample.m4a"
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
			.listRowSeparator(.hidden)
		}
		.listStyle(.plain)
		.listRowSeparator(.hidden)
		.listRowInsets(EdgeInsets())
		.fullScreenCover(item: $selectedRecording) { recording in
			RecordingDetailView(recording: recording)
		}
	}
}

#Preview {
	RecordingRowPreview()
}
