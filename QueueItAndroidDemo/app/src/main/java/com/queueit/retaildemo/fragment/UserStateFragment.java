package com.queueit.retaildemo.fragment;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TableLayout;
import android.widget.TableRow;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.Fragment;

import com.queueit.retaildemo.CookieManager;
import com.queueit.retaildemo.R;

import java.util.Map;

/**
 * User State screen — mirrors UserStateView.swift.
 *
 * Shows current SharedPreferences keys/values (equivalent to iOS UserDefaults),
 * and provides buttons to clear preferences and cookies.
 */
public class UserStateFragment extends Fragment {

    private static final String PREF_NAME = "QueueItSettings";

    private static final String[] PREF_KEYS = {
            "customerID", "waitingRoomID", "layoutName", "language",
            "enqueueToken", "enqueueKey", "waitingRoomDomain",
            "waitingRoomPrefix", "queueItToken"
    };

    private TableLayout tablePrefs;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater,
                             @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        View v = inflater.inflate(R.layout.fragment_user_state, container, false);

        tablePrefs = v.findViewById(R.id.table_prefs);

        Button btnClearPrefs = v.findViewById(R.id.btn_clear_prefs);
        Button btnClearCookies = v.findViewById(R.id.btn_clear_cookies);

        btnClearPrefs.setOnClickListener(view -> {
            clearPreferences();
            refreshTable();
            showCleared();
        });

        btnClearCookies.setOnClickListener(view -> {
            clearCookies();
            showCleared();
        });

        refreshTable();
        return v;
    }

    @Override
    public void onResume() {
        super.onResume();
        refreshTable();
    }

    // ─── Table rendering ──────────────────────────────────────────────────────

    private void refreshTable() {
        tablePrefs.removeAllViews();
        SharedPreferences prefs = requireContext()
                .getSharedPreferences(PREF_NAME, 0);

        for (String key : PREF_KEYS) {
            String value = prefs.getString(key, "—");
            if (value == null || value.isEmpty()) value = "—";

            TableRow row = new TableRow(requireContext());
            row.setPadding(0, 16, 0, 16);

            TextView tvKey = new TextView(requireContext());
            tvKey.setText(key);
            tvKey.setTextAppearance(com.google.android.material.R.style.TextAppearance_MaterialComponents_Body1);
            tvKey.setPadding(0, 0, 32, 0);

            TextView tvVal = new TextView(requireContext());
            tvVal.setText(value);
            tvVal.setTextAppearance(com.google.android.material.R.style.TextAppearance_MaterialComponents_Body2);
            tvVal.setAlpha(0.6f);
            tvVal.setMaxLines(1);
            tvVal.setEllipsize(android.text.TextUtils.TruncateAt.END);

            row.addView(tvKey);
            row.addView(tvVal);
            tablePrefs.addView(row);
        }
    }

    // ─── Actions ──────────────────────────────────────────────────────────────

    private void clearPreferences() {
        SharedPreferences prefs = requireContext()
                .getSharedPreferences(PREF_NAME, 0);
        SharedPreferences.Editor editor = prefs.edit();
        // Clear queue-state keys but leave settings keys intact
        editor.remove("queueItToken").apply();
    }

    private void clearCookies() {
        CookieManager.getInstance(requireContext()).clearCookies();

        // Also clear WebView cookies (mirrors iOS WKWebsiteDataStore clear)
        android.webkit.CookieManager.getInstance().removeAllCookies(null);
        android.webkit.CookieManager.getInstance().flush();
    }

    private void showCleared() {
        new AlertDialog.Builder(requireContext())
                .setTitle("Cleared")
                .setMessage("Data has been cleared.")
                .setPositiveButton("OK", null)
                .show();
    }
}
