import Foundation
import SwiftUI
import Observation

enum BrowserSection: String, CaseIterable, Identifiable {
    case overview = "Files"
    case transfers = "Transfers"
    case recent = "Recents"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
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
    var id: String
    var path: String
    var name: String
    var kind: String
    var size: String
    var sizeBytes: Int64?
    var modified: String
    var modifiedAt: Date
    var symbol: String
    var tint: Color
    var isFolder: Bool

    init(record: MTPFileRecord, storageID: UInt32) {
        id = "\(storageID):\(record.path)"
        path = record.path
        name = record.name
        isFolder = record.isFolder
        kind = Self.kind(for: record)
        sizeBytes = record.isFolder ? nil : max(0, record.size)
        size = record.isFolder ? "—" : ByteCountFormatter.string(fromByteCount: max(0, record.size), countStyle: .file)
        modifiedAt = Self.parseDate(record.dateAdded)
        modified = Self.dateLabel(modifiedAt)
        symbol = Self.symbol(for: record)
        tint = record.isFolder ? .blue : Self.tint(for: record.extensionName)
    }

    private static func kind(for record: MTPFileRecord) -> String {
        if record.isFolder { return "Folder" }
        guard !record.extensionName.isEmpty else { return "File" }
        return "\(record.extensionName.uppercased()) File"
    }

    private static func symbol(for record: MTPFileRecord) -> String {
        if record.isFolder { return "folder.fill" }
        return switch record.extensionName.lowercased() {
        case "jpg", "jpeg", "png", "heic", "webp": "photo"
        case "mp4", "mov", "mkv", "avi": "film"
        case "mp3", "wav", "m4a", "flac": "music.note"
        case "pdf": "doc.richtext"
        case "zip", "rar", "7z": "archivebox"
        default: "doc"
        }
    }

    private static func tint(for ext: String) -> Color {
        return switch ext.lowercased() {
        case "jpg", "jpeg", "png", "heic", "webp": .mint
        case "mp4", "mov", "mkv", "avi": .purple
        case "pdf": .red
        case "mp3", "wav", "m4a", "flac": .orange
        default: .secondary
        }
    }

    private static func parseDate(_ value: String) -> Date {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let standard = ISO8601DateFormatter()
        return standard.date(from: value) ?? .distantPast
    }

    private static func dateLabel(_ date: Date) -> String {
        guard date != .distantPast else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .medium
        formatter.timeStyle = Calendar.current.isDateInToday(date) ? .short : .none
        return formatter.string(from: date)
    }
}

struct TransferQueueItem: Identifiable {
    enum State { case running, complete, failed(String) }
    let id = UUID()
    var title: String
    var direction: TransferDirection
    var state: State = .running
    var progress: Double = 0
    var currentFile = ""
    var speed: Double = 0
}

@MainActor @Observable final class BrowserModel {
    private let backend = KalamBackend()

    var selection: BrowserSection? = .overview
    var layout: BrowserLayout = .list
    var search = ""
    var selectedItems = Set<String>()
    var inspectorVisible = false
    var transferQueueVisible = true
    var sorting = "Name"
    var showHiddenFiles = false

    var isConnecting = false
    var isConnected = false
    var connectionMessage = "Connect an Android device with USB File Transfer enabled."
    var deviceInfo: MTPDeviceSnapshot?
    var storages: [MTPStorageRecord] = []
    var selectedStorageID: UInt32?
    var currentPath = "/"
    var items: [BrowserItem] = []
    var transferQueue: [TransferQueueItem] = []
    var lastError: String?
    var recentActivity: [String] = []

    private var monitorStarted = false

    var filteredItems: [BrowserItem] {
        let filtered = search.isEmpty ? items : items.filter { $0.name.localizedCaseInsensitiveContains(search) }
        switch sorting {
        case "Kind":
            return filtered.sorted { $0.kind == $1.kind ? nameBefore($0, $1) : $0.kind < $1.kind }
        case "Size":
            return filtered.sorted {
                switch ($0.sizeBytes, $1.sizeBytes) {
                case let (lhs?, rhs?) where lhs != rhs: return lhs < rhs
                case (nil, _?): return true
                case (_?, nil): return false
                default: return nameBefore($0, $1)
                }
            }
        case "Date Modified":
            return filtered.sorted { $0.modifiedAt == $1.modifiedAt ? nameBefore($0, $1) : $0.modifiedAt < $1.modifiedAt }
        default:
            return filtered.sorted(by: nameBefore)
        }
    }

    var deviceName: String {
        deviceInfo?.mtpDeviceInfo?.model ?? deviceInfo?.usbDeviceInfo?.deviceName ?? "Android Device"
    }

    var selectedStorage: MTPStorageRecord? {
        storages.first { $0.sid == selectedStorageID }
    }

    var storageSummary: String {
        guard let info = selectedStorage?.info,
              let free = info.freeSpaceInBytes,
              let total = info.maxCapacity else { return "Storage information unavailable" }
        let freeText = ByteCountFormatter.string(fromByteCount: Int64(clamping: free), countStyle: .file)
        let totalText = ByteCountFormatter.string(fromByteCount: Int64(clamping: total), countStyle: .file)
        return "\(freeText) available of \(totalText)"
    }

    func startDeviceMonitor() async {
        guard !monitorStarted else { return }
        monitorStarted = true
        await connectIfNeeded()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(6))
            if !isConnected { await connectIfNeeded() }
        }
    }

    func connectIfNeeded() async {
        guard !isConnecting, !isConnected else { return }
        isConnecting = true
        connectionMessage = "Looking for an Android device…"
        lastError = nil
        defer { isConnecting = false }
        do {
            deviceInfo = try await backend.initialize()
            isConnected = true
            connectionMessage = "Connected over USB"
            storages = try await backend.storages()
            selectedStorageID = storages.first?.sid
            currentPath = "/"
            if let selectedStorageID { await loadDirectory(storageID: selectedStorageID, path: "/") }
            recentActivity.insert("Connected to \(deviceName)", at: 0)
        } catch {
            isConnected = false
            deviceInfo = nil
            storages = []
            selectedStorageID = nil
            items = []
            let message = error.localizedDescription
            lastError = message
            connectionMessage = Self.connectionHint(for: message)
        }
    }

    func refresh() async {
        if isConnected {
            do { try await backend.dispose() } catch { }
        }
        isConnected = false
        deviceInfo = nil
        storages = []
        selectedStorageID = nil
        currentPath = "/"
        items = []
        await connectIfNeeded()
    }

    func selectStorage(_ storageID: UInt32) async {
        guard selectedStorageID != storageID else { return }
        selectedStorageID = storageID
        currentPath = "/"
        selectedItems.removeAll()
        await loadDirectory(storageID: storageID, path: "/")
    }

    func loadDirectory(path: String? = nil) async {
        guard let selectedStorageID else { return }
        await loadDirectory(storageID: selectedStorageID, path: path ?? currentPath)
    }

    private func loadDirectory(storageID: UInt32, path: String) async {
        guard isConnected else { return }
        currentPath = Self.normalizedDevicePath(path)
        do {
            let records = try await backend.files(storageID: storageID, path: currentPath, showHidden: showHiddenFiles)
            items = records.map { BrowserItem(record: $0, storageID: storageID) }
            selectedItems = selectedItems.intersection(Set(items.map(\.id)))
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func createFolder(named name: String) async throws {
        guard let storageID = selectedStorageID, isConnected else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !cleanName.contains("/"), cleanName != ".", cleanName != ".." else {
            throw MTPBackendError.operation("InvalidPath", "Enter a valid folder name.")
        }
        try await backend.createFolder(storageID: storageID, path: Self.join(currentPath, cleanName))
        recentActivity.insert("Created folder \(cleanName)", at: 0)
        await loadDirectory()
    }

    func rename(_ item: BrowserItem, to newName: String) async throws {
        guard let storageID = selectedStorageID, isConnected else { return }
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !cleanName.contains("/"), cleanName != ".", cleanName != ".." else {
            throw MTPBackendError.operation("InvalidPath", "Enter a valid file name.")
        }
        try await backend.rename(storageID: storageID, path: item.path, newName: cleanName)
        recentActivity.insert("Renamed \(item.name) to \(cleanName)", at: 0)
        await loadDirectory()
    }

    func deleteSelectedItems() async throws {
        guard let storageID = selectedStorageID, isConnected else { return }
        let selectedPaths = items.filter { selectedItems.contains($0.id) }.map(\.path)
        guard !selectedPaths.isEmpty else { return }
        try await backend.delete(storageID: storageID, paths: selectedPaths)
        recentActivity.insert("Deleted \(selectedPaths.count) item(s)", at: 0)
        selectedItems.removeAll()
        await loadDirectory()
    }

    func upload(_ urls: [URL]) async {
        guard let storageID = selectedStorageID, isConnected, !urls.isEmpty else { return }
        await runTransfer(direction: .upload, storageID: storageID, sources: urls.map(\.path), destination: currentPath, title: "Copy to Device")
    }

    func downloadSelected(to directory: URL) async {
        guard let storageID = selectedStorageID, isConnected else { return }
        let sources = items.filter { selectedItems.contains($0.id) }.map(\.path)
        guard !sources.isEmpty else { return }
        await runTransfer(direction: .download, storageID: storageID, sources: sources, destination: directory.path, title: "Copy to Mac")
    }

    private func runTransfer(direction: TransferDirection, storageID: UInt32, sources: [String], destination: String, title: String) async {
        var queueItem = TransferQueueItem(title: title, direction: direction)
        transferQueue.insert(queueItem, at: 0)
        let id = queueItem.id
        transferQueueVisible = true
        do {
            try await backend.transfer(direction: direction, storageID: storageID, sources: sources, destination: destination, onPreprocess: { _ in }) { [weak self] progress in
                Task { @MainActor in self?.updateProgress(progress, id: id) }
            }
            queueItem.state = .complete
            queueItem.progress = 1
            updateTransfer(queueItem)
            recentActivity.insert("\(title) completed", at: 0)
            if direction == .upload { await loadDirectory() }
        } catch {
            queueItem.state = .failed(error.localizedDescription)
            updateTransfer(queueItem)
            lastError = error.localizedDescription
        }
    }

    private func updateProgress(_ progress: MTPTransferProgress, id: UUID) {
        guard let data = progress.data,
              let index = transferQueue.firstIndex(where: { $0.id == id }) else { return }
        transferQueue[index].progress = min(1, max(0, data.bulkFileSize.progress / 100))
        transferQueue[index].currentFile = data.name
        transferQueue[index].speed = data.speed
        if let error = progress.error, !error.isEmpty {
            transferQueue[index].state = .failed(error)
        }
    }

    private func updateTransfer(_ item: TransferQueueItem) {
        guard let index = transferQueue.firstIndex(where: { $0.id == item.id }) else { return }
        transferQueue[index] = item
    }

    private static func normalizedDevicePath(_ path: String) -> String {
        let parts = path.split(separator: "/").filter { $0 != "." && $0 != ".." }
        return parts.isEmpty ? "/" : "/" + parts.joined(separator: "/")
    }

    static func join(_ parent: String, _ child: String) -> String {
        parent == "/" ? "/\(child)" : "\(parent)/\(child)"
    }

    private func nameBefore(_ lhs: BrowserItem, _ rhs: BrowserItem) -> Bool {
        lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private static func connectionHint(for message: String) -> String {
        if message.contains("ErrorMtpDetectFailed") || message.localizedCaseInsensitiveContains("device") {
            return "Connect an Android device, unlock it, and choose USB File Transfer on the device."
        }
        return message
    }
}
