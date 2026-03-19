package com.queueit.retaildemo;

import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.webkit.WebView;

import androidx.appcompat.app.AppCompatActivity;

/**
 * Splash screen — mirrors SplashScreenView.swift.
 * Shows a Queue-it green background with "QUEUE-IT" text for 1.5 s,
 * then transitions to MainActivity.
 *
 * On first launch, clears any leftover queue state (token + WebView data).
 */
public class SplashActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_splash);

        // Clear leftover queue state from previous sessions (mirrors iOS app init)
        getSharedPreferences("QueueItSettings", MODE_PRIVATE)
                .edit().remove("queueItToken").apply();
        CookieManager.getInstance(this).clearCookies();

        // Clear WebView cookies / cache
        android.webkit.CookieManager.getInstance().removeAllCookies(null);
        android.webkit.CookieManager.getInstance().flush();

        // Navigate to MainActivity after 1.5 s
        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            startActivity(new Intent(this, MainActivity.class));
            overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out);
            finish();
        }, 1500);
    }
}
