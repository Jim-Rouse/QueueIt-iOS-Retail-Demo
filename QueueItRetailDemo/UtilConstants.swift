//
//  UtilConstants.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 5/22/26.
//


import Foundation

struct UtilConstants {
    static let QUEUE_IT_TOKEN = "queueItToken"
    static let COOKIES = "Cookie"
    
    // Toggle Queue-it debug logging
    static var QUEUE_IT_LOGGING_ENABLED = true
}

func QLog(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
    guard UtilConstants.QUEUE_IT_LOGGING_ENABLED else { return }
    let filename = (file as NSString).lastPathComponent
    print("[\(filename):\(line)] \(function) → \(message)")
}