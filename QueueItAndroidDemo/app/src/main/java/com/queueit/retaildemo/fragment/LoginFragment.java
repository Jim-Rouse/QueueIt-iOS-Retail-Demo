package com.queueit.retaildemo.fragment;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.Fragment;

import com.queueit.retaildemo.MainActivity;
import com.queueit.retaildemo.QueueManager;
import com.queueit.retaildemo.R;

/**
 * Simple integration screen — mirrors LogInViewController.swift.
 *
 * Flow:
 *  1. If settings are missing → alert → go Home
 *  2. If session already active → show login form immediately
 *  3. Otherwise:
 *       - Show "NO ACTIVE SESSION!" for 2 s
 *       - Then "Activating Queue-it Waiting Room..."
 *       - Call QueueManager.activateWaitingRoom(activity)
 *       - QueueActivity (waiting room WebView) opens automatically
 *       - onQueuePassed → reveal login form (username / password / Log In)
 */
public class LoginFragment extends Fragment implements QueueManager.QueueStateListener {

    private TextView tvIcon, tvStatus;
    private EditText etUsername, etPassword;
    private Button btnLogin;
    private View loginFormContainer;

    private QueueManager queueManager;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater,
                             @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        View v = inflater.inflate(R.layout.fragment_login, container, false);

        tvIcon            = v.findViewById(R.id.tv_login_icon);
        tvStatus          = v.findViewById(R.id.tv_login_status);
        etUsername        = v.findViewById(R.id.et_username);
        etPassword        = v.findViewById(R.id.et_password);
        btnLogin          = v.findViewById(R.id.btn_login);
        loginFormContainer = v.findViewById(R.id.login_form_container);

        queueManager = QueueManager.getInstance(requireContext());

        btnLogin.setOnClickListener(view -> handleLogInTap());
        return v;
    }

    @Override
    public void onResume() {
        super.onResume();
        queueManager.setQueueStateListener(this);
        handleLoginFlow();
    }

    @Override
    public void onPause() {
        super.onPause();
        // Don't clear listener — queue callbacks may still be in-flight
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        queueManager.setQueueStateListener(null);
    }

    // ─── Login flow ───────────────────────────────────────────────────────────

    private void handleLoginFlow() {
        if (!queueManager.isConfigured()) {
            showMissingSettingsAlert();
            return;
        }

        if (queueManager.isSessionActive()) {
            // Already queued + session running — skip the waiting room
            showLoginForm();
            return;
        }

        // New session — mirror iOS "NO ACTIVE SESSION!" then activate
        tvStatus.setText("NO ACTIVE SESSION!");
        tvStatus.setVisibility(View.VISIBLE);
        loginFormContainer.setVisibility(View.GONE);

        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            if (!isAdded()) return;
            tvStatus.setText("Activating Queue-it Waiting Room…");
            queueManager.activateWaitingRoom(requireActivity());
        }, 2000);
    }

    // ─── QueueStateListener callbacks ────────────────────────────────────────

    @Override
    public void onQueuePassed(String token) {
        if (!isAdded()) return;
        showLoginForm();
    }

    @Override
    public void onQueueViewWillOpen() {
        if (!isAdded()) return;
        // Hide status label while the waiting room WebView is covering the screen
        tvStatus.setVisibility(View.INVISIBLE);
    }

    @Override
    public void onQueueError(String message) {
        if (!isAdded()) return;
        tvStatus.setText("Error: " + message);
        tvStatus.setVisibility(View.VISIBLE);
    }

    // ─── UI helpers ───────────────────────────────────────────────────────────

    private void showLoginForm() {
        tvStatus.setVisibility(View.GONE);
        tvIcon.setVisibility(View.VISIBLE);
        loginFormContainer.setVisibility(View.VISIBLE);
    }

    private void handleLogInTap() {
        String username = etUsername.getText().toString().trim();
        String password = etPassword.getText().toString().trim();

        if (username.isEmpty() || password.isEmpty()) {
            new AlertDialog.Builder(requireContext())
                    .setTitle("Error")
                    .setMessage("Please enter a username and password.")
                    .setPositiveButton("OK", null)
                    .show();
            return;
        }

        // Demo only — in production this would call your authenticated backend
        // using the queue-it token as proof of queue passage
        new AlertDialog.Builder(requireContext())
                .setTitle("Success")
                .setMessage("Logged in successfully! (Demo)")
                .setPositiveButton("OK", null)
                .show();
    }

    private void showMissingSettingsAlert() {
        if (!isAdded()) return;
        new AlertDialog.Builder(requireContext())
                .setTitle("Missing Settings")
                .setMessage("Please configure Customer ID and Waiting Room ID in Settings first.")
                .setPositiveButton("OK", (d, w) -> {
                    if (getActivity() instanceof MainActivity) {
                        ((MainActivity) getActivity()).navigateHome();
                    }
                })
                .setCancelable(false)
                .show();
    }
}
