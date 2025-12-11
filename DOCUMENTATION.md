# Hamon SDK for iOS - Technical Documentation

Detailed technical documentation for Hamon iOS SDK.

## Table of Contents

1. [Architecture](#architecture)
2. [Component Details](#component-details)
3. [API Reference](#api-reference)
4. [Event Flow](#event-flow)
5. [Encryption Details](#encryption-details)
6. [Network Protocol](#network-protocol)
7. [Threading Model](#threading-model)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Hamon                                │
│  (Singleton, Main SDK Interface)                            │
└───────┬─────────────────────────────────────────────────────┘
        │
        ├──► HNetworkService
        │    ├─► HTTPURLSession (networking)
        │    └─► HEncryptionService (encryption)
        │
        ├──► HEventQueue
        │    ├─► DispatchQueue (thread safety)
        │    ├─► Timer (time-based flush)
        │    └─► NotificationCenter (background flush)
        │
        ├──► HDeviceInfoService
        │    ├─► UIDevice (device info)
        │    ├─► Bundle (app info)
        │    ├─► AdSupport (IDFA)
        │    └─► CoreTelephony (geo)
        │
        └──► HConfigHelper
             └─► URLSession (connection test)
```

### Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| **Hamon** | Public API, configuration, event logging |
| **HNetworkService** | HTTP requests, retry logic, response handling |
| **HEncryptionService** | AES/CBC encryption |
| **HEventQueue** | Event buffering, batching, auto-flush triggers |
| **HDeviceInfoService** | Device data collection |
| **HConfigHelper** | ATS configuration, connection testing |

---

## Component Details

### 1. Hamon (Main SDK)

**File:** `Hamon.swift`

#### Public API

```swift
// Configuration
public func configure(host: String, useHTTPS: Bool = false, userId: String? = nil)
public func setUserId(_ userId: String)
public func setFCM(token: String)

// Event tracking
public func logEvent(_ name: String, parameters: [String: Any] = [:])
public func flush()
public func clearQueue()

// Utilities
public func generateInfoPlistConfiguration(host: String) -> String
public func testConnection(host: String, completion: @escaping (Bool, String) -> Void)
```

#### Internal State

```swift
private var isInitialized: Bool           // SDK initialization status
private var baseURL: String?              // Server address
private var userId: String?               // User identifier (Firebase App Instance ID)
private var fcmToken: String?             // Firebase Cloud Messaging token
```

#### Initialization Flow

```
configure(host:) → checkATSConfiguration()
                 → create HNetworkService
                 → isInitialized = true
                 → wait for userId
                      ↓
setUserId()      → updateUserDataSync()
                 → start accepting events
```

---

### 2. HNetworkService

**File:** `HNetworkService.swift`

#### API Endpoints

```swift
// Base URL format
http(s)://<host>/v1

// Update user data
PATCH /v1/users/{firebase_installation_id}

// Send events
POST /v1/users/{firebase_installation_id}/event
```

#### Request Flow

```
Request → Encode to JSON
        → Encrypt payload
        → Wrap in {"payload": "..."}
        → Send via URLSession
        → Handle response
        → Retry on 5xx (once, after 2 seconds)
```

#### Error Handling

| HTTP Code | Action |
|-----------|--------|
| 200 | Success |
| 422 | Validation error, parse details |
| 500-599 | Retry once after 2 seconds |
| Other | Return error |

#### Configuration

```swift
URLSessionConfiguration:
- timeoutIntervalForRequest: 30s
- timeoutIntervalForResource: 60s
```

---

### 3. HEventQueue

**File:** `HEventQueue.swift`

#### Flush Triggers

Events are automatically sent when:

1. **Count trigger:** 10+ events accumulated
2. **Time trigger:** 10 seconds elapsed since first event
3. **Background:** App enters background
4. **Termination:** App is terminating

#### Thread Safety

```swift
private let queue = DispatchQueue(
    label: "com.hamon.eventqueue",
    qos: .utility
)
```

All operations on `events` array are dispatched to this queue.

#### Timer Implementation

```swift
// Main thread timer checks every 1 second
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    checkTimeBasedFlush()
}
```

#### Methods

```swift
func add(event: HAnalyticsEvent)              // Add single event
func add(events: [HAnalyticsEvent])           // Add multiple events
func flush()                                    // Trigger immediate flush
func drain() -> [HAnalyticsEvent]             // Get all events and clear
func clear()                                    // Clear without sending
```

---

### 4. HEncryptionService

**File:** `HEncryptionService.swift`

#### Algorithm

```
Algorithm: AES-256
Mode: CBC
Padding: PKCS7
IV: 16 bytes of zeros
Key: "5X<#)kRN+)S-2=9A<T,oQk4BUP?ACPVk".reversed()
```

#### Process

```
Input: JSON string
   ↓
1. Convert to Data (UTF-8)
2. Create IV (16 zero bytes)
3. Encrypt with AES/CBC/PKCS7
4. Combine: IV + encrypted_data
5. Encode to Base64
   ↓
Output: Base64 string
```

#### Code

```swift
func encrypt(message: String) -> String? {
    let key = "5X<#)kRN+)S-2=9A<T,oQk4BUP?ACPVk".asReversed()
    let iv = Data(count: 16) // Zero IV
    
    // Encrypt with CommonCrypto
    CCCrypt(
        CCOperation(kCCEncrypt),
        CCAlgorithm(kCCAlgorithmAES),
        CCOptions(kCCOptionPKCS7Padding),
        keyBytes, keyLength,
        ivBytes,
        messageBytes, messageLength,
        encryptedBytes, encryptedLength,
        &numBytesEncrypted
    )
    
    // Return Base64(IV + encrypted)
    return (iv + cipherData).base64EncodedString()
}
```

---

### 5. HDeviceInfoService

**File:** `HDeviceInfoService.swift`

#### Collected Data

| Method | Returns | Example |
|--------|---------|---------|
| `getPackageName()` | Bundle ID | `com.example.app` |
| `getOSVersion()` | iOS version | `17.0` |
| `getDevice()` | Device code | `iPhone14,2` |
| `getDeviceModel()` | Device model | `iPhone` |
| `getAppVersion()` | App version | `1.0.0` |
| `getAppVersionCode()` | Build number | `1` |
| `getBuildId()` | Kernel version | `21A123` |
| `getLocale()` | Locale | `en_US` |
| `getCountryCode()` | Country | `US` |
| `getAdvertisingId()` | IDFA/IDFV | `XXXXXXXX-...` |
| `isLimitedAdTracking()` | Ad tracking status | `false` |

#### Advertising ID Logic

```
iOS 14+:
  ↓
ATTrackingManager.trackingAuthorizationStatus == .authorized
  ↓ YES                        ↓ NO
IDFA                          IDFV

iOS 13:
  ↓
ASIdentifierManager.shared().advertisingIdentifier
  ↓ valid                      ↓ all zeros
IDFA                          IDFV
```

#### Country Code Priority

1. `Locale.current.regionCode`
2. `CTTelephonyNetworkInfo` carrier country

---

### 6. HConfigHelper

**File:** `HConfigHelper.swift`

#### ATS Check

```swift
func checkATSConfiguration(for serverIP: String, useHTTPS: Bool)
```

Prints warning if:
- Using HTTP (not HTTPS)
- Not a local IP (localhost, 127.0.0.1, 192.168.x.x, 10.x.x.x)

#### Connection Test

```swift
func testConnection(to baseURL: String, completion: @escaping (Bool, String) -> Void)
```

Tests:
- URL validity
- Server reachability
- ATS configuration

#### XML Generation

```swift
func generateInfoPlistXML(for serverIP: String) -> String
```

Generates:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>SERVER_IP</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

---

## API Reference

### Hamon

#### configure(host:useHTTPS:userId:)

```swift
public func configure(host: String, useHTTPS: Bool = false, userId: String? = nil)
```

Configures SDK with server address.

**Parameters:**
- `host`: Server IP or domain (e.g., "192.168.1.100")
- `useHTTPS`: Use HTTPS protocol (default: false)
- `userId`: Optional user identifier (default: nil)

**Example:**
```swift
Hamon.shared.configure(host: "192.168.1.100")
```

#### setUserId(_:)

```swift
public func setUserId(_ userId: String)
```

Sets user identifier. Required before events can be sent.

**Parameters:**
- `userId`: Unique user identifier (Firebase App Instance ID recommended)

**Example:**
```swift
import FirebaseAnalytics

if let appInstanceId = Analytics.appInstanceID() {
    Hamon.shared.setUserId(appInstanceId)
}
```

#### setFCM(token:)

```swift
public func setFCM(token: String)
```

Sets Firebase Cloud Messaging token.

**Parameters:**
- `token`: FCM token for push notifications

**Example:**
```swift
if let fcmToken = Messaging.messaging().fcmToken {
    Hamon.shared.setFCM(token: fcmToken)
}
```

#### logEvent(_:parameters:)

```swift
public func logEvent(_ name: String, parameters: [String: Any] = [:])
```

Logs an analytics event.

**Parameters:**
- `name`: Event name (e.g., "screen_view", "purchase")
- `parameters`: Event parameters (optional)

**Supported parameter types:**
- String
- Int
- Double
- Bool
- Array
- Dictionary

**Example:**
```swift
Hamon.shared.logEvent("purchase", parameters: [
    "product_id": "123",
    "price": 9.99,
    "currency": "USD",
    "items": ["item1", "item2"]
])
```

#### flush()

```swift
public func flush()
```

Forces immediate send of all buffered events.

**Example:**
```swift
Hamon.shared.logEvent("critical_event")
Hamon.shared.flush() // Send immediately
```

#### clearQueue()

```swift
public func clearQueue()
```

Clears event queue without sending.

**Example:**
```swift
Hamon.shared.clearQueue()
```

---

## Event Flow

### Complete Event Lifecycle

```
1. Application Code
   Hamon.shared.logEvent("purchase", parameters: [...])
      ↓
2. Hamon
   - Check isInitialized
   - Create HAnalyticsEvent
   - Add to EventQueue
      ↓
3. HEventQueue
   - Add to internal array
   - Check flush triggers:
     • 10+ events?
     • 10 seconds elapsed?
     • App backgrounding?
      ↓
4. Flush Triggered
   - Call onFlush callback
   - Pass events to Hamon
      ↓
5. Hamon (onFlush)
   - Check userId available
   - Call NetworkService.sendEvents()
      ↓
6. HNetworkService
   - Encode events to JSON
   - Encrypt JSON
   - Wrap in {"payload": "..."}
   - Send POST request
      ↓
7. Server Response
   - 200: Success ✓
   - 422: Validation error (parse details)
   - 5xx: Retry once after 2 seconds
      ↓
8. On Error
   - Add events back to queue
   - Will retry on next flush
```

### Event Structure

```json
{
  "events": [
    {
      "uuid": "550e8400-e29b-41d4-a716-446655440000",
      "timestamp": 1234567890000,
      "name": "purchase",
      "parameters": {
        "product_id": "123",
        "price": 9.99,
        "currency": "USD"
      }
    }
  ]
}
```

---

## Encryption Details

### AES-256-CBC Implementation

#### Key Generation

```swift
let originalKey = "5X<#)kRN+)S-2=9A<T,oQk4BUP?ACPVk"
let key = originalKey.reversed() // "kVPCA?PUB4kQo,T<A9=2-S+)NRk)#<X5"
```

Key length: 32 bytes (256 bits)

#### IV (Initialization Vector)

```swift
let iv = Data(count: 16) // 16 bytes of zeros
```

#### Encryption Process

```
1. Message (UTF-8 String)
   ↓
2. Convert to Data
   ↓
3. AES Encryption
   - Algorithm: AES-256
   - Mode: CBC
   - Padding: PKCS7
   - Key: 32 bytes
   - IV: 16 zero bytes
   ↓
4. Encrypted Data
   ↓
5. Combine: IV || Encrypted Data
   ↓
6. Base64 Encode
   ↓
7. Final Encrypted String
```

#### Security Notes

- **IV is constant (zeros)**: Acceptable for server communication with unique payloads
- **Key is hardcoded**: Same for all SDK instances
- **Purpose**: Prevent plaintext inspection, not cryptographic security
- **Transport**: Should use HTTPS in production

---

## Network Protocol

### Request Format

#### Update User

```http
PATCH /v1/users/{firebase_installation_id} HTTP/1.1
Host: your-server.com
Content-Type: application/json

{
  "payload": "BASE64_ENCRYPTED_DATA"
}
```

Decrypted payload:
```json
{
  "lib_id": null,
  "package": "com.example.app",
  "app_first_open_timestamp": 1234567890000,
  "app_last_update_timestamp": 1234567890000,
  "app_delete_timestamp": null,
  "firebase_token": "fcm_token_here",
  "geo": "US",
  "os_version": "17.0",
  "device": null,
  "device_model": "iPhone14,2",
  "app_version": "1.0.0",
  "referrer": null,
  "tenjin_analytics_installation_id": null,
  "is_limited_ad_tracking": false,
  "advertising_id": "XXXXXXXX-...",
  "os_version_int": null,
  "app_version_code": 1,
  "build_id": "21A123",
  "locale": "en_US",
  "hints": null,
  "affise_clickid" : null
}
```

#### Send Events

```http
POST /v1/users/{firebase_installation_id}/event HTTP/1.1
Host: your-server.com
Content-Type: application/json

{
  "payload": "BASE64_ENCRYPTED_DATA"
}
```

Decrypted payload:
```json
{
  "events": [
    {
      "uuid": "550e8400-e29b-41d4-a716-446655440000",
      "timestamp": 1234567890000,
      "name": "purchase",
      "parameters": {
        "product_id": "123",
        "price": 9.99
      }
    }
  ]
}
```

### Response Format

#### Success (200)

```json
{
  "status": "success"
}
```

#### Validation Error (422)

```json
{
  "detail": [
    {
      "loc": ["body", "field_name"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

#### Server Error (5xx)

SDK automatically retries once after 2 seconds.

---

## Threading Model

### Thread Safety Guarantees

| Component | Thread Safety | Implementation |
|-----------|---------------|----------------|
| Hamon | Thread-safe | Serial DispatchQueue |
| HEventQueue | Thread-safe | Serial DispatchQueue |
| HNetworkService | Thread-safe | URLSession |
| HDeviceInfoService | Thread-safe | Read-only operations |
| HEncryptionService | Thread-safe | Stateless |

### Queue Structure

```
Main Thread
    ↓
Hamon.logEvent()
    ↓
HEventQueue.add() → Serial Queue (utility QoS)
    ↓
Flush triggered
    ↓
HNetworkService.sendEvents() → URLSession background queue
    ↓
Completion handler → Main Thread
```

### Background Handling

```swift
// App enters background
UIApplication.didEnterBackgroundNotification
    ↓
HEventQueue.flush()
    ↓
Send all buffered events

// App terminating
UIApplication.willTerminateNotification
    ↓
HEventQueue.flush()
    ↓
Attempt to send events (best effort)
```

---

## Best Practices

### 1. Initialization

✅ **Do:**
```swift
func application(_ application: UIApplication, ...) -> Bool {
    // Initialize early in app lifecycle
    Hamon.shared.configure(host: "192.168.1.100")
    
    // Then get App Instance ID
    if let appInstanceId = Analytics.appInstanceID() {
        Hamon.shared.setUserId(appInstanceId)
    }
    
    return true
}
```

❌ **Don't:**
```swift
func someRandomMethod() {
    // Don't initialize lazily
    Hamon.shared.configure(host: "192.168.1.100")
}
```

### 2. Event Naming

✅ **Do:**
```swift
// Consistent snake_case
Hamon.shared.logEvent("screen_view", parameters: ["screen_name": "home"])
Hamon.shared.logEvent("button_click", parameters: ["button_name": "subscribe"])
```

❌ **Don't:**
```swift
// Inconsistent naming
Hamon.shared.logEvent("ScreenView")
Hamon.shared.logEvent("buttonClick")
Hamon.shared.logEvent("tap_subscribe_button")
```

### 3. Parameter Types

✅ **Do:**
```swift
Hamon.shared.logEvent("purchase", parameters: [
    "product_id": "123",                    // String
    "price": 9.99,                          // Double
    "quantity": 1,                          // Int
    "is_subscription": true,                // Bool
    "tags": ["premium", "featured"],        // Array
    "metadata": ["source": "app"]           // Dictionary
])
```

❌ **Don't:**
```swift
// Complex nested structures
Hamon.shared.logEvent("purchase", parameters: [
    "data": [
        "deeply": [
            "nested": [
                "structure": "hard to query"
            ]
        ]
    ]
])
```

### 4. Flush Strategy

✅ **Do:**
```swift
// Critical events - flush immediately
Hamon.shared.logEvent("purchase", parameters: [...])
Hamon.shared.flush()

// Registration completed
Hamon.shared.logEvent("sign_up_complete", parameters: [...])
Hamon.shared.flush()
```

✅ **Also okay:**
```swift
// Normal events - use automatic batching
Hamon.shared.logEvent("button_click")
Hamon.shared.logEvent("screen_view")
// SDK will batch and send automatically
```

❌ **Don't:**
```swift
// Don't flush after every event
Hamon.shared.logEvent("tap")
Hamon.shared.flush() // ❌ Unnecessary

Hamon.shared.logEvent("scroll")
Hamon.shared.flush() // ❌ Defeats batching
```

### 5. User ID Management

✅ **Do:**
```swift
// Use Firebase App Instance ID
import FirebaseAnalytics

if let appInstanceId = Analytics.appInstanceID() {
    Hamon.shared.setUserId(appInstanceId)
} else {
    print("Warning: Firebase App Instance ID not available")
}
```

✅ **Or custom ID:**
```swift
// After user authentication
func userDidSignIn(userId: String) {
    Hamon.shared.setUserId(userId)
}
```

❌ **Don't:**
```swift
// Don't use unstable IDs
Hamon.shared.setUserId(UUID().uuidString) // ❌ Changes every install
```

---

## Troubleshooting

### Problem: Events not sending

**Symptoms:**
- Events logged in console
- No network requests
- No success messages

**Solutions:**

1. Check userId is set:
```swift
// Add after Firebase App Instance ID fetch
print("UserId set: \(Hamon.shared.userId ?? "none")")
```

2. Check initialization:
```swift
if !Hamon.shared.isInitialized {
    print("SDK not initialized!")
}
```

3. Manually flush to debug:
```swift
Hamon.shared.logEvent("test")
Hamon.shared.flush()
// Check console for network errors
```

### Problem: ATS blocking HTTP

**Symptoms:**
```
Error Domain=NSURLErrorDomain Code=-1022
"The resource could not be loaded because the App Transport Security policy requires..."
```

**Solutions:**

1. Generate and add ATS configuration:
```swift
let xml = Hamon.shared.generateInfoPlistConfiguration(host: "192.168.1.100")
print(xml)
// Add to Info.plist
```

2. Or use HTTPS:
```swift
Hamon.shared.configure(host: "your-domain.com", useHTTPS: true)
```

```
### Problem: Firebase App Instance ID not available

**Symptoms:**
```
[Hamon] ⚠️ Waiting for userId (Firebase App Instance ID)
```

**Solutions:**

1. Ensure Firebase is configured:
```swift
import FirebaseCore
import FirebaseAnalytics

func application(...) -> Bool {
    FirebaseApp.configure() // Must be called first
    
    // Then get App Instance ID
    if let appInstanceId = Analytics.appInstanceID() {
        Hamon.shared.setUserId(appInstanceId)
    }
    
    return true
}
```

2. Check GoogleService-Info.plist is added to project

3. Verify Firebase Analytics is properly imported:
```swift
import FirebaseAnalytics // Should not error
```

**Note:** `Analytics.appInstanceID()` returns synchronously and may return nil on first app launch before Firebase is fully initialized. In production, consider getting it after a small delay or in `applicationDidBecomeActive`.
```
### Problem: Validation errors (422)

**Symptoms:**
```
[Hamon.NetworkService] Validation errors:
[Hamon.NetworkService.ErrorDescription] - Field: body.field_name, Message: ...
```

**Solutions:**

1. Check server expects correct data format
2. Verify all required fields are provided
3. Check data types match server expectations

### Problem: Events buffered indefinitely

**Symptoms:**
- Events logged
- Never sent
- No errors

**Solutions:**

1. Check userId:
```swift
// Make sure this is called:
Hamon.shared.setUserId("...")
```

2. Manually trigger flush:
```swift
Hamon.shared.flush()
```

3. Check queue status (add debug method):
```swift
// In HEventQueue.swift (for debugging)
func count() -> Int {
    var c = 0
    queue.sync {
        c = events.count
    }
    return c
}
```

---

## Performance Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Memory overhead | 1-2 MB | Excluding event data |
| CPU (idle) | <0.1% | Background timer only |
| CPU (flush) | 1-2% | Brief during send |
| Network per batch | 1-5 KB | Depends on event count |
| Battery impact | Minimal | Batching reduces wake-ups |
| Encryption overhead | <1ms | Per request |

---

## Compatibility

| Platform | Minimum Version | Tested |
|----------|----------------|--------|
| iOS | 13.0+ | ✅ |
| iPadOS | 13.0+ | ✅ |
| Mac Catalyst | 13.0+ | ⚠️ Limited testing |
| tvOS | Not supported | ❌ |
| watchOS | Not supported | ❌ |

---

## Support

- **Issues:** [GitHub Issues](https://github.com/Jumaon27848/ios_hamon/issues)
- **Questions:** Open a discussion on GitHub

---

**Last Updated:** 2025
**SDK Version:** 1.0.0  
**API Version:** v1
