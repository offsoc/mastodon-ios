//
//  NotificationItem.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/4/13.
//

import CoreData
import Foundation
import MastodonSDK

enum NotificationListItem: Hashable {
    case filteredNotificationsInfo(policy: Mastodon.Entity.NotificationPolicy)
    case notification(MastodonFeedItemIdentifier)
    case middleLoader(after: MastodonFeedItemIdentifier, before: MastodonFeedItemIdentifier)
    case bottomLoader
    
    var nextFetchAnchors: (MastodonFeedItemIdentifier?, MastodonFeedItemIdentifier?) {
        switch self {
        case .filteredNotificationsInfo:
            return (nil, nil)
        case .notification(let identifier):
            return (identifier, nil)
        case .middleLoader(let after, let before):
            return (after, before)
        case .bottomLoader:
            return (nil, nil)
        }
    }
}

extension NotificationListItem: Identifiable {
    typealias ID = String
    
    var id: ID {
        switch self {
        case .filteredNotificationsInfo:
            return "filtered_notifications_info"
        case .notification(let identifier):
            return identifier.id
        case let .middleLoader(afterID, beforeID):
            return afterID.id+"-"+beforeID.id
        case .bottomLoader:
            return "bottom_loader"
        }
    }
}