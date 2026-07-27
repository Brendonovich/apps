# Input Guard

Input Guard is a native macOS menu bar utility that prevents selected audio input devices from remaining the system default.

When macOS changes the default input to an excluded device, Input Guard immediately restores the last allowed input device. Exclusions are stored using Core Audio device UIDs, so they persist when devices are disconnected.

## Build

Requirements: macOS 14 or later, Xcode, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -project InputGuard.xcodeproj -scheme InputGuard -configuration Debug build
```

The app automatically requests registration as a login item on first launch. This can be changed in the Input Guard window.
