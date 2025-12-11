# Hamon SDK для iOS

Легкий, безпечний та надійний SDK для аналітики на iOS з шифруванням, буферизацією подій та автоматичним надсиланням.

![iOS 13.0+](https://img.shields.io/badge/iOS-13.0%2B-blue)
![Swift 5.7+](https://img.shields.io/badge/Swift-5.7%2B-orange)
![SPM](https://img.shields.io/badge/SPM-ready-brightgreen)

📖 **Документація:** [English](README.md) • [Русский](README-RU.md) • [Українська](README-UA.md)

## Можливості

✅ **Без залежностей** - Firebase потрібен лише для встановлення User ID  
✅ **AES/CBC шифрування** - Всі запити зашифровані  
✅ **Автоматичне надсилання** - 10 подій або 10 секунд  
✅ **Thread-safe** - Безпечно використовувати з будь-якого потоку  
✅ **Retry логіка** - Автоматичний повтор при 5xx помилках  
✅ **Підтримка background** - Автоматичне надсилання при згортанні  
✅ **Інформація про пристрій** - Автоматичний збір даних  
✅ **SwiftUI & UIKit** - Працює з обома фреймворками

## Вимоги

- iOS 13.0+
- Swift 5.7+
- Xcode 14.0+

## Встановлення

### Swift Package Manager

Додайте залежність у `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Jumaon27848/ios_hamon.git", from: "1.0.0")
]
```

Або в Xcode:  
**File → Add Package Dependencies**  
Вставте URL: `https://github.com/Jumaon27848/ios_hamon.git`

## Швидкий старт

### 1. Базове налаштування

```swift
import Hamon
import FirebaseAnalytics

func application(_ application: UIApplication, 
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // Налаштуйте SDK з IP вашого сервера
    Hamon.shared.configure(host: "ваш_ip_сервера")
    
    // Встановіть Firebase App Instance ID як ідентифікатор користувача
    if let appInstanceId = Analytics.appInstanceID() {
      Hamon.shared.setUserId(appInstanceId)
    }
    
    return true
}
```

### 2. Налаштування для SwiftUI

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
        Hamon.shared.configure(host: "ваш_ip_сервера")
        
        if let appInstanceId = Analytics.appInstanceID() {
          Hamon.shared.setUserId(appInstanceId)
        }
    }
}
```

## Використання

### Відстеження подій

```swift
// Проста подія
Hamon.shared.logEvent("screen_open")

// Подія з параметрами
Hamon.shared.logEvent("purchase", parameters: [
    "product_id": "premium_monthly",
    "price": 9.99,
    "currency": "USD"
])

// Складна подія
Hamon.shared.logEvent("level_complete", parameters: [
    "level": 5,
    "score": 1250,
    "time_seconds": 45.5,
    "items_collected": 12
])
```

### Оновлення даних користувача

```swift
// Встановлення Firebase Cloud Messaging токена
if let fcmToken = Messaging.messaging().fcmToken {
    Hamon.shared.setFCM(token: fcmToken)
}

// Встановлення Affise Click ID
Hamon.shared.setAffiseId("affise_click_id_тут")
    
// SDK автоматично оновлює дані користувача:
// - Ім'я пакету (Bundle ID)
// - Версія додатку
// - Версія ОС
// - Модель пристрою
// - Локаль
// - Код країни
// - Advertising ID / IDFV
// - Статус відстеження реклами
```

### Ручне надсилання

```swift
// Примусово надіслати всі буферизовані події
Hamon.shared.flush()

// Очистити чергу подій без надсилання
Hamon.shared.clearQueue()
```

## App Transport Security (ATS)

При використанні HTTP з'єднань необхідно налаштувати ATS в `Info.plist`.

### Варіант 1: Автоматична генерація XML

```swift
// Згенерувати XML для вашого Info.plist
let xml = Hamon.shared.generateInfoPlistConfiguration(host: "ваш_ip_сервера")
print(xml)
```

### Варіант 2: Тест з'єднання

```swift
Hamon.shared.testConnection(host: "ваш_ip_сервера") { success, message in
    if success {
        print("✅ Сервер доступний")
    } else {
        print("❌ Помилка з'єднання: \(message)")
        
        // Отримати конфігурацію ATS якщо потрібно
        let xml = Hamon.shared.generateInfoPlistConfiguration(host: "ваш_ip_сервера")
        print("Додайте це в Info.plist:\n\(xml)")
    }
}
```

### Варіант 3: Ручне налаштування

Додайте в `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>(ваш_ip_сервера)</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### Використання HTTPS

```swift
Hamon.shared.configure(host: "ваш-домен.com", useHTTPS: true)
```

## Дозвіл на відстеження (iOS 14+)

```swift
import AppTrackingTransparency

if #available(iOS 14, *) {
    Hamon.shared.requestTrackingAuthorization { status in
        switch status {
        case .authorized:
            print("Відстеження дозволено")
        case .denied:
            print("Відстеження заборонено")
        case .restricted:
            print("Відстеження обмежено")
        case .notDetermined:
            print("Відстеження не визначено")
        @unknown default:
            break
        }
    }
}
```

Додайте в `Info.plist`:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>Ми використовуємо відстеження для персоналізації вашого досвіду</string>
```

## Як це працює

### Буферизація подій

Події автоматично надсилаються коли:
- Накопичено **10+ подій** у черзі
- Минуло **10 секунд** з першої події
- Додаток переходить у **background**
- Додаток **завершується**

### Шифрування

Всі запити шифруються з використанням:
- **Алгоритм:** AES/CBC/PKCS5Padding
- **Ключ:** Кастомний зворотний ключ
- **Вивід:** Base64(IV + encrypted_data)

### Ідентифікація користувача

Пріоритет:
1. Firebase App Instance ID (рекомендується)
2. Кастомний userId переданий у `configure()`
3. UUID збережений в Keychain

## API Reference

### Конфігурація

```swift
/// Налаштувати SDK з IP сервера
/// - Parameters:
///   - host: IP адреса сервера (напр., "192.168.1.100")
///   - useHTTPS: Використовувати HTTPS протокол (за замовчуванням: false)
///   - userId: Опціональний ідентифікатор користувача
func configure(host: String, useHTTPS: Bool = false, userId: String? = nil)

/// Встановити user ID (рекомендується Firebase App Instance ID)
func setUserId(_ userId: String)

/// Встановити Affise Click ID (інтеграція Affise)
func setAffiseId(_ id: String)

/// Встановити Firebase Cloud Messaging токен
func setFCM(token: String)
```

### Відстеження подій

```swift
/// Логувати аналітичну подію
/// - Parameters:
///   - name: Ім'я події
///   - parameters: Параметри події (опціонально)
func logEvent(_ name: String, parameters: [String: Any] = [:])

/// Примусово надіслати всі буферизовані події
func flush()

/// Очистити чергу подій без надсилання
func clearQueue()
```

### Утиліти

```swift
/// Згенерувати Info.plist XML для конфігурації ATS
func generateInfoPlistConfiguration(host: String) -> String

/// Перевірити з'єднання з сервером
func testConnection(host: String, completion: @escaping (Bool, String) -> Void)
```

## Дані що збираються

SDK автоматично збирає:

| Поле | Опис | Приклад |
|------|------|---------|
| `package` | Bundle identifier | `com.example.app` |
| `app_version` | Версія додатку | `1.0.0` |
| `app_version_code` | Номер збірки | `1` |
| `os_version` | Версія iOS | `17.0` |
| `device_model` | Модель пристрою | `iPhone` |
| `device` | Ідентифікатор пристрою | `iPhone14,2` |
| `build_id` | Версія ядра | `21A123` |
| `locale` | Локаль пристрою | `en_US` |
| `geo` | Код країни | `US` |
| `advertising_id` | IDFA або IDFV | `XXXXXXXX-...` |
| `is_limited_ad_tracking` | Статус відстеження реклами | `false` |
| `firebase_token` | FCM токен | `xxxxx` |
| `app_first_open_timestamp` | Час першого запуску | `1234567890000` |
| `app_last_update_timestamp` | Час останнього оновлення | `1234567890000` |

## Приклади

### E-commerce додаток

```swift
// Перегляд продукту
Hamon.shared.logEvent("product_view", parameters: [
    "product_id": "123",
    "product_name": "Premium Subscription",
    "price": 9.99,
    "currency": "USD"
])

// Додавання в кошик
Hamon.shared.logEvent("add_to_cart", parameters: [
    "product_id": "123",
    "quantity": 1
])

// Покупка
Hamon.shared.logEvent("purchase", parameters: [
    "transaction_id": UUID().uuidString,
    "products": [
        ["id": "123", "name": "Premium", "price": 9.99]
    ],
    "total": 9.99,
    "currency": "USD"
])
Hamon.shared.flush() // Важлива подія - надіслати негайно
```

### Ігровий додаток

```swift
// Початок гри
Hamon.shared.logEvent("game_started", parameters: [
    "level": 1,
    "mode": "single_player"
])

// Завершення рівня
Hamon.shared.logEvent("level_complete", parameters: [
    "level": 1,
    "score": 1500,
    "time_seconds": 120,
    "stars": 3
])

// Досягнення
Hamon.shared.logEvent("achievement_unlocked", parameters: [
    "achievement_id": "first_win",
    "achievement_name": "First Victory"
])
```

### Соціальний додаток

```swift
// Реєстрація
Hamon.shared.logEvent("sign_up", parameters: [
    "method": "email"
])

// Створення посту
Hamon.shared.logEvent("post_created", parameters: [
    "post_type": "photo",
    "has_caption": true,
    "tags_count": 3
])

// Поділитися
Hamon.shared.logEvent("share", parameters: [
    "content_type": "post",
    "share_method": "link"
])
```

## Усунення неполадок

### Події не надсилаються

**Проблема:** Події логуються але не надсилаються на сервер.

**Рішення:**
1. Перевірте чи встановлено `userId`: `Hamon.shared.setUserId()`
2. Перевірте з'єднання з сервером: `Hamon.shared.testConnection()`
3. Перевірте конфігурацію ATS для HTTP
4. Перевірте логи консолі на наявність помилок

### ATS блокує з'єднання

**Проблема:** Помилка -1022 "App Transport Security has blocked a cleartext HTTP"

**Рішення:**
1. Використайте `generateInfoPlistConfiguration()` для отримання XML
2. Додайте згенерований XML в Info.plist
3. Або використайте HTTPS: `configure(host: "...", useHTTPS: true)`

### Firebase App Instance ID недоступний

**Проблема:** Не вдається отримати Firebase App Instance ID.

**Рішення:**
1. Додайте Firebase у ваш проект
2. Додайте `GoogleService-Info.plist`
3. Імпортуйте `FirebaseCore` та викличте `FirebaseApp.configure()`

### Події буферизуються нескінченно

**Проблема:** Події залишаються в черзі без надсилання.

**Рішення:**
- SDK очікує `userId` перед надсиланням подій
- Викличте `Hamon.shared.setUserId()` щоб почати надсилання

## Відлагоджувальне логування

SDK виводить логи з префіксом `[Hamon]`:

```
[Hamon] ✅ userId set: ABC123-DEF456-...
[Hamon] ✅ Event logged: screen_open
[Hamon] ✅ Sent 5 events successfully
[Hamon] ✅ User data updated successfully
[Hamon] ❌ SDK not initialized
[Hamon] ⚠️ Waiting for userId (Firebase App Instance ID)
```

## Найкращі практики

### 1. Ініціалізуйте рано
```swift
// ✅ Добре - в AppDelegate/App.swift
func application(_ application: UIApplication, ...) -> Bool {
    Hamon.shared.configure(host: "...")
}

// ❌ Погано - лінива ініціалізація
func someMethod() {
    Hamon.shared.configure(host: "...")
}
```

### 2. Встановлюйте userId якомога швидше
```swift
// ✅ Добре - отримати Firebase App Instance ID негайно
if let appInstanceId = Analytics.appInstanceID() {
    Hamon.shared.setUserId(appInstanceId)
}
```

### 3. Використовуйте узгоджені імена подій
```swift
// ✅ Добре - узгоджене іменування
Hamon.shared.logEvent("screen_view", parameters: ["screen_name": "Home"])
Hamon.shared.logEvent("screen_view", parameters: ["screen_name": "Profile"])

// ❌ Погано - неузгоджене
Hamon.shared.logEvent("home_opened")
Hamon.shared.logEvent("profile_screen_view")
```

### 4. Надсилайте критичні події
```swift
// ✅ Добре - надіслати важливі події негайно
Hamon.shared.logEvent("purchase", parameters: [...])
Hamon.shared.flush()

// ✅ Добре - звичайні події використовують автоматичне групування
Hamon.shared.logEvent("button_tap", parameters: [...])
```

## Продуктивність

| Метрика | Значення |
|---------|----------|
| Споживання пам'яті | ~1-2 МБ |
| CPU (idle) | <0.1% |
| CPU (batching) | ~1-2% |
| Мережа на пачку | 1-5 КБ |
| Вплив на батарею | Мінімальний |

## Підтримка

- **Issues:** [GitHub Issues](https://github.com/Jumaon27848/ios_hamon/issues)
- **Документація:** [Повна документація](DOCUMENTATION.md)
