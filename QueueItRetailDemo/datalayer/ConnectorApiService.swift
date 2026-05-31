//
//  ConnectorApiService.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 5/22/26.
//


import Foundation

class ConnectorApiService {
    private let LOG_TAG = "QueueItService:"
    
    private let QUEUEIT_REQUEST_HEADER_KEY = "x-queueit-ajaxpageurl"
    private let QUEUEIT_RESPONSE_HEADER_KEY = "x-queueit-redirect"
    private let QUEUEIT_TOKEN_REQUEST_HEADER_KEY = "x-queueittoken"
    
    private let sharedPreferences: SharedPreferencesService
    private var _connectorResponse: ConnectorResponseModel?
    
    init(sharedPreferencesService: SharedPreferencesService) {
        self.sharedPreferences = sharedPreferencesService
    }
    
    func doRedirect(_ httpResponse: HTTPURLResponse) -> Bool {
        persistCookie(httpResponse)
        return foundRedirectUrl(httpResponse)
    }

    private func persistCookie(_ httpResponse: HTTPURLResponse) {
        if let cookieString = httpResponse.value(forHTTPHeaderField: "Set-Cookie"),
           !isNullOrEmpty(cookieString) {
            sharedPreferences.saveData(UtilConstants.COOKIES, value: cookieString)
            QLog("Updated Cookies → \(cookieString)")
        }
    }

    private func foundRedirectUrl(_ httpResponse: HTTPURLResponse) -> Bool {
        guard let redirectUrl = httpResponse.value(forHTTPHeaderField: QUEUEIT_RESPONSE_HEADER_KEY),
              !isNullOrEmpty(redirectUrl) else {
            return false
        }

        QLog("\(QUEUEIT_RESPONSE_HEADER_KEY) populated → \(redirectUrl)")
        _connectorResponse = ConnectorResponseModel(queueItRedirectUrl: redirectUrl)
        return true
    }
    
    private func isNullOrEmpty(_ str: String?) -> Bool {
        return str == nil || str!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func addQueueItRequestHeader(_ headerCollection: IRequestHeaderCollection, requestUrl: String) {
        headerCollection.addRequestHeader(QUEUEIT_REQUEST_HEADER_KEY, requestUrl)
        QLog("📤 Added request header \(QUEUEIT_REQUEST_HEADER_KEY): \(requestUrl)")

        if let qtoken = sharedPreferences.getValue(UtilConstants.QUEUE_IT_TOKEN),
           !isNullOrEmpty(qtoken) {
            QLog("Q-token from shared prefs: \(qtoken)")
            headerCollection.addRequestHeader(QUEUEIT_TOKEN_REQUEST_HEADER_KEY, qtoken)
            QLog("📤 Added \(QUEUEIT_TOKEN_REQUEST_HEADER_KEY)")
            sharedPreferences.saveData(UtilConstants.QUEUE_IT_TOKEN, value: nil)
        }

        if let cookies = sharedPreferences.getValue(UtilConstants.COOKIES),
           !isNullOrEmpty(cookies) {
            QLog("Cookies from shared prefs: \(cookies)")
            headerCollection.addRequestHeader("Cookie", cookies)
            QLog("📤 Added Cookie header")
        }
    }
    
    func getQueueItConnectorResponse() -> ConnectorResponseModel? {
        return _connectorResponse
    }
}