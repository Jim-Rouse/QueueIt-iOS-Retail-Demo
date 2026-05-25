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
        let connectorApiService = ConnectorApiService(sharedPreferencesService: sharedPreferences)
        
        guard let url = URL(string: requestUrl) else {
            QLog("Invalid URL: \(requestUrl)")
            return FetchResponseModel(originResponse: nil, connectorResponse: nil)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 30
        
        var headerCollection = SampleHttpHeaderCollection(request: &urlRequest)
        
        connectorApiService.addQueueItRequestHeader(headerCollection, requestUrl: requestUrl)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: headerCollection.finalRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                QLog("Invalid HTTP response")
                return FetchResponseModel(originResponse: nil, connectorResponse: nil)
            }
            
            if connectorApiService.doRedirect(httpResponse.allHeaderFields) {
                QLog("Queue-it indicating redirect")
                return FetchResponseModel(originResponse: nil, connectorResponse: connectorApiService.getQueueItConnectorResponse())
            }
            
            let resultString = String(data: data, encoding: .utf8) ?? ""
            return FetchResponseModel(originResponse: resultString, connectorResponse: nil)
            
        } catch {
            QLog("Error fetching data: \(error.localizedDescription)")
            return FetchResponseModel(originResponse: nil, connectorResponse: nil)
        }
    }
}