//
//  FeedLoader.swift
//  EssentialFeed
//
//  Created by Hithakshi on 14/09/21.
//

import Foundation

public enum LoadFeedResult {
    case success([FeedItem])
    case failure(Error)
}

public protocol FeedLoader {
    func load(completion: @escaping (LoadFeedResult) -> Void)
}
