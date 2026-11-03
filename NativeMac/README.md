# OpenMTP Native — UI Preview

A separate, **fully native SwiftUI + AppKit UI prototype** for macOS 27 and later. Its visual design uses system navigation, sidebar materials, controls, typography, SF Symbols, native tables, the system inspector, and native toolbar/search. macOS supplies Liquid Glass appearance to supported system surfaces.

## Scope

- **UI only**. Fake example device and file data are clearly identified in the app.
- **No USB, MTP, file writes, or file transfers.**
- The original Electron OpenMTP source and backend remain untouched.
- Built as a Swift Package executable; the Actions workflow wraps it into a standard `.app` bundle and `.dmg` disk image.
- This is an initial functional layout prototype, not a complete parity recreation of every original OpenMTP screen.
- GitHub Actions has compiled and packaged the UI prototype successfully. The current branch continues to build after the follow-up fixes. The app has not been visually tested on a Mac desktop.

## Local preview

Requires Xcode 27+ and the macOS 27 SDK.

```bash
cd NativeMac
swift run OpenMTPNative
```

To download the installer, open **Actions → Build Native macOS UI** and download `OpenMTPNative-macOS` from the successful run's Artifacts. Unzip the artifact to get a DMG. This version is ad-hoc signed, not Developer ID signed or notarized, so macOS Gatekeeper may warn when opening it.

## Design direction

Finder-style sidebar, responsive file list and icon grid, toolbar search and view controls, native inspector, transfer queue drawer, storage summary and an uncluttered settings window. Interface-only placeholders are never presented as working transfer features.

## Next engineering steps

1. Visually inspect the prototype on a macOS 27 desktop and polish the interactions.
2. Audit every original OpenMTP screen and action for UI parity.
3. Implement proper navigation state and advanced interactions for file selections, drag-and-drop, folders and keyboard shortcuts using sample data.
4. After acceptance, bridge to the existing MTP backend in a separate change.
