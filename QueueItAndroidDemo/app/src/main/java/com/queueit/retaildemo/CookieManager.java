package com.queueit.retaildemo;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import java.net.HttpURLConnection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Manages cookies whose name begins with "QueueItAccepted".
 * All cookies are persisted to SharedPreferences so they survive app restarts.
 *
 * Mirrors the iOS CookieManager.swift singleton.
 */
public class CookieManager {

    private static final String TAG = "CookieManager";
    private static final String PREF_NAME = "QueueItAcceptedCookies";
    private static final String QUEUE_IT_PREFIX = "QueueItAccepted";

    // Singleton
    private static CookieManager instance;
    private final SharedPreferences prefs;

    public static synchronized CookieManager getInstance(Context context) {
        if (instance == null) {
            instance = new CookieManager(context.getApplicationContext());
        }
        return instance;
    }

    private CookieManager(Context context) {
        prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Returns a Cookie header value containing all stored QueueItAccepted cookies,
     * or null if the store is empty.
     */
    public String cookieHeaderValue() {
        Map<String, ?> all = prefs.getAll();
        if (all.isEmpty()) {
            Log.d(TAG, "🍪 cookieHeaderValue: store is empty, no Cookie header added");
            return null;
        }
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, ?> entry : all.entrySet()) {
            if (sb.length() > 0) sb.append("; ");
            sb.append(entry.getKey()).append("=").append(entry.getValue());
        }
        String header = sb.toString();
        Log.d(TAG, "🍪 cookieHeaderValue: returning " + all.size() + " cookie(s) → " + header);
        return header;
    }

    /**
     * Inspects the Set-Cookie response headers from an HttpURLConnection,
     * persists any cookie whose name starts with QueueItAccepted,
     * and clears the store if none are found.
     */
    public void processResponseCookies(HttpURLConnection connection) {
        Map<String, List<String>> headerFields = connection.getHeaderFields();
        List<String> setCookieHeaders = null;

        // Header field keys may be null or differently cased depending on server
        for (Map.Entry<String, List<String>> entry : headerFields.entrySet()) {
            if ("set-cookie".equalsIgnoreCase(entry.getKey())) {
                setCookieHeaders = entry.getValue();
                break;
            }
        }

        if (setCookieHeaders == null || setCookieHeaders.isEmpty()) {
            boolean hadCookies = !prefs.getAll().isEmpty();
            clearCookies();
            if (hadCookies) {
                Log.w(TAG, "⚠️  No Set-Cookie in response — store cleared");
            } else {
                Log.d(TAG, "ℹ️  No Set-Cookie in response and store was already empty");
            }
            return;
        }

        Log.d(TAG, "🍪 processResponseCookies: found " + setCookieHeaders.size() + " Set-Cookie header(s)");

        SharedPreferences.Editor editor = prefs.edit();
        boolean foundAccepted = false;

        for (String rawCookie : setCookieHeaders) {
            // Each raw header looks like: "name=value; Path=/; Expires=...; ..."
            String[] parts = rawCookie.split(";");
            if (parts.length > 0) {
                String[] nameValue = parts[0].trim().split("=", 2);
                if (nameValue.length == 2) {
                    String name = nameValue[0].trim();
                    String value = nameValue[1].trim();
                    if (name.startsWith(QUEUE_IT_PREFIX)) {
                        Log.d(TAG, "✅ Saving cookie: " + name + "=" + value);
                        editor.putString(name, value);
                        foundAccepted = true;
                    }
                }
            }
        }

        if (foundAccepted) {
            editor.apply();
            Log.d(TAG, "🍪 Store now contains " + prefs.getAll().size() + " cookie(s)");
        } else {
            clearCookies();
            Log.w(TAG, "⚠️  No QueueItAccepted cookies in response — store cleared");
        }
    }

    /**
     * Removes all stored QueueItAccepted cookies.
     */
    public void clearCookies() {
        prefs.edit().clear().apply();
        Log.d(TAG, "🗑️  Cookie store cleared");
    }

    /**
     * Returns a snapshot of all stored cookies (read-only, for debugging).
     */
    public Map<String, String> allCookies() {
        Map<String, ?> all = prefs.getAll();
        Map<String, String> result = new HashMap<>();
        for (Map.Entry<String, ?> entry : all.entrySet()) {
            result.put(entry.getKey(), String.valueOf(entry.getValue()));
        }
        return result;
    }
}
