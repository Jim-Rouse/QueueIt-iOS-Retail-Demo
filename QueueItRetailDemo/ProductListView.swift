
//
//  ProductListView.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 2/26/26.
//

import SwiftUI

struct Product: Codable {
    let name: String
    let price: String
    let icon: String
}

struct ProductListView: View {
    @ObservedObject var queueManager: QueueManager
    @State private var products: [Product] = []
    @State private var cartItems: [Product] = []
    
    var cartCount: Int {
        cartItems.count
    }
    
    var body: some View {
        List {
            ForEach(products, id: \.name) { product in
                HStack {
                    Image(systemName: product.icon)
                        .font(.largeTitle)
                        .frame(width: 60)
                    
                    VStack(alignment: .leading) {
                        Text(product.name)
                            .font(.headline)
                        Text(product.price)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Add To Cart") {
                        cartItems.append(product)
                        queueManager.activateWaitingRoom() // Demo: triggers queue on add to cart
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "00C853"))
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Shop")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ZStack {
                    Image(systemName: "cart")
                        .font(.title2)
                        .foregroundColor(.primary)
                    
                    if cartCount > 0 {
                        Text("\(cartCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 10, y: -10)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await fetchProducts()
            }
        }
    }
    
    private func fetchProducts() async {
        do {
            guard let url = URL(string: "https://retail.queue-it-demo.com/api/productList.json") else {
                print("Invalid URL")
                return
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            products = try JSONDecoder().decode([Product].self, from: data)
        } catch {
            print("Error fetching products: \(error.localizedDescription)")
            // For production, you might want to show an alert or retry button
        }
    }
}

