//
//  Product.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 4/30/26.
//
import Foundation
// Product.swift
struct Product: Identifiable {
    let id: String
    let name: String
    let category: String
    let description: String
    let price: Double
    let imageURL: URL?

    private static let baseURL = "https://retail.queue-it-demo.com/assets/products/"

    static let sampleProducts: [Product] = [
        Product(
            id: "card-wireless-headphones",
            name: "Wireless Headphones",
            category: "Audio",
            description: "Premium sound with active noise cancellation and 30-hour battery life.",
            price: 129,
            imageURL: URL(string: baseURL + "headphones.jpg")
        ),
        Product(
            id: "card-smart-watch",
            name: "Smart Watch",
            category: "Wearables",
            description: "Always-on display, GPS, heart rate monitoring, and 7-day battery with sleek aluminum case.",
            price: 349,
            imageURL: URL(string: baseURL + "smart-watch.avif")
        ),
        Product(
            id: "card-premium-sneakers",
            name: "Premium Sneakers",
            category: "Footwear",
            description: "Lightweight design with responsive cushioning for all-day comfort.",
            price: 89,
            imageURL: URL(string: baseURL + "sneakers.jpg")
        ),
        Product(
            id: "card-organic-cotton-tee",
            name: "Organic Cotton Tee",
            category: "Apparel",
            description: "Sustainably sourced, ultra-soft organic cotton. Available in 12 colors.",
            price: 39,
            imageURL: URL(string: baseURL + "tee.jpg")
        ),
        Product(
            id: "card-superior-electrolytes",
            name: "Superior Electrolytes",
            category: "Nutrition",
            description: "Advanced hydration formula with essential minerals for peak performance.",
            price: 29,
            imageURL: URL(string: baseURL + "electrolytes.jpg")
        ),
        Product(
            id: "card-bluetooth-speaker",
            name: "Bluetooth Speaker",
            category: "Audio",
            description: "360° immersive sound with 24-hour battery and waterproof design.",
            price: 79,
            imageURL: URL(string: baseURL + "speaker.jpg")
        )
    ]
}
