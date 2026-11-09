import SwiftUI

struct FileListView: View {
    @Environment(BrowserModel.self) private var model
    @Binding var path: [String]
    var onRename: (BrowserItem) -> Void
    var onDelete: () -> Void
    var onDownload: () -> Void

    var body: some View {
        @Bindable var model = model
        Table(model.filteredItems, selection: $model.selectedItems) {
            TableColumn("Name") { item in
                HStack(spacing: 10) {
                    Image(systemName: item.symbol)
                        .foregroundStyle(item.tint)
                        .font(.system(size: 20))
                        .frame(width: 25)
                    Text(item.name).lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    if item.isFolder { path.append(item.name) }
                }
            }
            .width(min: 240, ideal: 400)
            TableColumn("Date Modified") { item in
                Text(item.modified).foregroundStyle(.secondary)
            }
            .width(min: 130, ideal: 170)
            TableColumn("Kind") { item in
                Text(item.kind).foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 140)
            TableColumn("Size") { item in
                Text(item.size).foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: String.self) { ids in
            Button("Open") {
                guard let item = model.items.first(where: { ids.contains($0.id) && $0.isFolder }) else { return }
                model.selectedItems = [item.id]
                path.append(item.name)
            }
            .disabled(!model.items.contains(where: { ids.contains($0.id) && $0.isFolder }))
            Button("Get Info") {
                model.selectedItems = Set(ids)
                model.inspectorVisible = true
            }
            Divider()
            Button("Copy to Mac") {
                model.selectedItems = Set(ids)
                onDownload()
            }
                .disabled(ids.isEmpty)
            Button("Rename") {
                guard let item = model.items.first(where: { ids.contains($0.id) }) else { return }
                model.selectedItems = [item.id]
                onRename(item)
            }
            .disabled(ids.count != 1)
            Button("Delete", role: .destructive) {
                model.selectedItems = Set(ids)
                onDelete()
            }
                .disabled(ids.isEmpty)
        }
    }
}

struct FileGridView: View {
    @Environment(BrowserModel.self) private var model
    @Binding var path: [String]
    var onRename: (BrowserItem) -> Void
    var onDelete: () -> Void
    var onDownload: () -> Void
    private let columns = [GridItem(.adaptive(minimum: 112, maximum: 155), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(model.filteredItems) { item in
                    Button {
                        if model.selectedItems.contains(item.id) {
                            model.selectedItems.remove(item.id)
                        } else {
                            model.selectedItems.insert(item.id)
                        }
                    } label: {
                        VStack(spacing: 9) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 48, weight: .light))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(item.tint)
                                .frame(height: 70)
                            Text(item.name)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(model.selectedItems.contains(item.id) ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture(count: 2).onEnded {
                        if item.isFolder {
                            model.selectedItems = [item.id]
                            path.append(item.name)
                        }
                    })
                    .contextMenu {
                        Button("Open") {
                            model.selectedItems = [item.id]
                            if item.isFolder { path.append(item.name) }
                        }
                        .disabled(!item.isFolder)
                        Button("Get Info") {
                            model.selectedItems = [item.id]
                            model.inspectorVisible = true
                        }
                        Divider()
                        Button("Copy to Mac") {
                            model.selectedItems = [item.id]
                            onDownload()
                        }
                        Button("Rename") {
                            model.selectedItems = [item.id]
                            onRename(item)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            model.selectedItems = [item.id]
                            onDelete()
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

struct InspectorView: View {
    @Environment(BrowserModel.self) private var model

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 53, weight: .ultraLight))
                .foregroundStyle(.secondary)
                .padding(.top, 28)
            Text("Information")
                .font(.title3.weight(.semibold))
            Text(model.selectedItems.isEmpty ? "Select a file to inspect its details." : "\(model.selectedItems.count) item(s) selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Divider()
            LabeledContent("Device", value: model.deviceName)
            LabeledContent("Connection", value: model.isConnected ? "USB · MTP" : "Not connected")
            if model.selectedBrowserItems.count == 1, let item = model.selectedBrowserItems.first {
                LabeledContent("Name", value: item.name)
                LabeledContent("Kind", value: item.kind)
                if !item.isFolder { LabeledContent("Size", value: item.size) }
                LabeledContent("Modified", value: item.modified)
                LabeledContent("Path", value: item.path)
            }
            Spacer()
        }
        .padding(22)
        .frame(minWidth: 240, idealWidth: 280)
        .inspectorColumnWidth(min: 240, ideal: 280, max: 340)
    }
}
