# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Image Voice Memos** is a native macOS SwiftUI application for browsing photos from a user-selected folder and recording/transcribing voice memos for each photo (1:1 mapping).

- **Target**: macOS 15.0+ on Apple Silicon (M1 or later)
- **Architecture**: arm64 only (no Intel/x86_64 support)
- **Version**: 0.1.0
- **Build System**: Xcode (generated via xcodegen)
- **Bundle ID**: `com.adrian-altner.imagevoicememos`
- **Image Formats Supported**: JPEG, PNG, TIFF, HEIC, HEIF, WebP, BMP, GIF, and RAW (NEF, RAF, ORF, DNG, CR2, CR3, ARW, RW2)
- **On-Device AI**: Speech Recognition and Translation run entirely on-device via Apple Silicon Neural Engine — no cloud APIs

## Architecture

### MVVM Pattern with SwiftUI

The app follows MVVM with `@MainActor` ViewModels and `@EnvironmentObject` injection:

- **LibraryViewModel**: Manages photo grid, folder selection, sorting, and thumbnail loading
- **VoiceMemoViewModel**: Manages recording state, playback, transcription, and translation for selected photo
- Views observe published properties and update reactively

### Key Services (Actors & Services)

#### ImageLoadingService (Actor)
- **Purpose**: Load thumbnails and full-resolution images for RAW and standard formats
- **RAW Handling**: Uses `CGImageSource` with `kCGImageSourceCreateThumbnailFromImageIfAbsent` to extract embedded JPEG previews without decoding full RAW
- **Caching**: NSCache for thumbnails to avoid reloading

#### AudioRecordingService (@MainActor)
- **Recording Pipeline**: PCM (44100 Hz, 16-bit, mono) → AVAssetExportSession → AAC/M4A
- **Hardware Warmup**: `prepareToRecord()` call required before `record()` to initialize audio hardware
- **Key Method**: `startPreparedRecording()` for instant start after warmup countdown

#### AudioPlaybackService (@MainActor)
- **Delegates**: Handles playback completion via `onFinished` callback
- **Methods**: `prepare()`, `playPrepared()`, `play()`, `pause()`, `resume()`, `stop()`
- **Duration Tracking**: `duration` and `currentTime` properties for progress UI

#### TranscriptionService
- **Backend**: Apple's native `Speech` Framework (SFSpeechRecognizer)
- **Language**: German (`de-DE`) and English (`en-US`) — selectable via `TranscriptionLanguage` enum in `LibraryViewModel`
- **Processing**: Fully on-device via Apple Silicon Neural Engine (`requiresOnDeviceRecognition = true`), no cloud APIs
- **Timeout**: 60-second timeout via `DispatchWorkItem` to prevent hanging
- **Output**: Returns transcribed text as String; `saveTranscription()` writes .txt sidecar file
- **Orphaned .txt**: `loadState()` loads transcription independently of `.m4a` existence — orphaned `.txt` files are shown even without a voice memo

#### VoiceMemoStorageService (Static)
- **Directory**: `.voicememos/` subdirectory in user-selected folder (hidden)
- **File Naming**: Photo stem (e.g., `photo.m4a`, `photo.txt`)
- **Methods**: `voiceMemoURL()`, `exists()`, `delete()`, `duration()` using `AVURLAsset`

#### TranslationService
- **Backend**: Apple's native `Translation` Framework (TranslationSession)
- **Direction**: German (`de`) → English (`en`)
- **Processing**: Fully on-device, no external APIs
- **Output**: Returns translated text as String; saved as `.en.txt` sidecar file
- **Toggle**: User enables via "EN" checkbox in VoiceMemoControlsView when German is selected

#### FolderAccessService
- **Security-Scoped Bookmarks**: Persists folder access in UserDefaults under key `"folderBookmark"`
- **Sandbox Access**: Enables read/write to user-selected folders while maintaining sandbox integrity
- **Lifecycle**: `restoreFolder()` called on app launch to restore previous folder selection

### State Machine: VoiceMemoState

```swift
enum VoiceMemoState {
    case noNote
    case noteExists(duration: TimeInterval)
    case countingDown(secondsRemaining: Int)  // 1-second warmup
    case recording(level: Float)
    case converting
    case playing(progress: Double)
    case paused
}
```

The 1-second countdown before recording ensures audio hardware is ready; user sees "● Live" animated indicator.

### Recording Workflow

1. User clicks "Record" → `startRecording(for:)`
2. Permission check (request if needed)
3. Show 1-second countdown with "● Live" indicator → `showCountdown()`
4. Call `prepareToRecord()` + `startPreparedRecording()` for clean audio capture
5. User speaks while "● Live" + WaveformView + timer display
6. User clicks "Stop" → `stopRecording()`
7. Convert PCM to AAC (`convertToAAC()` via AVAssetExportSession)
8. Start transcription in background (`transcriptionService.transcribe()`)
9. During transcription: Hide controls, show ProgressView + "Processing..."
10. Save transcript as .txt sidecar when complete
11. If translation enabled: translate DE → EN via TranslationService, save as `.en.txt`

### Transcription Workflow

- Triggered automatically after recording conversion completes
- `isTranscribing: Bool` flag drives UI (hides controls, shows progress)
- Apple Speech Recognition runs on-device, takes seconds to minutes depending on audio length
- Result saved as `.txt` file alongside `.m4a`
- View updates reactively when `transcription` property changes

## Build & Development

### Generate Xcode Project

```bash
xcodegen generate
```

This reads `project.yml` and creates `Image-Voice-Memos.xcodeproj`. Always run this after adding new source files or modifying project settings.

### Open in Xcode

```bash
open Image-Voice-Memos.xcodeproj
```

Then build/run with Cmd+B / Cmd+R in Xcode.

### Project Configuration (project.yml)

Key settings:
- **Deployment Target**: macOS 15.0
- **Architecture**: arm64 only (Apple Silicon) — `ARCHS: arm64`, `EXCLUDED_ARCHS[sdk=macosx*]: x86_64`
- **Entitlements**: Microphone access (`com.apple.security.device.audio-input`), file access (`com.apple.security.files.user-selected.read-write`), app sandbox enabled
- **Code Signing**: Automatic
- **Swift Version**: 5.0
- **Hardened Runtime**: Enabled

## Important Notes

### macOS Compatibility

- **No AVAudioSession**: macOS apps don't configure `AVAudioSession`; audio configuration is implicit
- **Microphone Permission**: Requires `NSMicrophoneUsageDescription` in Info.plist
- **Speech Recognition Permission**: Requires `NSSpeechRecognitionUsageDescription` in Info.plist; user will be prompted on first transcription attempt

### File Organization

```
Image-Voice-Memos/
├── App/
│   ├── ImageVoiceMemosApp.swift
│   └── AppDelegate.swift
├── Models/
│   ├── PhotoItem.swift               # PhotoItem + SortOrder enum
│   └── VoiceMemoState.swift
├── ViewModels/
│   ├── LibraryViewModel.swift       # NoteFilter + TranscriptionLanguage enums
│   └── VoiceMemoViewModel.swift
├── Views/
│   ├── ContentView.swift
│   ├── DetailView.swift
│   ├── PhotoGridView.swift
│   ├── PhotoGridItemView.swift
│   ├── VoiceMemoControlsView.swift
│   ├── ToolbarView.swift
│   ├── WaveformView.swift
│   └── EmptyStateView.swift
├── Services/
│   ├── ImageLoadingService.swift
│   ├── AudioRecordingService.swift
│   ├── AudioPlaybackService.swift
│   ├── TranscriptionService.swift
│   ├── TranslationService.swift
│   ├── VoiceMemoStorageService.swift
│   └── FolderAccessService.swift
├── Utilities/
│   ├── SupportedImageTypes.swift
│   └── FileNameUtilities.swift
├── Resources/
│   ├── Info.plist
│   ├── Image-Voice-Memos.entitlements
│   └── Assets.xcassets/
├── Assets/
│   └── AppIcon/                     # App icon source files (not compiled)
└── docs/
    └── index.html                   # Project description website (Mermaid.js diagrams)
```

### Common Pitfalls

1. **Missing `prepareToRecord()`**: Audio will start with ~1 second of silence. Always call this before `startRecording()`.
2. **RAW Thumbnail Loading**: Don't attempt full RAW decoding for thumbnails; use `CGImageSource` with `kCGImageSourceCreateThumbnailFromImageIfAbsent`.
3. **@MainActor Requirement**: `AudioRecordingService`, `AudioPlaybackService`, and ViewModels must be `@MainActor` to avoid threading issues with AVAudio APIs.
4. **Security-Scoped Bookmarks**: Always call `restoreFolder()` on app launch; bookmarks expire if not used regularly.
5. **Transcription Blocking**: Speech recognition is async and can take time on first model load; wrap in `isTranscribing` flag for UI feedback.
6. **Thumbnail Sync**: `updateThumbnail()` must update both `allPhotos` and `photoItems` — `allPhotos` is the source of truth, `photoItems` is the filtered view.
7. **Delete Cleanup**: `VoiceMemoStorageService.delete()` removes `.m4a`, `.txt`, and `.en.txt` sidecars; always reset `transcription = ""` and `translation = ""` in ViewModel after delete.
8. **Filter State**: Always use eager thumbnail loading in `loadPhotos()` — lazy loading causes thumbnails to disappear on filter switches.
9. **xcodegen**: Always run `xcodegen generate` after adding new source files or modifying `project.yml`. The `.xcodeproj` is not committed to git.

### Testing Audio Recording/Playback

- Create test `.m4a` files in `.voicememos/` subdirectory manually if needed
- Audio queue errors during playback (e.g., "Error (-4)") are typically non-blocking; playback still succeeds
- Microphone permission must be granted in System Settings before recording

## Memory & State Persistence

- **Folder Bookmark**: Persisted in UserDefaults under `"folderBookmark"` (security-scoped)
- **Transcriptions**: Stored as `.txt` files alongside `.m4a` files
- **Translations**: Stored as `.en.txt` sidecar files alongside `.m4a` files
- **Photo State**: Loaded on demand when item is selected; no persistent cache
- **View State**: Managed entirely by ViewModels; reset on folder/item changes

