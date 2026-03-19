package com.queueit.retaildemo;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.MenuItem;
import android.view.View;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.appcompat.app.ActionBarDrawerToggle;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;
import androidx.drawerlayout.widget.DrawerLayout;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentTransaction;

import com.google.android.material.bottomnavigation.BottomNavigationView;
import com.google.android.material.navigation.NavigationView;
import com.queueit.retaildemo.fragment.HomeFragment;
import com.queueit.retaildemo.fragment.LoginFragment;
import com.queueit.retaildemo.fragment.ProductListFragment;
import com.queueit.retaildemo.fragment.SettingsFragment;
import com.queueit.retaildemo.fragment.UserStateFragment;

/**
 * Host activity — mirrors MainAppView.swift.
 *
 * Layout:
 *   DrawerLayout
 *     ├─ LinearLayout (vertical)
 *     │    ├─ Toolbar  (green, hamburger menu on left, "Queue-it Retail" title)
 *     │    ├─ TextView (session countdown timer — hidden when inactive)
 *     │    ├─ FrameLayout  (fragment container — fills remaining space)
 *     │    └─ BottomNavigationView  (Home · Log-in · Product List)
 *     └─ NavigationView  (drawer: Settings, User State)
 */
public class MainActivity extends AppCompatActivity
        implements QueueManager.SessionListener {

    private DrawerLayout drawerLayout;
    private BottomNavigationView bottomNav;
    private TextView tvTimer;

    private QueueManager queueManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        queueManager = QueueManager.getInstance(this);
        queueManager.setSessionListener(this);

        setupToolbar();
        setupDrawer();
        setupBottomNav();
        setupTimer();

        // Show Home on first launch
        if (savedInstanceState == null) {
            showFragment(new HomeFragment(), false);
        }
    }

    // ─── Toolbar ─────────────────────────────────────────────────────────────

    private void setupToolbar() {
        Toolbar toolbar = findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);
        if (getSupportActionBar() != null) {
            getSupportActionBar().setTitle("Queue-it Retail");
        }
    }

    // ─── Drawer (Settings + User State) ─────────────────────────────────────

    private void setupDrawer() {
        drawerLayout = findViewById(R.id.drawer_layout);
        NavigationView navView = findViewById(R.id.nav_view);
        Toolbar toolbar = findViewById(R.id.toolbar);

        ActionBarDrawerToggle toggle = new ActionBarDrawerToggle(
                this, drawerLayout, toolbar,
                R.string.navigation_drawer_open,
                R.string.navigation_drawer_close);
        drawerLayout.addDrawerListener(toggle);
        toggle.syncState();

        navView.setNavigationItemSelectedListener(item -> {
            int id = item.getItemId();
            if (id == R.id.nav_settings) {
                showFragment(new SettingsFragment(), true);
                bottomNav.setSelectedItemId(-1); // deselect bottom nav items
            } else if (id == R.id.nav_user_state) {
                showFragment(new UserStateFragment(), true);
                bottomNav.setSelectedItemId(-1);
            }
            drawerLayout.closeDrawers();
            return true;
        });
    }

    // ─── Bottom Navigation (Home · Log-in · Product List) ────────────────────

    private void setupBottomNav() {
        bottomNav = findViewById(R.id.bottom_nav);
        bottomNav.setOnItemSelectedListener(item -> {
            int id = item.getItemId();
            if (id == R.id.nav_home) {
                showFragment(new HomeFragment(), false);
            } else if (id == R.id.nav_login) {
                showFragment(new LoginFragment(), false);
            } else if (id == R.id.nav_product_list) {
                showFragment(new ProductListFragment(), false);
            }
            return true;
        });
    }

    // ─── Session timer display ────────────────────────────────────────────────

    private void setupTimer() {
        tvTimer = findViewById(R.id.tv_session_timer);
    }

    @Override
    public void onSessionStarted() {
        runOnUiThread(() -> tvTimer.setVisibility(View.VISIBLE));
    }

    @Override
    public void onTimerTick(int remainingSeconds) {
        runOnUiThread(() -> {
            int minutes = remainingSeconds / 60;
            int seconds = remainingSeconds % 60;
            tvTimer.setText(String.format("%02d:%02d", minutes, seconds));
            tvTimer.setVisibility(View.VISIBLE);
        });
    }

    @Override
    public void onSessionExpired() {
        runOnUiThread(() -> {
            new AlertDialog.Builder(this)
                    .setTitle("Session Expired")
                    .setMessage("Your session has timed out.")
                    .setPositiveButton("OK", null)
                    .show();
            tvTimer.setVisibility(View.GONE);

            // Navigate home after 5 s (mirrors iOS behavior)
            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                bottomNav.setSelectedItemId(R.id.nav_home);
                showFragment(new HomeFragment(), false);
            }, 5000);
        });
    }

    // ─── Fragment management ──────────────────────────────────────────────────

    public void showFragment(Fragment fragment, boolean addToBackStack) {
        FragmentTransaction tx = getSupportFragmentManager()
                .beginTransaction()
                .replace(R.id.fragment_container, fragment);
        if (addToBackStack) tx.addToBackStack(null);
        tx.commit();
    }

    /** Called by LoginFragment when settings are missing. */
    public void navigateHome() {
        bottomNav.setSelectedItemId(R.id.nav_home);
        showFragment(new HomeFragment(), false);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        queueManager.setSessionListener(null);
    }
}
