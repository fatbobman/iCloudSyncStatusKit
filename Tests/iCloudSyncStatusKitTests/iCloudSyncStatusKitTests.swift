import Testing
@testable import iCloudSyncStatusKit

// MARK: - NetworkStatus Tests

@Suite("NetworkStatus Tests")
struct NetworkStatusTests {
    @Test("NetworkStatus default disconnected state")
    func testDisconnectedDefault() {
        let status = NetworkStatus.disconnected

        #expect(status.isConnected == false)
        #expect(status.connectivity == .disconnected)
        #expect(status.isLowPowerModeEnabled == false)
        #expect(status.isConstrained == false)
        #expect(status.isExpensive == false)
    }

    @Test("NetworkStatus connected with WiFi")
    func testConnectedWiFi() {
        let status = NetworkStatus(
            isConnected: true,
            connectivity: .connected(.wifi),
            isLowPowerModeEnabled: false,
            isConstrained: false,
            isExpensive: false,
        )

        #expect(status.isConnected == true)
        #expect(status.connectivity == .connected(.wifi))
    }

    @Test("NetworkStatus connected with cellular is expensive")
    func testConnectedCellular() {
        let status = NetworkStatus(
            isConnected: true,
            connectivity: .connected(.cellular),
            isLowPowerModeEnabled: false,
            isConstrained: false,
            isExpensive: true,
        )

        #expect(status.isConnected == true)
        #expect(status.isExpensive == true)
    }

    @Test("NetworkStatus equality")
    func testEquality() {
        let status1 = NetworkStatus(
            isConnected: true,
            connectivity: .connected(.wifi),
            isLowPowerModeEnabled: false,
            isConstrained: false,
            isExpensive: false,
        )

        let status2 = NetworkStatus(
            isConnected: true,
            connectivity: .connected(.wifi),
            isLowPowerModeEnabled: false,
            isConstrained: false,
            isExpensive: false,
        )

        #expect(status1 == status2)
    }
}

// MARK: - AccountStatus Tests

@Suite("AccountStatus Tests")
struct AccountStatusTests {
    @Test("AccountStatus available equality")
    func testAvailableEquality() {
        let status1 = AccountStatus.available
        let status2 = AccountStatus.available

        #expect(status1 == status2)
    }

    @Test("AccountStatus notAvailable equality")
    func testNotAvailableEquality() {
        let status1 = AccountStatus.notAvailable(.noAccount)
        let status2 = AccountStatus.notAvailable(.noAccount)

        #expect(status1 == status2)
    }

    @Test("AccountStatus different states not equal")
    func testDifferentStatesNotEqual() {
        let available = AccountStatus.available
        let notAvailable = AccountStatus.notAvailable(.noAccount)

        #expect(available != notAvailable)
    }
}

// MARK: - SyncEvent Tests

@Suite("SyncEvent Tests")
struct SyncEventTests {
    @Test("SyncEvent equality")
    func testEquality() {
        #expect(SyncEvent.idle == SyncEvent.idle)
        #expect(SyncEvent.importing == SyncEvent.importing)
        #expect(SyncEvent.exporting == SyncEvent.exporting)
        #expect(SyncEvent.setup == SyncEvent.setup)
    }

    @Test("SyncEvent different states not equal")
    func testDifferentStatesNotEqual() {
        #expect(SyncEvent.idle != SyncEvent.importing)
        #expect(SyncEvent.importing != SyncEvent.exporting)
    }
}

// MARK: - SyncEnvironmentStatus Tests

@Suite("SyncEnvironmentStatus Tests")
struct SyncEnvironmentStatusTests {
    @Test("isSyncReady when all conditions met")
    func testIsSyncReadyTrue() {
        let status = SyncEnvironmentStatus(
            network: NetworkStatus(
                isConnected: true,
                connectivity: .connected(.wifi),
                isLowPowerModeEnabled: false,
                isConstrained: false,
                isExpensive: false,
            ),
            account: .available,
            syncEvent: .idle,
        )

        #expect(status.isSyncReady == true)
    }

    @Test("isSyncReady false when network disconnected")
    func testIsSyncReadyFalseNoNetwork() {
        let status = SyncEnvironmentStatus(
            network: .disconnected,
            account: .available,
            syncEvent: .idle,
        )

        #expect(status.isSyncReady == false)
    }

    @Test("isSyncReady false when account unavailable")
    func testIsSyncReadyFalseNoAccount() {
        let status = SyncEnvironmentStatus(
            network: NetworkStatus(
                isConnected: true,
                connectivity: .connected(.wifi),
                isLowPowerModeEnabled: false,
                isConstrained: false,
                isExpensive: false,
            ),
            account: .notAvailable(.noAccount),
            syncEvent: .idle,
        )

        #expect(status.isSyncReady == false)
    }

    @Test("isSyncReady false when low power mode enabled")
    func testIsSyncReadyFalseLowPowerMode() {
        let status = SyncEnvironmentStatus(
            network: NetworkStatus(
                isConnected: true,
                connectivity: .connected(.wifi),
                isLowPowerModeEnabled: true,
                isConstrained: false,
                isExpensive: false,
            ),
            account: .available,
            syncEvent: .idle,
        )

        #expect(status.isSyncReady == false)
    }

    @Test("isSyncing when importing")
    func testIsSyncingImporting() {
        let status = SyncEnvironmentStatus(
            network: .disconnected,
            account: .available,
            syncEvent: .importing,
        )

        #expect(status.isSyncing == true)
    }

    @Test("isSyncing when exporting")
    func testIsSyncingExporting() {
        let status = SyncEnvironmentStatus(
            network: .disconnected,
            account: .available,
            syncEvent: .exporting,
        )

        #expect(status.isSyncing == true)
    }

    @Test("isSyncing false when idle")
    func testIsSyncingFalseWhenIdle() {
        let status = SyncEnvironmentStatus(
            network: .disconnected,
            account: .available,
            syncEvent: .idle,
        )

        #expect(status.isSyncing == false)
    }

    @Test("isSuitableForLargeTransfer when WiFi and not constrained")
    func testIsSuitableForLargeTransfer() {
        let status = SyncEnvironmentStatus(
            network: NetworkStatus(
                isConnected: true,
                connectivity: .connected(.wifi),
                isLowPowerModeEnabled: false,
                isConstrained: false,
                isExpensive: false,
            ),
            account: .available,
            syncEvent: .idle,
        )

        #expect(status.isSuitableForLargeTransfer == true)
    }

    @Test("isSuitableForLargeTransfer false when expensive")
    func testIsSuitableForLargeTransferFalseWhenExpensive() {
        let status = SyncEnvironmentStatus(
            network: NetworkStatus(
                isConnected: true,
                connectivity: .connected(.cellular),
                isLowPowerModeEnabled: false,
                isConstrained: false,
                isExpensive: true,
            ),
            account: .available,
            syncEvent: .idle,
        )

        #expect(status.isSuitableForLargeTransfer == false)
    }
}

// MARK: - SyncStatusAsyncManager Tests

#if DEBUG
@Suite("SyncStatusAsyncManager Tests")
@MainActor
struct SyncStatusAsyncManagerTests {
    @Test("Initial state")
    func testInitialState() async {
        let manager = SyncStatusAsyncManager._forTesting()

        // Account status starts as notAvailable until checked
        #expect(manager.isAccountAvailable == false)
        #expect(manager.syncEvent == .idle)
        #expect(manager.isSyncing == false)
        #expect(manager.networkStatus == .disconnected)
    }

    @Test("Test set network status")
    func testSetNetworkStatus() async {
        let manager = SyncStatusAsyncManager._forTesting()

        let connectedStatus = NetworkStatus(
            isConnected: true,
            connectivity: .connected(.wifi),
            isLowPowerModeEnabled: false,
            isConstrained: false,
            isExpensive: false,
        )

        manager._testSetNetworkStatus(connectedStatus)

        #expect(manager.networkStatus == connectedStatus)
        #expect(manager.isNetworkConnected == true)
    }

    @Test("Test set account status")
    func testSetAccountStatus() async {
        let manager = SyncStatusAsyncManager._forTesting()

        manager._testSetAccountStatus(.available)

        #expect(manager.accountStatus == .available)
        #expect(manager.isAccountAvailable == true)
    }

    @Test("Test set sync event")
    func testSetSyncEvent() async {
        let manager = SyncStatusAsyncManager._forTesting()

        manager._testSetSyncEvent(.importing)

        #expect(manager.syncEvent == .importing)
        #expect(manager.isSyncing == true)

        manager._testSetSyncEvent(.idle)

        #expect(manager.syncEvent == .idle)
        #expect(manager.isSyncing == false)
    }

    @Test("Environment status composition")
    func testEnvironmentStatus() async {
        let manager = SyncStatusAsyncManager._forTesting()

        let connectedStatus = NetworkStatus(
            isConnected: true,
            connectivity: .connected(.wifi),
            isLowPowerModeEnabled: false,
            isConstrained: false,
            isExpensive: false,
        )

        manager._testSetNetworkStatus(connectedStatus)
        manager._testSetAccountStatus(.available)
        manager._testSetSyncEvent(.idle)

        let envStatus = manager.environmentStatus

        #expect(envStatus.isSyncReady == true)
        #expect(envStatus.isSyncing == false)
        #expect(envStatus.isSuitableForLargeTransfer == true)
    }

    @Test("Environment status not ready when network disconnected")
    func testEnvironmentStatusNotReadyNoNetwork() async {
        let manager = SyncStatusAsyncManager._forTesting()

        manager._testSetAccountStatus(.available)
        manager._testSetSyncEvent(.idle)
        // networkStatus is .disconnected by default

        let envStatus = manager.environmentStatus

        #expect(envStatus.isSyncReady == false)
    }

    @Test("Environment status not ready when account unavailable")
    func testEnvironmentStatusNotReadyNoAccount() async {
        let manager = SyncStatusAsyncManager._forTesting()

        manager._testSetNetworkStatus(NetworkStatus(
            isConnected: true,
            connectivity: .connected(.wifi),
            isLowPowerModeEnabled: false,
            isConstrained: false,
            isExpensive: false,
        ))
        manager._testSetAccountStatus(.notAvailable(.noAccount))

        let envStatus = manager.environmentStatus

        #expect(envStatus.isSyncReady == false)
    }

    @Test("Convenience properties")
    func testConvenienceProperties() async {
        let manager = SyncStatusAsyncManager._forTesting()

        // Initial state
        #expect(manager.isNetworkConnected == false)
        #expect(manager.isAccountAvailable == false)
        #expect(manager.isSyncing == false)

        // Set to connected/available/syncing
        manager._testSetNetworkStatus(NetworkStatus(
            isConnected: true,
            connectivity: .connected(.wifi),
            isLowPowerModeEnabled: false,
            isConstrained: false,
            isExpensive: false,
        ))
        manager._testSetAccountStatus(.available)
        manager._testSetSyncEvent(.exporting)

        #expect(manager.isNetworkConnected == true)
        #expect(manager.isAccountAvailable == true)
        #expect(manager.isSyncing == true)
    }
}
#endif
