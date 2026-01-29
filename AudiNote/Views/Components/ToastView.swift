//
//  ToastView.swift
//  AudiNote
//
//  Toast notification component with customizable appearance
//

import SwiftUI

// Toast types with predefined styles
enum ToastType {
    case success
    case error
    case warning
    case info
    case delete

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .delete: return .red
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark"
        case .error: return "xmark"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        case .delete: return "trash"
        }
    }
}

// Toast data model
struct Toast: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let message: String
    let duration: TimeInterval

    init(type: ToastType, message: String, duration: TimeInterval = 3.0) {
        self.type = type
        self.message = message
        self.duration = duration
    }
}

// Toast view component
struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        if colorScheme == .light {
            switch toast.type {
            case .success:
                return Color(red: 0.85, green: 0.985, blue: 0.85) // 15% green + 85% white
            case .error, .delete:
                return Color(red: 0.985, green: 0.85, blue: 0.85) // 15% red + 85% white
            case .warning:
                return Color(red: 0.985, green: 0.9275, blue: 0.85) // 15% orange + 85% white
            case .info:
                return Color(red: 0.85, green: 0.85, blue: 0.985) // 15% blue + 85% white
            }
        } else {
            switch toast.type {
            case .success:
                return Color(red: 0, green: 0.18, blue: 0) // 18% green on black
            case .error, .delete:
                return Color(red: 0.18, green: 0, blue: 0) // 18% red on black
            case .warning:
                return Color(red: 0.18, green: 0.09, blue: 0) // 18% orange on black
            case .info:
                return Color(red: 0, green: 0, blue: 0.18) // 18% blue on black
            }
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: toast.type.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(toast.type.color)

            Text(toast.message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(toast.type.color)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(backgroundColor)
        )
        .frame(maxWidth: 300)
    }
}

// Toast manager - handles showing/hiding toasts
@MainActor
@Observable
class ToastManager {
    static let shared = ToastManager()

    var currentToast: Toast?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ toast: Toast) {
        // Cancel any existing dismiss task
        dismissTask?.cancel()

        // Set the new toast
        currentToast = toast

        // Auto-dismiss after duration
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            if !Task.isCancelled {
                dismiss()
            }
        }
    }

    func show(type: ToastType, message: String, duration: TimeInterval = 3.0) {
        show(Toast(type: type, message: message, duration: duration))
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentToast = nil
        }
    }
}

// Toast container modifier
struct ToastModifier: ViewModifier {
    @State var toastManager: ToastManager

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                content

                if let toast = toastManager.currentToast {
                    ToastView(toast: toast) {
                        toastManager.dismiss()
                    }
                    .padding(.bottom, 34 + geometry.safeAreaInsets.bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                    .allowsHitTesting(true)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toastManager.currentToast)
    }
}

// View extension for easy usage
extension View {
    func toast(manager: ToastManager = .shared) -> some View {
        self.modifier(ToastModifier(toastManager: manager))
    }
}

// MARK: - Previews

#Preview("Success Toast") {
    VStack {
        Button("Show Success") {
            ToastManager.shared.show(type: .success, message: "Recording saved")
        }
        .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .toast()
}

#Preview("Error Toast") {
    VStack {
        Button("Show Error") {
            ToastManager.shared.show(type: .error, message: "Failed to save recording. Please try again.")
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .toast()
}

#Preview("Warning Toast") {
    VStack {
        Button("Show Warning") {
            ToastManager.shared.show(type: .warning, message: "Storage space is running low")
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .toast()
}

#Preview("Info Toast") {
    VStack {
        Button("Show Info") {
            ToastManager.shared.show(type: .info, message: "Transcription is processing in the background")
        }
        .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .toast()
}

#Preview("All Toasts") {
    VStack(spacing: 20) {
        Button("Success") {
            ToastManager.shared.show(type: .success, message: "Recording Saved")
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)

        Button("Error") {
            ToastManager.shared.show(type: .error, message: "Something went wrong")
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)

        Button("Warning") {
            ToastManager.shared.show(type: .warning, message: "Low storage space")
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)

        Button("Info") {
            ToastManager.shared.show(type: .info, message: "Processing...")
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .toast()
}
