// QueueItCookieManager.swift
// Manages Queue-it cookie lifecycle for the hybrid (KnownUser server-side) integration.
//
// WHY a dedicated cookie manager?
// ────────────────────────────────
// iOS URLSession can manage cookies automatically, but we need strict isolation
// (Queue-it cookies must not bleed into other sessions), we need to persist them
// across app launches, and we need to inject them as explicit `Cookie` headers
// so they also reach API calls made through *any* URLSession instance.
//
// Cookie forwarding contract (from Queue-it docs):
//   • Every outbound request to a protected API must include:
//       x-queueit-ajaxpageurl: <non-empty value>
//       Cookie: <any Queue-it cookies stored from prior responses>
//   • After receiving a response that does NOT have x-queueit-redirect:
//       → extract & store Set-Cookie headers for next round
//   • After the queue passes and the final API call succeeds:
//       → store those cookies too

import Foundation

// MARK: - Public interface

/// Thread-safe store for Queue-it cookies.
/// Persist across launches via UserDefaults (serialised HTTPCookie properties).
public final class QueueItCookieManager {

    // MARK: Constants

    private enum Keys {
        static let userDefaultsKey = "com.queueit.sdk.cookies"
        static let queueItCookiePrefixes = ["QueueITAccepted", "QueueIT", "queueit"]
    }

    // MARK: Singleton

    public static let shared = QueueItCookieManager()

    // MARK: Private state

    /// In-memory store; always the source of truth during a session.
    private var _cookies: [HTTPCookie] = []
    private let lock = NSLock()

    // MARK: Init

    private init() {
        _cookies = Self.loadFromDisk()
    }

    // MARK: - Reading cookies

    /// All currently stored Queue-it cookies.
    public var cookies: [HTTPCookie] {
        lock.lock(); defer { lock.unlock() }
        return _cookies
    }

    /// Returns the Cookie header value to inject into an outbound request.
    /// e.g. "QueueITAccepted-SDU3=abc123; QueueIT-d8b7=xyz"
    public func cookieHeaderValue(for url: URL) -> String? {
        let relevant = cookies(for: url)
        guard !relevant.isEmpty else { return nil }
        return relevant
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")
    }

    /// Returns only cookies that match the given URL's domain/path.
    public func cookies(for url: URL) -> [HTTPCookie] {
        lock.lock(); defer { lock.unlock() }
        return HTTPCookie.cookies(withResponseHeaderFields: [:], for: url)
            .isEmpty
            ? _cookies   // fallback: return all if no domain filter possible
            : _cookies.filter { cookie in
                guard let host = url.host else { return true }
                let domain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
                return host.hasSuffix(domain)
            }
    }

    // MARK: - Writing cookies

    /// Parse and store Queue-it cookies from a raw response header dictionary.
    /// Call this after every API response that does NOT trigger a queue redirect.
    ///
    /// - Parameters:
    ///   - headers: The `allHeaderFields` of the HTTP response.
    ///   - url: The request URL (needed for domain/path defaults).
    public func storeCookies(from headers: [AnyHashable: Any], for url: URL) {
        let stringHeaders = headers.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                result[key] = value
            }
        }
        let parsed = HTTPCookie.cookies(withResponseHeaderFields: stringHeaders, for: url)
        let queueItCookies = parsed.filter { isQueueItCookie($0) }
        guard !queueItCookies.isEmpty else { return }
        merge(queueItCookies)
    }

    /// Directly merge an array of HTTPCookie objects (e.g. from WKWebView's cookie store).
    public func storeCookies(_ newCookies: [HTTPCookie]) {
        let queueItCookies = newCookies.filter { isQueueItCookie($0) }
        guard !queueItCookies.isEmpty else { return }
        merge(queueItCookies)
    }

    /// Remove all stored Queue-it cookies (e.g. on logout or session expiry).
    public func clearAll() {
        lock.lock()
        _cookies = []
        lock.unlock()
        saveToDisk([])
    }

    // MARK: - URLRequest decoration

    /// Returns a copy of `request` with the Queue-it `Cookie` and
    /// `x-queueit-ajaxpageurl` headers injected.
    ///
    /// - Parameters:
    ///   - request: The original API request.
    ///   - ajaxPageURL: The value for `x-queueit-ajaxpageurl`. Must be non-empty.
    ///                  Typically the URL of the page/screen the user is on.
    public func decorate(
        _ request: URLRequest,
        ajaxPageURL: String = "app://protected"
    ) -> URLRequest {
        var decorated = request
        // 1. Queue-it AJAX marker header (required by KnownUser connector)
        decorated.setValue(ajaxPageURL, forHTTPHeaderField: "x-queueit-ajaxpageurl")

        // 2. Forward stored cookies
        if let url = request.url, let cookieHeader = cookieHeaderValue(for: url) {
            // Merge with any pre-existing Cookie header
            if let existing = decorated.value(forHTTPHeaderField: "Cookie"), !existing.isEmpty {
                decorated.setValue("\(existing); \(cookieHeader)", forHTTPHeaderField: "Cookie")
            } else {
                decorated.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
        }
        return decorated
    }

    // MARK: - Persistence helpers

    private func merge(_ incoming: [HTTPCookie]) {
        lock.lock()
        var map: [String: HTTPCookie] = Dictionary(uniqueKeysWithValues: _cookies.map { ($0.name, $0) })
        for cookie in incoming { map[cookie.name] = cookie }
        _cookies = Array(map.values)
        let snapshot = _cookies
        lock.unlock()
        saveToDisk(snapshot)
    }

    private func saveToDisk(_ cookies: [HTTPCookie]) {
        let serialised = cookies.map { $0.properties }.compactMap { $0 }
        UserDefaults.standard.set(serialised, forKey: Keys.userDefaultsKey)
    }

    private static func loadFromDisk() -> [HTTPCookie] {
        guard
            let raw = UserDefaults.standard.array(forKey: Keys.userDefaultsKey)
                as? [[HTTPCookiePropertyKey: Any]]
        else { return [] }
        return raw.compactMap { HTTPCookie(properties: $0) }
    }

    // MARK: - Cookie classification

    private func isQueueItCookie(_ cookie: HTTPCookie) -> Bool {
        Keys.queueItCookiePrefixes.contains(where: { cookie.name.hasPrefix($0) })
    }
}

// MARK: - HTTPCookie convenience

extension HTTPCookie {
    /// Build a Queue-it accepted cookie manually (useful for testing / pre-seeding).
    static func queueItAccepted(customerId: String, token: String, domain: String) -> HTTPCookie? {
        HTTPCookie(properties: [
            .name: "QueueITAccepted-\(customerId)",
            .value: token,
            .domain: domain,
            .path: "/",
            .secure: "TRUE",
        ])
    }
}
