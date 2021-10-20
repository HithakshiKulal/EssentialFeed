//
//   Tests.swift
//  EssentialFeedTests
//
//  Created by Hithakshi on 30/09/21.
//

import XCTest
import EssentialFeed

class URLSessionHTTPClientTests: XCTestCase {

    override func setUp() {
        URLProtocolStub.startInterceptingRequests()
    }

    override func tearDown() {
        URLProtocolStub.stopInterceptingRequests()
    }

    func test_getFromURL_perfromsGETRequestsWithURL() {
        let url = anyURL()
        let exp = expectation(description: "wait for request")

        URLProtocolStub.observeRequests { request in
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "GET")
            exp.fulfill()
        }

        makeSUT().get(from: url) { _ in }

        wait(for: [exp], timeout: 1)
    }


    func test_getFromURL_failsOnRequestError() {
        let requestError = anyNSError

        let receivedError = resultErrorFor(data: nil, response: nil, error: requestError)

        XCTAssertEqual((receivedError as NSError?)?.domain, requestError.domain)
        XCTAssertEqual((receivedError as NSError?)?.code, requestError.code)
    }

    func test_getFromURL_failsOnAllInvalidRepresentationCases() {
        XCTAssertNotNil(resultErrorFor(data: nil, response: nil, error: nil))
        XCTAssertNotNil(resultErrorFor(data: nil, response: nonHTTPURLResponse, error: nil))
        XCTAssertNotNil(resultErrorFor(data: anyData, response: nil, error: nil))
        XCTAssertNotNil(resultErrorFor(data: anyData, response: nil, error: anyNSError))
        XCTAssertNotNil(resultErrorFor(data: nil, response: nonHTTPURLResponse, error: anyNSError))
        XCTAssertNotNil(resultErrorFor(data: nil, response: anyHTTPURLResponse, error: anyNSError))
        XCTAssertNotNil(resultErrorFor(data: anyData, response: nonHTTPURLResponse, error: anyNSError))
        XCTAssertNotNil(resultErrorFor(data: anyData, response: anyHTTPURLResponse, error: anyNSError))
        XCTAssertNotNil(resultErrorFor(data: anyData, response: nonHTTPURLResponse, error: nil))
    }

    func test_getFromURL_succeedsOnHTTPURLResponseWithData() {
        let data = anyData
        let response = anyHTTPURLResponse

        let receivedValues = resultValuesFor(data: data, response: response, error: nil)

        XCTAssertEqual(data, receivedValues?.data)
        XCTAssertEqual(response.url, receivedValues?.response.url)

    }

    func test_getFromURL_succeedsWithEmptyDataOnHTTPURLResponseWithNilData() {
        let response = anyHTTPURLResponse
        let receivedValues = resultValuesFor(data: nil, response: response, error: nil)
        let emptyData = Data()
        XCTAssertEqual(emptyData, receivedValues?.data)
        XCTAssertEqual(response.url, receivedValues?.response.url)
        XCTAssertEqual(response.statusCode, receivedValues?.response.statusCode)
    }

    // MARK: - Helpers

    private func resultValuesFor(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (data: Data, response: HTTPURLResponse)? {
        let result = resultFor(data: data, response: response, error: error, file: file, line: line)

        switch result {
        case let .success((data, response)):
            return (data, response)
        default:
            XCTFail(
                "Expected success, got \(result) instead",
                file: file,
                line: line
            )
            return nil
        }
    }

    private func resultErrorFor(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Error? {
        let result = resultFor(data: data, response: response, error: error, file: file, line: line)

        switch result {
        case .failure(let error):
            return error
        default:
            XCTFail(
                "Expected failure, got \(result) instead",
                file: file,
                line: line
            )
            return nil
        }
    }

    private func resultFor(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> HTTPClientResult? {
        URLProtocolStub.stub(data: data, response: response, error: error)

        let sut = makeSUT(file: file, line: line)
        let exp = expectation(description: "wait for completion")

        var result: HTTPClientResult?
        sut.get(from: anyURL()) {
            result = $0
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1)
        return result
    }

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> HTTPClient {
        let sut = URLSessionHTTPClient()
        trackMemoryLeaks(sut, file: file, line: line)
        return sut
    }

    private func anyURL() -> URL {
        URL(string: "https://any-url.com")!
    }

    private var anyData: Data { Data("any Data".utf8) }

    var anyNSError: NSError { NSError(domain: "any error", code: 0) }

    var anyHTTPURLResponse: HTTPURLResponse {
        HTTPURLResponse(
            url: anyURL(),
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )
    }

    var nonHTTPURLResponse: URLResponse {
        URLResponse(
            url: anyURL(),
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )
    }

    private class URLProtocolStub: URLProtocol {

        private static var stub: Stub?
        private static var requestObserver: ((URLRequest) -> Void)?

        private struct Stub {
            let data: Data?
            let response: URLResponse?
            let error: Error?
        }

        static func stub(data: Data?, response: URLResponse?, error: Error? ) {
            self.stub = Stub(data: data, response: response, error: error)
        }

        static func startInterceptingRequests() {
            URLProtocol.registerClass(URLProtocolStub.self)
        }

        static func stopInterceptingRequests() {
            URLProtocol.unregisterClass(URLProtocolStub.self)
            stub = nil
            requestObserver = nil
        }

        static func observeRequests(observer: @escaping (URLRequest) -> Void) {
            requestObserver = observer
        }

        override class func canInit(with request: URLRequest) -> Bool {
            requestObserver?(request)
            return true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }

        override func startLoading() {
            guard let stub = Self.stub else { return }
            if let data = stub.data {
                client?.urlProtocol(self, didLoad: data)
            }
            if let response = stub.response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let error = stub.error {
                client?.urlProtocol(self, didFailWithError: error)
            }
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

}
