import SwiftUI
import AppKit

struct BrowserWindow: View {
    @Environment(BrowserModel.self) private var model
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var path: [String] = []
    @State private var folderName = ""
    @State private var renameName = ""
    @State private var itemToRename: BrowserItem?
    @State private var showFolderPrompt = false
    @State private var showRenamePrompt = false
    @State private var showDeleteConfirmation = false
    @State private var showError = false

    var body: some View {
        @Bindable var model = model
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } detail: {
            VStack(spacing: 0) {
                deviceHeader
                Divider()
                content
                Divider()
                statusBar
            }
            .navigationTitle(title)
            .toolbar { toolbar }
            .searchable(text: $model.search, placement: .toolbar, prompt: "Search device files")
            .inspector(isPresented: $model.inspectorVisible) { InspectorView() }
        }
        .navigationSplitViewStyle(.balanced)
        .task { await model.startDeviceMonitor() }
        .onChange(of: path) { _, newPath in
            Task { await model.loadDirectory(path: devicePath(newPath)) }
        }
        .onChange(of: model.showHiddenFiles) { _, _ in Task { await model.loadDirectory() } }
        .alert("New Folder", isPresented: $showFolderPrompt) {
            TextField("Folder name", text: $folderName)
            Button("Cancel", role: .cancel) { folderName = "" }
            Button("Create") { perform { try await model.createFolder(named: folderName); folderName = "" } }
        } message: {
            Text("Create a folder on \(model.selectedStorage?.info.storageDescription ?? "the device").")
        }
        .alert("Rename Item", isPresented: $showRenamePrompt) {
            TextField("Name", text: $renameName)
            Button("Cancel", role: .cancel) { itemToRename = nil }
            Button("Rename") {
                guard let itemToRename else { return }
                perform { try await model.rename(itemToRename, to: renameName); self.itemToRename = nil }
            }
        }
        .confirmationDialog("Delete selected items?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete \(model.selectedItems.count) Item(s)", role: .destructive) {
                perform { try await model.deleteSelectedItems() }
            }
        } message: {
            Text("This permanently deletes the selected items from the Android device.")
        }
        .alert("OpenMTP", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(model.lastError ?? "The operation could not be completed.")
        }
    }

    private var title: String {
        if model.selection != .overview { return model.selection?.rawValue ?? "OpenMTP" }
        return path.last ?? model.selectedStorage?.info.storageDescription ?? "Files"
    }

    private var toolbar: some ToolbarContent {
        @Bindable var model = model
        ToolbarItemGroup(placement: .navigation) {
            Button { if !path.isEmpty { path.removeLast() } } label: { Image(systemName: "chevron.left") }
                .disabled(path.isEmpty || !model.isConnected)
                .help("Back")
            Button { Task { await model.loadDirectory(path: devicePath(path)) } } label: { Image(systemName: "arrow.clockwise") }
                .disabled(!model.isConnected || model.isConnecting)
                .help("Refresh")
        }
        ToolbarItem(placement: .principal) {
            Text(title).font(.headline).lineLimit(1)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: chooseUploadFiles) { Label("Add to Device", systemImage: "square.and.arrow.down") }
                .disabled(!model.isConnected || model.selectedStorageID == nil)
                .help("Copy files from this Mac to the device")
            Button(action: chooseDownloadLocation) { Label("Copy to Mac", systemImage: "square.and.arrow.up") }
                .disabled(!model.isConnected || model.selectedItems.isEmpty)
                .help("Copy selected device files to this Mac")
            Button { showFolderPrompt = true } label: { Image(systemName: "folder.badge.plus") }
                .disabled(!model.isConnected || model.selectedStorageID == nil)
                .help("New Folder")
            Menu {
                Picker("Sort by", selection: $model.sorting) {
                    ForEach(["Name", "Kind", "Size", "Date Modified"], id: \.self) { Text($0) }
                }
                Divider()
                Toggle("Show Hidden Files", isOn: $model.showHiddenFiles)
            } label: { Image(systemName: "arrow.up.arrow.down") }
                .help("Sort and Display")
            Button { model.layout = .list } label: { Image(systemName: "list.bullet") }
                .help("List View")
            Button { model.layout = .grid } label: { Image(systemName: "square.grid.2x2") }
                .help("Icon View")
            Button { model.inspectorVisible.toggle() } label: { Image(systemName: "sidebar.right") }
                .help("Toggle Inspector")
        }
    }

    private var sidebar: some View {
        List {
            Section("Devices") {
                HStack(spacing: 9) {
                    Image(systemName: "iphone.gen3").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.deviceName).fontWeight(.semibold).lineLimit(1)
                        Text(model.isConnected ? "Android · USB" : "Not connected")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if model.isConnecting { ProgressView().controlSize(.small) }
                }
                if model.isConnected {
                    ForEach(model.storages) { storage in
                        Button {
                            model.selection = .overview
                            path = []
                            Task { await model.selectStorage(storage.sid) }
                        } label: {
                            Label(storage.info.storageDescription ?? "Storage", systemImage: storage.sid == model.selectedStorageID ? "internaldrive.fill" : "internaldrive")
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 18)
                    }
                } else {
                    Text(model.connectionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Section("Activity") {
                ForEach([BrowserSection.transfers, .recent]) { section in
                    Button { model.selection = section } label: {
                        Label(section.rawValue, systemImage: section.symbol)
                            .foregroundStyle(model.selection == section ? Color.accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Section("This Mac") {
                Label(NSHomeDirectory(), systemImage: "house")
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Circle().fill(model.isConnected ? .green : .secondary).frame(width: 7, height: 7)
                Text(model.isConnected ? "Device connected" : "Waiting for device")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { Task { await model.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .help("Reconnect")
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
    }

    private var deviceHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 27, weight: .thin))
                .foregroundStyle(.secondary)
                .frame(width: 42, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.deviceName).font(.title3.weight(.semibold))
                Text(model.connectionMessage).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 7) {
                Text(model.storageSummary).font(.caption).foregroundStyle(.secondary)
                if let storage = model.selectedStorage,
                   let free = storage.info.freeSpaceInBytes,
                   let total = storage.info.maxCapacity, total > 0 {
                    ProgressView(value: Double(total - min(total, free)), total: Double(total))
                        .frame(width: 180)
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 15)
    }

    @ViewBuilder private var content: some View {
        if model.selection == .transfers {
            TransfersView()
        } else if model.selection == .recent {
            recentView
        } else if !model.isConnected {
            ContentUnavailableView {
                Label("Connect an Android Device", systemImage: "cable.connector")
            } description: {
                Text(model.connectionMessage)
            } actions: {
                Button(model.isConnecting ? "Searching…" : "Try Again") { Task { await model.refresh() } }
                    .disabled(model.isConnecting)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text(path.last ?? model.selectedStorage?.info.storageDescription ?? "Files")
                        .font(.title2.weight(.semibold))
                    Text("\(model.filteredItems.count) items").foregroundStyle(.tertiary).font(.subheadline)
                    Spacer()
                    Button { model.transferQueueVisible.toggle() } label: { Label("Transfer Queue", systemImage: "arrow.left.arrow.right") }
                        .buttonStyle(.borderless)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 17)

                if let error = model.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .padding()
                }

                if model.layout == .list {
                    FileListView(
                        path: $path,
                        onRename: beginRename,
                        onDelete: { showDeleteConfirmation = true },
                        onDownload: chooseDownloadLocation
                    )
                } else {
                    FileGridView(path: $path)
                }
                if model.transferQueueVisible { transferFooter }
            }
        }
    }

    private var recentView: some View {
        List(model.recentActivity, id: \.self) { activity in
            Label(activity, systemImage: "clock")
        }
        .overlay {
            if model.recentActivity.isEmpty {
                ContentUnavailableView("No Recent Activity", systemImage: "clock", description: Text("Completed file operations will appear here."))
            }
        }
    }

    private var transferFooter: some View {
        HStack(spacing: 11) {
            Image(systemName: "arrow.left.arrow.right.circle").font(.title3).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Transfer Queue").font(.subheadline.weight(.medium))
                Text(queueDetail)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if let item = model.transferQueue.first, case .running = item.state {
                ProgressView(value: item.progress).frame(width: 100)
            } else {
                Text(model.isConnected ? "Ready" : "Disconnected").font(.caption).foregroundStyle(.tertiary)
            }
            Button { model.transferQueueVisible = false } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless).foregroundStyle(.secondary).help("Hide Transfer Queue")
        }
        .padding(.horizontal, 23)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var queueStatus: String {
        guard let item = model.transferQueue.first else { return "No transfers" }
        switch item.state {
        case .running: return "Preparing transfer…"
        case .complete: return "Latest transfer completed"
        case .failed(let error): return error
        }
    }

    private var queueDetail: String {
        guard let item = model.transferQueue.first, !item.currentFile.isEmpty else { return queueStatus }
        return item.currentFile
    }

    private var statusBar: some View {
        HStack {
            Text("\(model.selectedItems.count) selected")
            Spacer()
            Text(model.isConnected ? "OpenMTP Native · \(model.deviceName)" : "OpenMTP Native")
        }
        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.vertical, 8)
    }

    private func devicePath(_ components: [String]) -> String {
        components.isEmpty ? "/" : "/" + components.joined(separator: "/")
    }

    private func chooseUploadFiles() {
        let panel = NSOpenPanel()
        panel.title = "Choose files to copy to the device"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        Task { await model.upload(panel.urls) }
    }

    private func chooseDownloadLocation() {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder on this Mac"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        Task { await model.downloadSelected(to: directory) }
    }

    private func beginRename(_ item: BrowserItem) {
        itemToRename = item
        renameName = item.name
        showRenamePrompt = true
    }

    private func perform(_ operation: @escaping () async throws -> Void) {
        Task {
            do { try await operation() }
            catch {
                model.lastError = error.localizedDescription
                showError = true
            }
        }
    }
}
