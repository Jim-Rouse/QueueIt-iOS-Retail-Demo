//
//  Product.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 4/30/26.
//
import Foundation

struct Product: Codable, Identifiable {
    let id: String
    let product_id: String
    let name: String
    let category: String
    let description: String
    let price: Double
    let image: String   // filename only, e.g. "headphones.jpg"

    private static let baseURL = "https://retail.queue-it-demo.com/assets/products/"

    /// Computed from baseURL + image filename — not decoded from JSON
    var imageURL: URL? {
        URL(string: Self.baseURL + image)
    }

    // MARK: - SwiftUI Previews / Fallback

    static let sampleProducts: [Product] = [
        Product(
            id: "wireless-headphones",
            product_id: "WHP001",
            name: "Wireless Headphones",
            category: "Audio",
            description: "Premium over-ear wireless headphones with active noise cancellation and 30-hour battery life.",
            price: 129,
            image: "headphones.jpg"
        ),
        Product(
            id: "smart-watch",
            product_id: "SW234",
            name: "Smart Watch",
            category: "Wearables",
            description: "Always-on display, GPS, heart rate monitoring, and 7-day battery with sleek aluminum case.",
            price: 349,
            image: "smart-watch.avif"
        ),
        Product(
            id: "premium-sneakers",
            product_id: "PS987",
            name: "Premium Sneakers",
            category: "Footwear",
            description: "Lightweight performance sneakers with responsive foam cushioning and breathable mesh upper.",
            price: 89,
            image: "sneakers.jpg"
        ),
        Product(
            id: "organic-cotton-tee",
            product_id: "OCT987",
            name: "Organic Cotton Tee",
            category: "Apparel",
            description: "Sustainably sourced 100% organic cotton. Relaxed fit, pre-washed for softness right out of the bag.",
            price: 39,
            image: "tee.jpg"
        ),
        Product(
            id: "superior-electrolytes",
            product_id: "SE_NotAvailable",
            name: "Superior Electrolytes",
            category: "Nutrition",
            description: "Stay energised and hydrated with clean, effective electrolytes.",
            price: 29,
            image: "electrolytes.jpg"
        ),
        Product(
            id: "bluetooth-speaker",
            product_id: "BLS_NotAvailable",
            name: "Bluetooth Speaker",
            category: "Audio",
            description: "360° room-filling sound, IPX7 waterproof rating, and 12-hour playtime in a compact design.",
            price: 79,
            image: "speaker.jpg"
        )
    ]
}

