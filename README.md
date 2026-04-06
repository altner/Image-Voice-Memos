# Image Voice Memos

A native macOS application for browsing photos and recording voice memo — one voice memo per photo, automatically transcribed using Apple's on-device Speech Recognition.

![Version](https://img.shields.io/badge/version-0.1.0-blue)
![Platform](https://img.shields.io/badge/platform-macOS%2015.0%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

- **Photo Browser** — Browse any local folder of images in a responsive grid layout
- **Voice Memos** — Record a voice memo for each photo (1:1 mapping by filename)
- **Auto-Transcription** — Fully on-device transcription via Apple Speech Recognition (German & English)
- **Translation** — Optional German → English translation using Apple's Translation framework, fully on-device
- **Filter & Sort** — Filter by All / With Memo / Without Memo; sort by Name A→Z, Z→A, Date Newest or Oldest
- **RAW Support** — Native support for NEF, RAF, ORF, DNG and 15+ other formats
- **Sidecar Files** — Voice memos stored as `.m4a`, transcriptions as `.txt`, translations as `.en.txt` alongside your photos
- **Persistent Folder Access** — Folder selection is remembered across app launches via security-scoped bookmarks
- **Privacy First** — Fully on-device processing via Apple Silicon Neural Engine; no internet connection required

---

## Requirements

| Requirement | Version |
|-------------|---------|
| Mac | Apple Silicon (M1 or later) |
| macOS | 15.0 Sequoia or later |
| Xcode | 16.0 or later |
| xcodegen | 2.x |

---

## Getting Started

### 1. Install Dependencies

```bash
brew install xcodegen
```

### 2. Clone the Repository

```bash
git clone <repository-url>
cd Image-Voice-Memos
```

### 3. Generate Xcode Project

```bash
xcodegen generate
```

### 4. Open & Build

```bash
open Image-Voice-Memos.xcodeproj
```

Then press **Cmd+R** in Xcode to build and run.

---

## First Launch

On first launch the app will request two permissions — both are required:

| Permission | Reason |
|-----------|--------|
| **Microphone** | To record voice memos |
| **Speech Recognition** | To transcribe recordings on-device |

Grant both in the system dialog. If you accidentally deny a permission or the app is not working as expected, enable them manually:

**Microphone:**
1. Open **System Settings → Privacy & Security → Microphone**
2. Enable the toggle for **Image Voice Memos**

**Speech Recognition:**
1. Open **System Settings → Privacy & Security → Speech Recognition**
2. Enable the toggle for **Image Voice Memos**

After granting permissions, restart the app.

---

## Usage

1. **Open a Folder** — Click the folder icon in the toolbar or press **Cmd+O** to select your photo library
2. **Select a Photo** — Click any photo in the grid to open the detail view; photos with voice memos show a microphone badge
3. **Record a Voice Memo** — Click **Record**, wait for the 1-second countdown (animated "Live" indicator), then speak; a live waveform shows audio levels
4. **Stop** — Click **Stop** when done; transcription starts automatically
5. **Playback** — Click **Play** to listen back; use the progress bar and pause/resume as needed
6. **Delete** — Click the trash icon to remove the voice memo and its transcription
7. **Filter** — Filter by All / With Memo / Without Memo
8. **Sort** — Sort by Name A→Z, Name Z→A, Date (Newest), or Date (Oldest)
9. **Language** — Switch between German and English transcription per recording
10. **Translate** — Enable the "EN" toggle (visible when German is selected) to translate DE → EN on-device
11. **Copy Text** — Select and copy transcription or translation text directly from the detail view

---

## Supported Image Formats

| Format | Extensions |
|--------|-----------|
| JPEG | `.jpg`, `.jpeg` |
| PNG | `.png` |
| TIFF | `.tif`, `.tiff` |
| HEIC/HEIF | `.heic`, `.heif` |
| WebP | `.webp` |
| BMP | `.bmp` |
| GIF | `.gif` |
| RAW | `.nef`, `.raf`, `.orf`, `.dng`, `.cr2`, `.cr3`, `.arw`, `.rw2` |

---

## File Storage

Voice memos and transcriptions are stored in a hidden `.voicememos/` folder inside your selected photo directory:

```
your-photo-folder/
├── photo.jpg
├── photo2.nef
└── .voicememos/
    ├── photo.m4a        ← voice memo audio
    ├── photo.txt        ← transcription
    ├── photo.en.txt     ← english translation (optional)
    ├── photo2.m4a
    └── photo2.txt
```

Your original photos are never modified. Transcription files (`.txt`) are preserved even if the voice memo is deleted, so orphaned transcriptions remain accessible.

---

## Project Structure

```
Image-Voice-Memos/
├── App/
│   ├── ImageVoiceMemosApp.swift     # App entry point
│   └── AppDelegate.swift            # App lifecycle
├── Models/
│   ├── PhotoItem.swift              # Photo data model
│   └── VoiceMemoState.swift         # Recording state machine
├── ViewModels/
│   ├── LibraryViewModel.swift       # Photo grid, filtering, sorting
│   └── VoiceMemoViewModel.swift     # Recording, playback, transcription
├── Views/
│   ├── ContentView.swift            # Root layout
│   ├── DetailView.swift             # Photo detail + transcription
│   ├── PhotoGridView.swift          # Photo grid
│   ├── PhotoGridItemView.swift      # Grid cell
│   ├── VoiceMemoControlsView.swift  # Record/play controls
│   ├── ToolbarView.swift            # Filter, sort, folder path
│   ├── WaveformView.swift           # Live audio waveform
│   └── EmptyStateView.swift         # No folder selected state
├── Services/
│   ├── ImageLoadingService.swift    # Thumbnail & RAW loading (Actor)
│   ├── AudioRecordingService.swift  # PCM recording → AAC conversion
│   ├── AudioPlaybackService.swift   # Audio playback
│   ├── TranscriptionService.swift   # Apple Speech Recognition
│   ├── TranslationService.swift     # Apple Translation (DE→EN)
│   ├── VoiceMemoStorageService.swift # .voicememos/ file management
│   └── FolderAccessService.swift    # Security-scoped bookmarks
├── Utilities/
│   ├── SupportedImageTypes.swift    # Supported format definitions
│   └── FileNameUtilities.swift      # URL/filename helpers
├── Resources/
│   ├── Info.plist
│   ├── Image-Voice-Memos.entitlements
│   └── Assets.xcassets/
├── Assets/
│   └── AppIcon/                     # App icon source files
├── docs/
│   └── index.html                   # Project website (Mermaid.js diagrams)
└── project.yml                      # xcodegen configuration
```

---

## Architecture

The app follows **MVVM** with SwiftUI:

- **`@MainActor` ViewModels** — Thread-safe UI updates
- **Actor-based Services** — `ImageLoadingService` runs as a Swift Actor for safe concurrent thumbnail loading
- **State Machine** — `VoiceMemoState` enum drives the entire recording/playback UI
- **Security-Scoped Bookmarks** — Folder access persists across app launches via `FolderAccessService`

---

## Distribution (Ad-hoc)

To share the app without the App Store:

1. In Xcode: **Product → Archive**
2. In Organizer: **Distribute App → Custom → Copy App**
3. Package as ZIP:

```bash
zip -r "Image-Voice-Memos.zip" "Image Voice Memos.app"
```

**Note for recipients:** On first launch, right-click the app and choose **Open**, then confirm in the dialog to bypass Gatekeeper.

---

## Regenerating the Xcode Project

After adding new source files or modifying `project.yml`, regenerate the project:

```bash
xcodegen generate
```
