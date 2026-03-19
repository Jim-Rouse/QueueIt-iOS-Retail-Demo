package com.queueit.retaildemo.adapter;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.ProgressBar;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.queueit.retaildemo.R;
import com.queueit.retaildemo.model.Product;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * RecyclerView adapter for the Product List screen.
 * Mirrors the ProductListView.swift list rows — emoji icon, name, price, Add to Cart button.
 */
public class ProductAdapter extends RecyclerView.Adapter<ProductAdapter.ProductViewHolder> {

    public interface CartListener {
        void onAddToCart(Product product, int position);
    }

    private List<Product> products = new ArrayList<>();
    private Set<String> loadingProducts = new HashSet<>();
    private Set<String> addedProducts   = new HashSet<>();
    private final CartListener cartListener;

    public ProductAdapter(CartListener cartListener) {
        this.cartListener = cartListener;
    }

    public void setProducts(List<Product> products) {
        this.products = products;
        notifyDataSetChanged();
    }

    public void setLoading(String productName, boolean loading) {
        if (loading) loadingProducts.add(productName);
        else         loadingProducts.remove(productName);
        notifyItemChanged(indexOf(productName));
    }

    public void setAdded(String productName, boolean added) {
        if (added) addedProducts.add(productName);
        else       addedProducts.remove(productName);
        notifyItemChanged(indexOf(productName));
    }

    private int indexOf(String name) {
        for (int i = 0; i < products.size(); i++) {
            if (products.get(i).name.equals(name)) return i;
        }
        return -1;
    }

    @NonNull
    @Override
    public ProductViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View v = LayoutInflater.from(parent.getContext())
                .inflate(R.layout.item_product, parent, false);
        return new ProductViewHolder(v);
    }

    @Override
    public void onBindViewHolder(@NonNull ProductViewHolder holder, int position) {
        Product product = products.get(position);
        boolean isLoading = loadingProducts.contains(product.name);
        boolean isAdded   = addedProducts.contains(product.name);

        holder.tvIcon.setText(product.getIconEmoji());
        holder.tvName.setText(product.name);
        holder.tvPrice.setText(product.price);

        // Button states mirror the iOS .borderedProminent button
        holder.btnAdd.setVisibility(isLoading ? View.INVISIBLE : View.VISIBLE);
        holder.progressBar.setVisibility(isLoading ? View.VISIBLE : View.GONE);

        if (isAdded) {
            holder.btnAdd.setText("✓ Added");
            holder.btnAdd.setEnabled(false);
            holder.btnAdd.setAlpha(0.6f);
        } else {
            holder.btnAdd.setText("Add to Cart");
            holder.btnAdd.setEnabled(true);
            holder.btnAdd.setAlpha(1f);
        }

        holder.btnAdd.setOnClickListener(v -> {
            if (!isLoading && !isAdded) {
                cartListener.onAddToCart(product, holder.getAdapterPosition());
            }
        });
    }

    @Override
    public int getItemCount() { return products.size(); }

    static class ProductViewHolder extends RecyclerView.ViewHolder {
        TextView tvIcon, tvName, tvPrice;
        Button btnAdd;
        ProgressBar progressBar;

        ProductViewHolder(View itemView) {
            super(itemView);
            tvIcon      = itemView.findViewById(R.id.tv_product_icon);
            tvName      = itemView.findViewById(R.id.tv_product_name);
            tvPrice     = itemView.findViewById(R.id.tv_product_price);
            btnAdd      = itemView.findViewById(R.id.btn_add_to_cart);
            progressBar = itemView.findViewById(R.id.pb_add_loading);
        }
    }
}
