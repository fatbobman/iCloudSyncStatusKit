# iCloudSyncStatusKit

A Swift library that monitors iCloud account status, network connectivity, iCloud Drive availability, and synchronization events when using Core Data with CloudKit.

## Features

- **Network Status Monitoring**: Real-time network connectivity detection with interface type (WiFi/Cellular/Ethernet)
- **Account Status Monitoring**: Check if the iCloud account is available and handle unavailable states
- **iCloud Drive Detection**: Monitor iCloud Drive availability separately from account status
- **Synchronization Event Handling**: Monitor importing, exporting, setup, and idle states during data synchronization
- **Selective Monitoring**: Use `MonitoringOptions` to enable only the features you need
- **Error Handling**: Handle specific CloudKit errors, such as `quotaExceeded`
- **Low Data Mode Detection**: Detect constrained and expensive network conditions
- **Logging Support**: Optional logging of synchronization events for debugging purposes

## Requirements

| API | Swift | iOS | macOS | watchOS | tvOS | visionOS |
|-----|-------|-----|-------|---------|------|----------|
| `SyncStatusAsyncManager` (Modern) | 6.2+ | 17.0+ | 14.0+ | 10.0+ | 17.0+ | 1.0+ |
| `SyncStatusManager` (Legacy) | 6.0+ | 14.0+ | 11.0+ | - | - | - |

## Installation

### Swift Package Manager

Add the package to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/fatbobman/iCloudSyncStatusKit.git", from: "1.0.0")
]
```

Or add it via Xcode:

1. Go to **File > Add Packages...**
2. Enter the repository URL: `https://github.com/fatbobman/iCloudSyncStatusKit.git`
3. Choose the version and add the package to your project.

---

## Modern API (iOS 17+, Swift 6.2+)

### SyncStatusAsyncManager

The modern API uses the **Observation** framework and **async/await** for reactive state management.

### Import the Library

```swift
import iCloudSyncStatusKit
```

### Initialize SyncStatusAsyncManager

```swift
// Full monitoring (default)
@State private var syncManager = SyncStatusAsyncManager(
    cloudKitContainerID: "iCloud.com.yourcompany.yourapp"
)

// Selective monitoring with MonitoringOptions
@State private var syncManager = SyncStatusAsyncManager(
    monitoringOptions: [.network, .account, .cloudDrive],
    cloudKitContainerID: "iCloud.com.yourcompany.yourapp"
)
```

### MonitoringOptions

Control which status types to monitor using `MonitoringOptions`:

```swift
// Individual options
.network      // Network connectivity via NWPathMonitor
.account      // iCloud account status
.syncEvent    // CloudKit sync events (requires cloudKitContainerID)
.cloudDrive   // iCloud Drive availability

// Preset combinations
.all          // All options enabled
.basic        // Network + Account only (lightweight)
.default      // Network + Account + CloudDrive
.syncFocused  // Network + Account + SyncEvent
```

**Usage Example:**

```swift
// Only monitor network and account (no CloudKit sync events)
let manager = SyncStatusAsyncManager(
    monitoringOptions: .basic
)

// Full monitoring for CloudKit-enabled apps
let manager = SyncStatusAsyncManager(
    monitoringOptions: .all,
    cloudKitContainerID: "iCloud.com.yourcompany.yourapp"
)
```

### Basic Usage with SwiftUI

```swift
struct ContentView: View {
    @State private var syncManager = SyncStatusAsyncManager(
        monitoringOptions: .all,
        cloudKitContainerID: "iCloud.com.yourcompany.yourapp"
    )

    var body: some View {
        VStack(spacing: 16) {
            // Network Status
            HStack {
                Image(systemName: syncManager.isNetworkConnected ? "wifi" : "wifi.slash")
                Text(syncManager.isNetworkConnected ? "Connected" : "Disconnected")
            }

            // Account Status
            HStack {
                Image(systemName: syncManager.isAccountAvailable ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.xmark")
                Text(syncManager.isAccountAvailable ? "iCloud Available" : "iCloud Unavailable")
            }

            // iCloud Drive Status
            HStack {
                Image(systemName: syncManager.isCloudDriveAvailable ? "icloud.fill" : "icloud.slash")
                Text(syncManager.isCloudDriveAvailable ? "iCloud Drive On" : "iCloud Drive Off")
            }

            // Sync Status
            if syncManager.isSyncing {
                ProgressView("Syncing...")
            }

            // Comprehensive Status
            if syncManager.environmentStatus.isSyncReady {
                Text("✅ Ready to sync")
                    .foregroundStyle(.green)
            }
        }
    }
}
```

### Available Properties

| Property | Type | Description |
|----------|------|-------------|
| `networkStatus` | `NetworkStatus` | Detailed network status including interface type |
| `accountStatus` | `AccountStatus` | iCloud account availability status |
| `syncEvent` | `SyncEvent` | Current sync event (importing/exporting/setup/idle) |
| `isCloudDriveAvailable` | `Bool` | Whether iCloud Drive is enabled |
| `environmentStatus` | `SyncEnvironmentStatus` | Combined status with convenience properties |
| `isNetworkConnected` | `Bool` | Simple network connectivity check |
| `isAccountAvailable` | `Bool` | Simple account availability check |
| `isSyncing` | `Bool` | Whether sync is in progress |
| `monitoringOptions` | `MonitoringOptions` | Current monitoring configuration |

### iCloud Drive vs iCloud Account

**Important**: iCloud Drive availability is separate from iCloud account status.

```swift
// User may have iCloud account available but iCloud Drive disabled
if syncManager.isAccountAvailable && !syncManager.isCloudDriveAvailable {
    // Account is signed in, but iCloud Drive is turned off in Settings
    print("Please enable iCloud Drive in Settings")
}
```

| Scenario | `isAccountAvailable` | `isCloudDriveAvailable` |
|----------|---------------------|------------------------|
| Not signed in | ❌ | ❌ |
| Signed in, Drive off | ✅ | ❌ |
| Signed in, Drive on | ✅ | ✅ |

### NetworkStatus Details

```swift
// Check network interface type
switch syncManager.networkStatus.connectivity {
case .connected(.wifi):
    print("Connected via WiFi")
case .connected(.cellular):
    print("Connected via Cellular")
case .connected(.wiredEthernet):
    print("Connected via Ethernet")
case .disconnected:
    print("No network connection")
default:
    break
}

// Check network conditions
if syncManager.networkStatus.isConstrained {
    print("Low Data Mode is enabled")
}

if syncManager.networkStatus.isExpensive {
    print("Using expensive connection (cellular/hotspot)")
}

if syncManager.networkStatus.isLowPowerModeEnabled {
    print("Low Power Mode is enabled")
}
```

### SyncEnvironmentStatus

```swift
let status = syncManager.environmentStatus

// Check if CloudKit sync is ready (network + account + not in low power mode)
if status.isSyncReady {
    // Safe to sync via CloudKit
}

// Check if iCloud Drive is ready (network + account + drive enabled + not in low power mode)
if status.isCloudDriveReady {
    // Safe to use iCloud Drive / Documents
}

// Check if suitable for large transfers (not constrained, not expensive)
if status.isSuitableForLargeTransfer {
    // Good for syncing large files
}

// Check if currently syncing
if status.isSyncing {
    // Sync in progress
}
```

### Using AsyncStream

```swift
// Monitor network status changes
Task {
    for await status in syncManager.networkStatusStream {
        print("Network changed: \(status.isConnected)")
    }
}

// Monitor iCloud Drive availability changes
Task {
    for await available in syncManager.cloudDriveStatusStream {
        print("iCloud Drive: \(available ? "enabled" : "disabled")")
    }
}

// Monitor all status changes in one stream
Task {
    for await envStatus in syncManager.environmentStatusStream {
        if envStatus.isSyncReady {
            print("Ready to sync!")
        }
    }
}
```

### Wait Until Sync Ready

```swift
// Wait until sync conditions are met (with optional timeout)
let isReady = await syncManager.waitUntilSyncReady(timeout: .seconds(30))
if isReady {
    // Proceed with sync operation
}
```

### Manual Status Check

```swift
// Manually refresh account status
let accountStatus = try await syncManager.checkAccountStatus()

// Manually refresh network status
let networkStatus = syncManager.checkNetworkStatus()
```

### Handling Quota Exceeded

```swift
let syncManager = SyncStatusAsyncManager(
    monitoringOptions: .all,
    cloudKitContainerID: "iCloud.com.yourcompany.yourapp",
    quotaExceededHandler: {
        // Notify the user about iCloud storage being full
        print("iCloud storage is full!")
    }
)
```

### Logging

```swift
let syncManager = SyncStatusAsyncManager(
    monitoringOptions: .all,
    cloudKitContainerID: "iCloud.com.yourcompany.yourapp",
    logger: YourLoggerInstance, // Conforming to LoggerManagerProtocol
    showEventInLog: true
)
```

### Testing Support

```swift
#if DEBUG
// Create a manager for testing (no real monitoring)
let testManager = SyncStatusAsyncManager._forTesting()

// Set states directly for testing
testManager._testSetNetworkStatus(NetworkStatus(
    isConnected: true,
    connectivity: .connected(.wifi),
    isLowPowerModeEnabled: false,
    isConstrained: false,
    isExpensive: false
))
testManager._testSetAccountStatus(.available)
testManager._testSetSyncEvent(.importing)
testManager._testSetCloudDriveAvailable(true)
#endif
```

---

## Legacy API (iOS 14+)

### SyncStatusManager

The legacy API uses **Combine** and `@Published` for compatibility with older iOS versions.

### Initialize SyncStatusManager

```swift
@StateObject var syncManager = SyncStatusManager()
```

### Basic Usage

```swift
struct ContentView: View {
    @StateObject var syncManager = SyncStatusManager()

    var body: some View {
        VStack {
            Text("Sync Event: \(syncManager.syncEvent)")
            
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

```swift
let syncManager = SyncStatusManager(
    quotaExceededHandler: {
        // Notify the user about the quota issue
    }
)
```

---

## API Comparison

| Feature | `SyncStatusAsyncManager` | `SyncStatusManager` |
|---------|--------------------------|---------------------|
| Framework | Observation | Combine |
| State Management | `@Observable` | `@Published` |
| Network Monitoring | ✅ Detailed | ❌ Not included |
| iCloud Drive Detection | ✅ Yes | ❌ No |
| Selective Monitoring | ✅ MonitoringOptions | ❌ No |
| Auto Account Monitoring | ✅ Automatic | ❌ Manual check |
| AsyncStream Support | ✅ Yes | ❌ No |
| iOS Minimum | 17.0 | 14.0 |
| Swift Minimum | 6.2 | 6.0 |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [General Findings About NSPersistentCloudKitContainer](https://crunchybagel.com/nspersistentcloudkitcontainer/)

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png)](https://buymeacoffee.com/fatbobman)
