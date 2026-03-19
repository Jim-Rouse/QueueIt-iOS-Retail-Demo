package com.queueit.retaildemo;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.queue_it.androidsdk.Error;
import com.queue_it.androidsdk.QueueDisabledInfo;
import com.queue_it.androidsdk.QueueITEngine;
import com.queue_it.androidsdk.QueueITException;
import com.queue_it.androidsdk.QueueListener;
import com.queue_it.androidsdk.QueuePassedInfo;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;

/**
 * Singleton that manages:
 *  - QueueITEngine lifecycle (simple integration – Login screen)
 *  - Protected HTTP requests with x-queueit-ajaxpageurl header (hybrid – Product List)
 *  - Session timer (60-second countdown after queue pass on simple integration)
 *  - QueueItAccepted cookie persistence via CookieManager
 *
 * Mirrors QueueManager.swift from the iOS retail demo.
 */
public class QueueManager extends QueueListener {

    private static final String TAG = "QueueManager";
    private static final String PREF_NAME = "QueueItSettings";

    // ─── Singleton ────────────────────────────────────────────────────────────
    private static QueueManager instance;

    public static synchronized QueueManager getInstance(Context context) {
        if (instance == null) {
            instance = new QueueManager(context.getApplicationContext());
        }
        return instance;
    }

    // ─── Listener interfaces ─────────────────────────────────────────────────

    /**
     * Notified about queue events. Set by whichever fragment is currently active.
     */
    public interface QueueStateListener {
        void onQueuePassed(String token);
        void onQueueViewWillOpen();
        void onQueueError(String message);
    }

    /**
     * Notified about session timer events. Set by MainActivity.
     */
    public interface SessionListener {
        void onSessionStarted();
        void onTimerTick(int remainingSeconds);
        void onSessionExpired();
    }

    // ─── State ───────────────────────────────────────────────────────────────
    private final Context appContext;
    private final SharedPreferences prefs;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private QueueITEngine engine;
    private QueueStateListener queueStateListener;
    private SessionListener sessionListener;

    private boolean sessionActive = false;
    private int remainingTime = 0;
    private boolean isExplicitActivation = false;

    /** Replayed after onQueuePassed during a hybrid (protected API) flow. */
    private Runnable pendingRequest = null;

    private QueueManager(Context context) {
        appContext = context;
        prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE);
    }

    // ─── Listener registration ───────────────────────────────────────────────

    public void setQueueStateListener(QueueStateListener l) {
        this.queueStateListener = l;
    }

    public void setSessionListener(SessionListener l) {
        this.sessionListener = l;
        // Immediately deliver current timer value if session is already running
        if (sessionActive && l != null) {
            l.onTimerTick(remainingTime);
        }
    }

    // ─── Settings helpers ────────────────────────────────────────────────────

    public String getCustomerID()        { return prefs.getString("customerID", ""); }
    public String getWaitingRoomID()     { return prefs.getString("waitingRoomID", ""); }
    public String getLayoutName()        { return prefs.getString("layoutName", ""); }
    public String getLanguage()          { return prefs.getString("language", "en"); }
    public String getEnqueueToken()      { return prefs.getString("enqueueToken", ""); }
    public String getEnqueueKey()        { return prefs.getString("enqueueKey", ""); }
    public String getWaitingRoomDomain() { return prefs.getString("waitingRoomDomain", ""); }
    public String getWaitingRoomPrefix() { return prefs.getString("waitingRoomPrefix", ""); }
    public String getQueueItToken()      { return prefs.getString("queueItToken", null); }

    public boolean isSessionActive() { return sessionActive; }

    public boolean isConfigured() {
        return !getCustomerID().isEmpty() && !getWaitingRoomID().isEmpty();
    }

    // ─── Simple integration (Login screen) ───────────────────────────────────

    /**
     * Creates a QueueITEngine and calls run() — shows the waiting room if needed.
     * Mirrors iOS activateWaitingRoom().
     */
    public void activateWaitingRoom(Activity activity) {
        if (!isConfigured()) return;
        isExplicitActivation = true;

        String customerId    = getCustomerID();
        String waitingRoomId = getWaitingRoomID();
        String layout        = getLayoutName().isEmpty()        ? null : getLayoutName();
        String language      = getLanguage().isEmpty()          ? "en" : getLanguage();
        String domain        = getWaitingRoomDomain().isEmpty() ? null : getWaitingRoomDomain();
        String prefix        = getWaitingRoomPrefix().isEmpty() ? null : getWaitingRoomPrefix();

        engine = new QueueITEngine(
                activity,
                customerId,
                waitingRoomId,
                layout,
                language,
                domain,
                prefix,
                this,
                null   // QueueItEngineOptions — null = defaults
        );

        try {
            engine.run(activity);
        } catch (QueueITException e) {
            // Thrown when a request is already in progress — safe to ignore
            Log.d(TAG, "activateWaitingRoom: QueueITException (already in progress): " + e.getMessage());
        }
    }

    // ─── Hybrid integration (Product List – protected API) ───────────────────

    public interface RequestCallback {
        void onSuccess(byte[] data);
        void onFailure(Exception e);
    }

    /**
     * Makes an HTTP request to urlString with the required Queue-it headers:
     *   x-queueit-ajaxpageurl   — the request URL
     *   Cookie                  — stored QueueItAccepted cookies
     *   x-queueittoken          — stored queue-it token (if present)
     *
     * If the server responds with x-queueit-redirect, the user needs to queue.
     * The engine is created, run() is called, and the original request is
     * replayed automatically after onQueuePassed fires.
     *
     * Mirrors iOS makeProtectedRequest(to:completion:).
     */
    public void makeProtectedRequest(Activity activity, String urlString, RequestCallback callback) {
        Log.d(TAG, "🌐 makeProtectedRequest → " + urlString);

        new Thread(() -> {
            try {
                URL url = new URL(urlString);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("GET");
                conn.setConnectTimeout(15000);
                conn.setReadTimeout(15000);

                // ── Outgoing headers ──────────────────────────────────────
                conn.setRequestProperty("x-queueit-ajaxpageurl", urlString);
                Log.d(TAG, "📤 x-queueit-ajaxpageurl: " + urlString);

                String cookieHeader = CookieManager.getInstance(appContext).cookieHeaderValue();
                if (cookieHeader != null) {
                    conn.setRequestProperty("Cookie", cookieHeader);
                    Log.d(TAG, "📤 Cookie: " + cookieHeader);
                }

                String token = getQueueItToken();
                if (token != null) {
                    conn.setRequestProperty("x-queueittoken", token);
                    Log.d(TAG, "📤 x-queueittoken: " + token);
                }
                // ─────────────────────────────────────────────────────────

                conn.connect();
                int status = conn.getResponseCode();
                Log.d(TAG, "📥 Response status: " + status + " for " + urlString);

                // ── Incoming cookies ──────────────────────────────────────
                CookieManager.getInstance(appContext).processResponseCookies(conn);
                // ─────────────────────────────────────────────────────────

                // ── Queue-it redirect check ───────────────────────────────
                String redirectHeader = conn.getHeaderField("x-queueit-redirect");
                if (redirectHeader == null) {
                    redirectHeader = conn.getHeaderField("X-Queueit-Redirect");
                }

                if (redirectHeader != null) {
                    Log.d(TAG, "🔀 x-queueit-redirect detected: " + redirectHeader);
                    handleQueueItRedirect(activity, redirectHeader, urlString, callback);
                    return;
                }
                // ─────────────────────────────────────────────────────────

                // Success — read body
                byte[] data = readStream(conn.getInputStream());
                Log.d(TAG, "✅ Request succeeded, " + data.length + " byte(s)");

                // Clear token after successful request
                prefs.edit().remove("queueItToken").apply();
                Log.d(TAG, "🗑️  Cleared stored queueItToken after successful request");

                mainHandler.post(() -> callback.onSuccess(data));

            } catch (Exception e) {
                Log.e(TAG, "❌ Request failed: " + e.getMessage());
                mainHandler.post(() -> callback.onFailure(e));
            }
        }).start();
    }

    /**
     * Parses the x-queueit-redirect header, creates a QueueITEngine with the
     * extracted params, stores the pending retry, and calls run().
     */
    private void handleQueueItRedirect(Activity activity, String redirectStr,
                                       String originalUrl, RequestCallback callback) {
        String decoded;
        try {
            decoded = java.net.URLDecoder.decode(redirectStr, "UTF-8");
        } catch (Exception e) {
            decoded = redirectStr;
        }

        Uri redirectUri = Uri.parse(decoded);
        String customerId    = redirectUri.getQueryParameter("c");
        String waitingRoomId = redirectUri.getQueryParameter("e");
        String language      = redirectUri.getQueryParameter("language");
        String layout        = redirectUri.getQueryParameter("layoutName");
        String enqueueToken  = redirectUri.getQueryParameter("enqueuetoken");
        String enqueueKey    = redirectUri.getQueryParameter("enqueuekey");

        Log.d(TAG, "🔀 Redirect params — c=" + customerId + " e=" + waitingRoomId);

        if (customerId == null || waitingRoomId == null) {
            mainHandler.post(() -> callback.onFailure(
                    new Exception("Missing required redirect params (c or e)")));
            return;
        }

        final String finalCustomerId    = customerId;
        final String finalWaitingRoomId = waitingRoomId;
        final String finalLanguage      = language != null ? language : "en";
        final String finalLayout        = layout;
        final String domainPref         = getWaitingRoomDomain().isEmpty() ? null : getWaitingRoomDomain();
        final String prefixPref         = getWaitingRoomPrefix().isEmpty() ? null : getWaitingRoomPrefix();

        mainHandler.post(() -> {
            // Store the original request so it can be replayed after queue pass
            pendingRequest = () -> makeProtectedRequest(activity, originalUrl, callback);

            engine = new QueueITEngine(
                    activity,
                    finalCustomerId,
                    finalWaitingRoomId,
                    finalLayout,
                    finalLanguage,
                    domainPref,
                    prefixPref,
                    QueueManager.this,
                    null
            );

            try {
                engine.run(activity);
            } catch (QueueITException ex) {
                Log.d(TAG, "handleQueueItRedirect: QueueITException: " + ex.getMessage());
            }
        });
    }

    // ─── QueueListener callbacks ─────────────────────────────────────────────

    @Override
    public void onQueuePassed(QueuePassedInfo info) {
        String token = info.getQueueItToken();
        Log.d(TAG, "✅ onQueuePassed – token: " + token);
        handleQueuePassed(token);
    }

    @Override
    public void onQueueViewWillOpen() {
        Log.d(TAG, "ℹ️  onQueueViewWillOpen");
        mainHandler.post(() -> {
            if (queueStateListener != null) queueStateListener.onQueueViewWillOpen();
        });
    }

    @Override
    public void onQueueDisabled(QueueDisabledInfo info) {
        Log.d(TAG, "ℹ️  onQueueDisabled – treating as passed");
        if (isExplicitActivation) {
            mainHandler.post(this::startSessionTimer);
        }
        isExplicitActivation = false;
    }

    @Override
    public void onQueueItUnavailable() {
        Log.w(TAG, "⚠️  onQueueItUnavailable");
        isExplicitActivation = false;
        pendingRequest = null;
        mainHandler.post(() -> {
            if (queueStateListener != null) {
                queueStateListener.onQueueError("Queue-it service is currently unavailable.");
            }
        });
    }

    @Override
    public void onError(Error error, String errorMessage) {
        Log.e(TAG, "❌ onError – " + errorMessage);
        isExplicitActivation = false;
        pendingRequest = null;
        mainHandler.post(() -> {
            if (queueStateListener != null) queueStateListener.onQueueError(errorMessage);
        });
    }

    @Override
    public void onWebViewClosed() {
        Log.d(TAG, "ℹ️  onWebViewClosed");
    }

    @Override
    public void onSessionRestart(QueueITEngine queueITEngine) {
        Log.d(TAG, "ℹ️  onSessionRestart");
        // Re-run the engine so the user can rejoin the queue
        mainHandler.post(() -> {
            try {
                queueITEngine.run(null); // activity context is internal to the engine
            } catch (QueueITException e) {
                Log.d(TAG, "onSessionRestart: " + e.getMessage());
            }
        });
    }

    // ─── Internal helpers ─────────────────────────────────────────────────────

    private void handleQueuePassed(String token) {
        if (token != null) {
            prefs.edit().putString("queueItToken", token).apply();
        }

        mainHandler.post(() -> {
            if (isExplicitActivation) {
                startSessionTimer();
            }
            isExplicitActivation = false;

            if (queueStateListener != null) {
                queueStateListener.onQueuePassed(token);
            }

            // Replay pending hybrid request
            if (pendingRequest != null) {
                Runnable retry = pendingRequest;
                pendingRequest = null;
                Log.d(TAG, "🔁 Replaying pending request after queue pass");
                retry.run();
            }
        });
    }

    // ─── Session timer ───────────────────────────────────────────────────────

    private final Runnable timerRunnable = new Runnable() {
        @Override
        public void run() {
            remainingTime--;
            if (sessionListener != null) sessionListener.onTimerTick(remainingTime);
            if (remainingTime <= 0) {
                Log.d(TAG, "⏱️  Session timer expired");
                handleSessionExpiry();
            } else {
                mainHandler.postDelayed(this, 1000);
            }
        }
    };

    private void startSessionTimer() {
        Log.d(TAG, "⏱️  startSessionTimer – 60-second session started");
        sessionActive = true;
        remainingTime = 60;
        mainHandler.removeCallbacks(timerRunnable);
        mainHandler.postDelayed(timerRunnable, 1000);
        if (sessionListener != null) sessionListener.onSessionStarted();
    }

    private void handleSessionExpiry() {
        Log.d(TAG, "🔒 handleSessionExpiry – clearing token, navigating home in 5s");
        sessionActive = false;
        prefs.edit().remove("queueItToken").apply();
        if (sessionListener != null) sessionListener.onSessionExpired();
    }

    // ─── Utilities ────────────────────────────────────────────────────────────

    private static byte[] readStream(InputStream is) throws Exception {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        byte[] buffer = new byte[4096];
        int n;
        while ((n = is.read(buffer)) != -1) {
            baos.write(buffer, 0, n);
        }
        return baos.toByteArray();
    }
}
