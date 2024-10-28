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

import CloudKit
import Combine
import Foundation

#if canImport(Observation)
    import Observation
    /// Sync Status Manager Protocol
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @MainActor
    public protocol SyncStatusManagerProtocol: Observable, ObservableObject, Sendable {
        /// Sync status, primarily observing importing and exporting
        var syncEvent: SyncEvent { get }
        /// Checks the iCloud account status
        /// If the status is not obtained, returns nil
        /// Regardless of the status obtained, as long as it is not available, onUnavailable will be called
        @discardableResult
        func validateICloudAvailability(
            onUnavailable: @Sendable (AccountStatus, Error?) async -> Void
        ) async -> AccountStatus?
    }
#else
    @MainActor
    public protocol SyncStatusManagerProtocol: ObservableObject, Sendable {
        /// Sync status, primarily observing importing and exporting
        var syncEvent: SyncEvent { get }
        /// Checks the iCloud account status
        /// If the status is not obtained, returns nil
        /// Regardless of the status obtained, as long as it is not available, onUnavailable will be called
        @discardableResult
        func validateICloudAvailability(
            onUnavailable: @Sendable (AccountStatus, Error?) async -> Void
        ) async -> AccountStatus?
    }
#endif
