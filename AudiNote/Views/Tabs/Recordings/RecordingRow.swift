import SwiftUI

struct RecordingRow: View {
    let recording: Recording
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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

#Preview {
    RecordingRow(
        recording: Recording(
            title: "Sample Meeting",
            timestamp: Date(),
            duration: 110,
            audioFilePath: "sample.m4a"
        )
    )
}
