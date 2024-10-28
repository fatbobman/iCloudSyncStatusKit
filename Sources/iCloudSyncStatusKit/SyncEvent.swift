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

/// Defines different event states during the synchronization process
public enum SyncEvent {
    /// Represents the process of importing data from the cloud to the local device
    case importing
    /// Represents the process of sending data from the local device to the cloud
    case exporting
    /// Represents the process of initializing or configuring synchronization settings
    case setup
    /// Represents the state where the synchronization process is idle, with no data transfer taking place
    case idle
}
