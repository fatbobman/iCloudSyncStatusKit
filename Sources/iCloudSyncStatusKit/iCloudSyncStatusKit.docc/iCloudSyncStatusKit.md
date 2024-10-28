# ``iCloudSyncStatusKit``

A Swift library that monitors the iCloud account status and responds to synchronization events when using Core Data with CloudKit. It leverages the new Observation framework in iOS 17 and macOS 14, with compatibility for older OS versions using `ObservableObject`.

## Features

- **Account Status Monitoring**: Check if the iCloud account is available and handle unavailable states.
- **Synchronization Event Handling**: Monitor importing, exporting, setup, and idle states during data synchronization.
- **Error Handling**: Handle specific CloudKit errors, such as `quotaExceeded`.
- **Logging Support**: Optional logging of synchronization events for debugging purposes.

## Usage

### Import the Library

```swift
import SyncStatusManager
```

### Initialize SyncStatusManager

```swift
@StateObject var syncManager = SyncStatusManager()
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




