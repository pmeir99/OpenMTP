import SwiftUI

struct TransfersView: View {
    @Environment(BrowserModel.self) private var model

    var body: some View {
        List(model.transferQueue) { transfer in
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: transfer.direction == .upload ? "arrow.down.to.line" : "arrow.up.to.line")
                        .foregroundStyle(.secondary)
                    Text(transfer.title).fontWeight(.medium)
                    Spacer()
                    switch transfer.state {
                    case .running: Text("Transferring").foregroundStyle(.secondary)
                    case .complete: Label("Complete", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    case .failed: Label("Failed", systemImage: "exclamationmark.circle.fill").foregroundStyle(.red)
                    }
                }
                if case .running = transfer.state {
                    ProgressView(value: transfer.progress)
                    HStack {
                        Text(transfer.currentFile.isEmpty ? "Preparing…" : transfer.currentFile)
                        Spacer()
                        if transfer.speed > 0 { Text(String(format: "%.1f MB/s", transfer.speed)) }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                if case .failed(let message) = transfer.state {
                    Text(message).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(.vertical, 5)
        }
        .overlay {
            if model.transferQueue.isEmpty {
                ContentUnavailableView("No Transfers", systemImage: "arrow.left.arrow.right", description: Text("Uploads and downloads will appear here."))
            }
        }
    }
}

struct PreferencesView: View {
    @Environment(BrowserModel.self) private var model
    @State private var selectedTab = 0

    var body: some View {
        @Bindable var model = model
        TabView(selection: $selectedTab) {
            Form {
                LabeledContent("Appearance") {
                    Text("System").foregroundStyle(.secondary)
                }
                Picker("Default View", selection: $model.layout) {
                    ForEach(BrowserLayout.allCases, id: \.self) { layout in
                        Text(layout.rawValue).tag(layout)
                    }
                }
                Toggle("Show Hidden Files", isOn: $model.showHiddenFiles)
            }
            .padding(20)
            .tabItem { Label("General", systemImage: "gearshape") }.tag(0)

            Form {
                LabeledContent("Transfer Engine", value: model.isConnected ? "Kalam MTP" : "Waiting for device")
                Text("Connect an Android device over USB and select File Transfer mode to browse its storage.")
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .tabItem { Label("Transfers", systemImage: "arrow.left.arrow.right") }.tag(1)

            VStack(spacing: 10) {
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("OpenMTP").font(.headline)
                Text("Native macOS file transfer")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("OpenMTP original project is MIT licensed.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem { Label("About", systemImage: "info.circle") }.tag(2)
        }
        .frame(width: 520, height: 320)
    }
}
