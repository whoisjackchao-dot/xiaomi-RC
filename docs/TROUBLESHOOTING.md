# 排障

## 服务没启动

```bash
systemctl --user status zhipu-voice.service
tail -30 /tmp/zhipu-daemon.log
```

常见原因：

| 日志/现象 | 处理 |
|---|---|
| `parec: command not found` | `sudo apt install -y pulseaudio-utils` |
| `ModuleNotFoundError: requests` | `sudo apt install -y python3-requests` |
| `Connection refused` / 卡住 | 检查 `~/.config/zhipu/proxy.env` 是否需要代理 |
| `asr error ... 401` | API Key 无效或过期，重新获取并更新 `~/.config/zhipu/asr.key` |
| `asr error ... 429` | 触发限流，稍后重试 |
| `speech start` 不出现 | 默认录音设备不是 `Quarbor Virtual Microphone`，或 Axonkey 没在转发音频 |

## 有 `speech start` 但没有文字

1. 看日志里是否有 `text:` 行
   - 没有 → ASR 请求失败，检查网络/代理/Key
   - 有 → 注入失败，检查 `inject-text.ps1` 是否存在、终端是否在前台
2. 手动测试注入：
   ```bash
   printf '测试注入' > /mnt/c/Users/<你>/Tools/voice-text.txt
   /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe \
     -NoProfile -ExecutionPolicy Bypass \
     -File 'C:\Users\<你>\Tools\inject-text.ps1'
   ```

## 录音是静音

1. Windows 声音设置 → 输入 → 默认设备选 `Quarbor Virtual Microphone`
2. 确认 Axonkey 正在运行，且日志里有 `RC003 voice forwarding started`
3. 按住语音键时才会转发音频，松手后停止
4. 检查 WSL 源：
   ```bash
   pactl list short sources
   # 应看到 RDPSource
   ```

## 服务重启后不自动启动

```bash
loginctl show-user "$USER" -p Linger
# 若不是 Linger=yes：
sudo loginctl enable-linger "$USER"
```

## opencode 里没有 `/xiaomi-RC`

命令文件应位于：

```
~/.config/opencode/command/xiaomi-RC.md
```

重启 opencode 刷新命令列表。

## 如何完全卸载

```bash
bash uninstall.sh
```
