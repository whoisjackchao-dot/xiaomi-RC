# xiaomi-RC

用 **小米蓝牙遥控器 2 Pro（RC003-MS）** 在 **WSL + opencode** 里做语音输入。

按住遥控器语音键说话，松开后 2～3 秒，文字自动进入终端输入框。

```
RC003 语音键
  └─ Axonkey（Windows）：ATVV 音频 → Quarbor Virtual Microphone
       └─ WSL daemon（systemd 常驻）：RDPSource 录音 + VAD 裁剪
            └─ 智谱 GLM-ASR-2512
                 └─ SendInput（Unicode）注入前台终端
                      └─ opencode 输入框
```

---

## 你需要重新配置的东西

这个仓库**不包含任何密钥、公司代理、用户名或设备地址**。安装时由你填写或脚本自动检测。

| # | 项目 | 是否必须 | 说明 |
|---|---|---|---|
| 1 | 智谱 API Key | ✅ 必须 | `install.sh` 会提示输入，保存到 `~/.config/zhipu/asr.key`（权限 600），不会进仓库 |
| 2 | 网络代理 | ⚠️ 视网络 | 如果访问 `open.bigmodel.cn` 需要代理，安装时填写；保存在 `~/.config/zhipu/proxy.env` |
| 3 | Windows 用户名 | 自动检测 | 脚本通过 `powershell.exe` 读取；如需手动改，见 `install.sh` 顶部变量 |
| 4 | Axonkey 语音键 | ✅ 必须手动 | 在 Axonkey 里把「语音键」设为 **禁用**，只保留它的音频转发 |
| 5 | RC003 配对 + 驱动 | ✅ 必须 | 系统蓝牙配对 RC003-MS，Axonkey 内安装 `QuarborUniversalKeyboardDriver` |
| 6 | WSL systemd | ✅ 必须 | 需要 `systemctl --user` 可用 |

---

## 前置条件

**Windows**

- Windows 11 x64
- 蓝牙适配器，RC003-MS 已在系统蓝牙中配对（`VID_2717 / PID_32B8`）
- [Axonkey](https://github.com/leowzz/axonkey/releases) 已安装
- Axonkey 内已为 RC003 安装 `QuarborUniversalKeyboardDriver`
- Axonkey 内已安装 `Quarbor Virtual Microphone`（语音链路需要）

**WSL2**

- systemd 已启用（`ps -p 1 -o comm=` 输出 `systemd`）
- `pulseaudio-utils`（`parec` / `pactl`）
- Python 3 + `requests`

`install.sh` 会检查并提示缺失项。

---

## 安装

```bash
git clone https://github.com/whoisjackchao-dot/xiaomi-RC.git
cd xiaomi-RC
bash install.sh
```

安装脚本会：

1. 检测 Windows 用户名和 WSL/Windows 路径
2. 检查 `parec`、`python3`、`requests`，缺失时给出安装命令
3. 提示输入智谱 API Key（隐藏输入）
4. 提示输入代理（可留空）
5. 安装 daemon 到 `~/.local/bin/zhipu-voice-daemon.py`
6. 安装 `inject-text.ps1` 到 `C:\Users\<你>\Tools\`
7. 生成 systemd user service：`~/.config/systemd/user/zhipu-voice.service`
8. 生成 opencode 命令：`~/.config/opencode/command/xiaomi-RC.md`
9. 启动并 enable 服务

---

## Axonkey 配置（必须手动）

1. 打开 Axonkey → 添加 RC003 → 绑定
2. 设备工作区 → 安装 `QuarborUniversalKeyboardDriver`（可能需要重启）
3. 需要语音 → 安装 `Quarbor Virtual Microphone`
4. 进入「映射」→ 选择 **语音键** → 把 **单击** 设为 **禁用**
   - 目的：让语音键只触发 Axonkey 的音频转发，不再触发其他动作
5. 确认 Windows「声音 → 输入」的默认设备是 `Quarbor Virtual Microphone`

> 遥控器按键映射和语音输入是两条独立链路。本项目的语音 daemon 只读取 `Quarbor Virtual Microphone` 的音频，不依赖 Axonkey 的按键映射。

---

## 使用

**语音输入**

1. 按住遥控器语音键
2. 说话
3. 松开
4. 等 2～3 秒，文字进入当前终端输入框

**在 opencode 里启动/检查服务**

```
/xiaomi-RC
```

**手动管理**

```bash
systemctl --user status zhipu-voice.service
systemctl --user restart zhipu-voice.service
tail -20 /tmp/zhipu-daemon.log
```

---

## 文件说明

| 文件 | 作用 |
|---|---|
| `src/zhipu-voice-daemon.py` | 常驻监听：录音 + VAD + 调 ASR + 注入 |
| `templates/inject-text.ps1` | Windows 侧 SendInput Unicode 注入，不依赖输入法 |
| `templates/zhipu-voice.service.in` | systemd user service 模板 |
| `templates/proxy.env.example` | 代理配置示例 |
| `templates/xiaomi-RC.md` | opencode 命令模板 |
| `install.sh` | 安装脚本 |
| `uninstall.sh` | 卸载脚本 |
| `docs/TROUBLESHOOTING.md` | 排障 |

---

## 工作原理

- **录音**：WSLg 的 PulseAudio 把 Windows 默认录音设备暴露为 `RDPSource`，daemon 用 `parec` 持续读取 16 kHz 单声道 PCM。
- **VAD**：峰值超过阈值开始记录，静音 1.5 秒结束，前后留少量余量；单次最长 29 秒（智谱限制 30 秒）。
- **识别**：`POST https://open.bigmodel.cn/api/paas/v4/audio/transcriptions`，模型 `glm-asr-2512`。
- **注入**：文字写入 `C:\Users\<你>\Tools\voice-text.txt`，由 PowerShell 用 `SendInput` + `KEYEVENTF_UNICODE` 输入到前台窗口，不依赖任何输入法。

---

## 已知限制

- RC003 只在**按住语音键**时转发音频，所以交互是“按住说话”。
- 单次录音上限 30 秒（智谱 API 限制）。
- 识别结果可能没有标点。
- 需要 Axonkey 保持运行；Axonkey 退出后语音链路中断。
- 仅验证 Windows 11 + WSL2（Ubuntu）。

---

## 安全说明

- API Key 只保存在 `~/.config/zhipu/asr.key`（600），不写入仓库、不出现在进程命令行。
- 代理地址保存在 `~/.config/zhipu/proxy.env`（600）。
- 仓库内所有路径、用户名、代理、API Key 均已用占位符替换。
- 如果你曾把 Key 发到聊天/日志里，建议在智谱控制台**轮换**。

---

## 致谢

- [Axonkey](https://github.com/leowzz/axonkey) — RC003 按键映射与音频转发
- [智谱 GLM-ASR-2512](https://docs.bigmodel.cn/) — 语音识别
