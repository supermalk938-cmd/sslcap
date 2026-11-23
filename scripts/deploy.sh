#!/usr/bin/env bash
# Ставить останній зібраний .deb на iPhone по SSH і перезапускає Gmail.
#   wsl bash .../scripts/deploy.sh <iphone_ip> [ssh_port]
# стандартні порти: 22 (rootful jb), 44 (rootless)
set -euo pipefail

IP="${1:?usage: deploy.sh <iphone_ip> [port]}"
PORT="${2:-22}"
USER="${SSH_USER:-root}"

HERE="$(cd "$(dirname "$0")" && pwd)"
DEB="$(ls -t "$HERE/../sslcap/packages/"*.deb | head -1)"

echo "→ scp $DEB → $USER@$IP:$PORT:/var/root/"
scp -P "$PORT" "$DEB" "$USER@$IP:/var/root/"

NAME="$(basename "$DEB")"
echo "→ dpkg -i /var/root/$NAME"
ssh -p "$PORT" "$USER@$IP" "dpkg -i /var/root/$NAME && killall -9 Gmail 2>/dev/null; echo installed"
