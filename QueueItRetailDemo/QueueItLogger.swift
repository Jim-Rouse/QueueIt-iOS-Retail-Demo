// QueueItLogger.swift
// Prints all Queue-it request/response headers and cookies to the Xcode console.
// Register once at app startup — no other changes needed to use it.

import Foundation
import WebKit

// MARK: - URLSession Interceptor (SDK API calls)

final class QueueItNetworkLogger: URLProtocol {

    private static let handledKey = "QueueItNetworkLoggerHandled"
    private var activeTask: URLSessionDataTask?

    // ── Registration ──────────────────────────────────────────────────────────

    static func register() {
        URLProtocol.registerClass(QueueItNetworkLogger.self)
        print("✅ QueueItNetworkLogger registered")
    }

    // ── Only intercept Queue-it traffic ───────────────────────────────────────

    override class func canInit(with request: URLRequest) -> Bool {
        guard URLProtocol.property(forKey: handledKey, in: request) == nil else { return false }
        let host = request.url?.host?.lowercased() ?? ""
        return host.contains("queue-it") || host.contains("queueit")
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    // ── Log request ───────────────────────────────────────────────────────────

    override func startLoading() {
        print("""
        
        📤 ══ QUEUE-IT REQUEST ══════════════════════════════
        URL    : \(request.url?.absoluteString ?? "—")
        Method : \(request.httpMethod ?? "—")
        Headers:
        \(formatHeaders(request.allHTTPHeaderFields ?? [:]))
        """)

        if let body = request.httpBody, let str = String(data: body, encoding: .utf8) {
            print("Body   : \(str)")
        }

        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)

        let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
        activeTask = session.dataTask(with: mutableRequest as URLRequest)
        activeTask?.resume()
    }

    override func stopLoading() {
        activeTask?.cancel()
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func formatHeaders(_ headers: [AnyHashable: Any]) -> String {
        headers.map { "  \($0.key): \($0.value)" }.sorted().joined(separator: "\n")
    }
}

// MARK: - URLSessionDataDelegate

extension QueueItNetworkLogger: URLSessionDataDelegate {

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

        if let http = response as? HTTPURLResponse {
            // Pull out Set-Cookie headers separately for visibility
            let cookies = http.allHeaderFields.filter {
                ($0.key as? String)?.lowercased() == "set-cookie"
            }

            print("""
            
            📥 ══ QUEUE-IT RESPONSE ═════════════════════════════
            URL    : \(http.url?.absoluteString ?? "—")
            Status : \(http.statusCode)
            Headers:
            \(formatHeaders(http.allHeaderFields))
            """)

            if !cookies.isEmpty {
                print("🍪 Cookies:")
                cookies.forEach { print("  \($0.value)") }
            }
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error {
            print("""
            
            ❌ ══ QUEUE-IT ERROR ════════════════════════════════
            URL   : \(task.currentRequest?.url?.absoluteString ?? "—")
            Error : \(error.localizedDescription)
            """)
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

}

// MARK: - WKWebView Response Logger (waiting room WebView traffic)

final class QueueItWebViewLogger: NSObject, WKNavigationDelegate {

    static let shared = QueueItWebViewLogger()
    private override init() {}

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        if let http = navigationResponse.response as? HTTPURLResponse {
            print("""
            
            🌐 ══ WEBVIEW RESPONSE ══════════════════════════════
            URL    : \(http.url?.absoluteString ?? "—")
            Status : \(http.statusCode)
            Headers:
            \(http.allHeaderFields.map { "  \($0.key): \($0.value)" }.sorted().joined(separator: "\n"))
            """)
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        if let url = navigationAction.request.url?.absoluteString,
           url.lowercased().contains("queue-it") || url.lowercased().contains("queueit") {
            print("""
            
            🌐 ══ WEBVIEW REQUEST ═══════════════════════════════
            URL    : \(url)
            Headers:
            \(navigationAction.request.allHTTPHeaderFields?.map { "  \($0.key): \($0.value)" }.sorted().joined(separator: "\n") ?? "  none")
            """)
        }

        decisionHandler(.allow)
    }
}
