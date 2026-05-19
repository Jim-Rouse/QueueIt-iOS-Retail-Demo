//
//  ProductListView.swift
//  QueueItRetailDemo
//

import SwiftUI

struct ProductListView: View {
    @ObservedObject var queueManager: QueueManager
    
    @State private var products: [Product] = []
    @State private var cartItems: [Product] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private var cartCount: Int { cartItems.count }
    
    var body: some View {
        List {
            Section("Featured Products - Queue-it Protected") {
                ForEach(products) { product in
                    ProductRow(
                        product: product,
                        cartItems: $cartItems,
                        queueManager: queueManager,
                        alertMessage: $alertMessage,
                        showingAlert: $showingAlert
                    )
                }
            }
        }
        .navigationTitle("Shop")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ZStack {
                    Image(systemName: "cart")
                        .font(.title2)
                    if cartCount > 0 {
                        Text("\(cartCount)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 12, y: -10)
                    }
                }
            }
        }
        .onAppear {
            Task { await loadProducts() }
        }
        .alert("Queue-it Demo", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadProducts() async {
        do {
            guard let url = URL(string: "https://retail.queue-it-demo.com/api/productList.json") else { return }
            let (data, _) = try await URLSession.shared.data(from: url)
            products = try JSONDecoder().decode([Product].self, from: data)
        } catch {
            print("❌ Failed to load products: \(error)")
            // Fallback demo products
            products = [
                Product(id: "1", name: "Wireless Headphones", category: "Audio", description: "Premium noise cancelling", price: 199.99, image: "headphones.jpg"),
                Product(id: "2", name: "Smart Watch Pro", category: "Wearables", description: "Fitness tracking + notifications", price: 299.99, image: "watch.jpg"),
                Product(id: "3", name: "4K Webcam", category: "Electronics", description: "Crystal clear video calls", price: 129.99, image: "webcam.jpg")
            ]
        }
    }
}

// MARK: - Product Row
struct ProductRow: View {
    let product: Product
    @Binding var cartItems: [Product]
    @ObservedObject var queueManager: QueueManager
    @Binding var alertMessage: String
    @Binding var showingAlert: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: product.imageURL) { phase in
                switch phase {
                case .empty: ProgressView()
                case .success(let image): image.resizable().scaledToFill()
                case .failure: Image(systemName: "photo")
                @unknown default: EmptyView()
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(.headline)
                Text("$\(product.price, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Add to Cart") {
                cartItems.append(product)
                queueManager.activateWaitingRoom()  // 🔥 Real Queue-it activation
                
                alertMessage = "Added \(product.name) — Queue-it Waiting Room Activated!"
                showingAlert = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "00C853"))
        }
        .padding(.vertical, 8)
    }
}
