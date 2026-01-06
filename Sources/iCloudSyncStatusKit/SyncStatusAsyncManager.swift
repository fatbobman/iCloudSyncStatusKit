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

// This file requires Swift 6.2+ for isolated deinit support
#if swift(>=6.2)

    import CloudKit
    import CoreData
    import Foundation
    import Network
    import SimpleLogger

    /// Modern synchronization status manager using Observation framework
    ///
    /// `SyncStatusAsyncManager` provides a modern async/await API for monitoring:
    /// - Network connectivity status
    /// - iCloud account status
    /// - CloudKit synchronization events
    /// - iCloud Drive availability
    ///
    /// This class requires iOS 17.0 or later and uses the Observation framework
    /// for reactive state management.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Monitor all status types
    /// @State private var syncManager = SyncStatusAsyncManager(
    ///     monitoringOptions: .all,
    ///     cloudKitContainerID: "iCloud.com.example.app"
    /// )
    ///
    /// // Only monitor network and account (lightweight)
    /// @State private var syncManager = SyncStatusAsyncManager(
    ///     monitoringOptions: .basic
    /// )
    ///
    /// var body: some View {
    ///     VStack {
    ///         Text("Network: \(syncManager.isNetworkConnected ? "Connected" : "Disconnected")")
    ///         Text("Account: \(syncManager.isAccountAvailable ? "Available" : "Unavailable")")
    ///         Text("iCloud Drive: \(syncManager.isCloudDriveAvailable ? "Available" : "Unavailable")")
    ///
    ///         if syncManager.environmentStatus.isSyncReady {
    ///             Text("✅ Ready to sync")
    ///         }
    ///     }
    /// }
    /// ```
    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
    @MainActor
    @Observable
    public final class SyncStatusAsyncManager: @unchecked Sendable {
        // MARK: - Observable Properties

        /// Current network status
        public private(set) var networkStatus: NetworkStatus = .disconnected

        /// Current iCloud account status (automatically monitored)
        public private(set) var accountStatus: AccountStatus = .notAvailable(.couldNotDetermine)

        /// Current synchronization event (automatically monitored)
        public private(set) var syncEvent: SyncEvent = .idle

        /// Whether iCloud Drive is available
        ///
        /// This checks `FileManager.default.ubiquityIdentityToken` which indicates
        /// whether iCloud Drive is enabled for the current user.
        ///
        /// Note: This is separate from CloudKit sync status. A user may have iCloud
        /// account available but iCloud Drive disabled.
        public private(set) var isCloudDriveAvailable: Bool = false

        /// Comprehensive environment status combining network, account, and sync state
        public var environmentStatus: SyncEnvironmentStatus {
            SyncEnvironmentStatus(
                network: networkStatus,
                account: accountStatus,
                syncEvent: syncEvent,
                isCloudDriveAvailable: isCloudDriveAvailable,
            )
        }

        // MARK: - Convenience Properties

        /// Whether the network is currently connected
        public var isNetworkConnected: Bool {
            networkStatus.isConnected
        }

        /// Whether the iCloud account is available
        public var isAccountAvailable: Bool {
            if case .available = accountStatus { return true }
            return false
        }

        /// Whether synchronization is currently in progress
        public var isSyncing: Bool {
            switch syncEvent {
            case .importing, .exporting, .setup:
                true
            case .idle:
                false
            }
        }

        /// Current monitoring options
        public let monitoringOptions: MonitoringOptions

        // MARK: - Private Properties

        /// Network path monitor
        private var pathMonitor: NWPathMonitor?

        /// Queue for network monitoring
        private let monitorQueue = DispatchQueue(label: "com.fatbobman.iCloudSyncStatusKit.networkMonitor")

        /// CloudKit container (nil only for testing)
        private let container: CKContainer?

        /// Whether quota exceeded has been handled
        private var hasRunQuotaExceeded = false

        /// Quota exceeded callback
        private let quotaExceededHandler: (@Sendable () async -> Void)?

        /// Logger manager
        private let logger: (any LoggerManagerProtocol)?

        /// Whether to show events in log
        private let showEventInLog: Bool

        /// Monitoring task
        private var monitoringTask: Task<Void, Never>?

        /// Cloud Drive monitoring task
        private var cloudDriveTask: Task<Void, Never>?

        /// Stream continuations for cleanup
        private var networkContinuation: AsyncStream<NetworkStatus>.Continuation?
        private var accountContinuation: AsyncStream<AccountStatus>.Continuation?
        private var syncEventContinuation: AsyncStream<SyncEvent>.Continuation?
        private var cloudDriveContinuation: AsyncStream<Bool>.Continuation?

        // MARK: - Initialization

        /// Creates a new SyncStatusAsyncManager instance
        ///
        /// - Parameters:
        ///   - monitoringOptions: Options controlling which status types to monitor. Default is `.default`.
        ///   - cloudKitContainerID: CloudKit container identifier. Required if `.syncEvent` is in options.
        ///   - quotaExceededHandler: Callback when iCloud storage quota is exceeded.
        ///   - logger: Logger conforming to LoggerManagerProtocol for debugging.
        ///   - showEventInLog: Whether to log sync events for debugging. Default is false.
        public init(
            monitoringOptions: MonitoringOptions = .default,
            cloudKitContainerID: String? = nil,
            quotaExceededHandler: (@Sendable () async -> Void)? = nil,
            logger: (any LoggerManagerProtocol)? = nil,
            showEventInLog: Bool = false,
        ) {
            self.monitoringOptions = monitoringOptions
            container = cloudKitContainerID.map { CKContainer(identifier: $0) } ?? .default()
            self.quotaExceededHandler = quotaExceededHandler
            self.logger = logger
            self.showEventInLog = showEventInLog

            startMonitoring()
        }

        /// Internal initializer with option to skip monitoring (for testing)
        init(
            monitoringOptions: MonitoringOptions,
            cloudKitContainerID: String?,
            quotaExceededHandler: (@Sendable () async -> Void)?,
            logger: (any LoggerManagerProtocol)?,
            showEventInLog: Bool,
            _skipMonitoring: Bool,
        ) {
            self.monitoringOptions = monitoringOptions
            // Use nil container for testing to avoid CloudKit initialization
            container = nil
            self.quotaExceededHandler = quotaExceededHandler
            self.logger = logger
            self.showEventInLog = showEventInLog

            if !_skipMonitoring {
                startMonitoring()
            }
        }

        isolated deinit {
            stopMonitoring()
        }

        // MARK: - Public Methods

        /// Starts monitoring based on configured `monitoringOptions`
        ///
        /// This is called automatically during initialization.
        /// Call this method to restart monitoring after calling `stopMonitoring()`.
        public func startMonitoring() {
            stopMonitoring()

            // Start network monitoring if enabled
            if monitoringOptions.contains(.network) {
                startNetworkMonitoring()
            }

            // Start account monitoring if enabled
            var accountTask: Task<Void, Never>?
            if monitoringOptions.contains(.account) {
                accountTask = Task { @MainActor [weak self] in
                    await self?.monitorAccountStatus()
                }
            }

            // Start sync event monitoring if enabled
            var syncTask: Task<Void, Never>?
            if monitoringOptions.contains(.syncEvent) {
                syncTask = Task { @MainActor [weak self] in
                    await self?.monitorSyncEvents()
                }
            }

            // Start iCloud Drive monitoring if enabled
            if monitoringOptions.contains(.cloudDrive) {
                startCloudDriveMonitoring()
            }

            // Combine tasks for cleanup
            if accountTask != nil || syncTask != nil {
                monitoringTask = Task { @MainActor in
                    if let accountTask {
                        _ = await accountTask.result
                    }
                    if let syncTask {
                        _ = await syncTask.result
                    }
                }
            }
        }

        /// Stops all monitoring
        ///
        /// Call `startMonitoring()` to resume monitoring.
        public func stopMonitoring() {
            pathMonitor?.cancel()
            pathMonitor = nil
            monitoringTask?.cancel()
            monitoringTask = nil
            cloudDriveTask?.cancel()
            cloudDriveTask = nil

            networkContinuation?.finish()
            accountContinuation?.finish()
            syncEventContinuation?.finish()
            cloudDriveContinuation?.finish()
        }

        /// Checks the current iCloud account status
        ///
        /// - Returns: Current account status
        /// - Throws: Error if unable to determine account status
        public func checkAccountStatus() async throws -> AccountStatus {
            guard let container else {
                return .notAvailable(.couldNotDetermine)
            }
            let status = try await container.accountStatus()
            if status == .available {
                return .available
            } else {
                return .notAvailable(status)
            }
        }

        /// Checks the current network status
        ///
        /// - Returns: Current network status
        public func checkNetworkStatus() -> NetworkStatus {
            networkStatus
        }

        /// Manually refreshes iCloud Drive availability status
        ///
        /// This checks `FileManager.default.ubiquityIdentityToken` which reflects
        /// the system-level iCloud Drive setting, independent of app-specific
        /// iCloud backup settings.
        ///
        /// Note: This is separate from `accountStatus`. iCloud Drive can be available
        /// even when the app's iCloud backup is disabled.
        public func refreshCloudDriveStatus() {
            updateCloudDriveStatus()
        }

        /// Waits until the environment is ready for sync operations
        ///
        /// - Parameter timeout: Maximum time to wait. Pass nil for no timeout.
        /// - Returns: `true` if sync ready, `false` if timed out
        public func waitUntilSyncReady(timeout: Duration? = nil) async -> Bool {
            if environmentStatus.isSyncReady {
                return true
            }

            let startTime = ContinuousClock.now

            for await status in environmentStatusStream {
                if status.isSyncReady {
                    return true
                }

                if let timeout, ContinuousClock.now - startTime >= timeout {
                    return false
                }
            }

            return false
        }

        // MARK: - AsyncStream Properties

        /// Stream of network status changes
        public var networkStatusStream: AsyncStream<NetworkStatus> {
            AsyncStream { continuation in
                networkContinuation = continuation
                continuation.yield(networkStatus)

                continuation.onTermination = { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.networkContinuation = nil
                    }
                }
            }
        }

        /// Stream of account status changes
        public var accountStatusStream: AsyncStream<AccountStatus> {
            AsyncStream { continuation in
                accountContinuation = continuation
                continuation.yield(accountStatus)

                continuation.onTermination = { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.accountContinuation = nil
                    }
                }
            }
        }

        /// Stream of sync event changes
        public var syncEventStream: AsyncStream<SyncEvent> {
            AsyncStream { continuation in
                syncEventContinuation = continuation
                continuation.yield(syncEvent)

                continuation.onTermination = { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.syncEventContinuation = nil
                    }
                }
            }
        }

        /// Stream of iCloud Drive availability changes
        public var cloudDriveStatusStream: AsyncStream<Bool> {
            AsyncStream { continuation in
                cloudDriveContinuation = continuation
                continuation.yield(isCloudDriveAvailable)

                continuation.onTermination = { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.cloudDriveContinuation = nil
                    }
                }
            }
        }

        /// Stream of comprehensive environment status changes
        public var environmentStatusStream: AsyncStream<SyncEnvironmentStatus> {
            AsyncStream { continuation in
                let task = Task { @MainActor [weak self] in
                    guard let self else {
                        continuation.finish()
                        return
                    }

                    // Yield initial status
                    continuation.yield(environmentStatus)

                    // Use withObservationTracking to detect changes
                    while !Task.isCancelled {
                        let status = await withCheckedContinuation { innerContinuation in
                            withObservationTracking {
                                _ = self.networkStatus
                                _ = self.accountStatus
                                _ = self.syncEvent
                                _ = self.isCloudDriveAvailable
                            } onChange: {
                                Task { @MainActor in
                                    innerContinuation.resume(returning: self.environmentStatus)
                                }
                            }
                        }
                        continuation.yield(status)
                    }
                }

                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }

        // MARK: - Private Methods

        /// Starts network path monitoring
        private func startNetworkMonitoring() {
            let monitor = NWPathMonitor()
            pathMonitor = monitor

            monitor.pathUpdateHandler = { [weak self] path in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                    let status = NetworkStatus(from: path, isLowPowerModeEnabled: isLowPowerMode)
                    networkStatus = status
                    networkContinuation?.yield(status)
                }
            }

            monitor.start(queue: monitorQueue)

            // Immediately check current path status after starting
            // The pathUpdateHandler will be called shortly, but we also set initial state
            monitorQueue.async { [weak self] in
                let path = monitor.currentPath
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                    let status = NetworkStatus(from: path, isLowPowerModeEnabled: isLowPowerMode)
                    networkStatus = status
                    networkContinuation?.yield(status)
                }
            }

            // Also monitor Low Power Mode changes
            NotificationCenter.default.addObserver(
                forName: .NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main,
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let monitor = pathMonitor else { return }
                    let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                    let status = NetworkStatus(from: monitor.currentPath, isLowPowerModeEnabled: isLowPowerMode)
                    networkStatus = status
                    networkContinuation?.yield(status)
                }
            }
        }

        /// Starts iCloud Drive availability monitoring
        private func startCloudDriveMonitoring() {
            // Check initial status
            updateCloudDriveStatus()

            // Monitor identity changes (indicates iCloud Drive status change)
            cloudDriveTask = Task { @MainActor [weak self] in
                let notifications = NotificationCenter.default.notifications(
                    named: .NSUbiquityIdentityDidChange,
                )

                for await _ in notifications {
                    guard let self else { return }
                    updateCloudDriveStatus()
                }
            }
        }

        /// Updates the iCloud Drive availability status
        private func updateCloudDriveStatus() {
            let available = FileManager.default.ubiquityIdentityToken != nil
            if isCloudDriveAvailable != available {
                isCloudDriveAvailable = available
                cloudDriveContinuation?.yield(available)
            }
        }

        /// Monitors iCloud account status changes
        private func monitorAccountStatus() async {
            // Check initial status asynchronously - no waiting, just fire and forget
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let status = try await checkAccountStatus()
                    // Only update if status actually changed
                    if accountStatus != status {
                        accountStatus = status
                        accountContinuation?.yield(status)
                    }
                } catch {
                    // On error, don't update status - keep default .notAvailable(.couldNotDetermine)
                    // This prevents account status from being incorrectly marked unavailable
                    logger?.error("Failed to check initial account status: \(error)")
                }
            }

            // Listen for account changes
            let notifications = NotificationCenter.default.notifications(named: .CKAccountChanged)

            for await _ in notifications {
                do {
                    let status = try await checkAccountStatus()
                    // Only update if status actually changed
                    // This prevents false negatives when iCloud Drive settings change
                    if accountStatus != status {
                        accountStatus = status
                        accountContinuation?.yield(status)
                    }
                } catch {
                    // On error, don't update status - keep previous value
                    // This prevents account status from being incorrectly marked unavailable
                    logger?.error("Failed to check account status: \(error)")
                }
            }
        }

        /// Monitors NSPersistentCloudKitContainer sync events
        private func monitorSyncEvents() async {
            let notifications = NotificationCenter.default.notifications(
                named: NSPersistentCloudKitContainer.eventChangedNotification,
            )

            for await notification in notifications {
                handleSyncEventNotification(notification)
            }
        }

        /// Handles sync event notification
        private func handleSyncEventNotification(_ notification: Notification) {
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey,
            ] as? NSPersistentCloudKitContainer.Event else {
                syncEvent = .idle
                syncEventContinuation?.yield(.idle)
                return
            }

            let isFinished = event.endDate != nil

            let newEvent: SyncEvent = switch event.type {
            case .import:
                isFinished ? .idle : .importing
            case .export:
                isFinished ? .idle : .exporting
            case .setup:
                .setup
            @unknown default:
                .idle
            }

            syncEvent = newEvent
            syncEventContinuation?.yield(newEvent)

            // Handle quota exceeded errors
            if let error = event.error as? CKError {
                handleCloudKitError(error)
            }

            if showEventInLog {
                logger?.debug("Event: \(event) \nError: \(String(describing: event.error))")
            }
        }

        /// Handles CloudKit errors
        private func handleCloudKitError(_ error: CKError) {
            switch error.code {
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
    }

    // MARK: - Testing Support

    #if DEBUG
        @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
        extension SyncStatusAsyncManager {
            /// Creates a SyncStatusAsyncManager instance for testing purposes
            ///
            /// This initializer does not start any monitoring and does not require CloudKit entitlements.
            /// Use the `_testSet*` methods to set state for testing.
            ///
            /// - Note: This initializer is only available in DEBUG builds
            public static func _forTesting() -> SyncStatusAsyncManager {
                SyncStatusAsyncManager(_forTesting: true)
            }

            /// Internal initializer for testing that skips CloudKit initialization
            private convenience init(_forTesting: Bool) {
                self.init(
                    monitoringOptions: .all,
                    cloudKitContainerID: nil,
                    quotaExceededHandler: nil,
                    logger: nil,
                    showEventInLog: false,
                    _skipMonitoring: true,
                )
            }

            /// Sets network status for testing purposes
            ///
            /// - Parameter status: The network status to set
            /// - Note: This method is only available in DEBUG builds
            public func _testSetNetworkStatus(_ status: NetworkStatus) {
                networkStatus = status
                networkContinuation?.yield(status)
            }

            /// Sets account status for testing purposes
            ///
            /// - Parameter status: The account status to set
            /// - Note: This method is only available in DEBUG builds
            public func _testSetAccountStatus(_ status: AccountStatus) {
                accountStatus = status
                accountContinuation?.yield(status)
            }

            /// Sets sync event for testing purposes
            ///
            /// - Parameter event: The sync event to set
            /// - Note: This method is only available in DEBUG builds
            public func _testSetSyncEvent(_ event: SyncEvent) {
                syncEvent = event
                syncEventContinuation?.yield(event)
            }

            /// Sets iCloud Drive availability for testing purposes
            ///
            /// - Parameter available: Whether iCloud Drive is available
            /// - Note: This method is only available in DEBUG builds
            public func _testSetCloudDriveAvailable(_ available: Bool) {
                isCloudDriveAvailable = available
                cloudDriveContinuation?.yield(available)
            }

            /// Resets quota exceeded flag for testing purposes
            ///
            /// - Note: This method is only available in DEBUG builds
            public func _testResetQuotaExceeded() {
                hasRunQuotaExceeded = false
            }
        }
    #endif

#endif // swift(>=6.2)
