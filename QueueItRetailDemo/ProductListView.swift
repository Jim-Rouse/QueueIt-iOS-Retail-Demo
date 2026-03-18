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
    let product_id: String
}

struct ProductListView: View {
    @ObservedObject var queueManager: QueueManager
    @State private var products: [Product] = []
    @State private var cartItems: [Product] = []
    @State private var loadingProducts: Set<String> = []
    @State private var addedProducts: Set<String> = []
    
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
                    
                    let isLoading = loadingProducts.contains(product.name)
                    let isAdded   = addedProducts.contains(product.name)

                    Button {
                        addToCart(product: product)
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else if isAdded {
                                Label("Added", systemImage: "checkmark")
                            } else {
                                Text("Add To Cart")
                            }
                        }
                        .frame(width: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isAdded ? .gray : Color(hex: "00C853"))
                    .disabled(isLoading || isAdded)
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
        guard let url = URL(string: "https://retail.queue-it-demo.com/api/productList.json") else {
            print("Invalid URL")
            return
        }
        
        do {
            let data = try await queueManager.makeProtectedRequest(to: url.absoluteString)
            products = try JSONDecoder().decode([Product].self, from: data)
        } catch {
            print("Error fetching products: \(error.localizedDescription)")
            // For production, you might want to show an alert or retry button
        }
    }
    
    private func addToCart(product: Product) {
        loadingProducts.insert(product.name)
        let urlString = "https://retail.queue-it-demo.com/api/\(product.product_id).json?product=\(product.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        queueManager.makeProtectedRequest(to: urlString) { result in
            DispatchQueue.main.async {
                self.loadingProducts.remove(product.name)
                switch result {
                case .success:
                    self.cartItems.append(product)
                    self.addedProducts.insert(product.name)
                    print("Added \(product.name) to cart")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.addedProducts.remove(product.name)
                    }
                case .failure(let error):
                    print("Error adding to cart: \(error.localizedDescription)")
                }
            }
        }
    }
}
