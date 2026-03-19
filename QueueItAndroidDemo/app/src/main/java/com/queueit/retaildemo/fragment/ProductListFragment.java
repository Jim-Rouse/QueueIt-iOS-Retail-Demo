package com.queueit.retaildemo.fragment;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;
import com.queueit.retaildemo.QueueManager;
import com.queueit.retaildemo.R;
import com.queueit.retaildemo.adapter.ProductAdapter;
import com.queueit.retaildemo.model.Product;

import java.lang.reflect.Type;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.List;

/**
 * Hybrid integration screen — mirrors ProductListView.swift.
 *
 * All API calls go through QueueManager.makeProtectedRequest(), which:
 *   - Adds x-queueit-ajaxpageurl, Cookie, and x-queueittoken headers
 *   - Detects x-queueit-redirect responses and opens the waiting room
 *   - Automatically replays the original request after onQueuePassed
 */
public class ProductListFragment extends Fragment
        implements ProductAdapter.CartListener, QueueManager.QueueStateListener {

    private static final String PRODUCTS_URL = "https://retail.queue-it-demo.com/api/productList.json";
    private static final String ADD_TO_CART_URL = "https://retail.queue-it-demo.com/api/addToCart?product=";

    private RecyclerView recyclerView;
    private TextView tvCartBadge;
    private View progressOverlay;

    private ProductAdapter adapter;
    private QueueManager queueManager;
    private int cartCount = 0;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater,
                             @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        View v = inflater.inflate(R.layout.fragment_product_list, container, false);

        recyclerView    = v.findViewById(R.id.rv_products);
        tvCartBadge     = v.findViewById(R.id.tv_cart_badge);
        progressOverlay = v.findViewById(R.id.progress_overlay);

        adapter = new ProductAdapter(this);
        recyclerView.setLayoutManager(new LinearLayoutManager(requireContext()));
        recyclerView.setAdapter(adapter);

        queueManager = QueueManager.getInstance(requireContext());
        queueManager.setQueueStateListener(this);

        fetchProducts();
        return v;
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        queueManager.setQueueStateListener(null);
    }

    // ─── Protected API: fetch product list ───────────────────────────────────

    private void fetchProducts() {
        progressOverlay.setVisibility(View.VISIBLE);

        queueManager.makeProtectedRequest(requireActivity(), PRODUCTS_URL,
                new QueueManager.RequestCallback() {
                    @Override
                    public void onSuccess(byte[] data) {
                        progressOverlay.setVisibility(View.GONE);
                        try {
                            String json = new String(data, "UTF-8");
                            Type type = new TypeToken<List<Product>>() {}.getType();
                            List<Product> products = new Gson().fromJson(json, type);
                            if (products == null) products = new ArrayList<>();
                            adapter.setProducts(products);
                        } catch (Exception e) {
                            Toast.makeText(requireContext(),
                                    "Error parsing products: " + e.getMessage(),
                                    Toast.LENGTH_SHORT).show();
                        }
                    }

                    @Override
                    public void onFailure(Exception e) {
                        if (!isAdded()) return;
                        progressOverlay.setVisibility(View.GONE);
                        Toast.makeText(requireContext(),
                                "Error loading products: " + e.getMessage(),
                                Toast.LENGTH_SHORT).show();
                    }
                });
    }

    // ─── Protected API: add to cart ──────────────────────────────────────────

    @Override
    public void onAddToCart(Product product, int position) {
        adapter.setLoading(product.name, true);

        String url;
        try {
            url = ADD_TO_CART_URL + URLEncoder.encode(product.name, "UTF-8");
        } catch (Exception e) {
            url = ADD_TO_CART_URL + product.name;
        }
        final String finalUrl = url;

        queueManager.makeProtectedRequest(requireActivity(), finalUrl,
                new QueueManager.RequestCallback() {
                    @Override
                    public void onSuccess(byte[] data) {
                        if (!isAdded()) return;
                        adapter.setLoading(product.name, false);
                        adapter.setAdded(product.name, true);
                        cartCount++;
                        updateCartBadge();

                        // Reset "Added" state after 1.5 s — mirrors iOS behavior
                        recyclerView.postDelayed(() -> {
                            if (!isAdded()) return;
                            adapter.setAdded(product.name, false);
                        }, 1500);
                    }

                    @Override
                    public void onFailure(Exception e) {
                        if (!isAdded()) return;
                        adapter.setLoading(product.name, false);
                        Toast.makeText(requireContext(),
                                "Error adding to cart: " + e.getMessage(),
                                Toast.LENGTH_SHORT).show();
                    }
                });
    }

    // ─── QueueStateListener callbacks ────────────────────────────────────────

    @Override
    public void onQueuePassed(String token) {
        // pendingRequest is replayed automatically by QueueManager after this fires
    }

    @Override
    public void onQueueViewWillOpen() {
        if (!isAdded()) return;
        progressOverlay.setVisibility(View.GONE);
    }

    @Override
    public void onQueueError(String message) {
        if (!isAdded()) return;
        progressOverlay.setVisibility(View.GONE);
        Toast.makeText(requireContext(), "Queue error: " + message, Toast.LENGTH_LONG).show();
    }

    // ─── Cart badge (toolbar icon area) ──────────────────────────────────────

    private void updateCartBadge() {
        if (cartCount > 0) {
            tvCartBadge.setVisibility(View.VISIBLE);
            tvCartBadge.setText(String.valueOf(cartCount));
        } else {
            tvCartBadge.setVisibility(View.GONE);
        }
    }
}
