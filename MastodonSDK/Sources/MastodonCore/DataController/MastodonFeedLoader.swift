//
//  MastodonFeedLoader.swift
//  MastodonSDK
//
//  Created by Shannon Hughes on 1/8/25.
//

import Foundation
import UIKit
import Combine
import MastodonSDK
import os.log

@MainActor
final public class MastodonFeedLoader {
    
    public enum DeduplicationPolicy {
        case omitNewest
        case removeOldest
    }
    
    private let logger = Logger(subsystem: "MastodonFeedLoader", category: "Data")
    private static let entryNotFoundMessage = "Failed to find suitable record. Depending on the context this might result in errors (data not being updated) or can be discarded (e.g. when there are mixed data sources where an entry might or might not exist)."
    
    @Published public private(set) var records: [MastodonFeedItemIdentifier] = []
    
    private let authenticationBox: MastodonAuthenticationBox
    private let kind: MastodonFeedKind
    private let dedupePolicy: DeduplicationPolicy
    
    private var subscriptions = Set<AnyCancellable>()
    
    public init(authenticationBox: MastodonAuthenticationBox, kind: MastodonFeedKind, dedupePolicy: DeduplicationPolicy = .omitNewest) {
        self.authenticationBox = authenticationBox
        self.kind = kind
        self.dedupePolicy = dedupePolicy
        
        StatusFilterService.shared.$activeFilterBox
            .sink { filterBox in
                if filterBox != nil {
                    Task { [weak self] in
                        guard let self else { return }
                        await self.setRecordsAfterFiltering(self.records)
                    }
                }
            }
            .store(in: &subscriptions)
    }
    
    private func setRecordsAfterFiltering(_ newRecords: [MastodonFeedItemIdentifier]) async {
        guard let filterBox = StatusFilterService.shared.activeFilterBox else { self.records = newRecords; return }
        let filtered = await self.filter(newRecords, forFeed: kind, with: filterBox)
        self.records = filtered.removingDuplicates()
    }
    
    private func appendRecordsAfterFiltering(_ additionalRecords: [MastodonFeedItemIdentifier]) async {
        guard let filterBox = StatusFilterService.shared.activeFilterBox else { self.records += additionalRecords; return }
        let newRecords = await self.filter(additionalRecords, forFeed: kind, with: filterBox)
        switch dedupePolicy {
        case .omitNewest:
            self.records = (self.records + newRecords).removingDuplicates()
        case .removeOldest:
            assertionFailure("not implemented")
            self.records = (self.records + newRecords).removingDuplicates()
        }
    }
    
    public func loadInitial(kind: MastodonFeedKind) {
        Task {
            let unfilteredRecords = try await load(kind: kind)
            await setRecordsAfterFiltering(unfilteredRecords)
        }
    }
    
    public func loadNext(kind: MastodonFeedKind) {
        Task {
            guard let lastId = records.last?.id else {
                return loadInitial(kind: kind)
            }
            
            let unfiltered = try await load(kind: kind, olderThan: lastId)
            await self.appendRecordsAfterFiltering(unfiltered)
        }
    }
    
    private func filter(_ records: [MastodonFeedItemIdentifier], forFeed feedKind: MastodonFeedKind, with filterBox: Mastodon.Entity.FilterBox) async -> [MastodonFeedItemIdentifier] {
        
        let filteredRecords = records.filter { itemIdentifier in
            guard let status = MastodonFeedItemCacheManager.shared.filterableStatus(associatedWith: itemIdentifier) else { return true }
            let filterResult = filterBox.apply(to: status, in: feedKind.filterContext)
            switch filterResult {
            case .hide:
                return false
            default:
                return true
            }
        }
        return filteredRecords
    }
    
    // TODO: all of these updates should happen the cached item, and then any cells referencing them should be reconfigured
//    @MainActor
//    public func update(status: MastodonStatus, intent: MastodonStatus.UpdateIntent) {
//        switch intent {
//        case .delete:
//            delete(status)
//        case .edit:
//            updateEdited(status)
//        case let .bookmark(isBookmarked):
//            updateBookmarked(status, isBookmarked)
//        case let .favorite(isFavorited):
//            updateFavorited(status, isFavorited)
//        case let .reblog(isReblogged):
//            updateReblogged(status, isReblogged)
//        case let .toggleSensitive(isVisible):
//            updateSensitive(status, isVisible)
//        case .pollVote:
//            updateEdited(status) // technically the data changed so refresh it to reflect the new data
//        }
//    }
    
//    @MainActor
//    private func delete(_ status: MastodonStatus) {
//        records.removeAll { $0.id == status.id }
//    }
//    
//    @MainActor
//    private func updateEdited(_ status: MastodonStatus) {
//        var newRecords = Array(records)
//        guard let index = newRecords.firstIndex(where: { $0.id == status.id }) else {
//            logger.warning("\(Self.entryNotFoundMessage)")
//            return
//        }
//        let existingRecord = newRecords[index]
//        let newStatus = status.inheritSensitivityToggled(from: existingRecord.status)
//        newRecords[index] = .fromStatus(newStatus, kind: existingRecord.kind)
//        records = newRecords
//    }
//    
//    @MainActor
//    private func updateBookmarked(_ status: MastodonStatus, _ isBookmarked: Bool) {
//        var newRecords = Array(records)
//        guard let index = newRecords.firstIndex(where: { $0.id == status.id }) else {
//            logger.warning("\(Self.entryNotFoundMessage)")
//            return
//        }
//        let existingRecord = newRecords[index]
//        let newStatus = status.inheritSensitivityToggled(from: existingRecord.status)
//        newRecords[index] = .fromStatus(newStatus, kind: existingRecord.kind)
//        records = newRecords
//    }
//    
//    @MainActor
//    private func updateFavorited(_ status: MastodonStatus, _ isFavorited: Bool) {
//        var newRecords = Array(records)
//        if let index = newRecords.firstIndex(where: { $0.id == status.id }) {
//            // Replace old status entity
//            let existingRecord = newRecords[index]
//            let newStatus = status.inheritSensitivityToggled(from: existingRecord.status).withOriginal(status: existingRecord.status?.originalStatus)
//            newRecords[index] = .fromStatus(newStatus, kind: existingRecord.kind)
//        } else if let index = newRecords.firstIndex(where: { $0.status?.reblog?.id == status.id }) {
//            // Replace reblogged entity of old "parent" status
//            let newStatus: MastodonStatus
//            if let existingEntity = newRecords[index].status?.entity {
//                newStatus = .fromEntity(existingEntity)
//                newStatus.originalStatus = newRecords[index].status?.originalStatus
//                newStatus.reblog = status
//            } else {
//                newStatus = status
//            }
//            newRecords[index] = .fromStatus(newStatus, kind: newRecords[index].kind)
//        } else {
//            logger.warning("\(Self.entryNotFoundMessage)")
//        }
//        records = newRecords
//    }
//    
//    @MainActor
//    private func updateReblogged(_ status: MastodonStatus, _ isReblogged: Bool) {
//        var newRecords = Array(records)
//        
//        switch isReblogged {
//        case true:
//            let index: Int
//            if let idx = newRecords.firstIndex(where: { $0.status?.reblog?.id == status.reblog?.id }) {
//                index = idx
//            } else if let idx = newRecords.firstIndex(where: { $0.id == status.reblog?.id }) {
//                index = idx
//            } else {
//                logger.warning("\(Self.entryNotFoundMessage)")
//                return
//            }
//            let existingRecord = newRecords[index]
//            newRecords[index] = .fromStatus(status.withOriginal(status: existingRecord.status), kind: existingRecord.kind)
//        case false:
//            let index: Int
//            if let idx = newRecords.firstIndex(where: { $0.status?.reblog?.id == status.id }) {
//                index = idx
//            } else if let idx = newRecords.firstIndex(where: { $0.status?.id == status.id }) {
//                index = idx
//            } else {
//                logger.warning("\(Self.entryNotFoundMessage)")
//                return
//            }
//            let existingRecord = newRecords[index]
//            let newStatus = existingRecord.status?.originalStatus ?? status.inheritSensitivityToggled(from: existingRecord.status)
//            newRecords[index] = .fromStatus(newStatus, kind: existingRecord.kind)
//        }
//        records = newRecords
//    }
//    
//    @MainActor
//    private func updateSensitive(_ status: MastodonStatus, _ isVisible: Bool) {
//        var newRecords = Array(records)
//        if let index = newRecords.firstIndex(where: { $0.status?.reblog?.id == status.id }), let existingEntity = newRecords[index].status?.entity {
//            let existingRecord = newRecords[index]
//            let newStatus: MastodonStatus = .fromEntity(existingEntity)
//            newStatus.reblog = status
//            newRecords[index] = .fromStatus(newStatus, kind: existingRecord.kind)
//        } else if let index = newRecords.firstIndex(where: { $0.id == status.id }), let existingEntity = newRecords[index].status?.entity {
//            let existingRecord = newRecords[index]
//            let newStatus: MastodonStatus = .fromEntity(existingEntity)
//                .inheritSensitivityToggled(from: status)
//            newRecords[index] = .fromStatus(newStatus, kind: existingRecord.kind)
//        } else {
//            logger.warning("\(Self.entryNotFoundMessage)")
//            return
//        }
//        records = newRecords
//    }
}

private extension MastodonFeedLoader {
    
    func load(kind: MastodonFeedKind, olderThan maxID: String? = nil) async throws -> [MastodonFeedItemIdentifier] {
        switch kind {
        case .notificationsAll:
            return try await loadNotifications(withScope: .everything, olderThan: maxID)
        case .notificationsMentionsOnly:
            return try await loadNotifications(withScope: .mentions, olderThan: maxID)
        case .notificationsWithAccount(let accountID):
            return try await loadNotifications(withAccountID: accountID, olderThan: maxID)
        }
    }
        
    private func loadNotifications(withScope scope: APIService.MastodonNotificationScope, olderThan maxID: String? = nil) async throws -> [MastodonFeedItemIdentifier] {
        let useGroupedNotifications = false
        if useGroupedNotifications {
            return try await _getGroupedNotifications(withScope: scope, olderThan: maxID)
        } else {
            return try await _getUngroupedNotifications(withScope: scope, olderThan: maxID)
        }
    }
    
    private func loadNotifications(withAccountID accountID: String, olderThan maxID: String? = nil) async throws -> [MastodonFeedItemIdentifier] {
        let useGroupedNotifications = false
        if useGroupedNotifications {
            return try await _getGroupedNotifications(accountID: accountID, olderThan: maxID)
        } else {
            return try await _getUngroupedNotifications(accountID: accountID, olderThan: maxID)
        }
    }
    
    private func _getUngroupedNotifications(withScope scope: APIService.MastodonNotificationScope? = nil, accountID: String? = nil, olderThan maxID: String? = nil) async throws -> [MastodonFeedItemIdentifier] {
        
        assert(scope != nil || accountID != nil, "need a scope or an accountID")
        
        let notifications = try await APIService.shared.notifications(olderThan: maxID, fromAccount: accountID, scope: scope, authenticationBox: authenticationBox).value
        
        let accounts = notifications.map { $0.account }
        let relationships = try await APIService.shared.relationship(forAccounts: accounts, authenticationBox: authenticationBox).value
        for relationship in relationships {
            MastodonFeedItemCacheManager.shared.addToCache(relationship)
        }
        
        return notifications.map {
            MastodonFeedItemCacheManager.shared.addToCache($0)
            return MastodonFeedItemIdentifier.notification(id: $0.id)
        }
    }
    
    private func _getGroupedNotifications(withScope scope: APIService.MastodonNotificationScope? = nil, accountID: String? = nil, olderThan maxID: String? = nil) async throws -> [MastodonFeedItemIdentifier] {
        
        assert(scope != nil || accountID != nil, "need a scope or an accountID")
        
        let results = try await APIService.shared.groupedNotifications(olderThan: maxID, fromAccount: accountID, scope: scope, authenticationBox: authenticationBox).value
        
        for account in results.accounts {
            MastodonFeedItemCacheManager.shared.addToCache(account)
        }
        if let partials = results.partialAccounts {
            for partialAccount in partials {
                MastodonFeedItemCacheManager.shared.addToCache(partialAccount)
            }
        }
        for status in results.statuses {
            MastodonFeedItemCacheManager.shared.addToCache(status)
        }
        
        return results.notificationGroups.map {
            MastodonFeedItemCacheManager.shared.addToCache($0)
            return MastodonFeedItemIdentifier.notificationGroup(id: $0.id)
        }
    }
}

extension MastodonFeedKind {
    var filterContext: Mastodon.Entity.FilterContext {
        switch self {
        case .notificationsAll, .notificationsMentionsOnly, .notificationsWithAccount:
            return .notifications
        }
    }
}