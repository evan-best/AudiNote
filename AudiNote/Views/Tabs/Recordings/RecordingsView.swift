import SwiftUI
import SwiftData

enum RecordingSortOption: String, CaseIterable, Identifiable {
    case date = "Date"
    case length = "Length"
    var id: String { self.rawValue }
}

struct RecordingsView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @Query(sort: \Recording.timestamp, order: .reverse) private var recordings: [Recording]
    @State private var selected: Recording?
    @State private var showSettings = false
    @State private var showDetailSheet = false
    @State private var selectedRecording: Recording?
    @State private var showSortSheet = false
    
    @State private var selectedSort: RecordingSortOption = .date
    @State private var ascending: Bool = false
    
    @Namespace private var animation
    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    recordingsList
                        .navigationTitle("Recordings")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showSortSheet = true
                                } label: {
                                    Label("Sort By", systemImage: "line.3.horizontal.decrease")
                                }
                            }
                        }
                } detail: {
                    detailView
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                        .navigationTransition(.zoom(sourceID: "Settings", in: animation))
                }
            } else {
                recordingsList
                    .navigationTitle("Recordings")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showSortSheet = true
                            } label: {
                                Label("Sort By", systemImage: "line.3.horizontal.decrease")
                            }
                        }
                    }
                    .sheet(isPresented: $showSettings) {
                        SettingsView()
                            .presentationDetents([.fraction(0.9)])
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
        .sheet(isPresented: $showSortSheet) {
            SortSheetView(selectedSort: selectedSort,
                          ascending: ascending,
                          onDismiss: { didChange, sort, asc in
                if didChange {
                    selectedSort = sort
                    ascending = asc
                }
                showSortSheet = false
            })
        }
    }

    private var sortedRecordings: [Recording] {
        switch selectedSort {
        case .date:
            return ascending
                ? recordings.sorted { $0.timestamp < $1.timestamp }
                : recordings.sorted { $0.timestamp > $1.timestamp }
        case .length:
            return ascending
                ? recordings.sorted { $0.duration < $1.duration }
                : recordings.sorted { $0.duration > $1.duration }
        }
    }

    private var recordingsList: some View {
        List {
            ForEach(sortedRecordings, id: \.id) { recording in
                Button {
                    selectedRecording = recording
                    showDetailSheet = true
                } label: {
                    RecordingRowView(recording: recording)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .onDelete(perform: deleteItems)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem (placement: .topBarTrailing){
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
            }
            .matchedTransitionSource(id: "Settings", in: animation)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .navigationTransition(.zoom(sourceID: "Settings", in: animation))
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
    
    private func debugRecordings() {
        print("RecordingsView: Debug - Total recordings: \(recordings.count)")
        for recording in recordings {
            print("  - ID: \(recording.id), Title: \(recording.title), Duration: \(recording.duration), Path: \(recording.audioFilePath)")
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

private struct RecordingRowView: View {
    let recording: Recording
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.title.isEmpty ? "Untitled" : recording.title)
                .font(.headline)
            Text(recording.timestamp, format: .dateTime.day().month().year().hour().minute())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SortSheetView: View {
    @Environment(\.colorScheme) private var colorScheme

    let selectedSort: RecordingSortOption
    let ascending: Bool
    let onDismiss: (_ didChange: Bool, _ selectedSort: RecordingSortOption, _ ascending: Bool) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var localSort: RecordingSortOption
    @State private var localAscending: Bool
     
    init(selectedSort: RecordingSortOption, ascending: Bool, onDismiss: @escaping (_ didChange: Bool, _ selectedSort: RecordingSortOption, _ ascending: Bool) -> Void) {
        self.selectedSort = selectedSort
        self.ascending = ascending
        self.onDismiss = onDismiss
        _localSort = State(initialValue: selectedSort)
        _localAscending = State(initialValue: ascending)
    }
    
    var body: some View {
        VStack(spacing: 18) {
            // Grabber
            RoundedRectangle(cornerRadius: 3)
                .frame(width: 40, height: 5)
                .foregroundColor(Color.secondary.opacity(0.4))
                .padding(.top, 8)
            
            // Title pill with icon and text
            HStack(spacing: 8) {
                Text("Sort By")
                    .font(.system(size: 18, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            
            VStack(spacing: 16) {
                sortRow(title: "Newest", sort: .date, ascending: false)
                sortRow(title: "Oldest", sort: .date, ascending: true)
                sortRow(title: "Longest", sort: .length, ascending: false)
                sortRow(title: "Shortest", sort: .length, ascending: true)
            }
            .padding(.horizontal, 32)
            .padding(.top, 14)
            Spacer()
            
            Button {
                onDismiss(true, localSort, localAscending)
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(colorScheme == .dark ? Color.white : Color.black)
                    .foregroundColor(colorScheme == .dark ? Color.black : Color.black)
                    .fontWeight(.semibold)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
        }
        .presentationDetents([.fraction(0.45)])
    }
    
    @ViewBuilder
    private func sortRow(title: String, sort: RecordingSortOption, ascending: Bool) -> some View {
        Button {
            localSort = sort
            self.localAscending = ascending
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .fontWeight(localSort == sort && localAscending == ascending ? .semibold : .regular)
                Spacer()
                ZStack {
                    Circle()
						.stroke(Color(.systemGray4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if localSort == sort && localAscending == ascending {
                        Circle()
                            .fill(Color.accent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .contentShape(Rectangle())
        }
    }
}

#Preview {
    MainTabView()
}
