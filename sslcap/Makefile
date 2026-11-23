#  Theos Makefile for com.reger.sslcap
#  Збирається у WSL/macOS (НЕ у Windows напряму).
#  Налаштування: $THEOS має вказувати на theos, $THEOS_DEVICE_IP на айфон.
#    export THEOS=/opt/theos
#    export THEOS_DEVICE_IP=<ip_iphone>
#    export THEOS_DEVICE_PORT=22   # (або 44 для rootless, або твій SSH-порт)

TARGET := iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = sslcap

# Logos (.xm) — хуки; окремий .m — реалізація дампера (додаємо з Етапу 2).
sslcap_FILES = Tweak.xm
# sslcap_FILES += GmailDumper.m      # <- розкоментувати на Етапі 2

sslcap_CFLAGS = -fobjc-arc
sslcap_FRAMEWORKS = Foundation
sslcap_PRIVATE_FRAMEWORKS =

include $(THEOS_MAKE_PATH)/tweak.mk

# Після install: килим SpringBoard і перезапускаємо Gmail, щоб tweak перезавантажився.
after-install::
	install.exec "killall -9 SpringBoard || true; killall -9 Gmail || true"
