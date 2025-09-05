import SwiftUI
import SwiftData
import Combine
internal import CoreData

enum RecordingSortOption: String, CaseIterable, Identifiable {
    case date = "Date"
    case length = "Length"
    var id: String { self.rawValue }
}

struct RecordingsView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var session: SessionViewModel
    
    @State private var recordings: [Recording] = []
    @State private var selected: Recording?
    @State private var showSettings = false
    @State private var selectedRecording: Recording?
    @State private var showSortSheet = false
    
    @State private var selectedSort: RecordingSortOption = .date
    @State private var ascending: Bool = false
    @State private var showDeleteAlert = false
    @State private var recordingsToDelete: [Recording] = []
    
    @Namespace private var animation
    var body: some View {
        NavigationStack {
            recordingsList
                .navigationTitle("Recordings")
                .navigationBarTitleDisplayMode(.large)
				.navigationSubtitle("Record, transcribe, and share.")
                .navigationDestination(for: Recording.self) { recording in
                    RecordingDetailView(recording: recording)
                }
                .toolbar {
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
            .sheet(isPresented: $showSortSheet) {
                SortSheetView(
                    selectedSort: $selectedSort,
                    ascending: $ascending
                )
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
                .onAppear {
                    print("RecordingsView onAppear. modelContext: \(String(describing: modelContext))")
                    fetchRecordings()
                    debugRecordings()
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
                    print("Core Data context did save notification received - fetching recordings")
                    fetchRecordings()
                    debugRecordings()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RecordingSaved"))) { _ in
                    print("Recording saved notification received - refreshing list")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        fetchRecordings()
                        debugRecordings()
                    }
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
    
    private var displayRecordings: [Recording] {
        return sortedRecordings
    }
    

    private var recordingsList: some View {
        List {
            if displayRecordings.isEmpty {
                Text("No recordings yet")
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
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16))
                    .listRowSeparator(.visible)
                }
                .onDelete(perform: confirmDelete)
            }
        }
		.listRowSpacing(4.0)
        .listStyle(.plain)
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

    private func addItem() {
        withAnimation(.easeInOut(duration: 0.3)) {
            let item = Recording(title: "New Recording",
                                 timestamp: Date(),
                                 duration: 0,
                                 audioFilePath: "")
            modelContext.insert(item)
            do {
                try modelContext.save()
            } catch {
                print("Failed saving after addItem(): \(error)")
            }
            selected = item
        }
    }

    private func confirmDelete(at offsets: IndexSet) {
        recordingsToDelete = offsets.map { displayRecordings[$0] }
        showDeleteAlert = true
    }
    
    private func deleteRecordings() {
        withAnimation {
            recordingsToDelete.forEach(modelContext.delete)
            do {
                try modelContext.save()
                print("Successfully deleted \(recordingsToDelete.count) recording(s)")
            } catch {
                print("Failed saving after delete: \(error)")
            }
            recordingsToDelete = []
        }
    }
    
    private func fetchRecordings() {
        do {
            let fetchDescriptor = FetchDescriptor<Recording>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
            let fetchedRecordings = try modelContext.fetch(fetchDescriptor)
            print("Fetched \(fetchedRecordings.count) recordings from database")
            recordings = fetchedRecordings
        } catch {
            print("Failed to fetch recordings: \(error)")
        }
    }
    
    private func debugRecordings() {
        print("RecordingsView: Debug - Total recordings in state: \(recordings.count)")
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

private struct SortSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionViewModel
    
    @Binding var selectedSort: RecordingSortOption
    @Binding var ascending: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .frame(width: 40, height: 5)
                .foregroundColor(Color.secondary.opacity(0.4))
                .padding(.top, 8)
            
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
            Spacer()
            
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
        }
        .presentationDetents([.fraction(0.4)])
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
	RecordingsView()
}
