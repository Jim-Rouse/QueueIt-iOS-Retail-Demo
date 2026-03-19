package com.queueit.retaildemo.fragment;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;

import com.google.android.material.textfield.TextInputEditText;
import com.queueit.retaildemo.R;

/**
 * Settings form — mirrors SettingsView.swift.
 *
 * Uses @AppStorage equivalent: each field auto-saves to SharedPreferences
 * via a TextWatcher. Fields are loaded from SharedPreferences in onViewCreated.
 */
public class SettingsFragment extends Fragment {

    private static final String PREF_NAME = "QueueItSettings";

    private SharedPreferences prefs;
    private boolean isLoading = false; // Prevents saving during initial field population

    private TextInputEditText etCustomerID, etWaitingRoomID, etLayoutName,
            etLanguage, etEnqueueToken, etEnqueueKey,
            etWaitingRoomDomain, etWaitingRoomPrefix;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater,
                             @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        View v = inflater.inflate(R.layout.fragment_settings, container, false);
        prefs = requireContext().getSharedPreferences(PREF_NAME, 0);

        etCustomerID       = v.findViewById(R.id.et_customer_id);
        etWaitingRoomID    = v.findViewById(R.id.et_waiting_room_id);
        etLayoutName       = v.findViewById(R.id.et_layout_name);
        etLanguage         = v.findViewById(R.id.et_language);
        etEnqueueToken     = v.findViewById(R.id.et_enqueue_token);
        etEnqueueKey       = v.findViewById(R.id.et_enqueue_key);
        etWaitingRoomDomain = v.findViewById(R.id.et_waiting_room_domain);
        etWaitingRoomPrefix = v.findViewById(R.id.et_waiting_room_prefix);

        // Load saved values
        isLoading = true;
        etCustomerID.setText(prefs.getString("customerID", ""));
        etWaitingRoomID.setText(prefs.getString("waitingRoomID", ""));
        etLayoutName.setText(prefs.getString("layoutName", ""));
        etLanguage.setText(prefs.getString("language", "en"));
        etEnqueueToken.setText(prefs.getString("enqueueToken", ""));
        etEnqueueKey.setText(prefs.getString("enqueueKey", ""));
        etWaitingRoomDomain.setText(prefs.getString("waitingRoomDomain", ""));
        etWaitingRoomPrefix.setText(prefs.getString("waitingRoomPrefix", ""));
        isLoading = false;

        // Auto-save watchers (mirrors iOS @AppStorage behaviour)
        attachWatcher(etCustomerID,        "customerID");
        attachWatcher(etWaitingRoomID,     "waitingRoomID");
        attachWatcher(etLayoutName,        "layoutName");
        attachWatcher(etLanguage,          "language");
        attachWatcher(etEnqueueToken,      "enqueueToken");
        attachWatcher(etEnqueueKey,        "enqueueKey");
        attachWatcher(etWaitingRoomDomain, "waitingRoomDomain");
        attachWatcher(etWaitingRoomPrefix, "waitingRoomPrefix");

        return v;
    }

    private void attachWatcher(TextInputEditText field, String prefKey) {
        field.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int st, int c, int a) {}
            @Override public void onTextChanged(CharSequence s, int st, int b, int c) {}

            @Override
            public void afterTextChanged(Editable s) {
                if (!isLoading) {
                    prefs.edit().putString(prefKey, s.toString().trim()).apply();
                }
            }
        });
    }
}
