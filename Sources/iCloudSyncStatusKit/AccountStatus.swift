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

/// Account status enumeration
public enum AccountStatus: Sendable {
    /// Account status is normal
    case available
    /// Abnormal (states other than available)
    case notAvailable(CKAccountStatus)
}

/*
 CKAccountStatus Explanation
     /// The user's iCloud account is available.
     case available

     /// The system is temporarily unable to determine the user's iCloud account status.
     /// This is usually due to unstable network connections or the system not responding within a short period.
     /// Example prompt: "Unable to determine your iCloud account status, please check your network connection and try again later."
     case couldNotDetermine

     /// The device does not have an iCloud account.
     case noAccount

     /// This status indicates that system or parental controls, etc., restrict access to the iCloud account.
     /// This may be due to restrictions imposed by Parental Controls or device policies, which the user cannot remove.
     /// Example prompt: "Your device has restricted access to iCloud. Please check your device settings or contact an administrator."
     case restricted

     /// The user's iCloud account is temporarily unavailable, which may be due to server maintenance or temporary issues.
     /// This status usually resolves automatically after a period of time.
     /// Example prompt: "Your iCloud account is temporarily unavailable. Please try again later."
     case temporarilyUnavailable
 */
