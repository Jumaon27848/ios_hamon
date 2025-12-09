# Hamon SDK для iOS

Легкий, безопасный и надежный аналитический SDK для iOS с шифрованием, буферизацией событий и автоматической отправкой.

![iOS 13.0+](https://img.shields.io/badge/iOS-13.0%2B-blue)
![Swift 5.7+](https://img.shields.io/badge/Swift-5.7%2B-orange)
![SPM](https://img.shields.io/badge/SPM-ready-brightgreen)

📖 **Документация:** [English](README.md) • [Русский](README-RU.md) • [Українська](README-UA.md)

## Возможности

✅ **Нет зависимостей** - Firebase Installations требуется только для идентификации пользователя  
✅ **AES/CBC шифрование** - Все запросы шифруются  
✅ **Автоматическая пакетная отправка** - 10 событий или 2 секунды  
✅ **Потокобезопасность** - Безопасно использовать из любого потока  
✅ **Retry логика** - Автоматический повтор при ошибках 5xx  
✅ **Поддержка фона** - Автоотправка при сворачивании  
✅ **Данные устройства** - Автоматический сбор информации  
✅ **SwiftUI и UIKit** - Работает с обоими фреймворками

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

Или через Xcode:  
**File → Add Package Dependencies**  
Вставьте URL: `https://github.com/Jumaon27848/ios_hamon.git`

## Быстрый старт

### 1. Базовая настройка

```swift
import Hamon
import FirebaseInstallations

func application(_ application: UIApplication, 
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // Настройте SDK с IP вашего сервера
    Hamon.shared.configure(host: "IP_вашего_сервера")
    
    // Установите Firebase Installation ID как идентификатор пользователя
    Installations.installations().installationID { fid, error in
        if let fid = fid {
            Hamon.shared.setUserId(fid)
        } else if let error = error {
            print("Не удалось получить Installation ID: \(error.localizedDescription)")
        }
    }
    
    return true
}
```

### 2. Настройка для SwiftUI

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
        Hamon.shared.configure(host: "IP_вашего_сервера")
        
        Installations.installations().installationID { fid, error in
            if let fid = fid {
                Hamon.shared.setUserId(fid)
            }
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
// Установить Firebase Cloud Messaging токен
if let fcmToken = Messaging.messaging().fcmToken {
    Hamon.shared.setFCM(token: fcmToken)
}

// SDK автоматически обновляет данные пользователя:
// - Bundle ID
// - Версия приложения
// - Версия iOS
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

## App Transport Security (ATS)

При использовании HTTP-соединений необходимо настроить ATS в `Info.plist`.

### Вариант 1: Автоматическая генерация XML

```swift
// Сгенерировать XML для Info.plist
let xml = Hamon.shared.generateInfoPlistConfiguration(host: "IP_вашего_сервера")
print(xml)
```

### Вариант 2: Тест соединения

```swift
Hamon.shared.testConnection(host: "IP_вашего_сервера") { success, message in
    if success {
        print("✅ Сервер доступен")
    } else {
        print("❌ Ошибка подключения: \(message)")
        
        // Получить конфигурацию ATS при необходимости
        let xml = Hamon.shared.generateInfoPlistConfiguration(host: "IP_вашего_сервера")
        print("Добавьте в Info.plist:\n\(xml)")
    }
}
```

### Вариант 3: Ручная настройка

Добавьте в `Info.plist`:

```xml
NSAppTransportSecurity

    NSExceptionDomains
    
        IP_вашего_сервера
        
            NSExceptionAllowsInsecureHTTPLoads
            
        
    

```

### Использование HTTPS

```swift
Hamon.shared.configure(host: "your-domain.com", useHTTPS: true)
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
NSUserTrackingUsageDescription
Мы используем отслеживание для персонализации вашего опыта
```

## Как это работает

### Буферизация событий

События автоматически отправляются когда:
- Накоплено **10+ событий** в очереди
- Прошло **10 секунд** с первого события
- Приложение переходит в **фоновый режим**
- Приложение **завершается**

### Шифрование

Все запросы шифруются используя:
- **Алгоритм:** AES/CBC/PKCS5Padding
- **Ключ:** Кастомный реверсированный ключ
- **Результат:** Base64(IV + encrypted_data)

### Идентификация пользователя

Приоритет:
1. Firebase Installation ID (рекомендуется)
2. Кастомный userId переданный в `configure()`
3. UUID сохраненный в Keychain

## API Reference

### Конфигурация

```swift
/// Настроить SDK с IP сервера
/// - Parameters:
///   - host: IP адрес сервера (например, "192.168.1.100")
///   - useHTTPS: Использовать HTTPS протокол (по умолчанию: false)
///   - userId: Опциональный идентификатор пользователя
func configure(host: String, useHTTPS: Bool = false, userId: String? = nil)

/// Установить ID пользователя (рекомендуется Firebase Installation ID)
func setUserId(_ userId: String)

/// Установить Firebase Cloud Messaging токен
func setFCM(token: String)
```

### Отслеживание событий

```swift
/// Записать аналитическое событие
/// - Parameters:
///   - name: Название события
///   - parameters: Параметры события (опционально)
func logEvent(_ name: String, parameters: [String: Any] = [:])

/// Принудительно отправить все буферизованные события
func flush()

/// Очистить очередь событий без отправки
func clearQueue()
```

### Утилиты

```swift
/// Сгенерировать XML для Info.plist для настройки ATS
func generateInfoPlistConfiguration(host: String) -> String

/// Проверить соединение с сервером
func testConnection(host: String, completion: @escaping (Bool, String) -> Void)
```

## Собираемые данные

SDK автоматически собирает:

| Поле | Описание | Пример |
|------|----------|--------|
| `package` | Bundle identifier | `com.example.app` |
| `app_version` | Версия приложения | `1.0.0` |
| `app_version_code` | Номер сборки | `1` |
| `os_version` | Версия iOS | `17.0` |
| `device_model` | Модель устройства | `iPhone` |
| `device` | Идентификатор устройства | `iPhone14,2` |
| `build_id` | Версия ядра | `21A123` |
| `locale` | Локаль устройства | `ru_RU` |
| `geo` | Код страны | `RU` |
| `advertising_id` | IDFA или IDFV | `XXXXXXXX-...` |
| `is_limited_ad_tracking` | Статус отслеживания рекламы | `false` |
| `firebase_token` | FCM токен | `xxxxx` |
| `app_first_open_timestamp` | Время первого запуска | `1234567890000` |
| `app_last_update_timestamp` | Время последнего обновления | `1234567890000` |

## Примеры

### E-commerce приложение

```swift
// Просмотр товара
Hamon.shared.logEvent("product_view", parameters: [
    "product_id": "123",
    "product_name": "Премиум подписка",
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
    "achievement_name": "Первая победа"
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

## Решение проблем

### События не отправляются

**Проблема:** События записываются, но не отправляются на сервер.

**Решение:**
1. Проверьте установлен ли `userId`: `Hamon.shared.setUserId()`
2. Проверьте соединение с сервером: `Hamon.shared.testConnection()`
3. Проверьте настройку ATS для HTTP
4. Проверьте логи в консоли на наличие ошибок

### ATS блокирует соединение

**Проблема:** Ошибка -1022 "App Transport Security has blocked a cleartext HTTP"

**Решение:**
1. Используйте `generateInfoPlistConfiguration()` для получения XML
2. Добавьте сгенерированный XML в Info.plist
3. Или используйте HTTPS: `configure(host: "...", useHTTPS: true)`

### Firebase Installation ID недоступен

**Проблема:** Не удается получить Firebase Installation ID.

**Решение:**
1. Добавьте Firebase в ваш проект
2. Добавьте `GoogleService-Info.plist`
3. Импортируйте `FirebaseCore` и вызовите `FirebaseApp.configure()`

### События буферизируются бесконечно

**Проблема:** События остаются в очереди без отправки.

**Решение:**
- SDK ждет `userId` перед отправкой событий
- Вызовите `Hamon.shared.setUserId()` для начала отправки

## Отладочные логи

SDK выводит логи с префиксом `[Hamon]`:

```
[Hamon] ✅ userId set: ABC123-DEF456-...
[Hamon] ✅ Event logged: screen_open
[Hamon] ✅ Sent 5 events successfully
[Hamon] ✅ User data updated successfully
[Hamon] ❌ SDK not initialized
[Hamon] ⚠️ Waiting for userId (Firebase Installation ID)
```

## Лучшие практики

### 1. Инициализация на раннем этапе
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

### 2. Установка userId как можно скорее
```swift
// ✅ Хорошо - получить Firebase Installation ID сразу
Installations.installations().installationID { fid, _ in
    if let fid = fid {
        Hamon.shared.setUserId(fid)
    }
}
```

### 3. Использование консистентных названий событий
```swift
// ✅ Хорошо - консистентное именование
Hamon.shared.logEvent("screen_view", parameters: ["screen_name": "Home"])
Hamon.shared.logEvent("screen_view", parameters: ["screen_name": "Profile"])

// ❌ Плохо - непоследовательное
Hamon.shared.logEvent("home_opened")
Hamon.shared.logEvent("profile_screen_view")
```

### 4. Отправка критичных событий
```swift
// ✅ Хорошо - отправить важные события немедленно
Hamon.shared.logEvent("purchase", parameters: [...])
Hamon.shared.flush()

// ✅ Хорошо - обычные события используют автоматическую пакетную отправку
Hamon.shared.logEvent("button_tap", parameters: [...])
```

## Производительность

| Метрика | Значение |
|---------|----------|
| Расход памяти | ~1-2 МБ |
| CPU (покой) | <0.1% |
| CPU (отправка) | ~1-2% |
| Сеть за пакет | 1-5 КБ |
| Влияние на батарею | Минимальное |

## Поддержка

- **Проблемы:** [GitHub Issues](https://github.com/Jumaon27848/ios_hamon/issues)
- **Документация:** [Полная документация](DOCUMENTATION-RU.md)
