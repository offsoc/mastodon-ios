//
//  StatusFilterService.swift
//  Mastodon
//
//  Created by Cirno MainasuK on 2021-7-14.
//

import Foundation
import Combine
import CoreData
import CoreDataStack
import MastodonSDK
import MastodonMeta

@MainActor
public final class StatusFilterService {
    public static let shared = { StatusFilterService() }()

    var disposeBag = Set<AnyCancellable>()

    // input
    public let filterUpdatePublisher = PassthroughSubject<Void, Never>()

    // output
    @Published public var activeFilterApplication: Mastodon.Entity.FilterApplication? = nil

    private init() {
        // fetch account filters every 300s
        // also trigger fetch when app resume from background
        let filterUpdateTimerPublisher = Timer.publish(every: 300.0, on: .main, in: .common)
            .autoconnect()
            .share()
            .eraseToAnyPublisher()

        filterUpdateTimerPublisher
            .map { _ in }
            .subscribe(filterUpdatePublisher)
            .store(in: &disposeBag)

        Publishers.CombineLatest(
            AuthenticationServiceProvider.shared.currentActiveUser,
            filterUpdatePublisher
        )
        .sink { authBox, _ in
            Task {
                guard let box = authBox else {
                    throw APIService.APIError.implicit(.authenticationMissing)
                }
                let filters = try await APIService.shared.filters(mastodonAuthenticationBox: box)
                let now = Date()
                let activeFilters = filters.filter { filter in
                    if let expiresAt = filter.expiresAt {
                        // filter out expired rules
                        return expiresAt > now
                    } else {
                        return true
                    }
                }
                let newFilterBox = Mastodon.Entity.FilterApplication(filters: activeFilters)
                guard self.activeFilterApplication != newFilterBox else { return }
                self.activeFilterApplication = newFilterBox
            }
        }
        .store(in: &disposeBag)

        // make initial trigger once
        filterUpdatePublisher.send()
    }

}
