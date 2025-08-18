# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AudiNote is an iOS audio recording and note-taking app built with Swift and SwiftUI. The app allows users to record audio, manage recordings, and potentially generate automatic transcriptions and notes.

## Build Commands

```bash
# Build the project in Xcode
open AudiNote.xcodeproj

# Build from command line (requires Xcode Command Line Tools)
xcodebuild -project AudiNote.xcodeproj -scheme AudiNote -configuration Debug build

# Build for release
xcodebuild -project AudiNote.xcodeproj -scheme AudiNote -configuration Release build

# Clean build folder
xcodebuild -project AudiNote.xcodeproj -scheme AudiNote clean
```

## Architecture

### Core Architecture Pattern
- **MVVM**: Model-View-ViewModel pattern using SwiftUI and ObservableObject
- **SwiftData**: Core Data replacement for persistent storage
- **Session-based Authentication**: Simple authentication flow with SessionViewModel

### Key Components

#### Models (`AudiNote/Models/`)
- **Recording.swift**: Core data model with SwiftData `@Model` decorator
  - Stores audio file metadata, timestamps, transcription state
  - Includes computed properties for UI formatting (duration, dates)

#### ViewModels (`AudiNote/ViewModels/`)
- **SessionViewModel.swift**: Manages authentication state
  - `@Published var isAuthenticated: Bool`
  - Simple sign-in/sign-out methods

#### Views (`AudiNote/Views/`)
- **AppRootView.swift**: Root navigation controller, switches between auth and main app
- **Auth/AuthView.swift**: Simple authentication screen
- **Tabs/MainTabView.swift**: Tab-based navigation with two tabs:
  - Recordings tab (waveform icon)
  - Capture tab (microphone icon)
- **Tabs/Recordings/**: Recording list and detail views
- **Tabs/CaptureView.swift**: Audio recording interface (currently placeholder)

### App Structure Flow
```
AudiNoteApp.swift
├── SessionViewModel (StateObject)
├── SwiftData ModelContainer for Recording
└── AppRootView
    ├── AuthView (if not authenticated)
    └── MainTabView (if authenticated)
        ├── RecordingsView (list/detail view)
        └── CaptureView (recording interface)
```

### SwiftData Integration
- Model container configured at app level for `Recording.self`
- Uses `@Query` for reactive data fetching in views
- Environment model context for CRUD operations

### UI Patterns
- **Adaptive UI**: Uses `horizontalSizeClass` for iPad/iPhone differences
- **NavigationSplitView**: For iPad landscape mode
- **NavigationStack**: For iPhone and iPad portrait
- **Tab Navigation**: Primary navigation pattern with two main tabs

## Development Notes

### Target Configuration
- **iOS Deployment Target**: iOS 26.0 (very recent, may need adjustment)
- **Swift Version**: 5.0
- **Team ID**: T5RS4V4R68
- **Bundle ID**: com.evan-best.AudiNote

### Key Frameworks
- SwiftUI for UI
- SwiftData for persistence
- Foundation for core functionality
- Combine for reactive programming (in ViewModels)

### File Organization
```
AudiNote/
├── Models/           # SwiftData models
├── ViewModels/       # ObservableObject classes
├── Views/           # SwiftUI views
│   ├── Auth/        # Authentication screens
│   ├── Tabs/        # Main tab content
│   └── Shared/      # Reusable components
└── Resources/       # Assets, Info.plist
```

### Background Modes
- Remote notifications enabled in Info.plist
- Likely planning for cloud sync or push notifications

## Common Patterns to Follow

### Model Creation
```swift
@Model
final class NewModel: Identifiable {
    var id = UUID()
    // properties
    
    init(...) {
        // initialization
    }
}
```

### ViewModel Pattern
```swift
final class NewViewModel: ObservableObject {
    @Published var property: Type = defaultValue
    
    func method() {
        // business logic
    }
}
```

### View Pattern
```swift
struct NewView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        // SwiftUI content
    }
}
```