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
// Set Firebase Cloud Messaging token
if let fcmToken = Messaging.messaging().fcmToken {
    Hamon.shared.setFCM(token: fcmToken)
}

// Set Affise Click ID
Hamon.shared.setAffiseId("affise_click_id_here")

// Set Promo Code
Hamon.shared.setPromoCode("promo_code_here")

// SDK automatically updates user data with:
// - Package name (Bundle ID)
// - App version
// - OS version
// - Device model
// - Locale
// - Country code
// - Advertising ID / IDFV
// - Ad tracking status
```

### Manual Flush

```swift
// Force send all buffered events
Hamon.shared.flush()

// Clear event queue without sending
Hamon.shared.clearQueue()
```

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
3. UUID stored in Keychain

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

/// Set Firebase Cloud Messaging token
func setFCM(token: String)
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
| `package` | Bundle identifier | `com.example.app` |
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
