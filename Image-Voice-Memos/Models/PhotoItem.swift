import Foundation
import AppKit

struct PhotoItem: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let displayName: String
    let filenameStem: String
    var thumbnail: NSImage?
    var hasVoiceMemo: Bool
    var creationDate: Date?

    init(url: URL, creationDate: Date? = nil) {
        self.id = UUID()
        self.url = url
        self.displayName = url.lastPathComponent
        self.filenameStem = url.filenameStem
        self.thumbnail = nil
        self.hasVoiceMemo = false
        self.creationDate = creationDate
    }

    func hash(into hasher: inout Hasher) { hasher.combine(url) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.url == rhs.url }
}

enum SortOrder: String, CaseIterable {
    case nameAsc = "Name A→Z"
    case nameDesc = "Name Z→A"
    case dateDesc = "Date (Newest)"
    case dateAsc = "Date (Oldest)"
}
