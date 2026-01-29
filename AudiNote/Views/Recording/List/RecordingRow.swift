import SwiftUI
import SwiftData

struct RecordingRow: View {
    let recording: Recording
    
    @State private var tagViewModel: TagViewModel
    
    init(recording: Recording) {
        self.recording = recording
        self._tagViewModel = State(initialValue: TagViewModel(recording: recording))
    }
    
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
                if !tagViewModel.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(tagViewModel.tags.prefix(3)).enumerated(), id: \.element.id) { idx, tag in
                            let tagColor = Color(hex: tag.colorHex) ?? .blue
                            Text(tag.name)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(tagColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(tagColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        if tagViewModel.tags.count > 3 {
                            Text("+\(tagViewModel.tags.count - 3)")
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
    @Environment(\.modelContext) private var modelContext
    @State private var selectedRecording: Recording?
    @State private var sampleRecording: Recording?

    var body: some View {
        List {
            if let recording = sampleRecording {
                Button {
                    selectedRecording = recording
                } label: {
                    RecordingRow(recording: recording)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .listStyle(.plain)
        .listRowInsets(EdgeInsets())
        .fullScreenCover(item: $selectedRecording) { recording in
            RecordingDetailView(recording: recording)
        }
        .onAppear {
            if sampleRecording == nil {
                let recording = Recording(
                    title: "Sample Meeting",
                    timestamp: Date(),
                    duration: 110,
                    audioFilePath: "sample.m4a"
                )

                let tags = [
                    Tag(name: "Meeting", colorHex: "#3498db"),
                    Tag(name: "Work", colorHex: "#27ae60"),
                    Tag(name: "Important", colorHex: "#9b59b6"),
                    Tag(name: "Project", colorHex: "#e67e22")
                ]

                recording.tags = tags

                modelContext.insert(recording)
                tags.forEach { modelContext.insert($0) }

                sampleRecording = recording
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Recording.self, Tag.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return RecordingRowPreview()
        .modelContainer(container)
}

