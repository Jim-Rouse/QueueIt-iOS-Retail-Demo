// ProductListView.swift
import SwiftUI

struct ProductListView: View {
    @ObservedObject var queueManager: QueueManager
    @State private var products: [Product] = []
    @State private var isLoading = false
    @State private var loadError: String? = nil
    @State private var cartItems: [Product] = []
    @State private var addedProducts: Set<String> = []
    @State private var showCart = false

    private let productListURL = "https://retail.queue-it-demo.com/api/productList_test.json"

    var cartCount: Int { cartItems.count }

    var body: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "262BED")))
                        .scaleEffect(1.5)
                    Text("Loading products...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)

            } else if let error = loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await fetchProducts() }
                    }
                    .foregroundColor(Color(hex: "262BED"))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
                .padding(.horizontal, 32)

            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 16
                ) {
                    ForEach(products) { product in
                        ProductCardView(product: product) {
                            addToCart(product)
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // ── Center: logo ──
            ToolbarItem(placement: .principal) {
                Image("logo-white")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
            }

            // ── Right: cart button ──
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCart = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "cart")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())

                        if cartCount > 0 {
                            Text("\(cartCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCart) {
            CartView(cartItems: cartItems)
        }
        .onAppear {
            if products.isEmpty {
                Task { await fetchProducts() }
            }
        }
    }

    // MARK: - Fetch

    private func fetchProducts() async {
        isLoading = true
        loadError = nil
        print("[ProductList] 🚀 Fetching productList.json")

        do {
            let data = try await queueManager.makeProtectedRequest(to: productListURL)
            print("[ProductList] ✅ Got \(data.count) bytes")
            let decoded = try JSONDecoder().decode([Product].self, from: data)
            print("[ProductList] ✅ Decoded \(decoded.count) products")
            await MainActor.run { products = decoded }
        } catch {
            print("[ProductList] ❌ \(error.localizedDescription)")
            await MainActor.run { loadError = "Could not load products.\n\(error.localizedDescription)" }
        }

        await MainActor.run { isLoading = false }
    }

    // MARK: - Cart

    private func addToCart(_ product: Product) {
        let urlString = product.addToCartURL
        print("[ProductList] 🛒 Add to cart: \(urlString)")

        Task {
            do {
                _ = try await queueManager.makeProtectedRequest(to: urlString)
                await MainActor.run {
                    cartItems.append(product)
                    addedProducts.insert(product.id)
                }
            } catch {
                print("[ProductList] ❌ Add to cart failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Nav Bar Appearance
extension ProductListView {
    static func configureNavBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(hex: "262BED"))
        appearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}

// MARK: - Cart Sheet
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
