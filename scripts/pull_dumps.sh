#!/usr/bin/env bash
# Забирає дампи sslcap з iPhone на ПК.
#   wsl bash .../scripts/pull_dumps.sh <iphone_ip> [port]
set -euo pipefail

IP="${1:?usage: pull_dumps.sh <iphone_ip> [port]}"
PORT="${2:-22}"
USER="${SSH_USER:-root}"

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../dumps/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"

echo "→ rsync /var/mobile/Documents/gmail_dump/ → $OUT/"
rsync -av -e "ssh -p $PORT" "$USER@$IP:/var/mobile/Documents/gmail_dump/" "$OUT/" || {
  echo "(нічого немає або tweak ще не писав — очікувано на Етапі 1)"
}
echo "✅ dumps at: $OUT"
