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
    var sizeBytes: Int64?
    var modified: String
    var modifiedAt: Date
    var symbol: String
    var tint: Color
    var isFolder: Bool
}

private func fixtureDate(_ iso8601: String) -> Date {
    ISO8601DateFormatter().date(from: iso8601)!
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
        .init(name: "DCIM", kind: "Folder", size: "—", sizeBytes: nil, modified: "Today, 10:42 AM", modifiedAt: fixtureDate("2026-11-03T10:42:00Z"), symbol: "folder.fill", tint: .blue, isFolder: true),
        .init(name: "Download", kind: "Folder", size: "—", sizeBytes: nil, modified: "Yesterday", modifiedAt: fixtureDate("2026-11-02T12:00:00Z"), symbol: "folder.fill", tint: .blue, isFolder: true),
        .init(name: "Documents", kind: "Folder", size: "—", sizeBytes: nil, modified: "Oct 29, 2026", modifiedAt: fixtureDate("2026-10-29T12:00:00Z"), symbol: "folder.fill", tint: .blue, isFolder: true),
        .init(name: "Movies", kind: "Folder", size: "—", sizeBytes: nil, modified: "Oct 27, 2026", modifiedAt: fixtureDate("2026-10-27T12:00:00Z"), symbol: "folder.fill", tint: .blue, isFolder: true),
        .init(name: "Music", kind: "Folder", size: "—", sizeBytes: nil, modified: "Oct 21, 2026", modifiedAt: fixtureDate("2026-10-21T12:00:00Z"), symbol: "folder.fill", tint: .blue, isFolder: true),
        .init(name: "Pictures", kind: "Folder", size: "—", sizeBytes: nil, modified: "Oct 20, 2026", modifiedAt: fixtureDate("2026-10-20T12:00:00Z"), symbol: "folder.fill", tint: .blue, isFolder: true),
        .init(name: "VID_20261028.mp4", kind: "MPEG-4 Movie", size: "152.8 MB", sizeBytes: 152800000, modified: "Oct 28, 2026", modifiedAt: fixtureDate("2026-10-28T12:00:00Z"), symbol: "film", tint: .purple, isFolder: false),
        .init(name: "IMG_2048.jpg", kind: "JPEG Image", size: "3.4 MB", sizeBytes: 3400000, modified: "Oct 25, 2026", modifiedAt: fixtureDate("2026-10-25T12:00:00Z"), symbol: "photo", tint: .mint, isFolder: false),
        .init(name: "Notes.pdf", kind: "PDF Document", size: "1.2 MB", sizeBytes: 1200000, modified: "Oct 22, 2026", modifiedAt: fixtureDate("2026-10-22T12:00:00Z"), symbol: "doc.richtext", tint: .red, isFolder: false)
    ]

    var filteredItems: [BrowserItem] {
        let filtered = search.isEmpty ? items : items.filter { $0.name.localizedCaseInsensitiveContains(search) }
        switch sorting {
        case "Kind":
            return filtered.sorted {
                $0.kind == $1.kind
                    ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                    : $0.kind < $1.kind
            }
        case "Size":
            return filtered.sorted {
                switch ($0.sizeBytes, $1.sizeBytes) {
                case let (lhs?, rhs?) where lhs != rhs:
                    return lhs < rhs
                case (nil, _?):
                    return true
                case (_?, nil):
                    return false
                default:
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
            }
        case "Date Modified":
            return filtered.sorted {
                $0.modifiedAt == $1.modifiedAt
                    ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                    : $0.modifiedAt < $1.modifiedAt
            }
        default:
            return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}
