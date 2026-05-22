//
//  FetchResponseModel.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 5/22/26.
//


import Foundation

class FetchResponseModel {
    private let _result: String?
    private let _connectorResponse: ConnectorResponseModel?
    
    init(originResponse: String?, connectorResponse: ConnectorResponseModel?) {
        self._result = originResponse
        self._connectorResponse = connectorResponse
    }
    
    var originServerResponse: String? {
        return _result
    }
    
    var connectorResponse: ConnectorResponseModel? {
        return _connectorResponse
    }
}