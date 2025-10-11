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
    @EnvironmentObject private var session: SessionViewModel

    @Query(sort: \Recording.timestamp, order: .reverse) private var recordings: [Recording]
    @Binding var navigationPath: NavigationPath

    @State private var showSettings = false
    @State private var showSortSheet = false
    @State private var selectedSort: RecordingSortOption = .date
    @State private var ascending: Bool = false
    @State private var showDeleteAlert = false
    @State private var recordingsToDelete: [Recording] = []
    var body: some View {
        NavigationStack(path: $navigationPath) {
            recordingsList
                .navigationTitle("Recordings")
                .navigationBarTitleDisplayMode(.large)
				.navigationSubtitle("Record, transcribe, and share.")
                .navigationDestination(for: Recording.self) { recording in
                    RecordingDetailView(recording: recording)
                }
                .toolbar {
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

    private func confirmDelete(at offsets: IndexSet) {
        recordingsToDelete = offsets.map { displayRecordings[$0] }
        showDeleteAlert = true
    }
    
    private func deleteRecordings() {
        withAnimation {
            recordingsToDelete.forEach(modelContext.delete)
            do {
                try modelContext.save()
            } catch {
                print("Failed to delete: \(error)")
            }
            recordingsToDelete = []
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
    RecordingsView(navigationPath: .constant(NavigationPath()))
}
