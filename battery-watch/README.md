# Battery Watch

Battery Watch is a native macOS menu bar utility that checks trusted iPhones and known AirPods every 15 minutes. It sends a notification when a reported battery level drops below 25% and does not alert again until that battery recovers.

iPhones are queried over Wi-Fi with `libimobiledevice`. AirPods battery levels come from macOS Bluetooth data and may be stale while the case is closed or away from the Mac.

## Setup

1. Install the iPhone tools with `brew install libimobiledevice`.
2. Connect the iPhone to the Mac once, tap **Trust**, and enable **Show this iPhone when on Wi-Fi** in Finder.
3. Build and open Battery Watch, then allow notifications.

## Build

Requirements: macOS 14 or later, Xcode, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -project BatteryWatch.xcodeproj -scheme BatteryWatch -configuration Debug build
```
