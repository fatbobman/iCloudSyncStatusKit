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

import Network

/// Network interface type
public enum NetworkInterface: Sendable, Equatable {
    /// Wi-Fi connection
    case wifi
    /// Cellular network (3G/4G/5G)
    case cellular
    /// Wired Ethernet connection
    case wiredEthernet
    /// Loopback interface (localhost)
    case loopback
    /// Other network interface types
    case other
}

/// Detailed network connectivity status
public enum NetworkConnectivity: Sendable, Equatable {
    /// Connected to network with specific interface type
    case connected(NetworkInterface)
    /// No network connection available
    case disconnected
}

/// Comprehensive network status information
public struct NetworkStatus: Sendable, Equatable {
    /// Simple connectivity status: whether network is available
    public let isConnected: Bool

    /// Detailed connectivity information including interface type
    public let connectivity: NetworkConnectivity

    /// Whether Low Power Mode is enabled on the device
    public let isLowPowerModeEnabled: Bool

    /// Whether the connection is constrained (Low Data Mode enabled)
    public let isConstrained: Bool

    /// Whether the connection is expensive (cellular or personal hotspot)
    public let isExpensive: Bool

    /// Creates a new NetworkStatus instance
    /// - Parameters:
    ///   - isConnected: Whether network is available
    ///   - connectivity: Detailed connectivity information
    ///   - isLowPowerModeEnabled: Whether Low Power Mode is enabled
    ///   - isConstrained: Whether Low Data Mode is enabled
    ///   - isExpensive: Whether the connection is expensive
    public init(
        isConnected: Bool,
        connectivity: NetworkConnectivity,
        isLowPowerModeEnabled: Bool,
        isConstrained: Bool,
        isExpensive: Bool,
    ) {
        self.isConnected = isConnected
        self.connectivity = connectivity
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.isConstrained = isConstrained
        self.isExpensive = isExpensive
    }

    /// Default disconnected status
    public static let disconnected = NetworkStatus(
        isConnected: false,
        connectivity: .disconnected,
        isLowPowerModeEnabled: false,
        isConstrained: false,
        isExpensive: false,
    )
}

// MARK: - NWPath Extension

@available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *)
extension NetworkStatus {
    /// Creates NetworkStatus from NWPath
    /// - Parameters:
    ///   - path: The network path to analyze
    ///   - isLowPowerModeEnabled: Whether Low Power Mode is enabled
    init(from path: NWPath, isLowPowerModeEnabled: Bool) {
        let pathSatisfied = path.status == .satisfied
        let isConstrained = path.isConstrained
        let isExpensive = path.isExpensive

        // Check for real physical network interfaces
        // VPN-only connections (without underlying physical network) should be considered disconnected
        let hasPhysicalInterface = Self.hasPhysicalNetworkInterface(path)
        let isConnected = pathSatisfied && hasPhysicalInterface

        let connectivity: NetworkConnectivity
        if isConnected {
            let interface = Self.determineInterface(from: path)
            connectivity = .connected(interface)
        } else {
            connectivity = .disconnected
        }

        self.init(
            isConnected: isConnected,
            connectivity: connectivity,
            isLowPowerModeEnabled: isLowPowerModeEnabled,
            isConstrained: isConstrained,
            isExpensive: isExpensive,
        )
    }

    /// Checks if path has a real physical network interface (WiFi, Cellular, Ethernet)
    /// This helps detect VPN-only connections where the underlying network is unavailable
    private static func hasPhysicalNetworkInterface(_ path: NWPath) -> Bool {
        // Check for standard physical interfaces
        if path.usesInterfaceType(.wifi) ||
            path.usesInterfaceType(.cellular) ||
            path.usesInterfaceType(.wiredEthernet)
        {
            return true
        }

        // Also check availableInterfaces for physical types
        // This handles cases where usesInterfaceType might miss some configurations
        for interface in path.availableInterfaces {
            switch interface.type {
            case .wifi, .cellular, .wiredEthernet:
                return true
            default:
                continue
            }
        }

        return false
    }

    /// Determines the primary network interface from an NWPath
    private static func determineInterface(from path: NWPath) -> NetworkInterface {
        if path.usesInterfaceType(.wifi) {
            .wifi
        } else if path.usesInterfaceType(.cellular) {
            .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            .wiredEthernet
        } else if path.usesInterfaceType(.loopback) {
            .loopback
        } else {
            .other
        }
    }
}
