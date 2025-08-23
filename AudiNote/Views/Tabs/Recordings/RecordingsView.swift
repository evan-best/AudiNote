import SwiftUI
import SwiftData

struct RecordingsView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @Query(sort: \Recording.timestamp, order: .reverse) private var recordings: [Recording]
    @State private var selected: Recording?
    @State private var showSettings = false
    @State private var showDetailSheet = false
    @State private var selectedRecording: Recording?

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    recordingsList
                        .navigationTitle("Recordings")
                } detail: {
                    detailView
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
            } else {
                recordingsList
                    .navigationTitle("Recordings")
                    .sheet(isPresented: $showSettings) {
                        SettingsView()
                    }
                    .fullScreenCover(isPresented: $showDetailSheet) {
                        if let recording = selectedRecording {
                            RecordingDetailView(recording: recording)
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showDetailSheet) {
            if let recording = selectedRecording {
                RecordingDetailView(recording: recording)
            }
        }
    }

    private var recordingsList: some View {
        List {
            ForEach(recordings, id: \.id) { recording in
                Button {
                    selectedRecording = recording
                    showDetailSheet = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recording.title.isEmpty ? "Untitled" : recording.title)
                            .font(.headline)
                        Text(recording.timestamp, format: .dateTime.day().month().year().hour().minute())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .onDelete(perform: deleteItems)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItemGroup (placement: .topBarTrailing){
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                Button(action: addItem) {
                    Label("Add Recording", systemImage: "plus")
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
