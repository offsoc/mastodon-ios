//
//  BetaTestSetting.swift
//  MastodonSDK
//
//  Created by Shannon Hughes on 2025-01-13.
//

import Foundation

extension UserDefaults {
    
    public static var isDebugOrTestflightOrSimulator: Bool {
        #if DEBUG
            return true
        #else
            guard let path = Bundle.main.appStoreReceiptURL?.path else {
                return false
            }
            return path.contains("CoreSimulator") || path.contains("sandboxReceipt")
        #endif
    }

    @objc public dynamic var useStagingForDonations: Bool {
        get {
            register(defaults: [#function: true])
            return bool(forKey: #function) && UserDefaults.isDebugOrTestflightOrSimulator
        }
        set { self[#function] = newValue }
    }
    
    @objc public dynamic var useGroupedNotifications: Bool {
        get {
            register(defaults: [#function: false])
            return bool(forKey: #function) && UserDefaults.isDebugOrTestflightOrSimulator
        }
        set { self[#function] = newValue }
    }

    public func toggleUseStagingForDonations() {
        let useStaging = UserDefaults.standard.useStagingForDonations
        UserDefaults.standard.useStagingForDonations = !useStaging
    }
    
    public func toggleUseGroupedNotifications() {
        let useGrouped = UserDefaults.standard.useGroupedNotifications
        UserDefaults.standard.useGroupedNotifications = !useGrouped
    }
}
