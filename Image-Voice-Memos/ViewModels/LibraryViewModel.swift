import Foundation
import AppKit

enum TranscriptionLanguage: String, CaseIterable {
    case german = "Deutsch"
    case english = "English"

    var locale: Locale {
        switch self {
        case .german: return Locale(identifier: "de-DE")
        case .english: return Locale(identifier: "en-US")
        }
    }
}

enum NoteFilter: String, CaseIterable {
    case all = "All"
    case withNote = "With Note"
    case withoutNote = "Without Note"
}

@MainActor
final class LibraryViewModel: ObservableObject {

    @Published var photoItems: [PhotoItem] = []
    @Published var selectedItem: PhotoItem?
    @Published var folderURL: URL?
    @Published var sortOrder: SortOrder = .nameAsc
    @Published var noteFilter: NoteFilter = .all
    @Published var transcriptionLanguage: TranscriptionLanguage = .german
    @Published var translateToEnglish: Bool = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var allPhotos: [PhotoItem] = []
    let imageLoadingService = ImageLoadingService()
    private let folderAccessService = FolderAccessService()

    func openFolder() {
        Task {
            guard let url = await folderAccessService.requestFolder() else { return }
            folderURL = url
            selectedItem = nil
            await loadPhotos(from: url)
        }
    }

    func restoreBookmarkOnLaunch() {
        guard let url = folderAccessService.restoreFolder() else { return }
        folderURL = url
        Task { await loadPhotos(from: url) }
    }

    func releaseFolder() {
        folderAccessService.releaseActive()
    }

    func loadPhotos(from url: URL) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try VoiceMemoStorageService.ensureVoiceMemosDirectoryExists(in: url)
        } catch {
            // Non-fatal; recording will fail gracefully if directory can't be created
        }

        let keys: [URLResourceKey] = [.creationDateKey, .nameKey]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: .skipsHiddenFiles
        ) else {
            errorMessage = "Could not read folder."
            return
        }

        let items = contents
            .filter { SupportedImageTypes.extensions.contains($0.pathExtension.lowercased()) }
            .map { fileURL -> PhotoItem in
                let date = try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate
                var item = PhotoItem(url: fileURL, creationDate: date)
                item.hasVoiceMemo = VoiceMemoStorageService.voiceMemoExists(for: item, in: url)
                return item
            }

        allPhotos = items
        filterAndSort()

        // Load thumbnails eagerly
        Task {
            for (index, item) in allPhotos.enumerated() {
                if let thumb = await imageLoadingService.loadThumbnail(url: item.url, maxDimension: 300) {
                    await MainActor.run {
                        self.allPhotos[index].thumbnail = thumb
                        // Update photoItems directly if this item is in the filtered list
                        if let filteredIdx = self.photoItems.firstIndex(where: { $0.id == item.id }) {
                            self.photoItems[filteredIdx].thumbnail = thumb
                        }
                    }
                }
            }
        }

        errorMessage = nil
    }

    func setSortOrder(_ order: SortOrder) {
        sortOrder = order
        filterAndSort()
    }

    func setFilter(_ filter: NoteFilter) {
        noteFilter = filter
        filterAndSort()
    }

    private func filterAndSort() {
        var filtered = allPhotos

        // Apply filter
        switch noteFilter {
        case .all:
            break
        case .withNote:
            filtered = filtered.filter { $0.hasVoiceMemo }
        case .withoutNote:
            filtered = filtered.filter { !$0.hasVoiceMemo }
        }

        // Apply sort
        filtered = sorted(filtered, by: sortOrder)
        photoItems = filtered

        // Auto-select first photo if current selection is not in filtered list
        if selectedItem == nil || !filtered.contains(where: { $0.id == selectedItem?.id }) {
            selectedItem = filtered.first
        }
    }

    func updateThumbnail(_ thumbnail: NSImage, for item: PhotoItem) {
        // Update in allPhotos (source of truth)
        guard let idx = allPhotos.firstIndex(where: { $0.id == item.id }) else { return }
        allPhotos[idx].thumbnail = thumbnail

        // Also update in photoItems if it's in the filtered list
        if let idx2 = photoItems.firstIndex(where: { $0.id == item.id }) {
            photoItems[idx2].thumbnail = thumbnail
        }
    }

    func refreshVoiceMemoStatus(for item: PhotoItem) {
        guard let folderURL, let idx = allPhotos.firstIndex(where: { $0.id == item.id }) else { return }
        allPhotos[idx].hasVoiceMemo = VoiceMemoStorageService.voiceMemoExists(for: allPhotos[idx], in: folderURL)
        // Re-apply filter and sort
        filterAndSort()
        // Propagate to selectedItem if it's the same item
        if selectedItem?.id == item.id {
            selectedItem = allPhotos[idx]
        }
    }

    private func sorted(_ items: [PhotoItem], by order: SortOrder) -> [PhotoItem] {
        switch order {
        case .nameAsc:  return items.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        case .nameDesc: return items.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedDescending }
        case .dateAsc:  return items.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        case .dateDesc: return items.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        }
    }
}
