# OpenMTP Native — UI Preview

A separate, **fully native SwiftUI + AppKit UI prototype** for macOS 26 and later. Its visual design uses system navigation, sidebar materials, controls, typography, SF Symbols, native tables, the system inspector, and native toolbar/search. macOS supplies Liquid Glass appearance to supported system surfaces.

## Scope

- **UI only**. Fake example device and file data are clearly identified in the app.
- **No USB, MTP, file writes, or file transfers.**
- The original Electron OpenMTP source and backend remain untouched.
- Built as a Swift Package executable; the Actions workflow wraps it into a standard `.app` bundle and `.dmg` disk image.
- This is an initial functional layout prototype, not a complete parity recreation of every original OpenMTP screen.
- No claim is made that the UI has been compiled or visually tested until a GitHub macOS runner finishes the build.

## Local preview

Requires Xcode with Swift 6.2+ and the macOS 26 SDK.

```bash
cd NativeMac
swift run OpenMTPNative
```

To generate a distributable archive use **Actions → Build Native macOS UI → Run workflow**. Download `OpenMTPNative-macOS` from Artifacts when completed. Unzip the artifact to get a DMG. This version is not Developer ID signed or notarized, so macOS Gatekeeper may warn when opening it.

## Design direction

Finder-style sidebar, responsive file list and icon grid, toolbar search and view controls, native inspector, transfer queue drawer, storage summary and an uncluttered settings window. Interface-only placeholders are never presented as working transfer features.

## Next engineering steps

1. Use the macOS CI compiler and SwiftUI previews to repair compatibility and polish interactions.
2. Audit every original OpenMTP screen and action for UI parity.
3. Implement proper navigation state and advanced interactions for file selections, drag-and-drop, folders and keyboard shortcuts using sample data.
4. After acceptance, bridge to the existing MTP backend in a separate change.
