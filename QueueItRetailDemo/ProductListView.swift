//
//  ProductListView.swift
//  QueueItRetailDemo
//

import SwiftUI

struct ProductListView: View {
    @EnvironmentObject var queueManager: QueueManager
    @State private var products: [Product] = []
    @State private var cartItems: [Product] = []
    @State private var addedProducts: Set<String> = []
    @State private var showCart = false
    @State private var isLoading = false
    @State private var errorMessage: String?

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
            .onAppear {
                fetchProducts()
            }
        }
    }

    private func fetchProducts() {
        isLoading = true
        errorMessage = nil

        queueManager.makeProtectedRequest(to: "https://retail.queue-it-demo.com/api/productList_test.json") { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let data):
                    do {
                        products = try JSONDecoder().decode([Product].self, from: data)
                    } catch {
                        errorMessage = error.localizedDescription
                        print("❌ Failed to decode products: \(error)")
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    print("❌ fetchProducts failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Add to Cart

    private func addToCart(_ product: Product) {
        let apiUrl = "https://retail.queue-it-demo.com/api/\(product.product_id).json?"

        queueManager.makeProtectedRequest(to: apiUrl) { result in
            switch result {
            case .success:
                print("✅ Add to cart success for \(product.name)")
                DispatchQueue.main.async {
                    cartItems.append(product)
                    addedProducts.insert(product.id)
                }
            case .failure(let error):
                print("❌ Add to cart failed: \(error.localizedDescription)")
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


