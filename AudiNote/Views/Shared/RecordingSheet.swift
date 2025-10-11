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
    let onSave: (Recording) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var manager: RecordingManager? = nil

    private var isLargeMode: Bool {
        presentationDetent == .large
    }

    init(recorder: AudioRecorder, presentationDetent: PresentationDetent = .fraction(0.25), onSave: @escaping (Recording) -> Void) {
        self._recorder = ObservedObject(initialValue: recorder)
        self.presentationDetent = presentationDetent
        self.onSave = onSave
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
                let recording = try manager.saveRecording(title: title, transcript: transcript)
                dismiss()
                onSave(recording)
            } catch {
                print("Save failed: \(error)")
            }
            isSaving = false
        }
    }
}

struct SheetPreviewContainer: View {
    @State private var showSheet = false
    @StateObject private var recorder = AudioRecorder(previewMode: true)
    @Namespace private var animation
    @State private var detent: PresentationDetent = .large

    var body: some View {
        VStack {
            Spacer()
            RecordButton(recorder: recorder, onRecordTapped: {
                showSheet = true
                recorder.startRecording()
            })
            .matchedTransitionSource(id: "Record", in: animation)
        }
        .sheet(isPresented: $showSheet) {
            RecordingSheet(recorder: recorder, presentationDetent: detent) { _ in
                showSheet = false
            }
            .navigationTransition(.zoom(sourceID: "Record", in: animation))
            .presentationDetents([.fraction(0.25), .large], selection: $detent)
        }
        .onAppear {
            // Auto-start recording in preview for immediate styling feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !showSheet {
                    showSheet = true
                    recorder.startRecording()
                }
            }
        }
    }
}

#Preview {
    SheetPreviewContainer()
		.environmentObject(SessionViewModel())
		.modelContainer(for: Recording.self)
}
