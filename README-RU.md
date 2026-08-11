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

> **Подключаете новое приложение?** [INTEGRATION.md](INTEGRATION.md) — пошаговая инструкция.
> **Обновляетесь с 1.0.5?** [MIGRATION.md](MIGRATION.md) — ломающих изменений нет.

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
// Установка Firebase Cloud Messaging токена — см. «Push-уведомления (FCM токен)» ниже
Hamon.shared.setFCM(token: fcmToken)

// Установка Affise Click ID
Hamon.shared.setAffiseId("affise_click_id_здесь")

// Установка Web Customer ID
Hamon.shared.setWebCustomerId("web_customer_id_здесь")

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

### Push-уведомления (FCM токен)

FCM registration token уходит на сервер в поле `firebase_token`. У SDK нет зависимости от
Firebase, поэтому токен передаёт хост-приложение — дальше SDK кэширует его между запусками
и переотправляет сам, так что достаточно передать значение один раз на токен.

**Без этих трёх вещей Firebase вообще не выдаст токен:**

1. Capability **Push Notifications** в Xcode (entitlement `aps-environment`).
2. **APNs Auth Key (`.p8`)**, залитый в Firebase Console для этого приложения.
3. Вызов **`registerForRemoteNotifications()`** — иначе запрос токена падает с
   `No APNS token specified before fetching FCM Token`. Разрешение на уведомления при этом
   спрашивать **не нужно**: APNs выдаёт device token и без промпта.

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
    application.registerForRemoteNotifications()   // без промпта на уведомления

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

> Делегат надёжнее разового чтения `Messaging.messaging().fcmToken` на старте: колбэк
> срабатывает и когда токен приходит с задержкой (после регистрации в APNs), и при ротации.

### Покупки (`appAccountToken`)

Apple вшивает `appAccountToken` в транзакцию навсегда и возвращает его в App Store Server
Notifications — именно это позволяет бэкенду смэтчить покупку с юзером аналитики. SDK отдаёт
App Instance ID, уже приведённый к формату UUID, которого требует StoreKit.

```swift
import StoreKit
import Hamon

var options: Set<Product.PurchaseOption> = []
if let token = Hamon.shared.appAccountToken {
    options.insert(.appAccountToken(token))
}

let result = try await product.purchase(options: options)
```

Проставлять нужно на **каждой** покупке — подписке, ресабе и разовой. Продления подписки
наследуют токен автоматически.

Конвертация только расставляет дефисы, поэтому бэкенд получает исходный App Instance ID
обратным удалением дефисов:

```
b9660c2a16297c54d42d5a3986c6e6c8  ->  b9660c2a-1629-7c54-d42d-5a3986c6e6c8
```

> **Важно:** Firebase App Instance ID пересоздаётся при переустановке и при
> `resetAnalyticsData()`, поэтому `appAccountToken` отличается между инсталлами и не склеит
> юзера через переустановку. У текущих подписчиков токен задним числом не появится — только
> у покупок, совершённых после релиза.

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

Идентификатор — вместе с FCM токеном, Affise Click ID, промокодом и Web Customer ID —
кэшируется в `UserDefaults` и восстанавливается при следующем запуске. Благодаря этому
холодный старт отправляет уже известные значения, а не затирает их на сервере `null`, пока
ждёт, что хост-приложение передаст их заново.

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

/// Установить Web Customer ID (связывание web-to-app пользователя)
func setWebCustomerId(_ id: String)

/// Установить Firebase Cloud Messaging токен
func setFCM(token: String)

/// Зафиксировать решение по GDPR. По умолчанию .unknown, поле никогда не бывает null.
/// Невалидные значения в String-перегрузке игнорируются — прежнее решение сохраняется.
func setGdprConsent(_ status: Hamon.GdprConsent)   // .accepted / .rejected / .unknown
func setGdprConsent(_ status: String)

/// Установить AppsFlyer device ID. Липкое значение — однажды записанное не стирается.
func setAppsFlyerId(_ id: String)
```

### Воронка пейволла

```swift
/// Первый вызов защёлкивает time_to_paywall и замораживает три счётчика ниже.
func notifyPaywallOpened()

/// Первый вызов после notifyPaywallOpened защёлкивает paywall_conversion_time
/// (микросекунды). Игнорируется, если пейволл не был заявлен — задним числом не восстановить.
func notifyPurchaseStarted()

/// Первый вызов после notifyPurchaseStarted защёлкивает click_to_pay_time (целые секунды).
func notifyPurchaseCompleted()

/// Счётчики, замораживаются первым notifyPaywallOpened(). Ноль уезжает как 0, не как null.
func notifyUserAction()
func notifyInterstitialShown()
func notifyAoaShown()

/// Включить сбор taps_count_first_30s. Свизлит UIWindow.sendEvent(_:), поэтому выключено
/// по умолчанию — перехват процессный и может конфликтовать с другими SDK.
func enableTapTracking()
```

Порядок важен. `notifyPurchaseStarted()` до `notifyPaywallOpened()` молча теряется и
**не** восстанавливается более поздним сигналом о пейволле; то же с
`notifyPurchaseCompleted()` до начатой покупки. Все поля защёлкиваются один раз и
переживают перезапуск приложения.

### Идентификация

```swift
/// Идентификатор, который отправляется в Hamon (Firebase App Instance ID, если не
/// передан кастомный). Восстанавливается между запусками автоматически.
var userId: String? { get }

/// `userId` в формате RFC 4122, которого требует StoreKit для `appAccountToken`.
/// nil, если id не задан или не является 32 hex-символами.
var appAccountToken: UUID? { get }

/// Приводит Firebase App Instance ID (32 hex-символа) к виду 8-4-4-4-12.
/// Только дефисы — сами символы не меняются, конвертация обратима.
static func appAccountToken(from appInstanceID: String) -> UUID?
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
| `connection_type` | `wifi`, `cellular` или `none` | `wifi` |
| `screen_resolution` | Размер экрана в пикселях | `1179x2556` |
| `ram_total_bytes` | Установленная RAM, байты | `6442450944` |
| `manufacturer` / `brand` | На iOS всегда `Apple` | `Apple` |
| `storage_total` / `storage_free` | Ёмкость тома, байты | `128000000000` |
| `hamon_version` | Версия SDK | `1.1.0` |

Задаются хост-приложением:

| Поле | Метод | Пример |
|------|-------|--------|
| `web_customer_id` | `setWebCustomerId(_:)` | `abc123` |
| `affise_clickid` / `affise_promo_code` | `setAffiseId(_:)` / `setPromoCode(_:)` | `xxxxx` |
| `gdpr_consent_status` | `setGdprConsent(_:)`, по умолчанию `unknown` | `accepted` |
| `appsflyer_id` | `setAppsFlyerId(_:)` | `1234567890-1234567` |

Поведенческие метрики — см. [Воронка пейволла](#воронка-пейволла):

| Поле | Смысл | Единица |
|------|-------|---------|
| `session_length_first` | Первая сессия на переднем плане | **миллисекунды** |
| `taps_count_first_30s` | Тапы за первые 30 с (по opt-in) | штуки |
| `time_to_paywall` | Первый запуск → первый пейволл | **миллисекунды** |
| `actions_before_paywall` | Вызовов `notifyUserAction()` до пейволла | штуки |
| `inters_shown_before_paywall` | Интерстишлов до пейволла | штуки |
| `aoa_shown_before_paywall` | App Open Ads до пейволла | штуки |
| `paywall_conversion_time` | Пейволл → нажатие «купить» | **микросекунды** |
| `click_to_pay_time` | Нажатие «купить» → покупка выдана | **целые секунды**, вниз |

> ⚠️ `paywall_conversion_time` и `click_to_pay_time` стоят рядом, оба заканчиваются на
> `_time`, а единицы различаются в 10⁶ раз. Имена на проводе об этом не говорят. Значения
> совпадают со схемой Android — не «нормализуйте» ни одно из них.

> **На iOS не собирается:** `carrier`. `CTCarrier` задепрекейчен в iOS 16 и с 16.4
> возвращает заглушку `"--"`, замены Apple не дала — поэтому ключ отсутствует в payload,
> а не заполняется фиктивным значением.

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
