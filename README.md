# Hamon SDK for iOS

Lightweight, secure, and reliable analytics SDK for iOS with encryption, event buffering, and automatic submission.

![iOS 13.0+](https://img.shields.io/badge/iOS-13.0%2B-blue)
![Swift 5.7+](https://img.shields.io/badge/Swift-5.7%2B-orange)
![SPM](https://img.shields.io/badge/SPM-ready-brightgreen)

📖 **Documentation:** [English](README.md) • [Русский](README-RU.md) • [Українська](README-UA.md)

## Features

✅ **Zero dependencies** - Firebase required only to set User ID
✅ **AES/CBC encryption** - All requests are encrypted
✅ **Automatic batching** - 10 events or 2 seconds  
✅ **Thread-safe** - Safe to use from any thread  
✅ **Retry logic** - Automatic retry on 5xx errors  
✅ **Background support** - Auto-flush on background  
✅ **Device info** - Automatic device data collection  
✅ **SwiftUI & UIKit** - Works with both frameworks

## Requirements

- iOS 13.0+
- Swift 5.7+
- Xcode 14.0+

## Installation

### Swift Package Manager

Add dependency to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Jumaon27848/ios_hamon.git", from: "1.0.0")
]
```

Or in Xcode:  
**File → Add Package Dependencies**  
Paste URL: `https://github.com/Jumaon27848/ios_hamon.git`

> **Setting up a new app?** [INTEGRATION.md](INTEGRATION.md) is a step-by-step guide.
> **Coming from 1.0.5?** See [MIGRATION.md](MIGRATION.md) — no breaking changes.

## Quick Start

### 1. Basic Setup

```swift
import Hamon
import FirebaseAnalytics

func application(_ application: UIApplication, 
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // Configure SDK with your server IP
    Hamon.shared.configure(host: "your_server_ip_here")
    
    // Set Firebase App Instance ID as user identifier
    if let appInstanceId = Analytics.appInstanceID() {
      Hamon.shared.setUserId(appInstanceId)
    }
    
    return true
}
```

### 2. SwiftUI Setup

```swift
import SwiftUI
import Hamon
import FirebaseAnalytics

@main
struct MyApp: App {
    init() {
        setupAnalytics()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func setupAnalytics() {
        Hamon.shared.configure(host: "your_server_ip_here")
        
        if let appInstanceId = Analytics.appInstanceID() {
          Hamon.shared.setUserId(appInstanceId)
        }
    }
}
```

## Usage

### Track Events

```swift
// Simple event
Hamon.shared.logEvent("screen_open")

// Event with parameters
Hamon.shared.logEvent("purchase", parameters: [
    "product_id": "premium_monthly",
    "price": 9.99,
    "currency": "USD"
])

// Complex event
Hamon.shared.logEvent("level_complete", parameters: [
    "level": 5,
    "score": 1250,
    "time_seconds": 45.5,
    "items_collected": 12
])
```

### Update User Data

```swift
// Set Firebase Cloud Messaging token — see "Push Notifications (FCM Token)" below
Hamon.shared.setFCM(token: fcmToken)

// Set Affise Click ID
Hamon.shared.setAffiseId("affise_click_id_here")

// Set Web Customer ID
Hamon.shared.setWebCustomerId("web_customer_id_here")

// Set Promo Code
Hamon.shared.setPromoCode("promo_code_here")

// SDK automatically updates user data with:
// - Apple ID (App Store ID from Info.plist)
// - App version
// - OS version
// - Device model
// - Locale
// - Country code
// - Advertising ID / IDFV
// - Ad tracking status
```

### Push Notifications (FCM Token)

The FCM registration token is reported to the server as `firebase_token`. The SDK
takes no Firebase dependency, so the host app supplies the token — it is then cached
across launches and re-sent automatically, so you only hand it over once per token.

**Three things must be in place before Firebase will issue a token at all:**

1. **Push Notifications** capability enabled in Xcode (`aps-environment` entitlement).
2. **APNs Auth Key (`.p8`)** uploaded to the Firebase Console for this app.
3. **`registerForRemoteNotifications()`** called — otherwise the token request fails
   with `No APNS token specified before fetching FCM Token`. This does *not* require
   the notification permission prompt; APNs issues a device token without it.

```swift
import Hamon
import FirebaseCore
import FirebaseMessaging

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    FirebaseApp.configure()

    Hamon.shared.configure(host: "your_server_ip_here")
    if let appInstanceId = Analytics.appInstanceID() {
        Hamon.shared.setUserId(appInstanceId)
    }

    Messaging.messaging().delegate = self
    application.registerForRemoteNotifications()   // no permission prompt required

    return true
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Hamon.shared.setFCM(token: fcmToken)
    }
}
```

> Use the delegate rather than reading `Messaging.messaging().fcmToken` once at launch:
> the callback also fires when the token arrives late (after APNs registration completes)
> and whenever it rotates.

### In-App Purchases (`appAccountToken`)

Apple stamps `appAccountToken` into the transaction permanently and echoes it back in
App Store Server Notifications — that is what lets the backend match a purchase to an
analytics user. The SDK exposes the App Instance ID already reshaped into the UUID form
StoreKit requires.

```swift
import StoreKit
import Hamon

var options: Set<Product.PurchaseOption> = []
if let token = Hamon.shared.appAccountToken {
    options.insert(.appAccountToken(token))
}

let result = try await product.purchase(options: options)
```

Pass it on **every** purchase — subscription, resubscription and one-off alike.
Subscription renewals inherit the token automatically.

The conversion inserts dashes only, so the backend recovers the original App Instance ID
by stripping them back out:

```
b9660c2a16297c54d42d5a3986c6e6c8  ->  b9660c2a-1629-7c54-d42d-5a3986c6e6c8
```

> **Note:** the Firebase App Instance ID is regenerated on reinstall and on
> `resetAnalyticsData()`, so `appAccountToken` differs across installs and cannot be used
> to link a user through a reinstall. Existing subscribers keep whatever token (or none)
> their original transaction carried — it is never backfilled.

### Manual Flush

```swift
// Force send all buffered events
Hamon.shared.flush()

// Clear event queue without sending
Hamon.shared.clearQueue()
```

## Required Info.plist Configuration

Add your App Store ID to `Info.plist` — **required** for the SDK to send user data:

```xml
<key>AppStoreID</key>
<string>1234567890</string>
```

> If `AppStoreID` is missing, the SDK logs an error and skips all user data updates.

## App Transport Security (ATS)

When using HTTP connections, you need to configure ATS in `Info.plist`.

### Option 1: Automatic XML Generation

```swift
// Generate XML for your Info.plist
let xml = Hamon.shared.generateInfoPlistConfiguration(host: "your_server_ip_here")
print(xml)
```

### Option 2: Test Connection

```swift
Hamon.shared.testConnection(host: "your_server_ip_here") { success, message in
    if success {
        print("✅ Server reachable")
    } else {
        print("❌ Connection failed: \(message)")
        
        // Get ATS configuration if needed
        let xml = Hamon.shared.generateInfoPlistConfiguration(host: "your_server_ip_here")
        print("Add this to Info.plist:\n\(xml)")
    }
}
```

### Option 3: Manual Configuration

Add to `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>(your_server_ip_here)</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### Using HTTPS

```swift
Hamon.shared.configure(host: "your-domain.com", useHTTPS: true)
```

## Tracking Authorization (iOS 14+)

```swift
import AppTrackingTransparency

if #available(iOS 14, *) {
    Hamon.shared.requestTrackingAuthorization { status in
        switch status {
        case .authorized:
            print("Tracking authorized")
        case .denied:
            print("Tracking denied")
        case .restricted:
            print("Tracking restricted")
        case .notDetermined:
            print("Tracking not determined")
        @unknown default:
            break
        }
    }
}
```

Add to `Info.plist`:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>We use tracking to personalize your experience</string>
```

## How It Works

### Event Buffering

Events are automatically sent when:
- **10+ events** accumulated in queue
- **10 seconds** passed since first event
- App enters **background**
- App is **terminating**

### Encryption

All requests are encrypted using:
- **Algorithm:** AES/CBC/PKCS5Padding
- **Key:** Custom reversed key
- **Output:** Base64(IV + encrypted_data)

### User Identification

Priority order:
1. Firebase App Instance ID (recommended)
2. Custom userId passed to `configure()`

The identifier — along with the FCM token, Affise Click ID, promo code and Web Customer
ID — is cached in `UserDefaults` and restored on the next launch, so a cold start reports
the values it already knows instead of overwriting them with `null` while it waits for the
host app to supply them again.

## API Reference

### Configuration

```swift
/// Configure SDK with server IP
/// - Parameters:
///   - host: Server IP address (e.g., "192.168.1.100")
///   - useHTTPS: Use HTTPS protocol (default: false)
///   - userId: Optional user identifier
func configure(host: String, useHTTPS: Bool = false, userId: String? = nil)

/// Set user ID (Firebase App Instance ID recommended)
func setUserId(_ userId: String)

/// Set Affise Click ID (Affise integration)
func setAffiseId(_ id: String)

/// Set Web Customer ID (web-to-app user linking)
func setWebCustomerId(_ id: String)

/// Set Firebase Cloud Messaging token
func setFCM(token: String)

/// Record the GDPR consent decision. Defaults to .unknown; the field is never null.
/// Invalid values passed to the String overload are ignored, keeping the previous decision.
func setGdprConsent(_ status: Hamon.GdprConsent)   // .accepted / .rejected / .unknown
func setGdprConsent(_ status: String)

/// Set the AppsFlyer device ID. Sticky — never cleared once recorded.
func setAppsFlyerId(_ id: String)
```

### Paywall Funnel

```swift
/// First call locks time_to_paywall and freezes the three counters below.
func notifyPaywallOpened()

/// First call after notifyPaywallOpened locks paywall_conversion_time (microseconds).
/// Ignored if no paywall was reported — there is no retro-fill.
func notifyPurchaseStarted()

/// First call after notifyPurchaseStarted locks click_to_pay_time (whole seconds).
func notifyPurchaseCompleted()

/// Counters, frozen by the first notifyPaywallOpened(). Zero is reported as 0, not null.
func notifyUserAction()
func notifyInterstitialShown()
func notifyAoaShown()

/// Opt into taps_count_first_30s. Swizzles UIWindow.sendEvent(_:), so it is off by
/// default — the hook is process-wide and can collide with other SDKs.
func enableTapTracking()
```

Order matters. `notifyPurchaseStarted()` before any `notifyPaywallOpened()` is silently
dropped and is **not** recovered by a later paywall signal; the same applies to
`notifyPurchaseCompleted()` before a started purchase. Every field is first-occurrence-only
and survives app restarts.

### Identity

```swift
/// The identifier reported to Hamon (Firebase App Instance ID unless a custom
/// id was supplied). Restored automatically across launches.
var userId: String? { get }

/// `userId` in the RFC 4122 layout StoreKit requires for `appAccountToken`.
/// nil when no id is set or it isn't 32 hex characters.
var appAccountToken: UUID? { get }

/// Converts a Firebase App Instance ID (32 hex chars) into the 8-4-4-4-12 form.
/// Dashes only — the characters are untouched, so the conversion is reversible.
static func appAccountToken(from appInstanceID: String) -> UUID?
```

### Event Tracking

```swift
/// Log analytics event
/// - Parameters:
///   - name: Event name
///   - parameters: Event parameters (optional)
func logEvent(_ name: String, parameters: [String: Any] = [:])

/// Force send all buffered events
func flush()

/// Clear event queue without sending
func clearQueue()
```

### Utilities

```swift
/// Generate Info.plist XML for ATS configuration
func generateInfoPlistConfiguration(host: String) -> String

/// Test connection to server
func testConnection(host: String, completion: @escaping (Bool, String) -> Void)
```

## Collected Data

SDK automatically collects:

| Field | Description | Example |
|-------|-------------|---------|
| `package` | App Store ID (from `AppStoreID` in Info.plist) | `1234567890` |
| `app_version` | App version | `1.0.0` |
| `app_version_code` | Build number | `1` |
| `os_version` | iOS version | `17.0` |
| `device_model` | Device model | `iPhone` |
| `device` | Device identifier | `iPhone14,2` |
| `build_id` | Kernel version | `21A123` |
| `locale` | Device locale | `en_US` |
| `geo` | Country code | `US` |
| `advertising_id` | IDFA or IDFV | `XXXXXXXX-...` |
| `is_limited_ad_tracking` | Ad tracking status | `false` |
| `firebase_token` | FCM token | `xxxxx` |
| `app_first_open_timestamp` | First launch time | `1234567890000` |
| `app_last_update_timestamp` | Last update time | `1234567890000` |
| `connection_type` | `wifi`, `cellular` or `none` | `wifi` |
| `screen_resolution` | Screen size in pixels | `1179x2556` |
| `ram_total_bytes` | Installed RAM, bytes | `6442450944` |
| `manufacturer` / `brand` | Always `Apple` on iOS | `Apple` |
| `storage_total` / `storage_free` | Volume capacity, bytes | `128000000000` |
| `hamon_version` | SDK version | `1.1.0` |

Set by the host app:

| Field | Set with | Example |
|-------|----------|---------|
| `web_customer_id` | `setWebCustomerId(_:)` | `abc123` |
| `affise_clickid` / `affise_promo_code` | `setAffiseId(_:)` / `setPromoCode(_:)` | `xxxxx` |
| `gdpr_consent_status` | `setGdprConsent(_:)`, defaults to `unknown` | `accepted` |
| `appsflyer_id` | `setAppsFlyerId(_:)` | `1234567890-1234567` |

Behavioural metrics — see [Paywall Funnel](#paywall-funnel):

| Field | Meaning | Unit |
|-------|---------|------|
| `session_length_first` | First foreground session | **milliseconds** |
| `taps_count_first_30s` | Taps in the first 30 s (opt-in) | count |
| `time_to_paywall` | First app open → first paywall | **milliseconds** |
| `actions_before_paywall` | `notifyUserAction()` calls before the paywall | count |
| `inters_shown_before_paywall` | Interstitials before the paywall | count |
| `aoa_shown_before_paywall` | App Open Ads before the paywall | count |
| `paywall_conversion_time` | Paywall → buy tap | **microseconds** |
| `click_to_pay_time` | Buy tap → purchase granted | **whole seconds**, floored |

> ⚠️ `paywall_conversion_time` and `click_to_pay_time` sit next to each other, both end in
> `_time`, and their units differ by a factor of 10⁶. The wire names do not reveal this.
> The values match the Android schema exactly — do not "normalise" either one.

> **Not collected on iOS:** `carrier`. `CTCarrier` is deprecated as of iOS 16 and returns
> the placeholder `"--"` from 16.4 on, with no replacement API, so the key is omitted from
> the payload rather than filled with a fake value.

## Examples

### E-commerce App

```swift
// Product view
Hamon.shared.logEvent("product_view", parameters: [
    "product_id": "123",
    "product_name": "Premium Subscription",
    "price": 9.99,
    "currency": "USD"
])

// Add to cart
Hamon.shared.logEvent("add_to_cart", parameters: [
    "product_id": "123",
    "quantity": 1
])

// Purchase
Hamon.shared.logEvent("purchase", parameters: [
    "transaction_id": UUID().uuidString,
    "products": [
        ["id": "123", "name": "Premium", "price": 9.99]
    ],
    "total": 9.99,
    "currency": "USD"
])
Hamon.shared.flush() // Important event - send immediately
```

### Gaming App

```swift
// Game start
Hamon.shared.logEvent("game_started", parameters: [
    "level": 1,
    "mode": "single_player"
])

// Level complete
Hamon.shared.logEvent("level_complete", parameters: [
    "level": 1,
    "score": 1500,
    "time_seconds": 120,
    "stars": 3
])

// Achievement
Hamon.shared.logEvent("achievement_unlocked", parameters: [
    "achievement_id": "first_win",
    "achievement_name": "First Victory"
])
```

### Social App

```swift
// Sign up
Hamon.shared.logEvent("sign_up", parameters: [
    "method": "email"
])

// Post created
Hamon.shared.logEvent("post_created", parameters: [
    "post_type": "photo",
    "has_caption": true,
    "tags_count": 3
])

// Share
Hamon.shared.logEvent("share", parameters: [
    "content_type": "post",
    "share_method": "link"
])
```

## Troubleshooting

### Events not sending

**Problem:** Events are logged but not sent to server.

**Solution:**
1. Check if `userId` is set: `Hamon.shared.setUserId()`
2. Check server connectivity: `Hamon.shared.testConnection()`
3. Verify ATS configuration for HTTP
4. Check console logs for errors

### ATS blocking connection

**Problem:** Error -1022 "App Transport Security has blocked a cleartext HTTP"

**Solution:**
1. Use `generateInfoPlistConfiguration()` to get XML
2. Add generated XML to Info.plist
3. Or use HTTPS: `configure(host: "...", useHTTPS: true)`

### Firebase App Instance ID not available

**Problem:** Can't get Firebase App Instance ID.

**Solution:**
1. Add Firebase to your project
2. Add `GoogleService-Info.plist`
3. Import `FirebaseCore` and call `FirebaseApp.configure()`

### AppStoreID not configured

**Problem:** User data is not sent to the server.

**Solution:**
Add `AppStoreID` to your `Info.plist`:
```xml
<key>AppStoreID</key>
<string>YOUR_APP_STORE_ID</string>
```

### Events buffered indefinitely

**Problem:** Events stay in queue without sending.

**Solution:**
- SDK waits for `userId` before sending events
- Call `Hamon.shared.setUserId()` to start sending

## Debug Logging

SDK outputs logs with prefix `[Hamon]`:

```
[Hamon] ✅ userId set: ABC123-DEF456-...
[Hamon] ✅ Event logged: screen_open
[Hamon] ✅ Sent 5 events successfully
[Hamon] ✅ User data updated successfully
[Hamon] ❌ SDK not initialized
[Hamon] ⚠️ Waiting for userId (Firebase App Instance ID)
[Hamon] ❌ AppStoreID is not set in Info.plist. User data will not be sent to the server.
[Hamon] ❌ Skipping user data update: AppStoreID is not configured in Info.plist
```

## Best Practices

### 1. Initialize Early
```swift
// ✅ Good - in AppDelegate/App.swift
func application(_ application: UIApplication, ...) -> Bool {
    Hamon.shared.configure(host: "...")
}

// ❌ Bad - lazy initialization
func someMethod() {
    Hamon.shared.configure(host: "...")
}
```

### 2. Set userId ASAP
```swift
// ✅ Good - get Firebase App Instance ID immediately
if let appInstanceId = Analytics.appInstanceID() {
    Hamon.shared.setUserId(appInstanceId)
}
```

### 3. Use Consistent Event Names
```swift
// ✅ Good - consistent naming
Hamon.shared.logEvent("screen_view", parameters: ["screen_name": "Home"])
Hamon.shared.logEvent("screen_view", parameters: ["screen_name": "Profile"])

// ❌ Bad - inconsistent
Hamon.shared.logEvent("home_opened")
Hamon.shared.logEvent("profile_screen_view")
```

### 4. Flush Critical Events
```swift
// ✅ Good - flush important events immediately
Hamon.shared.logEvent("purchase", parameters: [...])
Hamon.shared.flush()

// ✅ Good - normal events use automatic batching
Hamon.shared.logEvent("button_tap", parameters: [...])
```

## Performance

| Metric | Value |
|--------|-------|
| Memory overhead | ~1-2 MB |
| CPU (idle) | <0.1% |
| CPU (batching) | ~1-2% |
| Network per batch | 1-5 KB |
| Battery impact | Minimal |

## Support

- **Issues:** [GitHub Issues](https://github.com/Jumaon27848/ios_hamon/issues)
- **Documentation:** [Full Documentation](DOCUMENTATION.md)
