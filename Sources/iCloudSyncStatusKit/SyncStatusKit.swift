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
import CoreData
import Foundation
import SimpleLogger
#if canImport(Observation)
    import Observation
#endif

/// Synchronization status manager
#if canImport(Observation)
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
    @Observable
#endif
@MainActor
public final class SyncStatusManager: SyncStatusManagerProtocol {
    #if canImport(Observation)
        /// Synchronization event state
        public var syncEvent: SyncEvent = .idle
    #else
        @Published public var syncEvent: SyncEvent = .idle
    #endif

    #if canImport(Observation)
        @ObservationIgnored
        var cancellables: Set<AnyCancellable> = []
    #else
        var cancellables: Set<AnyCancellable> = []
    #endif

    #if canImport(Observation)
        @ObservationIgnored
        /// Whether the quota has been exceeded, only alert once during the instance lifecycle
        var hasRunQuotaExceeded = false
    #else
        var hasRunQuotaExceeded = false
    #endif
    /// Quota exceeded callback method
    let quotaExceededHandler: (@Sendable () async -> Void)?
    /// Logger manager
    let logger: (any LoggerManagerProtocol)?
    /// CloudKit Container
    let container: CKContainer
    /// Whether to display system synchronization event logs
    let showEventInLog: Bool

    /// 检查 iCloud Account 是否处在 available 状态
    @discardableResult
    public func validateICloudAvailability(
        onUnavailable: @Sendable (AccountStatus, Error?) async -> Void
    ) async -> AccountStatus? {
        do {
            let accountStatus = try await container.accountStatus()
            guard accountStatus == .available else {
                await onUnavailable(.notAvailable(accountStatus), nil)
                return .notAvailable(accountStatus)
            }
        } catch {
            await onUnavailable(.notAvailable(.couldNotDetermine), error)
            return nil
        }
        return .available
    }

    /// Respond to synchronization events
    func syncEventHandler(_ notification: Notification) {
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event else {
            syncEvent = .idle
            return
        }

        let isFinished = event.endDate != nil

        switch event.type {
        case .import:
            syncEvent = isFinished ? .idle : .importing
        case .export:
            syncEvent = isFinished ? .idle : .exporting
        case .setup:
            syncEvent = .setup
        default:
            syncEvent = .idle
        }

        // Handle quota exceeded errors
        if let error = event.error as? CKError {
            handleCloudKitError(error)
        }

        if showEventInLog {
            logger?.debug("Event: \(event) \nError: \(String(describing: event.error))")
        }
    }

    /// Handle error information, currently only handling `quotaExceeded`
    func handleCloudKitError(_ error: CKError) {
        switch error.code {
        /// Handles the error when the capacity is exceeded.
        /// However, even when the capacity is exceeded, this error may not be reported, possibly resulting in .partialFailure
        /// In such cases, it can be attempted at a specific timing (e.g., cold start), to create a separate record (independent zone) on CloudKit to determine if the capacity exceeded error will be returned
        /// This is another independent mechanism that does not need to be handled in the current code
        case .quotaExceeded:
            guard !hasRunQuotaExceeded else { return }
            hasRunQuotaExceeded = true
            logger?.error("iCloud Storage is full")
            Task {
                await quotaExceededHandler?()
            }
        default:
            break
        }
    }

    /// Initialization method
    ///
    /// Initialize the SyncStatusKit instance, which is used to manage iCloud synchronization status.
    ///
    /// - Parameters:
    ///   - cloudKitContainerID: CloudKit container ID, used to specify the CloudKit container.
    ///   - enableSyncEventMonitoring: Whether to enable synchronization event monitoring, used to determine whether to listen to synchronization events.
    ///   - quotaExceededHandler: Quota exceeded callback method, used to handle quota exceeded errors.
    ///   - logger: Logger manager, used to record log information.
    ///   - showEventInLog: Whether to show events in the log, used to determine whether to record synchronization events in the log.
    public init(
        cloudKitContainerID: String? = nil,
        enableSyncEventMonitoring: Bool = true,
        quotaExceededHandler: (@Sendable () async -> Void)? = nil,
        logger: (any LoggerManagerProtocol)? = nil,
        showEventInLog: Bool = false
    ) {
        // Create a CKContainer instance based on the provided CloudKit container ID, or use the default container.
        container = cloudKitContainerID.map { CKContainer(identifier: $0) } ?? .default()
        // Set the flag to show events in the log.
        self.showEventInLog = showEventInLog
        // Set the quota exceeded callback method.
        self.quotaExceededHandler = quotaExceededHandler
        // Set the logger manager.
        self.logger = logger
        // If synchronization event monitoring is enabled, listen for the NSPersistentCloudKitContainer.eventChangedNotification notification.
        if enableSyncEventMonitoring {
            NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] notification in
                    // When a notification is received, call the syncEventHandler method to handle the event.
                    self?.syncEventHandler(notification)
                }
                .store(in: &cancellables)
        }
    }
}
