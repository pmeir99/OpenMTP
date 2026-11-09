# OpenMTP Native — macOS 27 app

The native SwiftUI + AppKit macOS app. macOS start and package commands now select this UI by default; Electron remains a fallback for the Linux and Windows builds. The app uses OpenMTP's Kalam MTP engine for USB device discovery, storage and directory browsing, and file operations.

## Scope

- Connects to Android devices over USB using the repository's macOS 27 compatible Kalam shared library.
- Lists actual MTP storage and files, supports hidden-file filtering, folder creation, rename and delete, and upload/download with progress.
- Runs the MTP calls serially through Kalam because its engine maintains one shared USB session.
- The macOS package bundles the ARM64 Kalam and libusb libraries, a generated liquid-glass app icon, and an installable `.dmg`.
- The native interface uses Apple SF Symbols for all in-app symbols and controls.
- The Electron interface remains available as a development and non-macOS fallback; it is no longer selected by the macOS start and package commands.
- The native UI still lacks local-folder browsing and drag-and-drop. Physical device operations still need validation with Android hardware.

## Local preview

Requires Xcode 27+ and the macOS 27 SDK.

```bash
yarn start-native-mac
```

Connect an unlocked Android device and select **USB File Transfer**. The app retries discovery, checks a connected device for removal, and clears stale selection when the connection drops. Run `yarn package-mac` to create the app and `.dmg`. The CI artifact is also available under **Actions → Build Native macOS UI**. This build is ad-hoc signed, not Developer ID signed or notarized, so macOS Gatekeeper may warn when opening it.

## Design direction

Finder-style sidebar, live storage selector, responsive file list and icon grid, toolbar search and view controls, native inspector, transfer queue, storage summary and settings.

## Next engineering steps

1. Exercise discovery and every operation against real Android models, including disconnects and USB permission prompts.
2. Add local-folder browsing and drag-and-drop between device and Mac.
3. Compare remaining file-operation and settings details against the legacy interface.
4. Harden recovery for device resets, duplicate names, and partial transfers.
