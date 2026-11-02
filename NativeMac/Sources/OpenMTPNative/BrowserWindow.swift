import SwiftUI
import AppKit

struct BrowserWindow: View {
    @Environment(BrowserModel.self) private var model
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var path: [String] = []

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
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button { if !path.isEmpty { path.removeLast() } } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(path.isEmpty)
                    .help("Back")
                    Button { } label: { Image(systemName: "chevron.right") }
                        .disabled(true)
                        .help("Forward")
                }
                ToolbarItem(placement: .principal) {
                    Text(title).font(.headline).lineLimit(1)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { model.layout = .list } label: { Image(systemName: "list.bullet") }
                        .help("List View")
                        .disabled(model.layout == .list)
                    Button { model.layout = .grid } label: { Image(systemName: "square.grid.2x2") }
                        .help("Icon View")
                        .disabled(model.layout == .grid)
                    Menu {
                        Picker("Sort by", selection: $model.sorting) {
                            ForEach(["Name", "Kind", "Size", "Date Modified"], id: \.self) { Text($0) }
                        }
                        Divider()
                        Toggle("Show Hidden Files", isOn: $model.showHiddenFiles)
                    } label: { Image(systemName: "arrow.up.arrow.down") }
                        .help("Sort and Display")
                    Button { model.inspectorVisible.toggle() } label: {
                        Image(systemName: "sidebar.right")
                    }
                    .help("Toggle Inspector")
                }
            }
            .searchable(text: $model.search, placement: .toolbar, prompt: "Search files")
            .inspector(isPresented: $model.inspectorVisible) { InspectorView() }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var title: String {
        path.last ?? model.selection?.rawValue ?? "OpenMTP"
    }

    private var sidebar: some View {
        List(selection: Binding(get: { model.selection }, set: { model.selection = $0; path = []; model.selectedItems = [] })) {
            Section("Devices") {
                Label("Pixel 9 Pro", systemImage: "iphone.gen3")
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                ForEach([BrowserSection.overview, .internalStorage, .sdCard]) { section in
                    Label(section.rawValue, systemImage: section.symbol)
                        .tag(section)
                }
            }
            Section("Activity") {
                ForEach([BrowserSection.transfers, .recent]) { section in
                    Label(section.rawValue, systemImage: section.symbol)
                        .tag(section)
                }
            }
            Section("Locations") {
                Label("This Mac", systemImage: "desktopcomputer")
                Label("Home", systemImage: "house")
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 9) {
                Circle().fill(.green).frame(width: 7, height: 7)
                Text("Preview device connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
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
                Text("Pixel 9 Pro").font(.title3.weight(.semibold))
                Text("Android device  ·  USB  ·  UI preview")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("89.4 GB available of 256 GB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule().fill(.blue.gradient).frame(width: proxy.size.width * 0.65)
                    }
                }
                .frame(width: 180, height: 6)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 15)
    }

    @ViewBuilder private var content: some View {
        if model.selection == .transfers {
            TransfersView()
        } else if model.selection == .recent {
            ContentUnavailableView("No Recent Activity", systemImage: "clock", description: Text("Recent operations will appear here when a transfer backend is connected."))
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text(path.isEmpty ? "Files" : title)
                        .font(.title2.weight(.semibold))
                    Text("\(model.filteredItems.count) items")
                        .foregroundStyle(.tertiary)
                        .font(.subheadline)
                    Spacer()
                    Button {
                        model.transferQueueVisible.toggle()
                    } label: { Label("Transfer Queue", systemImage: "arrow.left.arrow.right") }
                        .buttonStyle(.borderless)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 17)

                if model.layout == .list {
                    FileListView(path: $path)
                } else {
                    FileGridView(path: $path)
                }
                if model.transferQueueVisible { transferFooter }
            }
        }
    }

    private var transferFooter: some View {
        HStack(spacing: 11) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Transfer Queue").font(.subheadline.weight(.medium))
                Text("No active transfers").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("Preview mode")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button { model.transferQueueVisible = false } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Hide Transfer Queue")
        }
        .padding(.horizontal, 23)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var statusBar: some View {
        HStack {
            Text("\(model.selectedItems.count) selected")
            Spacer()
            Text("OpenMTP Native · Design Preview")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}
