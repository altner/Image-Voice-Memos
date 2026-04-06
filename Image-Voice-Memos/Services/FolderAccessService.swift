import Foundation
import AppKit

@MainActor
final class FolderAccessService {

    private let bookmarkKey = "folderBookmark"
    private var activeURL: URL?

    func requestFolder() async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder with photos"
        panel.prompt = "Open"

        let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())
        guard response == .OK, let url = panel.url else { return nil }

        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        } catch {
            // If bookmark creation fails, still return the URL for this session
        }

        releaseActive()
        _ = url.startAccessingSecurityScopedResource()
        activeURL = url
        return url
    }

    func restoreFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            return nil
        }

        releaseActive()
        _ = url.startAccessingSecurityScopedResource()
        activeURL = url
        return url
    }

    func releaseActive() {
        activeURL?.stopAccessingSecurityScopedResource()
        activeURL = nil
    }
}
