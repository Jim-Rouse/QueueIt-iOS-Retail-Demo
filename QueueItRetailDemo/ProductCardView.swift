//
//  ProductCardView.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 4/30/26.
//


// ProductCardView.swift
import SwiftUI

struct ProductCardView: View {
    let product: Product
    let onAddToCart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Product Image
            productImage
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(Color(hex: "#EEEEFF"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text("$\(Int(product.price))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#3333FF"))
            }
            .padding(.top, 10)

            Spacer()

            // Add to Cart Button
            Button(action: onAddToCart) {
                Text("Add to Cart")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#3333FF"))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(.top, 10)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private var productImage: some View {
        if let url = product.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(20)
                case .failure:
                    // Fallback icon matching your current placeholder style
                    Image(systemName: iconForCategory(product.category))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(30)
                        .foregroundColor(Color(hex: "#3333FF").opacity(0.6))
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            Image(systemName: iconForCategory(product.category))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(30)
                .foregroundColor(Color(hex: "#3333FF").opacity(0.6))
        }
    }

    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "audio":       return "headphones"
        case "wearables":   return "applewatch"
        case "footwear":    return "shoe"
        case "apparel":     return "tshirt"
        case "nutrition":   return "drop.fill"
        default:            return "bag"
        }
    }
}
