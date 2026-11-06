#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- 1. environment checks -------------------------------------------------
[ -d /mnt/c/Users ] || die "请在 WSL2 中运行（/mnt/c/Users 不存在）"

WIN_USER="$(powershell.exe -NoProfile -Command '$env:USERNAME' 2>/dev/null | tr -d '\r\n' || true)"
[ -n "$WIN_USER" ] || die "无法读取 Windows 用户名（powershell.exe 不可用）"
WIN_TOOLS="/mnt/c/Users/$WIN_USER/Tools"

command -v systemctl >/dev/null 2>&1 || die "缺少 systemctl"
systemctl --user show-environment >/dev/null 2>&1 || die "systemd user 实例不可用，请确认 WSL 已启用 systemd"

say "Windows 用户: $WIN_USER"
say "Windows 工具目录: $WIN_TOOLS"

if ! command -v parec >/dev/null 2>&1; then
  say ""
  say "缺少 pulseaudio-utils。请先运行："
  say "  sudo apt update && sudo apt install -y pulseaudio-utils"
  die "依赖未满足"
fi

command -v python3 >/dev/null 2>&1 || die "缺少 python3"

if ! python3 -c "import requests" >/dev/null 2>&1; then
  say ""
  say "缺少 Python requests。请先运行："
  say "  sudo apt install -y python3-requests"
  say "或： pip3 install --user requests"
  die "依赖未满足"
fi

# --- 2. API key ------------------------------------------------------------
mkdir -p "$HOME/.config/zhipu"
chmod 700 "$HOME/.config/zhipu"

if [ -s "$HOME/.config/zhipu/asr.key" ]; then
  say "已存在 ~/.config/zhipu/asr.key，保留现有 key（如需更换请先删除该文件）"
else
  printf '请输入智谱 API Key（输入不回显）: '
  read -rs KEY
  printf '\n'
  [ -n "$KEY" ] || die "API Key 不能为空"
  printf '%s' "$KEY" > "$HOME/.config/zhipu/asr.key"
  chmod 600 "$HOME/.config/zhipu/asr.key"
fi

# --- 3. optional proxy -----------------------------------------------------
if [ ! -f "$HOME/.config/zhipu/proxy.env" ]; then
  printf '如需代理访问 open.bigmodel.cn，输入代理地址（如 http://proxy:3128，留空跳过）: '
  read -r PROXY
  if [ -n "$PROXY" ]; then
    cat > "$HOME/.config/zhipu/proxy.env" <<EOF
HTTP_PROXY=$PROXY
HTTPS_PROXY=$PROXY
NO_PROXY=127.0.0.1,localhost,::1
EOF
    chmod 600 "$HOME/.config/zhipu/proxy.env"
    say "已写入 ~/.config/zhipu/proxy.env"
  fi
fi

# --- 4. install files ------------------------------------------------------
mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user" "$HOME/.config/opencode/command" "$WIN_TOOLS"
install -m 755 "$REPO_DIR/src/zhipu-voice-daemon.py" "$HOME/.local/bin/zhipu-voice-daemon.py"
install -m 644 "$REPO_DIR/templates/inject-text.ps1" "$WIN_TOOLS/inject-text.ps1"

sed "s|__WIN_USER__|$WIN_USER|g" \
  "$REPO_DIR/templates/zhipu-voice.service.in" \
  > "$HOME/.config/systemd/user/zhipu-voice.service"

install -m 644 "$REPO_DIR/templates/xiaomi-RC.md" \
  "$HOME/.config/opencode/command/xiaomi-RC.md"

# --- 5. start --------------------------------------------------------------
systemctl --user daemon-reload
systemctl --user enable --now zhipu-voice.service
sleep 2

if systemctl --user is-active --quiet zhipu-voice.service; then
  say "服务已启动: zhipu-voice.service"
else
  say "服务启动失败，请查看："
  say "  systemctl --user status zhipu-voice.service"
  say "  tail -20 /tmp/zhipu-daemon.log"
fi

# --- 6. linger -------------------------------------------------------------
if loginctl show-user "$USER" -p Linger 2>/dev/null | grep -q "Linger=yes"; then
  say "linger 已启用（WSL 重启后会自动启动服务）"
else
  say "建议启用 linger："
  say "  sudo loginctl enable-linger $USER"
fi

say ""
say "安装完成。还需要手动完成："
say "  1. Axonkey 里把遥控器「语音键」设为「禁用」"
say "  2. Windows 声音设置里默认输入选 Quarbor Virtual Microphone"
say "  3. 按住遥控器语音键说话，松开后文字会进入终端"
say "  4. opencode 里输入 /xiaomi-RC 可随时检查服务"
