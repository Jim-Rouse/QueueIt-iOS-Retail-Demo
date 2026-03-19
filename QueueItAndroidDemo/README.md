# Queue-it Android Retail Demo

An Android port of the **Queue-it iOS Retail Demo** app, rewritten in Java using the
[Queue-it Android WebUI SDK](https://github.com/queueit/android-webui-sdk).

Every screen, flow, and feature from the iOS SwiftUI / UIKit app has a direct Android equivalent.

---

## Feature Parity: iOS → Android

| iOS Component | Android Equivalent |
|---|---|
| `SplashScreenView.swift` | `SplashActivity.java` |
| `MainAppView.swift` (NavigationStack + CustomBottomBar) | `MainActivity.java` (DrawerLayout + BottomNavigationView) |
| `HomeView.swift` | `HomeFragment.java` + `fragment_home.xml` |
| `LogInViewController.swift` | `LoginFragment.java` + `fragment_login.xml` |
| `ProductListView.swift` | `ProductListFragment.java` + `fragment_product_list.xml` + `ProductAdapter.java` |
| `SettingsView.swift` | `SettingsFragment.java` + `fragment_settings.xml` |
| `UserStateView.swift` | `UserStateFragment.java` + `fragment_user_state.xml` |
| `QueueManager.swift` | `QueueManager.java` |
| `CookieManager.swift` | `CookieManager.java` |
| `@AppStorage` (UserDefaults) | `SharedPreferences` (auto-saved TextWatchers) |
| `QueueItKit` (iOS SDK) | `com.queue-it.androidsdk:library:2.2.3` |
| `QueueWebViewContainer` | `QueueActivity` (provided by SDK, declared in manifest) |

---

## Architecture

```
QueueManager (singleton)
├── Simple Integration (Login screen)
│     └── QueueITEngine.run(activity)
│           → QueueActivity (SDK WebView opens automatically)
│           → onQueuePassed → show login form + start 60s session timer
│
└── Hybrid Integration (Product List screen)
      └── makeProtectedRequest(activity, url, callback)
            1. Adds x-queueit-ajaxpageurl header
            2. Adds stored QueueItAccepted cookies
            3. Adds x-queueittoken if present
            4. Checks x-queueit-redirect response header
               → If present: extract c/e params, create engine, call run()
                             store pendingRequest → replayed after onQueuePassed
               → If absent:  return response data, clear token
```

---

## Project Setup

### 1. Clone / open in Android Studio

```
File → Open → select the QueueItAndroidDemo folder
```

Android Studio Hedgehog (2023.1.1) or later recommended.

### 2. Sync Gradle

The project pulls the Queue-it SDK automatically from Maven Central:

```groovy
implementation 'com.queue-it.androidsdk:library:2.2.3'
```

No manual AAR download is needed.

### 3. Required manifest entries (already included)

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Queue-it SDK activity — must be present -->
<activity android:name="com.queue_it.androidsdk.QueueActivity" />
```

### 4. Run

Connect a device or start an emulator and press **Run ▶**.

---

## Configuration (Settings screen)

Open the hamburger menu → **Settings** and fill in:

| Field | Description |
|---|---|
| **Customer ID** | Your Queue-it customer ID |
| **Waiting Room or Alias ID** | Event alias or waiting room ID |
| Layout Name (Theme) | Optional — leave blank for default |
| Language | Optional — defaults to `en` |
| Enqueue Token | Optional |
| Enqueue Key | Optional |
| Waiting Room Domain | Optional — for Behind-Proxy setups |
| Waiting Room Prefix | Optional — for Behind-Proxy setups |

Settings persist to `SharedPreferences` immediately on each keystroke (mirrors iOS `@AppStorage`).

---

## Integration Flows

### Simple Integration — Log-in Screen

1. Tap **Log-in** in the bottom navigation.
2. If settings are configured and no active session exists, the app shows
   *"Activating Queue-it Waiting Room…"* then calls `QueueITEngine.run()`.
3. The SDK's `QueueActivity` opens automatically and shows the waiting room WebView.
4. Once the user passes the queue, `onQueuePassed` fires:
   - The login form (username / password / Log In) appears.
   - A 60-second session countdown timer appears in the toolbar.
5. When the timer expires, an alert is shown and the app navigates back to Home.

### Hybrid Integration — Product List Screen

1. Tap **Product List** in the bottom navigation.
2. `ProductListFragment` calls `QueueManager.makeProtectedRequest()` against
   `https://retail.queue-it-demo.com/api/productList.json`.
3. **If the user is not queued**, the server responds with `x-queueit-redirect`.
   - `QueueManager` extracts `c`/`e` parameters, creates `QueueITEngine`, calls `run()`.
   - The waiting room WebView opens.
   - After `onQueuePassed`, the original product-list request is replayed automatically.
4. **If the user is already queued**, the product list renders immediately.
5. Tapping **Add to Cart** fires another protected request to `/api/addToCart`.

---

## User State Screen

Open the hamburger menu → **User State** to:
- View all current `SharedPreferences` key/value pairs (equivalent to iOS UserDefaults inspector).
- **Clear Queue Token** — removes the stored `queueItToken`.
- **Clear Cookies** — wipes `CookieManager` storage and Android WebView cookies.

---

## SDK Notes

- The `QueueITEngine` constructor mirrors the iOS `QueueItEngine` constructor parameter-for-parameter.
- `QueueActivity` is the Android equivalent of iOS `QueueWebViewContainer` — it is shipped inside the
  SDK AAR and only needs to be declared in `AndroidManifest.xml`.
- `QueueListener` (Android) is the equivalent of iOS `QueueListener` protocol.
- `QueuePassedInfo.getQueueItToken()` (Android) = iOS `QueuePassedInfo.queueItToken`.
- `onSessionRestart` passes the engine back so `run()` can be called again inline.

---

## Dependencies

```
androidx.appcompat:appcompat:1.6.1
com.google.android.material:material:1.11.0
androidx.constraintlayout:constraintlayout:2.1.4
androidx.recyclerview:recyclerview:1.3.2
androidx.cardview:cardview:1.0.0
com.queue-it.androidsdk:library:2.2.3   ← Queue-it SDK
com.google.code.gson:gson:2.10.1        ← JSON parsing for product list
```
