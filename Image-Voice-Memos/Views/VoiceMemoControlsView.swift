import SwiftUI

struct VoiceMemoControlsView: View {
    @EnvironmentObject var voiceMemoVM: VoiceMemoViewModel
    @EnvironmentObject var libraryVM: LibraryViewModel

    @State private var isPulsing = false

    var body: some View {
        Group {
            if let item = libraryVM.selectedItem {
                controls(for: item)
            }
        }
        .alert("Microphone Access Denied", isPresented: $voiceMemoVM.showMicPermissionAlert) {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow microphone access in System Settings → Privacy → Microphone.")
        }
    }

    @ViewBuilder
    private func controls(for item: PhotoItem) -> some View {
        // Hide controls during transcription
        if voiceMemoVM.isTranscribing {
            EmptyView()
        } else {
            controlsForState(for: item)
        }
    }

    @ViewBuilder
    private func controlsForState(for item: PhotoItem) -> some View {
        switch voiceMemoVM.voiceMemoState {
        case .countingDown:
            HStack(spacing: 12) {
                // Animated red Live indicator
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
                    .onAppear { isPulsing = true }

                Text("Live")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .fontWeight(.bold)

                Spacer()
            }

        case .noNote:
            HStack {
                Image(systemName: "mic.slash")
                    .foregroundStyle(.secondary)
                Text("No Voice Note")
                    .foregroundStyle(.secondary)
                Spacer()
                translateToggle
                languagePicker
                Button {
                    voiceMemoVM.startRecording(for: item)
                } label: {
                    Label("Record", systemImage: "mic.fill")
                }
                .buttonStyle(.borderedProminent)
            }

        case .noteExists(let duration):
            HStack(spacing: 12) {
                Button {
                    voiceMemoVM.startPlayback(for: item)
                } label: {
                    Label("Play", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)

                Text(duration.formattedAsVoiceMemoDuration)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Spacer()

                translateToggle
                languagePicker

                Button {
                    voiceMemoVM.startRecording(for: item)
                } label: {
                    Label("Re-record", systemImage: "mic")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    voiceMemoVM.deleteVoiceMemo(for: item)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .help("Delete Voice Note")
            }

        case .recording(let level):
            HStack(spacing: 12) {
                // Live indicator
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
                    .onAppear { isPulsing = true }

                Text("Live")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .fontWeight(.bold)

                WaveformView(level: level, recordingTime: voiceMemoVM.recordingTime)
                    .frame(maxWidth: .infinity)

                Text(voiceMemoVM.recordingTime.formattedAsVoiceMemoDuration)
                    .monospacedDigit()
                    .foregroundStyle(.red)
                    .frame(width: 40)

                Button {
                    voiceMemoVM.stopRecording()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button {
                    voiceMemoVM.cancelRecording()
                } label: {
                    Text("Cancel")
                }
                .buttonStyle(.bordered)
            }

        case .converting:
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                Text("Saving…")
                    .foregroundStyle(.secondary)
                Spacer()
            }

        case .playing(let progress):
            HStack(spacing: 12) {
                Button {
                    voiceMemoVM.pausePlayback()
                } label: {
                    Image(systemName: "pause.fill")
                }
                .buttonStyle(.bordered)

                PlaybackProgressBar(progress: progress)
                    .frame(maxWidth: .infinity)

                Text(voiceMemoVM.playbackTime.formattedAsVoiceMemoDuration)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 40)

                Button {
                    voiceMemoVM.stopPlayback()
                    if let folderURL = libraryVM.folderURL {
                        Task {
                            let dur = await VoiceMemoStorageService.duration(for: item, in: folderURL) ?? 0
                            voiceMemoVM.voiceMemoState = .noteExists(duration: dur)
                        }
                    }
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.bordered)
            }

        case .paused:
            HStack(spacing: 12) {
                Button {
                    voiceMemoVM.resumePlayback()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)

                Text(voiceMemoVM.playbackTime.formattedAsVoiceMemoDuration)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    voiceMemoVM.stopPlayback()
                    if let folderURL = libraryVM.folderURL {
                        Task {
                            let dur = await VoiceMemoStorageService.duration(for: item, in: folderURL) ?? 0
                            voiceMemoVM.voiceMemoState = .noteExists(duration: dur)
                        }
                    }
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var translateToggle: some View {
        if libraryVM.transcriptionLanguage == .german {
            Toggle("EN", isOn: $libraryVM.translateToEnglish)
                .toggleStyle(.checkbox)
                .help("Translate to English")
                .fixedSize()
        }
    }

    private var languagePicker: some View {
        Picker("", selection: $libraryVM.transcriptionLanguage) {
            ForEach(TranscriptionLanguage.allCases, id: \.self) { lang in
                Text(lang.rawValue).tag(lang)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
        .labelsHidden()
    }
}

private struct PlaybackProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)))
                    .animation(.linear(duration: 0.05), value: progress)
            }
        }
        .frame(height: 4)
    }
}
