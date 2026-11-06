---
description: 启动/检查小米遥控器语音服务（zhipu-voice），用于 RC003 语音输入
agent: build
---

# /xiaomi-RC — 启动小米遥控器语音服务

服务状态：

!`systemctl --user enable --now zhipu-voice.service; systemctl --user is-active zhipu-voice.service; pgrep -af "[z]hipu-voice-daemon" || true`

根据上面的输出处理：

- **`active` 且有 `zhipu-voice-daemon.py` 进程**：回复「小米遥控器语音服务已启动」，并附一句用法：按住遥控器语音键说话，松开后文字会自动进入终端输入框。
- **未启动或进程缺失**：执行 `systemctl --user restart zhipu-voice.service`，等待 2 秒后再查 `systemctl --user is-active`；若仍失败，读取 `systemctl --user status zhipu-voice.service` 和 `tail -20 /tmp/zhipu-daemon.log`，报告具体错误。
- 不要修改 `~/.config/zhipu/proxy.env` 或 service 文件，除非用户明确要求。
