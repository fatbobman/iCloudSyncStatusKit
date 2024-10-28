# iCloudSyncStatusKit

A Swift library that monitors the iCloud account status and responds to synchronization events when using Core Data with CloudKit. It leverages the new Observation framework in iOS 17 and macOS 14, with compatibility for older OS versions using `ObservableObject`.

## Features

- **Account Status Monitoring**: Check if the iCloud account is available and handle unavailable states.
- **Synchronization Event Handling**: Monitor importing, exporting, setup, and idle states during data synchronization.
- **Error Handling**: Handle specific CloudKit errors, such as `quotaExceeded`.
- **Compatibility**: Uses the Observation framework on iOS 17 and above; compatible with `ObservableObject` on older versions.
- **Logging Support**: Optional logging of synchronization events for debugging purposes.

## Requirements

- **Swift** 6
- **iOS** 14.0 or later
- **macOS** 11 or later

## Installation

### Swift Package Manager

Add the package to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/fatbobman/iCloudSyncStatusKit.git", from: "0.1.0")
]
```

Or add it via Xcode:

1. Go to **File > Add Packages...**
2. Enter the repository URL: `https://github.com/fatbobman/iCloudSyncStatusKit.git`
3. Choose the version and add the package to your project.

## Usage

### Import the Library

```swift
import SyncStatusManager
```

### Initialize SyncStatusManager

You can initialize `SyncStatusManager` using either `@StateObject` or `@State`, depending on your needs. Even on iOS 17 and above, using `@StateObject` does not affect the Observation features.

#### Using @StateObject

```swift
@StateObject var syncManager = SyncStatusManager()
```

#### Using @State (iOS 17 and above)

```swift
@State var syncManager = SyncStatusManager()
```

### Observing Sync Events

You can observe `syncEvent` to monitor the synchronization status.

#### SwiftUI View Example

```swift
struct ContentView: View {
    @StateObject var syncManager = SyncStatusManager()

    var body: some View {
        VStack {
            Text("Sync Event: \(syncManager.syncEvent)")
            // Your UI components
            Button("Check iCloud Status") {
                Task {
                    let status = await syncManager.validateICloudAvailability { status, error in
                        print("Status: \(status)")
                        if let error = error {
                            print("Error: \(error)")
                        }
                    }
                    if let status = status {
                        print("iCloud Account Status: \(status)")
                    }
                }
            }
        }
    }
}
```

### Checking iCloud Availability

Use the `validateICloudAvailability` method to check the iCloud account status:

```swift
Task {
    let status = await syncManager.validateICloudAvailability { status, error in
        print("Account Status: \(status)")
        if let error = error {
            print("Error: \(error.localizedDescription)")
        }
    }
    if status == .available {
        // Proceed with synchronization
    } else {
        // Handle unavailable iCloud account
    }
}
```

### Handling Quota Exceeded

Provide a `quotaExceededHandler` when initializing `SyncStatusManager`:

```swift
let syncManager = SyncStatusManager(
    quotaExceededHandler: {
        // Notify the user about the quota issue
    }
)
```

### Logging Synchronization Events

If you want to log synchronization events for debugging purposes, set `showEventInLog` to `true` and provide a logger that conforms to `LoggerManagerProtocol`:

```swift
let syncManager = SyncStatusManager(
    logger: YourLoggerInstance, // Conforming to LoggerManagerProtocol
    showEventInLog: true
)
```

## Notes

- **Observation Framework**: Even though `SyncStatusManager` uses the Observation framework on iOS 17 and above, you can safely use `@StateObject` without affecting its functionality.
- **Backward Compatibility**: The library is designed to work seamlessly across different iOS versions, abstracting away the differences between the Observation framework and `ObservableObject`.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [General Findings About NSPersistentCloudKitContainer](https://crunchybagel.com/nspersistentcloudkitcontainer/)

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/fatbobman)
