import Foundation
import SwiftUI

enum BrowserSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case internalStorage = "Internal Storage"
    case sdCard = "SD Card"
    case transfers = "Transfers"
    case recent = "Recents"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .internalStorage: "internaldrive"
        case .sdCard: "sdcard"
        case .transfers: "arrow.left.arrow.right"
        case .recent: "clock"
        }
    }
}

enum BrowserLayout: String, CaseIterable {
    case list = "List", grid = "Icons"
    var symbol: String { self == .list ? "list.bullet" : "square.grid.2x2" }
}

struct BrowserItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var kind: String
    var size: String
    var modified: String
    var symbol: String
    var tint: Color
    var isFolder: Bool
}

@Observable final class BrowserModel {
    var selection: BrowserSection? = .overview
    var layout: BrowserLayout = .list
    var search = ""
    var selectedItems = Set<UUID>()
    var inspectorVisible = false
    var transferQueueVisible = true
    var sorting = "Name"
    var showHiddenFiles = false

    // UI-only fixture data. No MTP/USB operations are performed by this target.
    var items: [BrowserItem] = [
        .init(name: "DCIM", kind: "Folder", size: "—", modified: "Today, 10:42 AM", symbol: "folder.fill", tint: .blue, isFolder: true),
        .init(name: "Download", kind: "Folder", size: "—", modified: "Yesterday", symbol: "folder.fill", tint: .blue, isFolder: true),
        .init(name: "Documents", kind: "Folder", size: "—", modified: "Oct 29, 2026", symbol: "folder.fill", tint: .blue, isFolder: true),
        .init(name: "Movies", kind: "Folder", size: "—", modified: "Oct 27, 2026", symbol: "folder.fill", tint: .blue, isFolder: true),
        .init(name: "Music", kind: "Folder", size: "—", modified: "Oct 21, 2026", symbol: "folder.fill", tint: .blue, isFolder: true),
        .init(name: "Pictures", kind: "Folder", size: "—", modified: "Oct 20, 2026", symbol: "folder.fill", tint: .blue, isFolder: true),
        .init(name: "VID_20261028.mp4", kind: "MPEG-4 Movie", size: "152.8 MB", modified: "Oct 28, 2026", symbol: "film", tint: .purple, isFolder: false),
        .init(name: "IMG_2048.jpg", kind: "JPEG Image", size: "3.4 MB", modified: "Oct 25, 2026", symbol: "photo", tint: .mint, isFolder: false),
        .init(name: "Notes.pdf", kind: "PDF Document", size: "1.2 MB", modified: "Oct 22, 2026", symbol: "doc.richtext", tint: .red, isFolder: false)
    ]

    var filteredItems: [BrowserItem] {
        let filtered = search.isEmpty ? items : items.filter { $0.name.localizedCaseInsensitiveContains(search) }
        switch sorting {
        case "Kind": return filtered.sorted { $0.kind < $1.kind }
        case "Size": return filtered.sorted { $0.size < $1.size }
        case "Date Modified": return filtered.sorted { $0.modified < $1.modified }
        default: return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}
