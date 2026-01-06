//
//  ------------------------------------------------
//  Original project: iCloudSyncStatusKit
//  Created on 2026/1/6 by Fatbobman(东坡肘子)
//  X: @fatbobman
//  Mastodon: @fatbobman@mastodon.social
//  GitHub: @fatbobman
//  Blog: https://fatbobman.com
//  ------------------------------------------------
//  Copyright © 2024-present Fatbobman. All rights reserved.

/// Comprehensive environment status for sync operations
///
/// Combines network, account, sync event, and iCloud Drive status into a single structure
/// for convenient status checking.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
public struct SyncEnvironmentStatus: Sendable, Equatable {
    /// Current network status
    public let network: NetworkStatus

    /// Current iCloud account status
    public let account: AccountStatus

    /// Current synchronization event
    public let syncEvent: SyncEvent

    /// Whether iCloud Drive is available
    ///
    /// Note: iCloud Drive may be disabled even when iCloud account is available.
    /// This checks if the user has enabled "iCloud Drive" in Settings.
    public let isCloudDriveAvailable: Bool

    /// Creates a new SyncEnvironmentStatus instance
    /// - Parameters:
    ///   - network: Network status
    ///   - account: iCloud account status
    ///   - syncEvent: Current sync event
    ///   - isCloudDriveAvailable: Whether iCloud Drive is available
    public init(
        network: NetworkStatus,
        account: AccountStatus,
        syncEvent: SyncEvent,
        isCloudDriveAvailable: Bool = false,
    ) {
        self.network = network
        self.account = account
        self.syncEvent = syncEvent
        self.isCloudDriveAvailable = isCloudDriveAvailable
    }

    /// Whether the environment is ready for sync operations (CloudKit)
    ///
    /// Returns `true` when:
    /// - Network is connected
    /// - iCloud account is available
    /// - Device is not in Low Power Mode
    ///
    /// Note: This does not check iCloud Drive status, as CloudKit sync
    /// (NSPersistentCloudKitContainer) works independently of iCloud Drive.
    public var isSyncReady: Bool {
        network.isConnected &&
            account == .available &&
            !network.isLowPowerModeEnabled
    }

    /// Whether the environment is ready for iCloud Drive operations
    ///
    /// Returns `true` when:
    /// - Network is connected
    /// - iCloud account is available
    /// - iCloud Drive is enabled
    /// - Device is not in Low Power Mode
    public var isCloudDriveReady: Bool {
        network.isConnected &&
            account == .available &&
            isCloudDriveAvailable &&
            !network.isLowPowerModeEnabled
    }

    /// Whether sync is currently in progress
    public var isSyncing: Bool {
        switch syncEvent {
        case .importing, .exporting, .setup:
            true
        case .idle:
            false
        }
    }

    /// Whether the network connection is suitable for large data transfers
    ///
    /// Returns `true` when:
    /// - Network is connected
    /// - Connection is not constrained (Low Data Mode off)
    /// - Connection is not expensive (not cellular/hotspot)
    public var isSuitableForLargeTransfer: Bool {
        network.isConnected &&
            !network.isConstrained &&
            !network.isExpensive
    }
}

// MARK: - AccountStatus Equatable

extension AccountStatus: Equatable {
    public static func == (lhs: AccountStatus, rhs: AccountStatus) -> Bool {
        switch (lhs, rhs) {
        case (.available, .available):
            true
        case let (.notAvailable(lhsStatus), .notAvailable(rhsStatus)):
            lhsStatus == rhsStatus
        default:
            false
        }
    }
}

// MARK: - SyncEvent Equatable

extension SyncEvent: Equatable {}
