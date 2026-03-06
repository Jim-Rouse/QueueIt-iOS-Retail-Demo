//
//  ProductListView.swift
//  QueueItRetailDemo
//
//  Created by James Rouse on 2/26/26.
//


import SwiftUI

struct ProductListView: View {
    @ObservedObject var queueManager: QueueManager
    
    let products = [
        ("Wireless Headphones", "$129", "headphones"),
        ("Smart Watch", "$349", "applewatch"),
        ("Premium Sneakers", "$89", "shoe"),
        ("Organic Cotton Tee", "$39", "tshirt")
    ]
    
    var body: some View {
        List {
            ForEach(products, id: \.0) { name, price, icon in
                HStack {
                    Image(systemName: icon)
                        .font(.largeTitle)
                        .frame(width: 60)
                    
                    VStack(alignment: .leading) {
                        Text(name)
                            .font(.headline)
                        Text(price)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Buy Now") {
                        queueManager.activateWaitingRoom() // Demo: triggers queue on purchase
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "00C853"))
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Shop")
    }
}
