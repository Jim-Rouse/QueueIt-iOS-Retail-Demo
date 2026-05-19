//
//  Product.swift
//  QueueItRetailDemo
//

import Foundation

public struct Product: Identifiable, Codable {
    public let id: String
    public let name: String
    public let category: String
    public let description: String
    public let price: Double
    public let image: String
    
    public var imageURL: URL? {
        URL(string: "https://retail.queue-it-demo.com/assets/products/\(image)")
    }
}
