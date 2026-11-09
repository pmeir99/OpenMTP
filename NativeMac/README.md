# OpenMTP Native — macOS 27 app

A separate, fully native SwiftUI + AppKit app for macOS 27 and later. It uses the existing OpenMTP Kalam MTP engine for USB device discovery, storage and directory browsing, and file operations.

## Scope

- Connects to Android devices over USB using the repository's macOS 27 compatible Kalam shared library.
- Lists actual MTP storage and files, supports hidden-file filtering, folder creation, rename and delete, and upload/download with progress.
- Runs the MTP calls serially through Kalam because its engine maintains one shared USB session.
- The Actions workflow bundles the ARM64 Kalam and libusb libraries inside the app and creates a `.dmg`.
- The existing Electron app and backend remain available as before.
- The native app is still an initial layout and feature port, not complete screen-by-screen parity. It has not yet been exercised with a physical Android device in this environment.

## Local preview

Requires Xcode 27+ and the macOS 27 SDK.

```bash
cd NativeMac
swift run OpenMTPNative
```

Connect an unlocked Android device, select **USB File Transfer** on the device, and keep it awake during transfers. The app retries device discovery every six seconds. To download the installer, open **Actions → Build Native macOS UI** and download `OpenMTPNative-macOS` from a successful run's Artifacts. Unzip the artifact to get a DMG. This version is ad-hoc signed, not Developer ID signed or notarized, so macOS Gatekeeper may warn when opening it.

## Design direction

Finder-style sidebar, live storage selector, responsive file list and icon grid, toolbar search and view controls, native inspector, transfer queue, storage summary and settings.

## Next engineering steps

1. Exercise discovery and every operation against real Android models, including disconnects and USB permission prompts.
2. Add local-folder browsing and drag-and-drop between device and Mac.
3. Audit every original OpenMTP screen and action for UI parity.
4. Compare edge cases against the existing Electron file explorer and harden recovery for device resets and partial transfers.
