#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook true
#MaxThreadsPerHotkey 1
Persistent

if A_Args.Length > 0 && A_Args[1] = "--check"
    ExitApp

; ==================== Input method switcher ====================

config := Map(
    ; 规则 1: 默认输入法，未命中规则 2、3 时使用
    "default_ime", 0x0409,

    ; 规则 2: 记忆哪些进程的输入法状态，空数组表示全部
    "remember_processes", [],

    ; 规则 3: 固定输入法，这些进程每次聚焦都强制切换，记忆无效
    "pinned_ime", Map(
        "chrome.exe", 0x0804,
        "wechat.exe", 0x0804,
        "simplenote.exe", 0x0804,
        "qq.exe", 0x0804,
        "telegram.exe", 0x0804,
    ),

    "hotkey_rules", Map(
        "#z", 0x0804,
        "#a", 0x0409
    ),

    ; 忽略窗口 - 这些窗口抢到焦点时不切换输入法，也不更新 last_hwnd
    ; 按窗口类忽略（不限进程）
    "ignore_classes", [
        "Shell_TrayWnd",                    ; 任务栏
        "Shell_SecondaryTrayWnd",
        "NotifyIconOverflowWindow",         ; 隐藏图标浮窗
        "TopLevelWindowForOverflowXamlIsland",
        "TaskListThumbnailWnd",             ; 任务栏缩略图预览
        "MultitaskingViewFrame",            ; Win+Tab 任务视图
        "XamlExplorerHostIslandWindow",     ; Win11 任务视图/开始菜单
        "Windows.UI.Core.CoreWindow",       ; 各类 Flyout
        "ForegroundStaging",                ; 前台切换临时窗口
        "Progman", "WorkerW",               ; 桌面
        "#32768"                            ; 弹出菜单
    ],

    ; 按进程忽略（不限窗口类）
    "ignore_processes", [
        "shellexperiencehost.exe",
        "startmenuexperiencehost.exe",
        "searchhost.exe",
        "textinputhost.exe"                 ; 输入法候选窗
    ]
)

window_ime_memory := Map()

; ==================== 诊断日志 ====================
log_file := A_ScriptDir "\main.log"

Log(msg) {
    global log_file
    try FileAppend(FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss.") SubStr(Format("{:03}", A_MSec), 1, 3) " " msg "`n", log_file)
}

HKL_NAME := Map(0x0409, "EN", 0x0804, "ZH")
ImeName(code) {
    global HKL_NAME
    return HKL_NAME.Has(code) ? HKL_NAME[code] : Format("0x{:04X}", code)
}

WinDesc(hwnd) {
    if !hwnd
        return "<none>"
    try
        return Format("hwnd=0x{:X} proc={} class={} ime={}", hwnd, WinGetProcessName("ahk_id " hwnd), WinGetClass("ahk_id " hwnd), ImeName(GetCurrentIME(hwnd)))
    return Format("hwnd=0x{:X} <gone>", hwnd)
}

GetCurrentIME(hwnd := 0) {
    try {
        if !hwnd
            hwnd := WinExist("A")
        if !hwnd
            return 0
        threadId := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
        inputLocale := DllCall("GetKeyboardLayout", "UInt", threadId, "Ptr")
        return inputLocale & 0xFFFF
    }
    return 0
}

SetIME(ime_code) {
    try {
        hwnd := WinExist("A")
        PostMessage(0x50, 0, ime_code, , "ahk_id " hwnd)
        return true
    }
    return false
}

GetActiveProcessName(hwnd := 0) {
    try {
        if !hwnd
            hwnd := WinExist("A")
        if !hwnd
            return ""
        return StrLower(WinGetProcessName("ahk_id " hwnd))
    }
    return ""
}

ShouldRememberIME(processName) {
    remember_list := config["remember_processes"]

    ; 空数组表示对所有进程启用
    if remember_list.Length == 0
        return true

    for process in remember_list {
        if StrLower(process) == processName
            return true
    }

    return false
}

ShouldIgnoreWindow(hwnd) {
    if !hwnd
        return false

    try {
        cls := WinGetClass("ahk_id " hwnd)
        for c in config["ignore_classes"] {
            if (c = cls)
                return true
        }

        proc := StrLower(WinGetProcessName("ahk_id " hwnd))
        for p in config["ignore_processes"] {
            if (p = proc)
                return true
        }
    }

    return false
}

SwitchIMEByRule() {
    processName := GetActiveProcessName()
    if !processName
        return

    hwnd := WinExist("A")

    ; 规则 3: 固定输入法优先于记忆
    if config["pinned_ime"].Has(processName) {
        target_ime := config["pinned_ime"][processName]
        Log("  -> pinned " ImeName(target_ime))
        SetIME(target_ime)
        return
    }

    ; 规则 2: 恢复该窗口上次的状态
    if ShouldRememberIME(processName) && window_ime_memory.Has(hwnd) {
        target_ime := window_ime_memory[hwnd]
        Log("  -> memory " ImeName(target_ime))
        SetIME(target_ime)
        return
    }

    ; 规则 1: 首次聚焦，用默认输入法
    Log("  -> default " ImeName(config["default_ime"]))
    SetIME(config["default_ime"])
}

last_hwnd := 0
CheckActiveWindow() {
    global last_hwnd
    current_hwnd := WinExist("A")

    if current_hwnd != last_hwnd && current_hwnd != 0 {
        ; shell 弹窗/托盘/菜单抢焦点时：不切换，也不更新 last_hwnd，等于没发生
        if ShouldIgnoreWindow(current_hwnd) {
            Log("focus change -> ignored " WinDesc(current_hwnd))
            return
        }

        Log("focus change: " WinDesc(last_hwnd) " | new " WinDesc(current_hwnd))

        ; 离开旧窗口前，记录它真实的输入法状态（含用户手动切换的结果）
        if last_hwnd {
            prev_process := GetActiveProcessName(last_hwnd)
            if prev_process && ShouldRememberIME(prev_process) {
                prev_ime := GetCurrentIME(last_hwnd)
                if prev_ime {
                    window_ime_memory[last_hwnd] := prev_ime
                    Log("  -> saved " WinDesc(last_hwnd))
                }
            }
        }

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

for hotkey_str, ime_code in config["hotkey_rules"] {
    ((target_ime) => Hotkey(hotkey_str, (*) => ManualSetIME(target_ime)))(ime_code)
}

SetTimer(CheckActiveWindow, 100)
Log("==== script started pid=" ProcessExist() " ====")
SetIME(config["default_ime"])

; ==================== CapsLock / 左 Ctrl ====================

; CapsLock 当左 Ctrl。驱动层不再做映射，所以只有 AHK 在跑时才生效。
*CapsLock::LCtrl

; 物理左 Ctrl 只用来切中英：按下吞掉，松开时切换。
; 注入的 LCtrl（来自 CapsLock）不会触发这里的热键。
*LCtrl::return
*LCtrl Up::ToggleIME()

ToggleIME() {
    target_ime := (GetCurrentIME() == 0x0804) ? 0x0409 : 0x0804
    Log("LCtrl toggle -> " ImeName(target_ime))
    ManualSetIME(target_ime)
}

; ==================== WezTerm Left Alt shortcuts ====================

SendWezTermCtrlAlt(key) {
    Send "{Blind}{LCtrl Down}" key "{LCtrl Up}"
}

#HotIf WinActive("ahk_exe wezterm-gui.exe")
<!,::SendWezTermCtrlAlt(",")
<!0::SendWezTermCtrlAlt("0")
<!1::SendWezTermCtrlAlt("1")
<!2::SendWezTermCtrlAlt("2")
<!3::SendWezTermCtrlAlt("3")
<!4::SendWezTermCtrlAlt("4")
<!5::SendWezTermCtrlAlt("5")
<!6::SendWezTermCtrlAlt("6")
<!7::SendWezTermCtrlAlt("7")
<!8::SendWezTermCtrlAlt("8")
<!9::SendWezTermCtrlAlt("9")
<!d::SendWezTermCtrlAlt("d")
<!+d::SendWezTermCtrlAlt("d")
<!w::SendWezTermCtrlAlt("w")
<!s::SendWezTermCtrlAlt("s")
<!h::SendWezTermCtrlAlt("h")
<!j::SendWezTermCtrlAlt("j")
<!k::SendWezTermCtrlAlt("k")
<!l::SendWezTermCtrlAlt("l")
<!n::SendWezTermCtrlAlt("n")
<!+n::SendWezTermCtrlAlt("n")
<!p::SendWezTermCtrlAlt("p")
<!`;::SendWezTermCtrlAlt(";")
<!o::SendWezTermCtrlAlt("o")
<!f::SendWezTermCtrlAlt("f")
<!r::SendWezTermCtrlAlt("r")
<!+`;::SendWezTermCtrlAlt(";")
#HotIf
