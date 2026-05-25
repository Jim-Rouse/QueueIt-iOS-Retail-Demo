//
//  ConnectorResponseModel.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 5/22/26.
//


import Foundation

class ConnectorResponseModel {
    private var _customerId: String?
    private var _eventId: String?
    private var _queueItRedirectUrl: String?
    private var _redirectUrl: String?
    
    init(queueItRedirectUrl: String) {
        setRedirectUrlAndEventData(queueItRedirectUrl)
    }
    
    private func setRedirectUrlAndEventData(_ redirectUrl: String) {
        _redirectUrl = redirectUrl  // You can add URL decoding if needed
        if let components = URLComponents(string: redirectUrl),
           let queryItems = components.queryItems {
            
            for item in queryItems {
                if item.name == "c" {
                    _customerId = item.value
                } else if item.name == "e" {
                    _eventId = item.value
                }
            }
        }
    }
    
    var customerId: String? { _customerId }
    var eventId: String? { _eventId }
    var redirectUrl: String? { _queueItRedirectUrl }
    
    func doRedirect() -> Bool {
        return _queueItRedirectUrl != nil
    }
}