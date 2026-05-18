//
//  Product.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 4/30/26.
//

import Foundation

struct Product: Identifiable, Codable {
    let id: String
    let name: String
    let category: String
    let description: String
    let price: Double
    let image: String           // filename only, e.g. "headphones.jpg"

    private static let imageBaseURL = "https://retail.queue-it-demo.com/assets/products/"

    /// Full image URL constructed from the base path + filename from JSON
    var imageURL: URL? {
        URL(string: Self.imageBaseURL + image)
    }

    /// The Queue-it protected add-to-cart endpoint for this product
    var addToCartURL: String {
        "https://retail.queue-it-demo.com/api/\(id).json"
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, category, description, price, image
    }
}
