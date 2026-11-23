#!/usr/bin/env bash
# Білд sslcap.deb у WSL. Запуск з Windows:
#   wsl bash /mnt/c/Users/Admin/Desktop/Worc/Instagram_ios/Twiks_ssl/scripts/build.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$HERE/../sslcap"

: "${THEOS:?Set THEOS=/opt/theos}"

cd "$PROJ"
make clean
make package FINALPACKAGE=1

DEB="$(ls -t packages/*.deb | head -1)"
echo ""
echo "✅ built: $DEB"
echo "   size:  $(du -h "$DEB" | cut -f1)"
