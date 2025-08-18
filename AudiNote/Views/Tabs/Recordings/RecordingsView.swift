import SwiftUI
import SwiftData

struct RecordingsView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @Query(sort: \Recording.timestamp, order: .reverse) private var recordings: [Recording]
    @State private var selected: Recording?

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    recordingsList
                        .navigationTitle("Recordings")
                        .navigationSubtitle("Record, transcribe, and share.")
                } detail: {
                    detailView
                }
            } else {
                NavigationStack {
                    recordingsList
                        .navigationTitle("Recordings")
                        .navigationSubtitle("Record, transcribe, and share.")
                }
            }
        }
    }

    private var recordingsList: some View {
        List {
            ForEach(recordings, id: \.id) { recording in
                NavigationLink(destination: RecordingDetailView(recording: recording)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recording.title.isEmpty ? "Untitled" : recording.title)
                            .font(.headline)
                        Text(recording.timestamp, format: .dateTime.day().month().year().hour().minute())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItemGroup (placement: .topBarTrailing){
                Button(action: addItem) {
                    Label("Settings", systemImage: "gearshape")
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                Button(action: addItem) {
                    Label("Notifications", systemImage: "bell")
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
            }
        }
    }

    private var detailView: some View {
        Group {
            if let rec = selected ?? recordings.first {
                RecordingDetailView(recording: rec)
            } else {
                ContentPlaceholderView(text: "Select a recording")
            }
        }
        .navigationTitle("Details")
    }

    private func addItem() {
        withAnimation {
            let item = Recording(title: "New Recording",
                                 timestamp: Date(),
                                 duration: 0,
                                 audioFilePath: "")
            modelContext.insert(item)
            selected = item
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        withAnimation {
            offsets.map { recordings[$0] }.forEach(modelContext.delete)
        }
    }
}

private struct ContentPlaceholderView: View {
    let text: String
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            Text(text).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    MainTabView()
}
