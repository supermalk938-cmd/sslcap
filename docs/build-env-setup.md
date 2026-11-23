# Theos build environment — під Windows через WSL2

Theos **не** збирає на нативному Windows (треба Unix-shell, make, clang+iOS SDK).
Найпростіший шлях — **WSL2 Ubuntu**.

## 1. Встановити WSL2 (одноразово, у PowerShell as admin)
```powershell
wsl --install -d Ubuntu
# → reboot → у Ubuntu створити користувача
```

## 2. У WSL — залежності
```bash
sudo apt update
sudo apt install -y build-essential fakeroot rsync curl perl git \
                    libplist-utils libtinfo5 zip
```

## 3. Theos
```bash
# Клонимо у /opt (щоб $THEOS був коротким)
sudo mkdir -p /opt && sudo chown $USER /opt
git clone --recursive https://github.com/theos/theos.git /opt/theos
echo 'export THEOS=/opt/theos' >> ~/.bashrc
echo 'export PATH=$THEOS/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

## 4. iOS SDK
```bash
cd /opt/theos/sdks
# iPhoneOS 15.5 — під наш iPhone 7.
curl -LO https://github.com/theos/sdks/archive/master.zip
unzip master.zip 'sdks-master/iPhoneOS15.5.sdk/*'
mv sdks-master/iPhoneOS15.5.sdk .
rm -rf master.zip sdks-master
```

## 5. toolchain (ldid + swift-stdlib tools)
Theos сам підтягне `ldid` (sandbox-compatible codesign для пакування .deb).
Нічого робити не треба.

## 6. Перевірка
```bash
cd /mnt/c/Users/Admin/Desktop/Worc/Instagram_ios/Twiks_ssl/sslcap
make package FINALPACKAGE=1
# → packages/com.reger.sslcap_0.1.0_iphoneos-arm64.deb
```

## 7. Деплой на айфон
```bash
export THEOS_DEVICE_IP=192.168.X.Y          # IP iPhone у локальній мережі
export THEOS_DEVICE_PORT=22                 # або 44 для rootless palera1n
make package install   # збирає + scp + dpkg -i + killall SpringBoard
```

Якщо `make install` просить пароль — стандартний iPhone jb SSH root pass = `alpine` (**поміняй його одразу**).

---

## Альтернатива — GitHub Actions
Якщо не хочеш WSL — є [theos/theos-action](https://github.com/theos/theos-action) + macOS-runner. Пушимо репу, actions збирає `.deb`, качаємо артефакт. Повільніше (2-3 хв на збірку), але нуль налаштування локально.
