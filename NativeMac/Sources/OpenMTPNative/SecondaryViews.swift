import SwiftUI

struct TransfersView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Transfer Queue", systemImage: "arrow.left.arrow.right")
        } description: {
            Text("Your file transfers and their progress will appear here. This native UI preview does not connect to the existing MTP backend.")
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
                LabeledContent("Transfer Engine", value: "Not connected")
                Text("Transfer settings will become available when the native UI is connected to the original OpenMTP backend.")
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .tabItem { Label("Transfers", systemImage: "arrow.left.arrow.right") }.tag(1)

            VStack(spacing: 10) {
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("OpenMTP Native").font(.headline)
                Text("UI concept for macOS 26 and later")
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
