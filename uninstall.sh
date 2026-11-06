#!/usr/bin/env bash
set -uo pipefail

say() { printf '%s\n' "$*"; }

systemctl --user disable --now zhipu-voice.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/zhipu-voice.service"
systemctl --user daemon-reload 2>/dev/null || true

rm -f "$HOME/.local/bin/zhipu-voice-daemon.py"
rm -f "$HOME/.config/opencode/command/xiaomi-RC.md"

WIN_USER="$(powershell.exe -NoProfile -Command '$env:USERNAME' 2>/dev/null | tr -d '\r\n' || true)"
if [ -n "$WIN_USER" ]; then
  rm -f "/mnt/c/Users/$WIN_USER/Tools/inject-text.ps1"
  rm -f "/mnt/c/Users/$WIN_USER/Tools/voice-text.txt"
fi

say "已卸载服务和程序。"
say "API Key 与代理配置保留在 ~/.config/zhipu/；如需删除："
say "  rm -rf ~/.config/zhipu"
