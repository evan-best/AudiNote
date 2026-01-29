import SwiftUI
import SwiftData

enum RecordingSortOption: String, CaseIterable, Identifiable {
    case date = "Date"
    case length = "Length"
    var id: String { self.rawValue }
}

struct RecordingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var session: SessionViewModel

    @Query(sort: \Recording.timestamp, order: .reverse) private var recordings: [Recording]
    @Binding var navigationPath: NavigationPath
    private let recordButton: AnyView?

    @State private var showSettings = false
    @State private var showSortSheet = false
    @State private var selectedSort: RecordingSortOption = .date
    @State private var ascending: Bool = false
    @State private var showDeleteAlert = false
    @State private var recordingsToDelete: [Recording] = []
    @State private var selectedRecordingID: PersistentIdentifier?
    @State private var searchText: String = ""
    @State private var didBackfillAudioData = false
    init(navigationPath: Binding<NavigationPath>, recordButton: AnyView? = nil) {
        self._navigationPath = navigationPath
        self.recordButton = recordButton
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                splitView
            } else {
                compactView
            }
        }
        .onChange(of: displayRecordings) { _, newValue in
            if let selectedRecordingID,
               !newValue.contains(where: { $0.persistentModelID == selectedRecordingID }) {
                self.selectedRecordingID = nil
            }
        }
        .sheet(isPresented: $showSortSheet) {
            SortSheetView(
                selectedSort: $selectedSort,
                ascending: $ascending
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .task {
            await backfillAudioDataIfNeeded()
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

    private var splitView: some View {
        NavigationSplitView {
            NavigationStack {
                recordingsListSplit
                    .navigationTitle("Recordings")
                    .navigationBarTitleDisplayMode(.large)
                    .navigationSubtitle("Record, transcribe, and share.")
                    .toolbar {
                        recordingsToolbar
                    }
            }
        } detail: {
            NavigationStack {
                detailContent
                    .id(selectedRecordingID)
            }
        }
    }

    private var compactView: some View {
        NavigationStack(path: $navigationPath) {
            recordingsList
                .navigationTitle("Recordings")
                .navigationBarTitleDisplayMode(.large)
                .navigationSubtitle("Record, transcribe, and share.")
                .navigationDestination(for: Recording.self) { recording in
                    RecordingDetailView(recording: recording)
                }
                .toolbar {
                    recordingsToolbar
                }
        }
    }
    
    private var displayRecordings: [Recording] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return sortedRecordings
        }

        let lowercased = query.lowercased()
        return sortedRecordings.filter { recording in
            if recording.title.lowercased().contains(lowercased) {
                return true
            }
            if recording.displayTranscript?.lowercased().contains(lowercased) == true {
                return true
            }
            if recording.notes?.lowercased().contains(lowercased) == true {
                return true
            }
			return recording.tags?.contains { $0.name.lowercased().contains(lowercased) } ?? false
        }
    }
    

    private var recordingsList: some View {
        List {
            if displayRecordings.isEmpty {
                Text(searchText.isEmpty ? "No recordings yet" : "No results")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            } else {
                ForEach(displayRecordings) { recording in
                    NavigationLink(value: recording) {
                        RecordingRow(recording: recording)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 12)
                            .contentShape(Rectangle())
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                }
                .onDelete(perform: confirmDelete)
            }
        }
        .listRowSpacing(4.0)
        .listStyle(.plain)
        .listRowSeparator(.hidden)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .alert("Delete Recording", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteRecordings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(recordingsToDelete.count == 1 ? 
                 "Are you sure you want to delete this recording? This action cannot be undone." :
                 "Are you sure you want to delete these \(recordingsToDelete.count) recordings? This action cannot be undone.")
        }
    }

    private var recordingsListSplit: some View {
        List(selection: $selectedRecordingID) {
            if displayRecordings.isEmpty {
                Text(searchText.isEmpty ? "No recordings yet" : "No results")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            } else {
                ForEach(displayRecordings) { recording in
                    RecordingRow(recording: recording)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRecordingID = recording.persistentModelID
                        }
                        .tag(recording.persistentModelID)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)
                }
                .onDelete(perform: confirmDelete)
            }
        }
        .listRowSpacing(4.0)
        .listStyle(.plain)
        .listRowSeparator(.hidden)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .tint(.primary)
        .safeAreaInset(edge: .bottom) {
            if let recordButton {
                recordButton
            }
        }
        .alert("Delete Recording", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteRecordings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(recordingsToDelete.count == 1 ?
                 "Are you sure you want to delete this recording? This action cannot be undone." :
                 "Are you sure you want to delete these \(recordingsToDelete.count) recordings? This action cannot be undone.")
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let selectedRecordingID,
           let selectedRecording = recordings.first(where: { $0.persistentModelID == selectedRecordingID }) {
            RecordingDetailView(recording: selectedRecording)
        } else {
            Text("No recording selected")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var recordingsToolbar: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    session.triggerHaptic(style: .light)
                    showSortSheet = true
                } label: {
                    Label("Sort By", systemImage: "line.3.horizontal.decrease")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    session.triggerHaptic(style: .light)
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
                    .onTapGesture {
                        session.triggerHaptic(style: .light)
                    }
            }
        }
    }

    private func confirmDelete(at offsets: IndexSet) {
        recordingsToDelete = offsets.map { displayRecordings[$0] }
        showDeleteAlert = true
    }
    
    private func deleteRecordings() {
        let count = recordingsToDelete.count
        withAnimation {
            recordingsToDelete.forEach(modelContext.delete)
            do {
                try modelContext.save()
                // Show deletion toast
                ToastManager.shared.show(
                    type: .delete,
                    message: count == 1 ? "Recording deleted" : "\(count) recordings deleted"
                )
            } catch {
                print("Failed to delete: \(error)")
                // Show error toast
                ToastManager.shared.show(type: .error, message: "Failed to delete recording")
            }
            recordingsToDelete = []
        }
    }

    @MainActor
    private func backfillAudioDataIfNeeded() async {
        guard !didBackfillAudioData else { return }
        didBackfillAudioData = true

        var didUpdate = false
        for recording in recordings where recording.audioData == nil {
            guard let url = recording.audioFileURL,
                  FileManager.default.fileExists(atPath: url.path) else {
                continue
            }
            if let data = try? Data(contentsOf: url) {
                recording.audioData = data
                didUpdate = true
            }
        }

        if didUpdate {
            try? modelContext.save()
        }
    }
}

private struct SortSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionViewModel
    
    @Binding var selectedSort: RecordingSortOption
    @Binding var ascending: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("Sort By")
                    .font(.system(size: 18, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

            VStack(spacing: 16) {
                sortRow(title: "Newest", sort: .date, isAscending: false)
                sortRow(title: "Oldest", sort: .date, isAscending: true)
                sortRow(title: "Longest", sort: .length, isAscending: false)
                sortRow(title: "Shortest", sort: .length, isAscending: true)
            }
            .padding(.horizontal, 32)

            Button {
                session.triggerHaptic(style: .light)
                dismiss()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(colorScheme == .dark ? Color.white : Color.black)
                    .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                    .fontWeight(.semibold)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, alignment: .center)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }
    
    @ViewBuilder
    private func sortRow(title: String, sort: RecordingSortOption, isAscending: Bool) -> some View {
        Button {
            session.triggerHaptic(style: .light)
            
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedSort = sort
                ascending = isAscending
            }
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .fontWeight(selectedSort == sort && ascending == isAscending ? .semibold : .regular)
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if selectedSort == sort && ascending == isAscending {
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
    let container = try! ModelContainer(
        for: Recording.self, Tag.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return RecordingsView(navigationPath: .constant(NavigationPath()))
        .environmentObject(SessionViewModel())
        .modelContainer(container)
}
