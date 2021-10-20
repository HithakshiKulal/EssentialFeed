//
//  HTTPClient.swift
//  EssentialFeed
//
//  Created by Hithakshi on 19/09/21.
//

import Foundation

public typealias HTTPClientResult = Result<(Data, HTTPURLResponse), Error>

public protocol HTTPClient {

    func get(from url: URL, completion: @escaping (HTTPClientResult) -> Void)
}
