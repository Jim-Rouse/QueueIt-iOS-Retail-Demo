//
//  FetchDataService.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 5/22/26.
//


import Foundation

class FetchDataService {
    private let LOG_TAG = "QueueIt:FetchData"
    private let sharedPreferences: SharedPreferencesService
    
    init(sharedPreferences: SharedPreferencesService) {
        self.sharedPreferences = sharedPreferences
    }
    
    func fetchDataRequest(_ requestUrl: String) async -> FetchResponseModel {
        QLog("🌐 [PROTECTED REQUEST] → \(requestUrl)")

        let connectorApiService = ConnectorApiService(sharedPreferencesService: sharedPreferences)

        guard let url = URL(string: requestUrl) else {
            QLog("❌ Invalid URL: \(requestUrl)")
            return FetchResponseModel(originResponse: nil, connectorResponse: nil)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 30

        let headerCollection = SampleHttpHeaderCollection(request: &urlRequest)

        connectorApiService.addQueueItRequestHeader(headerCollection, requestUrl: requestUrl)

        let finalRequest = headerCollection.finalRequest
        QLog("📤 Final request headers being sent: \(finalRequest.allHTTPHeaderFields ?? [:])")
        QLog("📤 Request URL: \(finalRequest.url?.absoluteString ?? "nil")  Method: \(finalRequest.httpMethod ?? "nil")")

        do {
            let (data, response) = try await URLSession.shared.data(for: finalRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                QLog("❌ Invalid or nil response")
                return FetchResponseModel(originResponse: nil, connectorResponse: nil)
            }

            QLog("📥 [RESPONSE] Status: \(httpResponse.statusCode)")
            QLog("🔍 All Response Headers:")
            if httpResponse.allHeaderFields.isEmpty {
                QLog(" (No headers found)")
            } else {
                let sortedHeaders = httpResponse.allHeaderFields.sorted {
                    String(describing: $0.key).lowercased() < String(describing: $1.key).lowercased()
                }
                for (key, value) in sortedHeaders {
                    if let k = key as? String {
                        let safeValue = String(describing: value)
                        QLog(" 🔑 \(k): \(safeValue)")
                    }
                }
            }

            if connectorApiService.doRedirect(httpResponse.allHeaderFields) {
                QLog("🔀 x-queueit-redirect detected")
                return FetchResponseModel(originResponse: nil, connectorResponse: connectorApiService.getQueueItConnectorResponse())
            }

            QLog("✅ Request succeeded")
            let resultString = String(data: data, encoding: .utf8) ?? ""
            return FetchResponseModel(originResponse: resultString, connectorResponse: nil)

        } catch {
            QLog("❌ Request failed: \(error.localizedDescription)")
            return FetchResponseModel(originResponse: nil, connectorResponse: nil)
        }
    }
}