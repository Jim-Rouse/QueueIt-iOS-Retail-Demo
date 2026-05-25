//
//  ProductListView.swift
//  QueueItRetailDemo
//

import SwiftUI

struct ProductListView: View {
    @EnvironmentObject var queueManager: QueueManager
    @State private var cartItems: [Product] = []
    @State private var addedProducts: Set<String> = []
    @State private var showCart = false

    let products = Product.sampleProducts

    var cartCount: Int { cartItems.count }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(products) { product in
                        ProductCardView(product: product) {
                            addToCart(product)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Product List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCart = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "cart")
                                .font(.system(size: 20))
                            if cartCount > 0 {
                                Text("\(cartCount)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 10, y: -10)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCart) {
                CartView(cartItems: cartItems)
            }
        }
    }

    private func addToCart(_ product: Product) {
        // TODO: Replace with your real API endpoint
        let apiUrl = "https://your-api-endpoint.com/cart/add"   // ← Change this
        
        queueManager.makeProtectedRequest(to: apiUrl) { result in
            switch result {
            case .success(let data):
                print("✅ Add to cart success for \(product.name)")
                // Add to local cart
                cartItems.append(product)
                addedProducts.insert(product.id)
                
            case .failure(let error):
                print("❌ Add to cart failed: \(error.localizedDescription)")
                // You can show an alert here if needed
            }
        }
    }
}

// Simple Cart sheet
struct CartView: View {
    let cartItems: [Product]
    @Environment(\.dismiss) var dismiss

    var total: Double { cartItems.reduce(0) { $0 + $1.price } }

    var body: some View {
        NavigationView {
            List(cartItems) { item in
                HStack {
                    Text(item.name)
                    Spacer()
                    Text("$\(Int(item.price))")
                        .bold()
                }
            }
            .navigationTitle("Cart (\(cartItems.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Text("Total: $\(Int(total))")
                        .bold()
                }
            }
        }
    }
}
