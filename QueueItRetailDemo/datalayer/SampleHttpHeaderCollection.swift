//
//  SampleHttpHeaderCollection.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 5/22/26.
//


import Foundation

class SampleHttpHeaderCollection: IRequestHeaderCollection {
    private var request: URLRequest
    
    init(request: inout URLRequest) {
        self.request = request
    }
    
    func addRequestHeader(_ headerName: String, _ headerValue: String) {
        request.addValue(headerValue, forHTTPHeaderField: headerName)
    }
    
    var finalRequest: URLRequest {
        return request
    }
}