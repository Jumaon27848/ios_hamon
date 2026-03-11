# Hamon SDK для iOS

Легкий, безопасный и надежный SDK для аналитики на iOS с шифрованием, буферизацией событий и автоматической отправкой.

![iOS 13.0+](https://img.shields.io/badge/iOS-13.0%2B-blue)
![Swift 5.7+](https://img.shields.io/badge/Swift-5.7%2B-orange)
![SPM](https://img.shields.io/badge/SPM-ready-brightgreen)

📖 **Документация:** [English](README.md) • [Русский](README-RU.md) • [Українська](README-UA.md)

## Возможности

✅ **Без зависимостей** - Firebase нужен только для установки User ID  
✅ **AES/CBC шифрование** - Все запросы зашифрованы  
✅ **Автоматическая отправка** - 10 событий или 10 секунд  
✅ **Thread-safe** - Безопасно использовать из любого потока  
✅ **Retry логика** - Автоматический повтор при 5xx ошибках  
✅ **Поддержка background** - Автоматическая отправка при сворачивании  
✅ **Информация об устройстве** - Автоматический сбор данных  
✅ **SwiftUI & UIKit** - Работает с обоими фреймворками

## Требования

- iOS 13.0+
- Swift 5.7+
- Xcode 14.0+

## Установка

### Swift Package Manager

Добавьте зависимость в `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Jumaon27848/ios_hamon.git", from: "1.0.0")
]
```

Или в Xcode:  
**File → Add Package Dependencies**  
Вставьте URL: `https://github.com/Jumaon27848/ios_hamon.git`

## Быстрый старт

### 1. Базовая настройка

```swift
import Hamon
import FirebaseAnalytics

func application(_ application: UIApplication, 
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // Настройте SDK с IP вашего сервера
    Hamon.shared.configure(host: "ваш_ip_сервера")
    
    // Установите Firebase App Instance ID как идентификатор пользователя
    if let appInstanceId = Analytics.appInstanceID() {
      Hamon.shared.setUserId(appInstanceId)
    }
    
    return true
}
```

### 2. Настройка для SwiftUI

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

## Использование

### Отслеживание событий

```swift
// Простое событие
Hamon.shared.logEvent("screen_open")

// Событие с параметрами
Hamon.shared.logEvent("purchase", parameters: [
    "product_id": "premium_monthly",
    "price": 9.99,
    "currency": "USD"
])

// Сложное событие
Hamon.shared.logEvent("level_complete", parameters: [
    "level": 5,
    "score": 1250,
    "time_seconds": 45.5,
    "items_collected": 12
])
```

### Обновление данных пользователя

```swift
// Установка Firebase Cloud Messaging токена
if let fcmToken = Messaging.messaging().fcmToken {
    Hamon.shared.setFCM(token: fcmToken)
}

// Установка Affise Click ID
Hamon.shared.setAffiseId("affise_click_id_здесь")

// Установка Promo Code
Hamon.shared.setPromoCode("promo_code_here")

// SDK автоматически обновляет данные пользователя:
// - Apple ID (App Store ID из Info.plist)
// - Версия приложения
// - Версия ОС
// - Модель устройства
// - Локаль
// - Код страны
// - Advertising ID / IDFV
// - Статус отслеживания рекламы
```

### Ручная отправка

```swift
// Принудительно отправить все буферизованные события
Hamon.shared.flush()

// Очистить очередь событий без отправки
Hamon.shared.clearQueue()
```

## Обязательная конфигурация Info.plist

Добавьте ваш App Store ID в `Info.plist` — **обязательно** для отправки данных пользователя:

```xml
<key>AppStoreID</key>
<string>1234567890</string>
```

> Если `AppStoreID` не задан, SDK логирует ошибку и пропускает все обновления данных пользователя.

## App Transport Security (ATS)

При использовании HTTP соединений необходимо настроить ATS в `Info.plist`.

### Вариант 1: Автоматическая генерация XML

```swift
// Сгенерировать XML для вашего Info.plist
let xml = Hamon.shared.generateInfoPlistConfiguration(host: "ваш_ip_сервера")
print(xml)
```

### Вариант 2: Тест соединения

```swift
Hamon.shared.testConnection(host: "ваш_ip_сервера") { success, message in
    if success {
        print("✅ Сервер доступен")
    } else {
        print("❌ Ошибка соединения: \(message)")
        
        // Получить конфигурацию ATS если нужно
        let xml = Hamon.shared.generateInfoPlistConfiguration(host: "ваш_ip_сервера")
        print("Добавьте это в Info.plist:\n\(xml)")
    }
}
```

### Вариант 3: Ручная настройка

Добавьте в `Info.plist`:

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

### Использование HTTPS

```swift
Hamon.shared.configure(host: "ваш-домен.com", useHTTPS: true)
```

## Разрешение на отслеживание (iOS 14+)

```swift
import AppTrackingTransparency

if #available(iOS 14, *) {
    Hamon.shared.requestTrackingAuthorization { status in
        switch status {
        case .authorized:
            print("Отслеживание разрешено")
        case .denied:
            print("Отслеживание запрещено")
        case .restricted:
            print("Отслеживание ограничено")
        case .notDetermined:
            print("Отслеживание не определено")
        @unknown default:
            break
        }
    }
}
```

Добавьте в `Info.plist`:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>Мы используем отслеживание для персонализации вашего опыта</string>
```

## Как это работает

### Буферизация событий

События автоматически отправляются когда:
- Накоплено **10+ событий** в очереди
- Прошло **10 секунд** с первого события
- Приложение переходит в **background**
- Приложение **завершается**

### Шифрование

Все запросы шифруются с использованием:
- **Алгоритм:** AES/CBC/PKCS5Padding
- **Ключ:** Кастомный обратный ключ
- **Вывод:** Base64(IV + encrypted_data)

### Идентификация пользователя

Приоритет:
1. Firebase App Instance ID (рекомендуется)
2. Кастомный userId переданный в `configure()`
3. UUID сохраненный в Keychain

## API Reference

### Конфигурация

```swift
/// Настроить SDK с IP сервера
/// - Parameters:
///   - host: IP адрес сервера (напр., "192.168.1.100")
///   - useHTTPS: Использовать HTTPS протокол (по умолчанию: false)
///   - userId: Опциональный идентификатор пользователя
func configure(host: String, useHTTPS: Bool = false, userId: String? = nil)

/// Установить user ID (рекомендуется Firebase App Instance ID)
func setUserId(_ userId: String)

/// Установить Affise Click ID (интеграция Affise)
func setAffiseId(_ id: String)

/// Установить Firebase Cloud Messaging токен
func setFCM(token: String)
```

### Отслеживание событий

```swift
/// Логировать аналитическое событие
/// - Parameters:
///   - name: Имя события
///   - parameters: Параметры события (опционально)
func logEvent(_ name: String, parameters: [String: Any] = [:])

/// Принудительно отправить все буферизованные события
func flush()

/// Очистить очередь событий без отправки
func clearQueue()
```

### Утилиты

```swift
/// Сгенерировать Info.plist XML для конфигурации ATS
func generateInfoPlistConfiguration(host: String) -> String

/// Проверить соединение с сервером
func testConnection(host: String, completion: @escaping (Bool, String) -> Void)
```

## Собираемые данные

SDK автоматически собирает:

| Поле | Описание | Пример |
|------|----------|--------|
| `package` | App Store ID (из `AppStoreID` в Info.plist) | `1234567890` |
| `app_version` | Версия приложения | `1.0.0` |
| `app_version_code` | Номер сборки | `1` |
| `os_version` | Версия iOS | `17.0` |
| `device_model` | Модель устройства | `iPhone` |
| `device` | Идентификатор устройства | `iPhone14,2` |
| `build_id` | Версия ядра | `21A123` |
| `locale` | Локаль устройства | `en_US` |
| `geo` | Код страны | `US` |
| `advertising_id` | IDFA или IDFV | `XXXXXXXX-...` |
| `is_limited_ad_tracking` | Статус отслеживания рекламы | `false` |
| `firebase_token` | FCM токен | `xxxxx` |
| `app_first_open_timestamp` | Время первого запуска | `1234567890000` |
| `app_last_update_timestamp` | Время последнего обновления | `1234567890000` |

## Примеры

### E-commerce приложение

```swift
// Просмотр продукта
Hamon.shared.logEvent("product_view", parameters: [
    "product_id": "123",
    "product_name": "Premium Subscription",
    "price": 9.99,
    "currency": "USD"
])

// Добавление в корзину
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
Hamon.shared.flush() // Важное событие - отправить немедленно
```

### Игровое приложение

```swift
// Начало игры
Hamon.shared.logEvent("game_started", parameters: [
    "level": 1,
    "mode": "single_player"
])

// Завершение уровня
Hamon.shared.logEvent("level_complete", parameters: [
    "level": 1,
    "score": 1500,
    "time_seconds": 120,
    "stars": 3
])

// Достижение
Hamon.shared.logEvent("achievement_unlocked", parameters: [
    "achievement_id": "first_win",
    "achievement_name": "First Victory"
])
```

### Социальное приложение

```swift
// Регистрация
Hamon.shared.logEvent("sign_up", parameters: [
    "method": "email"
])

// Создание поста
Hamon.shared.logEvent("post_created", parameters: [
    "post_type": "photo",
    "has_caption": true,
    "tags_count": 3
])

// Поделиться
Hamon.shared.logEvent("share", parameters: [
    "content_type": "post",
    "share_method": "link"
])
```

## Устранение неполадок

### События не отправляются

**Проблема:** События логируются но не отправляются на сервер.

**Решение:**
1. Проверьте установлен ли `userId`: `Hamon.shared.setUserId()`
2. Проверьте соединение с сервером: `Hamon.shared.testConnection()`
3. Проверьте конфигурацию ATS для HTTP
4. Проверьте логи консоли на наличие ошибок

### ATS блокирует соединение

**Проблема:** Ошибка -1022 "App Transport Security has blocked a cleartext HTTP"

**Решение:**
1. Используйте `generateInfoPlistConfiguration()` для получения XML
2. Добавьте сгенерированный XML в Info.plist
3. Или используйте HTTPS: `configure(host: "...", useHTTPS: true)`

### Firebase App Instance ID недоступен

**Проблема:** Не удается получить Firebase App Instance ID.

**Решение:**
1. Добавьте Firebase в ваш проект
2. Добавьте `GoogleService-Info.plist`
3. Импортируйте `FirebaseCore` и вызовите `FirebaseApp.configure()`

### AppStoreID не настроен

**Проблема:** Данные пользователя не отправляются на сервер.

**Решение:**
Добавьте `AppStoreID` в `Info.plist`:
```xml
<key>AppStoreID</key>
<string>ВАШ_APP_STORE_ID</string>
```

### События буферизуются бесконечно

**Проблема:** События остаются в очереди без отправки.

**Решение:**
- SDK ожидает `userId` перед отправкой событий
- Вызовите `Hamon.shared.setUserId()` чтобы начать отправку

## Отладочное логирование

SDK выводит логи с префиксом `[Hamon]`:

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

## Лучшие практики

### 1. Инициализируйте рано
```swift
// ✅ Хорошо - в AppDelegate/App.swift
func application(_ application: UIApplication, ...) -> Bool {
    Hamon.shared.configure(host: "...")
}

// ❌ Плохо - ленивая инициализация
func someMethod() {
    Hamon.shared.configure(host: "...")
}
```

### 2. Устанавливайте userId как можно скорее
```swift
// ✅ Хорошо - получить Firebase App Instance ID немедленно
if let appInstanceId = Analytics.appInstanceID() {
    Hamon.shared.setUserId(appInstanceId)
}
```

### 3. Используйте согласованные имена событий
```swift
// ✅ Хорошо - согласованное именование
Hamon.shared.logEvent("screen_view", parameters: ["screen_name": "Home"])
Hamon.shared.logEvent("screen_view", parameters: ["screen_name": "Profile"])

// ❌ Плохо - несогласованное
Hamon.shared.logEvent("home_opened")
Hamon.shared.logEvent("profile_screen_view")
```

### 4. Отправляйте критичные события
```swift
// ✅ Хорошо - отправить важные события немедленно
Hamon.shared.logEvent("purchase", parameters: [...])
Hamon.shared.flush()

// ✅ Хорошо - обычные события используют автоматическую группировку
Hamon.shared.logEvent("button_tap", parameters: [...])
```

## Производительность

| Метрика | Значение |
|---------|----------|
| Потребление памяти | ~1-2 МБ |
| CPU (idle) | <0.1% |
| CPU (batching) | ~1-2% |
| Сеть на пачку | 1-5 КБ |
| Влияние на батарею | Минимальное |

## Поддержка

- **Issues:** [GitHub Issues](https://github.com/Jumaon27848/ios_hamon/issues)
- **Документация:** [Полная документация](DOCUMENTATION.md)
