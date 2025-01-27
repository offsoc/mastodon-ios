// Copyright © 2024 Mastodon gGmbH. All rights reserved.

import Foundation
import MastodonSDK

extension MastodonStatusThreadViewModel {
    // Bookmark
    func handleBookmark(_ status: MastodonStatus) {
        ancestors = handleBookmark(status, items: ancestors)
        descendants = handleBookmark(status, items: descendants)
    }
    
    private func handleBookmark(_ status: MastodonStatus, items: [MastodonItemIdentifier]) -> [MastodonItemIdentifier] {
        var newRecords = Array(items)
        guard let index = newRecords.firstIndex(where: { $0.mastodonStatus?.id == status.id }) else {
            return items
        }
        var newRecord = newRecords[index]
        newRecord.mastodonStatus = status
        newRecords[index] = newRecord
        return newRecords
    }
    
    // Favorite
    func handleFavorite(_ status: MastodonStatus) {
        ancestors = handleFavorite(status, items: ancestors)
        descendants = handleFavorite(status, items: descendants)
    }
    
    private func handleFavorite(_ status: MastodonStatus, items: [MastodonItemIdentifier]) -> [MastodonItemIdentifier] {
        var newRecords = Array(items)
        guard let index = newRecords.firstIndex(where: { $0.mastodonStatus?.id == status.id }) else {
            return items
        }
        var newRecord = newRecords[index]
        newRecord.mastodonStatus = status
        newRecords[index] = newRecord
        return newRecords
    }
    
    // Reblog
    func handleReblog(_ status: MastodonStatus, _ isReblogged: Bool) {
        ancestors = handleReblog(status, isReblogged, items: ancestors)
        descendants = handleReblog(status, isReblogged, items: descendants)
    }
    
    private func handleReblog(_ status: MastodonStatus, _ isReblogged: Bool, items: [MastodonItemIdentifier]) -> [MastodonItemIdentifier] {
        var newRecords = Array(items)

        switch isReblogged {
        case true:
            let index: Int
            if let idx = newRecords.firstIndex(where: { $0.mastodonStatus?.reblog?.id == status.reblog?.id }) {
                index = idx
            } else if let idx = newRecords.firstIndex(where: { $0.mastodonStatus?.id == status.reblog?.id }) {
                index = idx
            } else {
                logger.warning("\(Self.entryNotFoundMessage)")
                return newRecords
            }
            var newRecord = newRecords[index]
            newRecord.mastodonStatus = status.inheritSensitivityToggled(from: newRecord.mastodonStatus)
            newRecords[index] = newRecord
        case false:
            let index: Int
            if let idx = newRecords.firstIndex(where: { $0.mastodonStatus?.reblog?.id == status.id }) {
                index = idx
            } else if let idx = newRecords.firstIndex(where: { $0.mastodonStatus?.id == status.id }) {
                index = idx
            } else {
                logger.warning("\(Self.entryNotFoundMessage)")
                return newRecords
            }
            var newRecord = newRecords[index]
            newRecord.mastodonStatus = status.inheritSensitivityToggled(from: newRecord.mastodonStatus)
            newRecords[index] = newRecord
        }

        return newRecords
    }
    
    // Sensitive
    func handleSensitive(_ status: MastodonStatus, _ isVisible: Bool) {
        ancestors = handleSensitive(status, isVisible, ancestors)
        descendants = handleSensitive(status, isVisible, descendants)
    }
    
    private func handleSensitive(_ status: MastodonStatus, _ isVisible: Bool, _ items: [MastodonItemIdentifier]) -> [MastodonItemIdentifier] {
        var newRecords = Array(items)
        guard let index = newRecords.firstIndex(where: { $0.mastodonStatus?.id == status.id }) else {
            return items
        }
        var newRecord = newRecords[index]
        newRecord.mastodonStatus = status
        newRecords[index] = newRecord
        return newRecords
    }
    
    // Edit
    func handleEdit(_ status: MastodonStatus) {
        ancestors = handleEdit(status, items: ancestors)
        descendants = handleEdit(status, items: descendants)
    }
    
    private func handleEdit(_ status: MastodonStatus, items: [MastodonItemIdentifier]) -> [MastodonItemIdentifier] {
        var newRecords = Array(items)
        guard let index = newRecords.firstIndex(where: { $0.mastodonStatus?.id == status.id }) else {
            return items
        }
        var newRecord = newRecords[index]
        newRecord.mastodonStatus = status
        newRecords[index] = newRecord
        return newRecords
    }
    
    // Delete
    func handleDelete(_ status: MastodonStatus) {
        ancestors = handleDelete(status, ancestors)
        descendants = handleDelete(status, descendants)
    }
    
    private func handleDelete(_ status: MastodonStatus, _ items: [MastodonItemIdentifier]) -> [MastodonItemIdentifier] {
        var newRecords = Array(items)
        newRecords.removeAll(where: { $0.mastodonStatus?.id == status.id })
        return newRecords
    }
}


private extension MastodonItemIdentifier {
    var mastodonStatus: MastodonStatus? {
        get {
            switch self {
            case .feed(let record):
                return record.status
            case .feedLoader(let record):
                return record.status
            case .status(let record):
                return record
            case .thread(let thread):
                return thread.record
            case .topLoader, .bottomLoader:
                return nil
            }
        }
        
        set {
            guard let status = newValue else { return }
            switch self {
            case .feed(let record):
                self = .feed(.fromStatus(status, kind: record.kind))
            case .feedLoader(let record):
                self = .feedLoader(feed: .fromStatus(status, kind: record.kind))
            case .status:
                self = .status(status)
            case let .thread(thread):
                var newThread = thread
                newThread.record = status
                self = .thread(newThread)
            case .topLoader, .bottomLoader:
                break
            }
        }
    }
}
