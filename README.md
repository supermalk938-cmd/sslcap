# Twiks_ssl — iOS tweak для перехоплення HTTPS-запитів

> Власний tweak на iPhone 7 (jailbreak) для MITM/дампу запитів
> Instagram / Gmail / Facebook — без Frida, повністю на tweak-рівні.
> Аналог нашого Android-стеку (LSPosed + castlemod + Mirage), але для iOS.

---

## Чому так, а не Frida

| | Frida | Наш tweak (цей проєкт) |
|---|---|---|
| Запуск | треба щоразу запускати `frida-server` | tweak стартує САМ разом з apk |
| Переживає ребут | ні (крім rootful + launchctl-плist вручну) | так (при rootful jb) |
| Детект | `/usr/sbin/frida-server`, порт 27042, `frida-agent.dylib` у dyld | ховається через Shadow + Choicy, виглядає як stock |
| Scope | — (глобально на всьому) | тільки Gmail/IG/FB через Choicy |
| Стабільність | рветься при pokes з багатьох скриптів | ElleKit = native MobileSubstrate, стабільно |

Той самий шлях пройшли на Android: починали з Frida → перейшли на LSPosed-модулі. Тут одразу на ElleKit.

---

## Ціль

**Перехопити HTTPS-трафік Gmail.app на iPhone 7** (iOS 15.5, jailbreak palera1n/rootless), з можливістю:

1. **Дампити** всі запити+відповіді у файл (`/var/mobile/Documents/gmail_dump/*.har`-подібне).
2. **Модифікувати на льоту** (пізніше — для реєстрації, читання кодів).
3. **MITM через ПК** (mitmproxy / HTTP Toolkit) — повна видимість трафіку з Burp-подібним інтерфейсом.

Пізніше — застосувати той самий стек на **com.burbn.instagram** (IPA вже лежить у батьківській папці) і **com.facebook.Facebook**.

---

## Стек (що встановлюємо на iPhone 7)

### Готові tweaks з Sileo (НЕ пишемо самі):
| Tweak | Repo | Навіщо |
|---|---|---|
| **ElleKit** | Procursus (стандартно) | base: substrate-сумісний інжектор |
| **SSL Kill Switch 3** | https://repo.chariz.com / [Opa334 GitHub](https://github.com/opa334/SSLKillSwitch) | ламає cert pinning у BoringSSL (той самий шар, що хукає Frida-script `ios-connect-hook.js`) |
| **Choicy** | https://repo.chariz.com | per-app toggle: tweaks ON тільки для Gmail/IG/FB, не глобально |
| **Shadow (Rootless)** | https://ios.jjolano.me | ховає jailbreak від Gmail/IG (аналог нашого Mirage RootHide) |
| **AppSync Unified** | https://cydia.akemi.ai | дозволяє ставити unsigned IPA (щоб пропатчений IG працював) |

### Наш власний .deb (цей репозиторій):
`com.reger.sslcap` — **один tweak** що:
- Хукає `NSURLSession.dataTaskWithRequest:`, `NSURLSessionWebSocketTask`, `NSURLConnection` (legacy).
- Логує кожен запит+відповідь у JSON-файл.
- (Пізніше) робить `iOS-connect-hook`-like redirect `connect()` → проксі ПК.
- Scope через `.plist` Filter → тільки `com.google.Gmail` (пізніше додамо `com.burbn.instagram`, `com.facebook.Facebook`).

---

## Архітектура

```
┌─────────────────── iPhone 7 (jailbreak) ────────────────────┐
│                                                              │
│   com.google.Gmail.app                                       │
│        │                                                     │
│        │ (запуск → ElleKit вантажить наші .dylib за Filter)  │
│        ▼                                                     │
│   ┌────────────────────────────────────┐                     │
│   │ SSLKillSwitch3.dylib (готовий)     │ ← ламає pinning     │
│   ├────────────────────────────────────┤                     │
│   │ Shadow.dylib (готовий)             │ ← ховає JB          │
│   ├────────────────────────────────────┤                     │
│   │ com.reger.sslcap.dylib (НАШЕ)      │ ← хук NSURLSession  │
│   │   → GmailDumper.m                  │ ← пише dump         │
│   └────────────────────────────────────┘                     │
│        │                                                     │
│   /var/mobile/Documents/gmail_dump/*.json                    │
│        │                                                     │
└────────┼─────────────────────────────────────────────────────┘
         │ SSH / SFTP
         ▼
      ПК (Windows) → парсимо дампи, читаємо коди
         ▲
         │ (опціонально) mitmproxy на 192.168.x.x:8080
         │ Shadowrocket / system-proxy на айфоні → MITM у real-time
         ▼
    HTTP Toolkit / mitmweb → GUI з відкритим трафіком
```

Два незалежні шляхи:
- **Пасивний**: наш tweak сам дампить у файл на айфоні, забираємо по SSH. **Без ПК під час роботи.**
- **Активний MITM**: трафік → проксі ПК → mitmproxy. Потрібен лише коли хочемо бачити в реалі / модифікувати.

---

## Інструменти для розробки (на ПК/WSL)

**⚠️ Theos НЕ запускається напряму на Windows** — тільки на **macOS або Linux/WSL2**.

Варіант під Windows:
```bash
# 1. Встановити WSL2 (Ubuntu) — одноразово
wsl --install -d Ubuntu

# 2. У WSL — встановити Theos + iOS 15 SDK
cd /opt
sudo git clone --recursive https://github.com/theos/theos.git
echo 'export THEOS=/opt/theos' >> ~/.bashrc
# SDK з https://github.com/theos/sdks → iPhoneOS15.5.sdk у $THEOS/sdks/

# 3. Клонувати цей проєкт у WSL
cp -r /mnt/c/Users/Admin/Desktop/Worc/Instagram_ios/Twiks_ssl ~/
cd ~/Twiks_ssl/sslcap
make package FINALPACKAGE=1
```

Результат: `packages/com.reger.sslcap_0.1.0_iphoneos-arm64.deb` → scp на айфон → `dpkg -i` → `killall -9 SpringBoard`.

Альтернатива — [theos-jailed](https://github.com/kabiroberai/theos-jailed) або GitHub Actions з готовим macOS-runner'ом (якщо не хочемо WSL).

---

## Етапи (що робимо)

### ✅ Етап 0 — документація і каркас (цей README)
Структура проєкту, готові tweaks перелічені.

### ⏳ Етап 1 — Hello-world tweak
`sslcap/` — мінімальний Theos-проєкт:
- `Makefile`, `control`, `sslcap.plist`, `Tweak.xm`.
- Хук на `NSURLSession.dataTaskWithRequest:` → `NSLog` URL у syslog.
- Перевірка: ставимо .deb на iPhone → відкриваємо Gmail → `idevicesyslog | grep sslcap` бачить URL.

### ⏳ Етап 2 — Дамп у файл
- `GmailDumper.m` — пише кожен запит у `/var/mobile/Documents/gmail_dump/YYYYMMDD_HHMMSS_<n>.json`:
  ```json
  {"url": "...", "method": "POST", "headers": {...}, "body_b64": "..."}
  ```
- Відповіді: хук `URLSession:dataTask:didReceiveData:`.
- Кореляція request↔response через task-id.

### ⏳ Етап 3 — Scope через Choicy
- `Filter.plist` обмежує tweak тільки на `com.google.Gmail`.
- У Choicy: `Gmail → Tweak Injection: Choosy → лише sslcap + Shadow + SSLKillSwitch3`.

### ⏳ Етап 4 — Активний MITM (connect-hook)
- Опціональний режим з `config.plist`: `ProxyHost`, `ProxyPort`.
- Хук `connect()` через MSHookFunction (як у `ios-connect-hook.js` HTTP Toolkit), редірект сокетів на проксі ПК.
- Потрібен тільки якщо хочемо live MITM замість пост-факторного дампу.

### ⏳ Етап 5 — Розширення на IG/FB
- Додати `com.burbn.instagram` і `com.facebook.Facebook` у Filter.
- IG має власний Tigon-стек (ми вже реверсили — див. `Instagram/tokens/`). NSURLSession-хук покриває тільки HTTP; під Tigon треба буде окремий layer (пізніше).

### ⏳ Етап 6 — Анти-детект
- Shadow активує ховання jb.
- Ховаємо сам tweak від Gmail (не показувати у `dyld_image_names`, `libsslcap.dylib` замінити на безликий `libresolv2.dylib`).

---

## Файли

```
Twiks_ssl/
├── README.md                    ← цей файл
├── sslcap/                      ← Theos-проєкт
│   ├── Makefile
│   ├── control                  ← metadata .deb
│   ├── sslcap.plist             ← Filter (bundle IDs)
│   ├── Tweak.xm                 ← Logos-хуки NSURLSession
│   └── GmailDumper.m            ← дампер у файл (створимо на Етапі 2)
├── scripts/
│   ├── build.sh                 ← викликає make у WSL
│   ├── deploy.sh                ← scp .deb на айфон + dpkg -i
│   └── pull_dumps.sh            ← забирає дампи з айфона по SSH
└── docs/
    ├── build-env-setup.md       ← як завести Theos у WSL крок за кроком
    └── jailbreak-ios15.md       ← як відновити palera1n після ребута
```

---

## Поточний статус

- 📋 Етап 0 — **документація** (ти її читаєш)
- ⏳ Етап 1 — **hello-world tweak** — зараз створюю `sslcap/`.

Далі — скелет Theos-проєкту і тестова збірка у WSL.
