#Requires AutoHotkey v2.0
#SingleInstance Force

; ==================== 配置区 ====================
; 输入法配置 - 使用输入法语言代码
; 代码: 0x0804 (中文简体), 0x0409 (英文美国)，0x0411（日语）

config := Map(
    ; 默认输入法
    "default_ime", 0x0409,

    ; 进程规则 - 进程名(小写) => 输入法代码
    "process_rules", Map(
        "Zed.exe", 0x0409,           ; VSCode -> English
        "chrome.exe", 0x0804,         ; Chrome -> Chinese
        "wechat.exe", 0x0804,         ; WeChat -> Chinese
        "Telegram.exe", 0x0804,         ; IntelliJ -> English
    ),

    ; 快捷键规则 - 快捷键 => 输入法代码
    ; 修饰键: # (Win), ! (Alt), ^ (Ctrl), + (Shift)
    "hotkey_rules", Map(
        "#z", 0x0804,                 ; Win+1 -> Chinese
        "#a", 0x0409                  ; Win+2 -> English
    ),

    ; 窗口记忆规则 - 哪些进程启用窗口记忆
    ; 空数组 [] 表示对所有进程启用
    ; 否则只对列表中的进程启用窗口记忆
    "remember_processes", ["chrome.exe"]  ; 例如: ["code.exe", "chrome.exe"]
)

; ==================== 核心功能 ====================

; 窗口输入法记忆 Map
window_ime_memory := Map()

; 获取当前窗口的输入法
GetCurrentIME() {
    try {
        hwnd := WinExist("A")
        threadId := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
        inputLocale := DllCall("GetKeyboardLayout", "UInt", threadId, "Ptr")
        return inputLocale & 0xFFFF
    }
    return 0
}

; 设置输入法
SetIME(ime_code) {
    try {
        hwnd := WinExist("A")
        ; 发送 WM_INPUTLANGCHANGEREQUEST 消息
        PostMessage(0x50, 0, ime_code, , "ahk_id " hwnd)
        return true
    }
    return false
}

; 获取当前窗口的进程名
GetActiveProcessName() {
    try {
        processName := WinGetProcessName("A")
        return StrLower(processName)
    }
    return ""
}

; 判断当前进程是否启用窗口记忆
ShouldRememberIME(processName) {
    remember_list := config["remember_processes"]

    ; 如果是空数组，对所有进程启用
    if remember_list.Length == 0
        return true

    ; 否则检查进程是否在列表中
    for process in remember_list {
        if StrLower(process) == processName
            return true
    }

    return false
}

; 根据规则切换输入法
SwitchIMEByRule() {
    processName := GetActiveProcessName()
    if !processName
        return

    hwnd := WinExist("A")
    should_remember := ShouldRememberIME(processName)

    if should_remember {
        if window_ime_memory.Has(hwnd) {
            target_ime := window_ime_memory[hwnd]
            SetIME(target_ime)
            return
        }
    }

    if config["process_rules"].Has(processName) {
        target_ime := config["process_rules"][processName]
        SetIME(target_ime)

        if should_remember {
            window_ime_memory[hwnd] := target_ime
        }
        return
    }

    SetIME(config["default_ime"])
}

; 窗口切换时自动执行
; 使用 SetTimer 定期检测活动窗口变化
last_hwnd := 0
CheckActiveWindow() {
    global last_hwnd
    current_hwnd := WinExist("A")

    if current_hwnd != last_hwnd && current_hwnd != 0 {
        last_hwnd := current_hwnd
        SwitchIMEByRule()
    }
}

ManualSetIME(target_ime) {
    SetIME(target_ime)

    processName := GetActiveProcessName()
    if !processName
        return
    should_remember := ShouldRememberIME(processName)
    if should_remember {
        hwnd := WinExist("A")
        window_ime_memory[hwnd] := target_ime
    }
}

; ==================== 注册快捷键 ====================
for hotkey_str, ime_code in config["hotkey_rules"] {
    ((target_ime) => Hotkey(hotkey_str, (*) => ManualSetIME(target_ime)))(ime_code)
}

; ==================== 启动 ====================
; 开始监控窗口切换 (每100ms检查一次)
SetTimer(CheckActiveWindow, 100)

; 启动时切换到默认输入法
SetIME(config["default_ime"])
