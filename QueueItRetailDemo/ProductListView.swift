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

    private let fetchDataService = FetchDataService(sharedPreferences: SharedPreferencesService())

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

        Task {
            let response = await fetchDataService.fetchDataRequest("https://retail.queue-it-demo.com/api/productList_test.json")

            await MainActor.run {
                isLoading = false

                if response.connectorResponse != nil {
                    queueManager.activateWaitingRoom()
                    return
                }

                guard let body = response.originServerResponse,
                      let data = body.data(using: .utf8) else {
                    errorMessage = "Empty response"
                    return
                }

                do {
                    products = try JSONDecoder().decode([Product].self, from: data)
                } catch {
                    errorMessage = error.localizedDescription
                    print("❌ Failed to decode products: \(error)")
                }
            }
        }
    }

    // MARK: - Add to Cart

    private func addToCart(_ product: Product) {
        let apiUrl = "https://retail.queue-it-demo.com/api/\(product.product_id).json?"

        Task {
            let response = await fetchDataService.fetchDataRequest(apiUrl)

            await MainActor.run {
                if response.connectorResponse != nil {
                    queueManager.activateWaitingRoom()
                    return
                }

                guard response.originServerResponse != nil else {
                    print("❌ Add to cart failed: empty response")
                    return
                }

                print("✅ Add to cart success for \(product.name)")
                cartItems.append(product)
                addedProducts.insert(product.id)
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


