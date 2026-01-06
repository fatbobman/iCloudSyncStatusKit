//
//  ------------------------------------------------
//  Original project: iCloudSyncStatusKit
//  Created on 2024/10/27 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

import Foundation

/// Options for controlling which status types to monitor
///
/// Use this to selectively enable monitoring for specific features,
/// which can help reduce resource usage when you don't need all status types.
///
/// Example:
/// ```swift
/// // Only monitor network and account status
/// let manager = SyncStatusAsyncManager(
///     monitoringOptions: [.network, .account]
/// )
///
/// // Monitor everything
/// let manager = SyncStatusAsyncManager(
///     monitoringOptions: .all,
///     cloudKitContainerID: "iCloud.com.example.app"
/// )
/// ```
@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
public struct MonitoringOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    // MARK: - Individual Options

    /// Monitor network connectivity status using NWPathMonitor
    ///
    /// Provides: `networkStatus`, `networkStatusStream`
    public static let network = MonitoringOptions(rawValue: 1 << 0)

    /// Monitor iCloud account status
    ///
    /// Provides: `accountStatus`, `accountStatusStream`
    public static let account = MonitoringOptions(rawValue: 1 << 1)

    /// Monitor CloudKit sync events from NSPersistentCloudKitContainer
    ///
    /// Requires `cloudKitContainerID` to be set.
    /// Provides: `syncEvent`, `syncEventStream`
    public static let syncEvent = MonitoringOptions(rawValue: 1 << 2)

    /// Monitor iCloud Drive availability
    ///
    /// Checks `FileManager.default.ubiquityIdentityToken` for iCloud Drive status.
    /// Note: This is separate from CloudKit sync - iCloud Drive may be disabled
    /// even when iCloud account is available.
    ///
    /// Provides: `isCloudDriveAvailable`, `cloudDriveStatusStream`
    public static let cloudDrive = MonitoringOptions(rawValue: 1 << 3)

    // MARK: - Preset Combinations

    /// All monitoring options enabled
    ///
    /// Note: `syncEvent` requires `cloudKitContainerID` to function
    public static let all: MonitoringOptions = [.network, .account, .syncEvent, .cloudDrive]

    /// Basic monitoring: network + account only
    ///
    /// Lightweight option for apps that only need connectivity and account status
    public static let basic: MonitoringOptions = [.network, .account]

    /// Default monitoring: network + account + cloudDrive
    ///
    /// Suitable for most apps using iCloud features
    public static let `default`: MonitoringOptions = [.network, .account, .cloudDrive]

    /// Sync-focused monitoring: network + account + syncEvent
    ///
    /// For apps using NSPersistentCloudKitContainer without iCloud Drive
    public static let syncFocused: MonitoringOptions = [.network, .account, .syncEvent]
}

