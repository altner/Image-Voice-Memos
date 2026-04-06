import SwiftUI
import AppKit
import Translation

struct DetailView: View {
    @EnvironmentObject var libraryVM: LibraryViewModel
    @EnvironmentObject var voiceMemoVM: VoiceMemoViewModel

    @State private var fullResImage: NSImage?
    @State private var isLoadingFullRes = false
    @State private var translationConfiguration: TranslationSession.Configuration?

    var body: some View {
        if let item = libraryVM.selectedItem {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Image pane (60% of available height)
                    ZStack {
                        Color(NSColor.windowBackgroundColor)

                        if let image = fullResImage {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let thumb = item.thumbnail {
                            Image(nsImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .blur(radius: isLoadingFullRes ? 1 : 0)
                                .overlay(alignment: .bottomTrailing) {
                                    if isLoadingFullRes {
                                        ProgressView()
                                            .padding(12)
                                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                            .padding(12)
                                    }
                                }
                        } else {
                            ProgressView("Loading…")
                        }
                    }
                    .frame(height: geometry.size.height * 0.6)

                    Divider()

                    // Filename
                    HStack {
                        Text(item.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

                    Divider()

                    // Voice note controls
                    VoiceMemoControlsView()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(minHeight: 52)

                    Divider()

                    // Transcription pane
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Transcription")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if voiceMemoVM.isTranscribing {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("processing...")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        if voiceMemoVM.isTranscribing {
                            Text("Transcribing…")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        } else if voiceMemoVM.transcription.isEmpty {
                            Text("No Transcription Available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(voiceMemoVM.transcription)
                                        .font(.system(.body, design: .default))
                                        .foregroundColor(.primary)
                                        .lineLimit(nil)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)

                                    // Translation section
                                    if voiceMemoVM.isTranslating {
                                        Divider()
                                        HStack(spacing: 4) {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                            Text("Translating…")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else if !voiceMemoVM.translation.isEmpty {
                                        Divider()
                                        Text("Translation")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(voiceMemoVM.translation)
                                            .font(.system(.body, design: .default))
                                            .foregroundColor(.primary)
                                            .lineLimit(nil)
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .topLeading)
                                    }
                                }
                                .padding(12)
                            }
                        }

                        Spacer()
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .translationTask(translationConfiguration) { session in
                        let text = voiceMemoVM.transcription
                        guard !text.isEmpty else {
                            voiceMemoVM.handleTranslationError()
                            return
                        }
                        do {
                            let response = try await withThrowingTaskGroup(of: String.self) { group in
                                group.addTask {
                                    let result = try await session.translate(text)
                                    return result.targetText
                                }
                                group.addTask {
                                    try await Task.sleep(nanoseconds: 30_000_000_000) // 30s timeout
                                    throw CancellationError()
                                }
                                let first = try await group.next()!
                                group.cancelAll()
                                return first
                            }
                            voiceMemoVM.handleTranslationResult(response)
                        } catch {
                            print("❌ Translation error: \(error.localizedDescription)")
                            voiceMemoVM.handleTranslationError()
                        }
                    }
                    .onChange(of: voiceMemoVM.translationConfiguration) { _, newValue in
                        if newValue != nil {
                            translationConfiguration = newValue
                            voiceMemoVM.translationConfiguration = nil
                        }
                    }
                }
            }
            .task(id: item.id) {
                // Reload both image and voice note state
                fullResImage = nil
                isLoadingFullRes = true
                voiceMemoVM.loadState(for: item)
                fullResImage = await libraryVM.imageLoadingService.loadFullResolution(url: item.url)
                isLoadingFullRes = false
            }
        }
    }
}
