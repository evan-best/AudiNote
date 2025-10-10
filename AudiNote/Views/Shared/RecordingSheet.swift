//
//  RecordingSheet.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import SwiftUI
import SwiftData

struct SheetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct RecordingSheet: View {
    @ObservedObject var recorder: AudioRecorder
    let presentationDetent: PresentationDetent
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var manager: RecordingManager? = nil

    private var isLargeMode: Bool {
        presentationDetent == .large
    }

    init(recorder: AudioRecorder, presentationDetent: PresentationDetent = .fraction(0.25)) {
        self._recorder = ObservedObject(initialValue: recorder)
        self.presentationDetent = presentationDetent
    }

    var body: some View {
        VStack(spacing: 0) {
            // Waveform view - takes most of the space
            Group {
                if recorder.isRecording || recorder.isPaused {
                    Spacer()
                    LiveScrollWaveformView(
                        recorder: recorder,
                        isLargeMode: isLargeMode,
                        onCancel: {
                            dismiss()
                        },
                        onDone: { title, transcript in
                            saveRecording(title: title, transcript: transcript)
                        }
                    )
                }
            }
        }
        .onAppear {
            // Initialize unified recording manager on appearance
            if manager == nil {
                manager = RecordingManager(modelContext: modelContext, recorder: recorder)
            }
        }
    }

    private func saveRecording(title: String = "New Recording", transcript: String? = nil) {
        guard !isSaving, let manager else { return }
        isSaving = true

        Task { @MainActor in
            do {
                _ = try manager.saveRecording(title: title, transcript: transcript)
                dismiss()
            } catch {
                print("Save failed: \(error)")
            }
            isSaving = false
        }
    }
}

struct SheetPreviewContainer: View {
    @State private var showSheet = false
    @StateObject private var recorder = AudioRecorder()
    @Namespace private var animation
    @State private var detent: PresentationDetent = .fraction(0.25)

    var body: some View {
        Spacer()
        RecordButton(recorder: recorder, onRecordTapped: { showSheet = true })
            .matchedTransitionSource(id: "Record", in: animation)
            .sheet(isPresented: $showSheet) {
                RecordingSheet(recorder: recorder, presentationDetent: detent)
                    .navigationTransition(.zoom(sourceID: "Record", in: animation))
                    .presentationDetents([.fraction(0.25), .large], selection: $detent)
            }
    }
}

#Preview {
    SheetPreviewContainer()
		.environmentObject(SessionViewModel())
		.modelContainer(for: Recording.self)
}
