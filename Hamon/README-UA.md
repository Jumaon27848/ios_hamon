# Hamon SDK для iOS

Легкий, безпечний та надійний аналітичний SDK для iOS з шифруванням, буферизацією подій та автоматичним відправленням.

![iOS 13.0+](https://img.shields.io/badge/iOS-13.0%2B-blue)
![Swift 5.7+](https://img.shields.io/badge/Swift-5.7%2B-orange)
![SPM](https://img.shields.io/badge/SPM-ready-brightgreen)

📖 **Документація:** [English](README.md) • [Русский](README-RU.md) • [Українська](README-UA.md)

## Можливості

✅ **Без залежностей** - Firebase Installations потрібен лише для ідентифікації користувача
✅ **AES/CBC шифрування** - Всі запити шифруються  
✅ **Автоматична пакетна відправка** - 10 подій або 2 секунди
✅ **Потокобезпечність** - Безпечно використовувати з будь-якого потоку  
✅ **Retry логіка** - Автоматичний повтор при помилках 5xx  
✅ **Підтримка фону** - Автовідправка при згортанні  
✅ **Дані пристрою** - Автоматичний збір інформації  
✅ **SwiftUI та UIKit** - Працює з обома фреймворками

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

Або через Xcode:  
**File → Add Package Dependencies**  
Вставте URL: `https://github.com/Jumaon27848/ios_hamon.git`

## Швидкий старт

### 1. Базове налаштування

```swift
import Hamon
import FirebaseInstallations

func application(_ application: UIApplication, 
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // Налаштуйте SDK з IP вашого сервера
    Hamon.shared.configure(host: "IP_вашого_сервера")
    
    // Встановіть Firebase Installation ID як ідентифікатор користувача
    Installations.installations().installationID { fid, error in
        if let fid = fid {
            Hamon.shared.setUserId(fid)
        } else if let error = error {
            print("Не вдалося отримати Installation ID: \(error.localizedDescription)")
        }
    }
    
    return true
}
```

### 2. Налаштування для SwiftUI

```swift
import SwiftUI
import Hamon
import FirebaseInstallations

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
        Hamon.shared.configure(host: "IP_вашого_сервера")
        
        Installations.installations().installationID { fid, error in
            if let fid = fid {
                Hamon.shared.setUserId(fid)
            }
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
// Встановити Firebase Cloud Messaging токен
if let fcmToken = Messaging.messaging().fcmToken {
    Hamon.shared.setFCM(token: fcmToken)
}

// SDK автоматично оновлює дані користувача:
// - Bundle ID
// - Версія додатку
// - Версія iOS
// - Модель пристрою
// - Локаль
// - Код країни
// - Advertising ID / IDFV
// - Статус відстеження реклами
```

### Ручне відправлення

```swift
// Примусово відправити всі буферизовані події
Hamon.shared.flush()

// Очистити чергу подій без відправлення
Hamon.shared.clearQueue()
```

## App Transport Security (ATS)

При використанні HTTP-з'єднань необхідно налаштувати ATS у `Info.plist`.

### Варіант 1: Автоматична генерація XML

```swift
// Згенерувати XML для Info.plist
let xml = Hamon.shared.generateInfoPlistConfiguration(host: "IP_вашого_сервера")
print(xml)
```

### Варіант 2: Тест з'єднання

```swift
Hamon.shared.testConnection(host: "IP_вашого_сервера") { success, message in
    if success {
        print("✅ Сервер доступний")
    } else {
        print("❌ Помилка підключення: \(message)")
        
        // Отримати конфігурацію ATS за необхідності
        let xml = Hamon.shared.generateInfoPlistConfiguration(host: "IP_вашого_сервера")
        print("Додайте до Info.plist:\n\(xml)")
    }
}
```

### Варіант 3: Ручне налаштування

Додайте до `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>(IP_вашого_сервера)</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### Використання HTTPS

```swift
Hamon.shared.configure(host: "your-domain.com", useHTTPS: true)
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

Додайте до `Info.plist`:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>Ми використовуємо відстеження для персоналізації вашого досвіду</string>
```

## Як це працює

### Буферизація подій

Події автоматично відправляються коли:
- Накопичено **10+ подій** у черзі
- Минуло **10 секунд** з першої події
- Додаток переходить у **фоновий режим**
- Додаток **завершується**

### Шифрування

Всі запити шифруються використовуючи:
- **Алгоритм:** AES/CBC/PKCS5Padding
- **Ключ:** Кастомний реверсований ключ
- **Результат:** Base64(IV + encrypted_data)

### Ідентифікація користувача

Пріоритет:
1. Firebase Installation ID (рекомендується)
2. Кастомний userId переданий у `configure()`
3. UUID збережений у Keychain

## API Reference

### Конфігурація

```swift
/// Налаштувати SDK з IP сервера
/// - Parameters:
///   - host: IP адреса сервера (наприклад, "192.168.1.100")
///   - useHTTPS: Використовувати HTTPS протокол (за замовчуванням: false)
///   - userId: Опціональний ідентифікатор користувача
func configure(host: String, useHTTPS: Bool = false, userId: String? = nil)

/// Встановити ID користувача (рекомендується Firebase Installation ID)
func setUserId(_ userId: String)

/// Встановити Firebase Cloud Messaging токен
func setFCM(token: String)
```

### Відстеження подій

```swift
/// Записати аналітичну подію
/// - Parameters:
///   - name: Назва події
///   - parameters: Параметри події (опціонально)
func logEvent(_ name: String, parameters: [String: Any] = [:])

/// Примусово відправити всі буферизовані події
func flush()

/// Очистити чергу подій без відправлення
func clearQueue()
```

### Утиліти

```swift
/// Згенерувати XML для Info.plist для налаштування ATS
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
| `locale` | Локаль пристрою | `uk_UA` |
| `geo` | Код країни | `UA` |
| `advertising_id` | IDFA або IDFV | `XXXXXXXX-...` |
| `is_limited_ad_tracking` | Статус відстеження реклами | `false` |
| `firebase_token` | FCM токен | `xxxxx` |
| `app_first_open_timestamp` | Час першого запуску | `1234567890000` |
| `app_last_update_timestamp` | Час останнього оновлення | `1234567890000` |

## Приклади

### E-commerce додаток

```swift
// Перегляд товару
Hamon.shared.logEvent("product_view", parameters: [
    "product_id": "123",
    "product_name": "Преміум підписка",
    "price": 9.99,
    "currency": "USD"
])

// Додавання до кошика
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
Hamon.shared.flush() // Важлива подія - відправити негайно
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
    "achievement_name": "Перша перемога"
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

## Вирішення проблем

### Події не відправляються

**Проблема:** Події записуються, але не відправляються на сервер.

**Рішення:**
1. Перевірте чи встановлено `userId`: `Hamon.shared.setUserId()`
2. Перевірте з'єднання з сервером: `Hamon.shared.testConnection()`
3. Перевірте налаштування ATS для HTTP
4. Перевірте логи в консолі на наявність помилок

### ATS блокує з'єднання

**Проблема:** Помилка -1022 "App Transport Security has blocked a cleartext HTTP"

**Рішення:**
1. Використовуйте `generateInfoPlistConfiguration()` для отримання XML
2. Додайте згенерований XML до Info.plist
3. Або використовуйте HTTPS: `configure(host: "...", useHTTPS: true)`

### Firebase Installation ID недоступний

**Проблема:** Не вдається отримати Firebase Installation ID.

**Рішення:**
1. Додайте Firebase до вашого проєкту
2. Додайте `GoogleService-Info.plist`
3. Імпортуйте `FirebaseCore` та викличте `FirebaseApp.configure()`

### Події буферизуються нескінченно

**Проблема:** Події залишаються в черзі без відправлення.

**Рішення:**
- SDK чекає на `userId` перед відправленням подій
- Викличте `Hamon.shared.setUserId()` для початку відправлення

## Відладочні логи

SDK виводить логи з префіксом `[Hamon]`:

```
[Hamon] ✅ userId set: ABC123-DEF456-...
[Hamon] ✅ Event logged: screen_open
[Hamon] ✅ Sent 5 events successfully
[Hamon] ✅ User data updated successfully
[Hamon] ❌ SDK not initialized
[Hamon] ⚠️ Waiting for userId (Firebase Installation ID)
```

## Найкращі практики

### 1. Ініціалізація на ранньому етапі
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

### 2. Встановлення userId якомога швидше
```swift
// ✅ Добре - отримати Firebase Installation ID одразу
Installations.installations().installationID { fid, _ in
    if let fid = fid {
        Hamon.shared.setUserId(fid)
    }
}
```

### 3. Використання консистентних назв подій
```swift
// ✅ Добре - консистентне іменування
Hamon.shared.logEvent("screen_view", parameters: ["screen_name": "Home"])
Hamon.shared.logEvent("screen_view", parameters: ["screen_name": "Profile"])

// ❌ Погано - непослідовне
Hamon.shared.logEvent("home_opened")
Hamon.shared.logEvent("profile_screen_view")
```

### 4. Відправлення критичних подій
```swift
// ✅ Добре - відправити важливі події негайно
Hamon.shared.logEvent("purchase", parameters: [...])
Hamon.shared.flush()

// ✅ Добре - звичайні події використовують автоматичну пакетну відправку
Hamon.shared.logEvent("button_tap", parameters: [...])
```

## Продуктивність

| Метрика | Значення |
|---------|----------|
| Витрата пам'яті | ~1-2 МБ |
| CPU (спокій) | <0.1% |
| CPU (відправка) | ~1-2% |
| Мережа за пакет | 1-5 КБ |
| Вплив на батарею | Мінімальний |

## Підтримка

- **Проблеми:** [GitHub Issues](https://github.com/Jumaon27848/ios_hamon/issues)
- **Документація:** [Повна документація](DOCUMENTATION.uk.md)
