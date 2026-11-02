import SwiftUI

@main
struct OpenMTPNativeApp: App {
    @State private var model = BrowserModel()

    var body: some Scene {
        WindowGroup {
            BrowserWindow()
                .environment(model)
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultSize(width: 1260, height: 790)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    NSApplication.shared.sendAction(#selector(NSWindow.makeKeyAndOrderFront(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            PreferencesView()
                .environment(model)
        }
    }
}
