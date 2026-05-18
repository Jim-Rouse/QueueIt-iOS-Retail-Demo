	// QueueItAPIClient.swift
// Drop-in async/await API client for the Queue-it hybrid (server-side KnownUser) integration.
//
// HYBRID FLOW (per Queue-it docs):
// ─────────────────────────────────
//  1. Outbound request:
//       - Attach x-queueit-ajaxpageurl header (non-empty)
//       - Attach Cookie header with any stored Queue-it cookies
//
//  2. Response routing:
//       A. Has `x-queueit-redirect` header  →  user must queue
//          - Parse customerId (c=) and waitingRoomId (e=) from redirect URL
//          - Surface a .queueRequired result so the caller can invoke QueueItEngine
//          - Caller waits for onQueuePassed, then retries with queueittoken query param
//
//       B. No redirect header  →  success path
//          - Store any Set-Cookie values from response
//          - Return .success(data, response)
//
//  3. Post-queue retry:
//       - Append queueittoken={token} query param to the URL
//       - Re-run the decorated request
//       - Store cookies from this final response too

import Foundation
import QueueItKit

// MARK: - Result types

public enum QueueItAPIResult<T> {
    /// The API call succeeded. Cookies have been stored automatically.
    case success(T, HTTPURLResponse)
    /// The Queue-it connector intercepted the call. The caller must present the queue.
    case queueRequired(QueueItRedirectInfo)
    /// A non-queue HTTP error occurred.
    case httpError(Int, Data)
    /// A transport/network error occurred.
    case networkError(Error)
}

/// Info extracted from the x-queueit-redirect header.
public struct QueueItRedirectInfo {
    public let customerId: String
    public let waitingRoomId: String
    public let redirectURL: URL
}

// MARK: - Client

/// Async/await wrapper around URLSession that handles Queue-it cookie forwarding
/// and intercept detection automatically.
public final class QueueItAPIClient {

    // MARK: Configuration

    public struct Config {
        /// Sent as x-queueit-ajaxpageurl. Must be non-empty. Identifies the
        /// logical "page" or screen being protected.
        public var ajaxPageURL: String
        /// Timeout for each individual request.
        public var timeoutInterval: TimeInterval

        public init(
            ajaxPageURL: String = "app://protected",
            timeoutInterval: TimeInterval = 30
        ) {
            self.ajaxPageURL = ajaxPageURL
            self.timeoutInterval = timeoutInterval
        }
    }

    // MARK: Properties

    public let config: Config
    private let session: URLSession
    private let cookieManager: QueueItCookieManager

    // MARK: Init

    public init(
        config: Config = Config(),
        cookieManager: QueueItCookieManager = .shared
    ) {
        self.config = config
        self.cookieManager = cookieManager

        // Disable automatic cookie handling — we manage cookies manually so we
        // have complete visibility into what is sent and received.
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpCookieAcceptPolicy = .never
        sessionConfig.httpShouldSetCookies = false
        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - Public API

    /// Executes `request`, handling Queue-it cookie injection and intercept detection.
    ///
    /// - Returns: `.success` with raw `Data`, `.queueRequired`, `.httpError`, or `.networkError`.
    ///
    /// Usage:
    /// ```swift
    /// let result = await apiClient.perform(URLRequest(url: productURL))
    /// switch result {
    /// case .success(let data, _):
    ///     // decode data
    /// case .queueRequired(let info):
    ///     // call QueueItEngine with info.customerId / info.waitingRoomId
    ///     // wait for onQueuePassed → call retryAfterQueue(request, token:)
    /// case .httpError(let code, _):
    ///     // handle
    /// case .networkError(let error):
    ///     // handle
    /// }
    /// ```
    public func perform(_ request: URLRequest) async -> QueueItAPIResult<Data> {
        let decorated = cookieManager.decorate(request, ajaxPageURL: config.ajaxPageURL)
        return await execute(decorated)
    }

    /// Re-issues `originalRequest` after the user has passed the queue,
    /// appending `queueittoken={token}` to prevent re-interception by the connector.
    ///
    /// Call this from your `onQueuePassed` handler after storing the token.
    public func retryAfterQueue(
        _ originalRequest: URLRequest,
        token: String
    ) async -> QueueItAPIResult<Data> {
        guard let urlWithToken = originalRequest.url?.appendingQueueItToken(token) else {
            return .networkError(QueueItClientError.invalidURL)
        }
        var retryRequest = originalRequest
        retryRequest.url = urlWithToken
        let decorated = cookieManager.decorate(retryRequest, ajaxPageURL: config.ajaxPageURL)
        return await execute(decorated)
    }

    // MARK: - Private execution

    private func execute(_ request: URLRequest) async -> QueueItAPIResult<Data> {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .networkError(QueueItClientError.unexpectedResponse)
            }

            // ── Step 1: Check for Queue-it intercept ─────────────────────────
            if let redirectHeader = httpResponse.value(forHTTPHeaderField: "x-queueit-redirect"),
               let redirectURL = URL(string: redirectHeader),
               let info = parseRedirectInfo(from: redirectURL) {
                // Do NOT store cookies here — the response is synthetic from the connector.
                return .queueRequired(info)
            }

            // ── Step 2: Non-queue response — store cookies ───────────────────
            if let url = request.url {
                cookieManager.storeCookies(from: httpResponse.allHeaderFields, for: url)
            }

            // ── Step 3: Check for HTTP errors ────────────────────────────────
            guard (200...299).contains(httpResponse.statusCode) else {
                return .httpError(httpResponse.statusCode, data)
            }

            return .success(data, httpResponse)

        } catch {
            return .networkError(error)
        }
    }

    // MARK: - Redirect header parsing

    /// Extracts `c` (customerId) and `e` (waitingRoomId) query parameters
    /// from the x-queueit-redirect header value.
    private func parseRedirectInfo(from url: URL) -> QueueItRedirectInfo? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return nil }

        let params = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        guard let customerId = params["c"], let waitingRoomId = params["e"] else {
            return nil
        }
        return QueueItRedirectInfo(
            customerId: customerId,
            waitingRoomId: waitingRoomId,
            redirectURL: url
        )
    }
}

// MARK: - Client errors

public enum QueueItClientError: LocalizedError {
    case invalidURL
    case unexpectedResponse

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Could not construct a valid URL for the Queue-it retry request."
        case .unexpectedResponse: return "Received a non-HTTP response."
        }
    }
}

// MARK: - URL helpers

private extension URL {
    /// Appends `queueittoken={token}` as a query parameter to the URL.
    func appendingQueueItToken(_ token: String) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "queueittoken" }   // replace if already present
        items.append(URLQueryItem(name: "queueittoken", value: token))
        components.queryItems = items
        return components.url
    }
}
