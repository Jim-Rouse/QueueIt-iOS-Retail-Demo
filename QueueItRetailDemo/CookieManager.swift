//
//  CookieManager.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 3/17/26.
//


//
//  CookieManager.swift
//  QueueItRetailDemo
//
//  Manages cookies whose name begins with "QueueItAccepted".
//  All cookies are persisted to UserDefaults so they survive app restarts.
//

import Foundation

final class CookieManager {

    // MARK: - Singleton
    static let shared = CookieManager()
    private init() {}

    // MARK: - Constants
    private let storageKey = "QueueItAcceptedCookies"
    private let queueItPrefix = "QueueItAccepted"

    // MARK: - In-memory cache (kept in sync with UserDefaults)
    /// [cookieName: cookieValue]
    private var cookieStore: [String: String] {
        get {
            UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: storageKey)
        }
    }

    // MARK: - Public API

    /// Returns a `Cookie` header value containing all stored QueueItAccepted cookies,
    /// or `nil` if the store is empty.
    func cookieHeaderValue() -> String? {
        let store = cookieStore
        guard !store.isEmpty else {
            print("[CookieManager] 🍪 cookieHeaderValue: store is empty, no Cookie header added")
            return nil
        }
        let header = store.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        print("[CookieManager] 🍪 cookieHeaderValue: returning \(store.count) cookie(s) → \(header)")
        return header
    }

    /// Inspects the `Set-Cookie` response headers, persists any cookie whose
    /// name starts with `QueueItAccepted`, and **clears** the store if none are found.
    ///
    /// - Parameters:
    ///   - response: The `HTTPURLResponse` from the request.
    ///   - url:      The request URL (required by `HTTPCookie` parser).
    func processResponseCookies(from response: HTTPURLResponse, requestURL url: URL) {
        // HTTPURLResponse exposes all headers; extract them for the cookie parser.
        let headers = response.allHeaderFields as? [String: String] ?? [:]

        // Parse using Foundation's cookie parser so multi-value headers are handled correctly.
        let allCookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
        print("[CookieManager] 🍪 processResponseCookies: found \(allCookies.count) total cookie(s) in response")

        let accepted = allCookies.filter { $0.name.hasPrefix(queueItPrefix) }
        print("[CookieManager] 🍪 processResponseCookies: \(accepted.count) QueueItAccepted cookie(s) found")

        if accepted.isEmpty {
            let hadCookies = !cookieStore.isEmpty
            clearCookies()
            if hadCookies {
                print("[CookieManager] ⚠️  No QueueItAccepted cookies in response — store cleared")
            } else {
                print("[CookieManager] ℹ️  No QueueItAccepted cookies in response and store was already empty")
            }
        } else {
            var updated = cookieStore
            for cookie in accepted {
                print("[CookieManager] ✅ Saving cookie: \(cookie.name)=\(cookie.value)")
                updated[cookie.name] = cookie.value
            }
            cookieStore = updated
            print("[CookieManager] 🍪 Store now contains \(cookieStore.count) cookie(s): \(cookieStore.keys.joined(separator: ", "))")
        }
    }

    /// Removes all stored QueueItAccepted cookies.
    func clearCookies() {
        cookieStore = [:]
        print("[CookieManager] 🗑️  Cookie store cleared")
    }

    /// Returns a snapshot of all stored cookies (read-only, for debugging).
    func allCookies() -> [String: String] {
        return cookieStore
    }
}
