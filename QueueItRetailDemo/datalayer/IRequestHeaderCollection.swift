//
//  IRequestHeaderCollection.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 5/22/26.
//


import Foundation

protocol IRequestHeaderCollection {
    func addRequestHeader(_ headerName: String, _ headerValue: String)
}