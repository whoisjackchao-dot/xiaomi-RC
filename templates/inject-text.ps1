$ErrorActionPreference = "Stop"

$path = Join-Path $PSScriptRoot "voice-text.txt"
if (-not (Test-Path -LiteralPath $path)) { exit 0 }

$text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
if ([string]::IsNullOrEmpty($text)) { exit 0 }

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class KB {
    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT { public uint type; public InputUnion u; }

    [StructLayout(LayoutKind.Explicit)]
    public struct InputUnion {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
        [FieldOffset(0)] public HARDWAREINPUT hi;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Sequential)]
    public struct HARDWAREINPUT { public uint uMsg; public ushort wParamL; public ushort wParamH; }

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    const uint INPUT_KEYBOARD = 1;
    const uint KEYEVENTF_UNICODE = 0x0004;
    const uint KEYEVENTF_KEYUP = 0x0002;

    public static void Type(string s) {
        int size = Marshal.SizeOf(typeof(INPUT));
        foreach (char c in s) {
            INPUT down = new INPUT();
            down.type = INPUT_KEYBOARD;
            down.u.ki = new KEYBDINPUT { wVk = 0, wScan = (ushort)c, dwFlags = KEYEVENTF_UNICODE, time = 0, dwExtraInfo = IntPtr.Zero };
            SendInput(1, new INPUT[] { down }, size);

            INPUT up = new INPUT();
            up.type = INPUT_KEYBOARD;
            up.u.ki = new KEYBDINPUT { wVk = 0, wScan = (ushort)c, dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP, time = 0, dwExtraInfo = IntPtr.Zero };
            SendInput(1, new INPUT[] { up }, size);
        }
    }
}
"@

[KB]::Type($text)
