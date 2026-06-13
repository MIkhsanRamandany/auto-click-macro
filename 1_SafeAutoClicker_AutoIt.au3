; Nama file: 1_SafeAutoClicker_AutoIt.au3
; Program: Safe Auto Clicker Lightweight
; Tujuan program:
;   Auto clicker ringan berbasis AutoIt dengan mode Single Click, Macro Record,
;   Settings terpisah, hotkey global, hotkey capture langsung dari keyboard,
;   macro repeat-until-stopped yang lebih stabil, smooth return-to-start,
;   playback dimulai dari klik pertama agar gerakan awal rekaman tidak diputar ulang,
;   gerakan pembuka presisi memakai titik pemicu sebelum klik pertama + titik klik pertama,
;   auto-hide saat single clicker berjalan, auto-stop timer, emergency stop,
;   penyimpanan semua pengaturan ke file INI, auto-save option saat nilai berubah, fix load checkbox/radio dari INI, save/load macro lewat folder macro_saver, dan tanpa file macro otomatis last_macro.sacm.
; Cara penggunaan:
;   1. Install AutoIt dari situs resminya.
;   2. Jalankan file ini dengan AutoIt.
;   3. Tab Single Click dipakai untuk klik otomatis biasa.
;   4. Tab Macro Record dipakai untuk merekam/play gerakan mouse dan klik.
;   5. Tab Settings dipakai untuk mengatur hotkey tanpa mengetik manual.
;   6. Untuk membuat EXE: klik kanan file .au3 ini lalu pilih Compile Script.
;
; Step program:
;   1. Memuat library dan deklarasi variabel global.
;   2. Memuat settings dari file INI.
;   3. Membuat GUI dengan 3 tab: Single Click, Macro Record, Settings.
;   4. Mendaftarkan hotkey global.
;   5. Menjalankan event loop utama.
;   6. Menjalankan mode auto clicker atau macro recorder/playback sesuai status.
;   7. Menyimpan settings saat berubah atau aplikasi ditutup.

#NoTrayIcon
#RequireAdmin
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <ComboConstants.au3>
#include <TabConstants.au3>
#include <Misc.au3>
#include <Array.au3>
#include <Date.au3>
#include <FileConstants.au3>

Opt("MustDeclareVars", 1)
Opt("MouseCoordMode", 1)
Opt("PixelCoordMode", 1)
Opt("GUIOnEventMode", 0)

; =========================
; Global constants/settings
; =========================
Global Const $APP_TITLE = "Safe Auto Clicker v3.0"
Global Const $INI_FILE = @ScriptDir & "\safe_auto_clicker_settings.ini"
Global Const $MACRO_DIR = @ScriptDir & "\macro_saver"

Global $g_hGui = 0
Global $g_hTab = 0
Global $g_hDll = DllOpen("user32.dll")

; Hotkeys internal syntax + display text
Global $g_clickHotkey = IniRead($INI_FILE, "hotkeys", "click_syntax", "{F6}")
Global $g_clickHotkeyDisplay = IniRead($INI_FILE, "hotkeys", "click_display", "F6")
Global $g_recordHotkey = IniRead($INI_FILE, "hotkeys", "record_syntax", "^1")
Global $g_recordHotkeyDisplay = IniRead($INI_FILE, "hotkeys", "record_display", "Ctrl+1")
Global $g_macroHotkey = IniRead($INI_FILE, "hotkeys", "macro_syntax", "^3")
Global $g_macroHotkeyDisplay = IniRead($INI_FILE, "hotkeys", "macro_display", "Ctrl+3")

; Runtime state
Global $g_clickRunning = False
Global $g_recording = False
Global $g_macroPlaying = False
Global $g_pickMode = False
Global $g_clickStartTimer = 0
Global $g_clickCountDone = 0
Global $g_lastRecordTimer = 0
Global $g_recordLastX = -99999
Global $g_recordLastY = -99999
Global $g_lastLeft = False
Global $g_lastRight = False
Global $g_lastMiddle = False
Global $g_stopRequested = False
Global $g_lastAutoSaveTimer = TimerInit()
Global $g_lastSettingsSnapshot = ""

; Macro events: [type, x, y, delay_ms]
Global $g_macro[0][4]

; GUI controls: Single Click tab
Global $idHours, $idMins, $idSecs, $idMs, $idRandomEnabled, $idRandomMs
Global $idMouseButton, $idClickType
Global $idRepeatFixed, $idRepeatCount, $idRepeatUntilStopped
Global $idUseCurrent, $idUseFixed, $idPickLocation, $idX, $idY
Global $idAutoStopEnabled, $idStopH, $idStopM, $idStopS
Global $idStopAfterClicksEnabled, $idStopAfterClicks
Global $idEmergencyEnabled, $idAlwaysOnTop, $idClickHide
Global $idStartStopClick, $idClickStatus, $idClickHotkeyMain

; GUI controls: Macro tab
Global $idRecordToggle, $idMacroPlayToggle, $idMacroStatus, $idMacroCount
Global $idMacroSpeed, $idMacroRepeatFixed, $idMacroRepeatCount, $idMacroRepeatUntilStopped
Global $idMacroIntervalH, $idMacroIntervalM, $idMacroIntervalS
Global $idMacroReturnToStart, $idMacroReturnSpeed
Global $idMacroHide, $idMacroIgnoreSelf, $idSaveMacro, $idLoadMacro
Global $idRecordHotkeyMain, $idPlayHotkeyMain

; GUI controls: Settings tab
Global $idSetClickHotkey, $idSetRecordHotkey, $idSetMacroHotkey
Global $idSettingClickHotkeyLabel, $idSettingRecordHotkeyLabel, $idSettingMacroHotkeyLabel
Global $idSaveSettings, $idResetHotkeys

; =========================
; GUI creation
; =========================
EnsureMacroDir()
CreateGui()
LoadSettingsToGui()
RegisterAllHotkeys()
UpdateLabels()
$g_lastSettingsSnapshot = BuildSettingsSnapshot()
GUISetState(@SW_SHOW, $g_hGui)

; =========================
; Main loop
; =========================
While True
    Global $msg = GUIGetMsg()
    Switch $msg
        Case $GUI_EVENT_CLOSE
            SaveSettingsFromGui()
            UnregisterAllHotkeys()
            If $g_hDll <> -1 Then DllClose($g_hDll)
            Exit

        Case $idStartStopClick
            ToggleClicker()

        Case $idPickLocation
            PickLocation()

        Case $idRecordToggle
            ToggleRecord()

        Case $idMacroPlayToggle
            ToggleMacroPlay()

        Case $idSaveMacro
            SaveMacroDialog()

        Case $idLoadMacro
            LoadMacroDialog()

        Case $idAlwaysOnTop
            ApplyAlwaysOnTop()
            SaveSettingsFromGui()

        Case $idSetClickHotkey
            CaptureAndSetHotkey("click")

        Case $idSetRecordHotkey
            CaptureAndSetHotkey("record")

        Case $idSetMacroHotkey
            CaptureAndSetHotkey("macro")

        Case $idSaveSettings
            SaveSettingsFromGui()
            $g_lastSettingsSnapshot = BuildSettingsSnapshot()
            MsgBox(64, $APP_TITLE, "Semua settings tersimpan, termasuk Single Click, Macro Record, Safety, posisi X/Y, dan Hotkeys.")

        Case $idResetHotkeys
            ResetHotkeys()
    EndSwitch

    If $g_clickRunning Then ClickerTick()
    If $g_recording Then RecordTick()
    AutoSaveSettingsTick()

    Sleep(10)
WEnd

; =========================
; GUI functions
; =========================
Func CreateGui()
    $g_hGui = GUICreate($APP_TITLE, 520, 455, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU, $WS_MINIMIZEBOX))
    $g_hTab = GUICtrlCreateTab(8, 8, 504, 407)

    ; -------------------------
    ; Tab 1: Single Click
    ; -------------------------
    GUICtrlCreateTabItem("Single Click")

    GUICtrlCreateGroup("Click interval", 18, 42, 480, 62)
    $idHours = GUICtrlCreateInput("0", 30, 66, 45, 22, $ES_NUMBER)
    GUICtrlCreateLabel("hours", 80, 70, 35, 18)
    $idMins = GUICtrlCreateInput("0", 122, 66, 45, 22, $ES_NUMBER)
    GUICtrlCreateLabel("mins", 172, 70, 30, 18)
    $idSecs = GUICtrlCreateInput("0", 212, 66, 45, 22, $ES_NUMBER)
    GUICtrlCreateLabel("secs", 262, 70, 30, 18)
    $idMs = GUICtrlCreateInput("100", 302, 66, 55, 22, $ES_NUMBER)
    GUICtrlCreateLabel("milliseconds", 362, 70, 75, 18)
    $idRandomEnabled = GUICtrlCreateCheckbox("Random offset +-", 30, 91, 115, 18)
    $idRandomMs = GUICtrlCreateInput("40", 150, 88, 55, 22, $ES_NUMBER)
    GUICtrlCreateLabel("ms", 210, 92, 25, 18)
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    GUICtrlCreateGroup("Click options", 18, 112, 230, 78)
    GUICtrlCreateLabel("Mouse button:", 32, 137, 85, 18)
    $idMouseButton = GUICtrlCreateCombo("Left", 122, 132, 92, 25, $CBS_DROPDOWNLIST)
    GUICtrlSetData($idMouseButton, "Left|Right|Middle", "Left")
    GUICtrlCreateLabel("Click type:", 32, 164, 75, 18)
    $idClickType = GUICtrlCreateCombo("Single", 122, 159, 92, 25, $CBS_DROPDOWNLIST)
    GUICtrlSetData($idClickType, "Single|Double", "Single")
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    GUICtrlCreateGroup("Click repeat", 260, 112, 238, 78)
    $idRepeatFixed = GUICtrlCreateRadio("Repeat", 275, 136, 70, 18)
    $idRepeatCount = GUICtrlCreateInput("1", 350, 133, 55, 22, $ES_NUMBER)
    GUICtrlCreateLabel("times", 410, 137, 40, 18)
    $idRepeatUntilStopped = GUICtrlCreateRadio("Repeat until stopped", 275, 164, 150, 18)
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    GUICtrlCreateGroup("Cursor position", 18, 198, 480, 62)
    $idUseCurrent = GUICtrlCreateRadio("Current location", 30, 223, 112, 18)
    $idUseFixed = GUICtrlCreateRadio("Fixed location", 154, 223, 105, 18)
    $idPickLocation = GUICtrlCreateButton("Pick location", 264, 218, 90, 25)
    GUICtrlCreateLabel("X", 365, 223, 15, 18)
    $idX = GUICtrlCreateInput("0", 382, 219, 45, 22, $ES_NUMBER)
    GUICtrlCreateLabel("Y", 432, 223, 15, 18)
    $idY = GUICtrlCreateInput("0", 449, 219, 45, 22, $ES_NUMBER)
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    GUICtrlCreateGroup("Safety", 18, 268, 480, 92)
    $idAutoStopEnabled = GUICtrlCreateCheckbox("Stop after duration", 30, 290, 130, 18)
    $idStopH = GUICtrlCreateInput("0", 166, 287, 35, 22, $ES_NUMBER)
    GUICtrlCreateLabel("h", 205, 291, 15, 18)
    $idStopM = GUICtrlCreateInput("10", 220, 287, 35, 22, $ES_NUMBER)
    GUICtrlCreateLabel("m", 260, 291, 15, 18)
    $idStopS = GUICtrlCreateInput("0", 278, 287, 35, 22, $ES_NUMBER)
    GUICtrlCreateLabel("s", 318, 291, 15, 18)
    $idStopAfterClicksEnabled = GUICtrlCreateCheckbox("Stop after clicks", 30, 316, 120, 18)
    $idStopAfterClicks = GUICtrlCreateInput("1000", 166, 313, 70, 22, $ES_NUMBER)
    $idAlwaysOnTop = GUICtrlCreateCheckbox("Always on top", 255, 316, 120, 18)
    $idEmergencyEnabled = GUICtrlCreateCheckbox("Emergency stop at top-left corner", 30, 342, 220, 18)
    $idClickHide = GUICtrlCreateCheckbox("Minimize during single click", 255, 342, 190, 18)
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    $idClickHotkeyMain = GUICtrlCreateLabel("Hotkey: F6", 25, 374, 160, 18)
    $idClickStatus = GUICtrlCreateLabel("Status: stopped", 190, 374, 180, 18)
    $idStartStopClick = GUICtrlCreateButton("Start", 388, 370, 100, 28)

    ; -------------------------
    ; Tab 2: Macro Record
    ; -------------------------
    GUICtrlCreateTabItem("Macro Record")

    GUICtrlCreateGroup("Macro control", 18, 42, 480, 82)
    $idRecordHotkeyMain = GUICtrlCreateLabel("Record hotkey: Ctrl+1", 32, 66, 180, 18)
    $idPlayHotkeyMain = GUICtrlCreateLabel("Play hotkey: Ctrl+3", 242, 66, 180, 18)
    $idRecordToggle = GUICtrlCreateButton("● Record", 32, 88, 140, 27)
    $idMacroPlayToggle = GUICtrlCreateButton("▶ Play", 184, 88, 140, 27)
    $idMacroStatus = GUICtrlCreateLabel("Status: stopped", 338, 92, 145, 18)
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    GUICtrlCreateGroup("Playback", 18, 135, 480, 126)
    GUICtrlCreateLabel("Speed:", 32, 160, 50, 18)
    $idMacroSpeed = GUICtrlCreateCombo("1.0", 85, 155, 70, 25, $CBS_DROPDOWNLIST)
    GUICtrlSetData($idMacroSpeed, "0.25|0.5|0.75|1.0|1.5|2.0|3.0", "1.0")
    $idMacroRepeatFixed = GUICtrlCreateRadio("Repeat", 32, 188, 70, 18)
    $idMacroRepeatCount = GUICtrlCreateInput("1", 105, 185, 55, 22, $ES_NUMBER)
    GUICtrlCreateLabel("times", 165, 189, 40, 18)
    $idMacroRepeatUntilStopped = GUICtrlCreateRadio("Repeat until stopped", 32, 214, 150, 18)
    GUICtrlCreateLabel("Interval:", 235, 188, 55, 18)
    $idMacroIntervalH = GUICtrlCreateInput("0", 295, 185, 35, 22, $ES_NUMBER)
    GUICtrlCreateLabel("h", 334, 189, 15, 18)
    $idMacroIntervalM = GUICtrlCreateInput("0", 352, 185, 35, 22, $ES_NUMBER)
    GUICtrlCreateLabel("m", 392, 189, 15, 18)
    $idMacroIntervalS = GUICtrlCreateInput("0", 410, 185, 35, 22, $ES_NUMBER)
    GUICtrlCreateLabel("s", 450, 189, 15, 18)
    $idMacroReturnToStart = GUICtrlCreateCheckbox("Smooth return to start before next loop", 32, 237, 260, 18)
    GUICtrlCreateLabel("Speed:", 312, 238, 42, 18)
    $idMacroReturnSpeed = GUICtrlCreateInput("20", 358, 234, 42, 22, $ES_NUMBER)
    GUICtrlCreateLabel("1-100", 405, 238, 45, 18)
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    GUICtrlCreateGroup("Recording behavior", 18, 270, 480, 64)
    $idMacroHide = GUICtrlCreateCheckbox("Minimize/hide during macro record/play", 32, 291, 245, 18)
    $idMacroIgnoreSelf = GUICtrlCreateCheckbox("Ignore actions on this app while recording", 32, 316, 260, 18)
    $idMacroCount = GUICtrlCreateLabel("Recorded events: 0", 310, 304, 160, 18)
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    $idSaveMacro = GUICtrlCreateButton("Save macro", 120, 352, 120, 28)
    $idLoadMacro = GUICtrlCreateButton("Load macro", 262, 352, 120, 28)

    ; -------------------------
    ; Tab 3: Settings
    ; -------------------------
    GUICtrlCreateTabItem("Settings")

    GUICtrlCreateGroup("Hotkeys", 18, 42, 480, 155)
    GUICtrlCreateLabel("Single clicker:", 32, 70, 105, 18)
    $idSettingClickHotkeyLabel = GUICtrlCreateLabel("F6", 150, 70, 180, 18)
    $idSetClickHotkey = GUICtrlCreateButton("Set", 360, 64, 90, 28)

    GUICtrlCreateLabel("Macro record:", 32, 108, 105, 18)
    $idSettingRecordHotkeyLabel = GUICtrlCreateLabel("Ctrl+1", 150, 108, 180, 18)
    $idSetRecordHotkey = GUICtrlCreateButton("Set", 360, 102, 90, 28)

    GUICtrlCreateLabel("Macro play:", 32, 146, 105, 18)
    $idSettingMacroHotkeyLabel = GUICtrlCreateLabel("Ctrl+3", 150, 146, 180, 18)
    $idSetMacroHotkey = GUICtrlCreateButton("Set", 360, 140, 90, 28)
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    GUICtrlCreateGroup("Info", 18, 212, 480, 88)
    GUICtrlCreateLabel("Klik Set, lalu tekan tombol keyboard yang mau dijadikan shortcut.", 32, 236, 440, 18)
    GUICtrlCreateLabel("Contoh: F6, Ctrl+1, Ctrl+Shift+R, Alt+F8.", 32, 260, 440, 18)
    GUICtrlCreateLabel("ESC saat capture = batal ganti hotkey.", 32, 282, 440, 18)
    GUICtrlCreateGroup("", -99, -99, 1, 1)

    $idSaveSettings = GUICtrlCreateButton("Save settings", 150, 330, 110, 30)
    $idResetHotkeys = GUICtrlCreateButton("Reset hotkeys", 280, 330, 110, 30)

    GUICtrlCreateTabItem("")
EndFunc

Func LoadSettingsToGui()
    GUICtrlSetData($idHours, IniRead($INI_FILE, "click", "hours", "0"))
    GUICtrlSetData($idMins, IniRead($INI_FILE, "click", "mins", "0"))
    GUICtrlSetData($idSecs, IniRead($INI_FILE, "click", "secs", "0"))
    GUICtrlSetData($idMs, IniRead($INI_FILE, "click", "ms", "100"))
    _SetCheck($idRandomEnabled, IniRead($INI_FILE, "click", "random_enabled", "0"))
    GUICtrlSetData($idRandomMs, IniRead($INI_FILE, "click", "random_ms", "40"))
    GUICtrlSetData($idMouseButton, IniRead($INI_FILE, "click", "button", "Left"))
    GUICtrlSetData($idClickType, IniRead($INI_FILE, "click", "type", "Single"))
    _SetCheck($idRepeatFixed, IniRead($INI_FILE, "click", "repeat_fixed", "0"))
    _SetCheck($idRepeatUntilStopped, IniRead($INI_FILE, "click", "repeat_until_stopped", "1"))
    GUICtrlSetData($idRepeatCount, IniRead($INI_FILE, "click", "repeat_count", "1"))
    _SetCheck($idUseCurrent, IniRead($INI_FILE, "click", "use_current", "1"))
    _SetCheck($idUseFixed, IniRead($INI_FILE, "click", "use_fixed", "0"))
    GUICtrlSetData($idX, IniRead($INI_FILE, "click", "x", "0"))
    GUICtrlSetData($idY, IniRead($INI_FILE, "click", "y", "0"))
    _SetCheck($idAutoStopEnabled, IniRead($INI_FILE, "safety", "autostop_enabled", "1"))
    GUICtrlSetData($idStopH, IniRead($INI_FILE, "safety", "stop_h", "0"))
    GUICtrlSetData($idStopM, IniRead($INI_FILE, "safety", "stop_m", "10"))
    GUICtrlSetData($idStopS, IniRead($INI_FILE, "safety", "stop_s", "0"))
    _SetCheck($idStopAfterClicksEnabled, IniRead($INI_FILE, "safety", "stop_clicks_enabled", "0"))
    GUICtrlSetData($idStopAfterClicks, IniRead($INI_FILE, "safety", "stop_clicks", "1000"))
    _SetCheck($idEmergencyEnabled, IniRead($INI_FILE, "safety", "emergency", "1"))
    _SetCheck($idAlwaysOnTop, IniRead($INI_FILE, "window", "always_on_top", "0"))
    _SetCheck($idClickHide, IniRead($INI_FILE, "click", "hide_on_run", "0"))

    GUICtrlSetData($idMacroSpeed, IniRead($INI_FILE, "macro", "speed", "1.0"))
    _SetCheck($idMacroRepeatFixed, IniRead($INI_FILE, "macro", "repeat_fixed", "1"))
    _SetCheck($idMacroRepeatUntilStopped, IniRead($INI_FILE, "macro", "repeat_until_stopped", "0"))
    GUICtrlSetData($idMacroRepeatCount, IniRead($INI_FILE, "macro", "repeat_count", "1"))
    GUICtrlSetData($idMacroIntervalH, IniRead($INI_FILE, "macro", "interval_h", "0"))
    GUICtrlSetData($idMacroIntervalM, IniRead($INI_FILE, "macro", "interval_m", "0"))
    GUICtrlSetData($idMacroIntervalS, IniRead($INI_FILE, "macro", "interval_s", "0"))
    _SetCheck($idMacroReturnToStart, IniRead($INI_FILE, "macro", "return_to_start", "1"))
    GUICtrlSetData($idMacroReturnSpeed, IniRead($INI_FILE, "macro", "return_speed", "20"))
    _SetCheck($idMacroHide, IniRead($INI_FILE, "macro", "hide", "1"))
    _SetCheck($idMacroIgnoreSelf, IniRead($INI_FILE, "macro", "ignore_self", "1"))

    ApplyAlwaysOnTop()
EndFunc

Func SaveSettingsFromGui()
    IniWrite($INI_FILE, "click", "hours", GUICtrlRead($idHours))
    IniWrite($INI_FILE, "click", "mins", GUICtrlRead($idMins))
    IniWrite($INI_FILE, "click", "secs", GUICtrlRead($idSecs))
    IniWrite($INI_FILE, "click", "ms", GUICtrlRead($idMs))
    IniWrite($INI_FILE, "click", "random_enabled", _IsChecked($idRandomEnabled))
    IniWrite($INI_FILE, "click", "random_ms", GUICtrlRead($idRandomMs))
    IniWrite($INI_FILE, "click", "button", GUICtrlRead($idMouseButton))
    IniWrite($INI_FILE, "click", "type", GUICtrlRead($idClickType))
    IniWrite($INI_FILE, "click", "repeat_fixed", _IsChecked($idRepeatFixed))
    IniWrite($INI_FILE, "click", "repeat_until_stopped", _IsChecked($idRepeatUntilStopped))
    IniWrite($INI_FILE, "click", "repeat_count", GUICtrlRead($idRepeatCount))
    IniWrite($INI_FILE, "click", "use_current", _IsChecked($idUseCurrent))
    IniWrite($INI_FILE, "click", "use_fixed", _IsChecked($idUseFixed))
    IniWrite($INI_FILE, "click", "x", GUICtrlRead($idX))
    IniWrite($INI_FILE, "click", "y", GUICtrlRead($idY))
    IniWrite($INI_FILE, "safety", "autostop_enabled", _IsChecked($idAutoStopEnabled))
    IniWrite($INI_FILE, "safety", "stop_h", GUICtrlRead($idStopH))
    IniWrite($INI_FILE, "safety", "stop_m", GUICtrlRead($idStopM))
    IniWrite($INI_FILE, "safety", "stop_s", GUICtrlRead($idStopS))
    IniWrite($INI_FILE, "safety", "stop_clicks_enabled", _IsChecked($idStopAfterClicksEnabled))
    IniWrite($INI_FILE, "safety", "stop_clicks", GUICtrlRead($idStopAfterClicks))
    IniWrite($INI_FILE, "safety", "emergency", _IsChecked($idEmergencyEnabled))
    IniWrite($INI_FILE, "window", "always_on_top", _IsChecked($idAlwaysOnTop))
    IniWrite($INI_FILE, "click", "hide_on_run", _IsChecked($idClickHide))
    IniWrite($INI_FILE, "macro", "speed", GUICtrlRead($idMacroSpeed))
    IniWrite($INI_FILE, "macro", "repeat_fixed", _IsChecked($idMacroRepeatFixed))
    IniWrite($INI_FILE, "macro", "repeat_until_stopped", _IsChecked($idMacroRepeatUntilStopped))
    IniWrite($INI_FILE, "macro", "repeat_count", GUICtrlRead($idMacroRepeatCount))
    IniWrite($INI_FILE, "macro", "interval_h", GUICtrlRead($idMacroIntervalH))
    IniWrite($INI_FILE, "macro", "interval_m", GUICtrlRead($idMacroIntervalM))
    IniWrite($INI_FILE, "macro", "interval_s", GUICtrlRead($idMacroIntervalS))
    IniWrite($INI_FILE, "macro", "return_to_start", _IsChecked($idMacroReturnToStart))
    IniWrite($INI_FILE, "macro", "return_speed", GUICtrlRead($idMacroReturnSpeed))
    IniWrite($INI_FILE, "macro", "hide", _IsChecked($idMacroHide))
    IniWrite($INI_FILE, "macro", "ignore_self", _IsChecked($idMacroIgnoreSelf))
    IniWrite($INI_FILE, "hotkeys", "click_syntax", $g_clickHotkey)
    IniWrite($INI_FILE, "hotkeys", "click_display", $g_clickHotkeyDisplay)
    IniWrite($INI_FILE, "hotkeys", "record_syntax", $g_recordHotkey)
    IniWrite($INI_FILE, "hotkeys", "record_display", $g_recordHotkeyDisplay)
    IniWrite($INI_FILE, "hotkeys", "macro_syntax", $g_macroHotkey)
    IniWrite($INI_FILE, "hotkeys", "macro_display", $g_macroHotkeyDisplay)
EndFunc


Func AutoSaveSettingsTick()
    ; v2.8:
    ; Menyimpan semua option secara otomatis saat user mengubah nilai.
    ; Ini mencegah setting balik default kalau aplikasi ditutup tidak lewat tombol Save.
    ; Tidak dijalankan saat clicker/macro aktif supaya logika klik yang sudah fix tidak terganggu.
    If $g_clickRunning Or $g_recording Or $g_macroPlaying Then Return
    If TimerDiff($g_lastAutoSaveTimer) < 700 Then Return
    $g_lastAutoSaveTimer = TimerInit()

    Local $nowSnapshot = BuildSettingsSnapshot()
    If $nowSnapshot <> $g_lastSettingsSnapshot Then
        SaveSettingsFromGui()
        $g_lastSettingsSnapshot = $nowSnapshot
    EndIf
EndFunc

Func BuildSettingsSnapshot()
    Local $s = ""
    $s &= GUICtrlRead($idHours) & "|" & GUICtrlRead($idMins) & "|" & GUICtrlRead($idSecs) & "|" & GUICtrlRead($idMs) & "|"
    $s &= _IsChecked($idRandomEnabled) & "|" & GUICtrlRead($idRandomMs) & "|"
    $s &= GUICtrlRead($idMouseButton) & "|" & GUICtrlRead($idClickType) & "|"
    $s &= _IsChecked($idRepeatFixed) & "|" & _IsChecked($idRepeatUntilStopped) & "|" & GUICtrlRead($idRepeatCount) & "|"
    $s &= _IsChecked($idUseCurrent) & "|" & _IsChecked($idUseFixed) & "|" & GUICtrlRead($idX) & "|" & GUICtrlRead($idY) & "|"
    $s &= _IsChecked($idAutoStopEnabled) & "|" & GUICtrlRead($idStopH) & "|" & GUICtrlRead($idStopM) & "|" & GUICtrlRead($idStopS) & "|"
    $s &= _IsChecked($idStopAfterClicksEnabled) & "|" & GUICtrlRead($idStopAfterClicks) & "|"
    $s &= _IsChecked($idEmergencyEnabled) & "|" & _IsChecked($idAlwaysOnTop) & "|" & _IsChecked($idClickHide) & "|"
    $s &= GUICtrlRead($idMacroSpeed) & "|" & _IsChecked($idMacroRepeatFixed) & "|" & _IsChecked($idMacroRepeatUntilStopped) & "|" & GUICtrlRead($idMacroRepeatCount) & "|"
    $s &= GUICtrlRead($idMacroIntervalH) & "|" & GUICtrlRead($idMacroIntervalM) & "|" & GUICtrlRead($idMacroIntervalS) & "|"
    $s &= _IsChecked($idMacroReturnToStart) & "|" & GUICtrlRead($idMacroReturnSpeed) & "|" & _IsChecked($idMacroHide) & "|" & _IsChecked($idMacroIgnoreSelf) & "|"
    $s &= $g_clickHotkey & "|" & $g_clickHotkeyDisplay & "|" & $g_recordHotkey & "|" & $g_recordHotkeyDisplay & "|" & $g_macroHotkey & "|" & $g_macroHotkeyDisplay
    Return $s
EndFunc

Func UpdateLabels()
    GUICtrlSetData($idClickHotkeyMain, "Hotkey: " & $g_clickHotkeyDisplay)
    GUICtrlSetData($idRecordHotkeyMain, "Record hotkey: " & $g_recordHotkeyDisplay)
    GUICtrlSetData($idPlayHotkeyMain, "Play hotkey: " & $g_macroHotkeyDisplay)
    GUICtrlSetData($idSettingClickHotkeyLabel, $g_clickHotkeyDisplay)
    GUICtrlSetData($idSettingRecordHotkeyLabel, $g_recordHotkeyDisplay)
    GUICtrlSetData($idSettingMacroHotkeyLabel, $g_macroHotkeyDisplay)
EndFunc

Func ApplyAlwaysOnTop()
    If _IsChecked($idAlwaysOnTop) Then
        WinSetOnTop($g_hGui, "", 1)
    Else
        WinSetOnTop($g_hGui, "", 0)
    EndIf
EndFunc

; =========================
; Hotkey functions
; =========================
Func RegisterAllHotkeys()
    UnregisterAllHotkeys()
    If $g_clickHotkey <> "" Then HotKeySet($g_clickHotkey, "HotkeyClicker")
    If $g_recordHotkey <> "" Then HotKeySet($g_recordHotkey, "HotkeyRecord")
    If $g_macroHotkey <> "" Then HotKeySet($g_macroHotkey, "HotkeyMacroPlay")
    HotKeySet("{ESC}", "HotkeyEsc")
EndFunc

Func UnregisterAllHotkeys()
    If $g_clickHotkey <> "" Then HotKeySet($g_clickHotkey)
    If $g_recordHotkey <> "" Then HotKeySet($g_recordHotkey)
    If $g_macroHotkey <> "" Then HotKeySet($g_macroHotkey)
    HotKeySet("{ESC}")
EndFunc

Func HotkeyClicker()
    ToggleClicker()
EndFunc

Func HotkeyRecord()
    ToggleRecord()
EndFunc

Func HotkeyMacroPlay()
    ToggleMacroPlay()
EndFunc

Func HotkeyEsc()
    If $g_recording Then
        StopRecord()
        Return
    EndIf
    If $g_macroPlaying Then
        StopMacroPlay()
        Return
    EndIf
    If $g_clickRunning Then
        StopClicker()
        Return
    EndIf
EndFunc

Func ResetHotkeys()
    $g_clickHotkey = "{F6}"
    $g_clickHotkeyDisplay = "F6"
    $g_recordHotkey = "^1"
    $g_recordHotkeyDisplay = "Ctrl+1"
    $g_macroHotkey = "^3"
    $g_macroHotkeyDisplay = "Ctrl+3"
    RegisterAllHotkeys()
    UpdateLabels()
    SaveSettingsFromGui()
EndFunc

Func CaptureAndSetHotkey($target)
    UnregisterAllHotkeys()
    Global $cap = CaptureHotkeyDialog()
    RegisterAllHotkeys()

    If Not IsArray($cap) Then Return
    If $cap[0] = "" Then Return

    Switch $target
        Case "click"
            $g_clickHotkey = $cap[0]
            $g_clickHotkeyDisplay = $cap[1]
        Case "record"
            $g_recordHotkey = $cap[0]
            $g_recordHotkeyDisplay = $cap[1]
        Case "macro"
            $g_macroHotkey = $cap[0]
            $g_macroHotkeyDisplay = $cap[1]
    EndSwitch

    RegisterAllHotkeys()
    UpdateLabels()
    SaveSettingsFromGui()
EndFunc

Func CaptureHotkeyDialog()
    Local $hCap = GUICreate("Set Hotkey", 360, 130, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU), -1, $g_hGui)
    Local $lbl = GUICtrlCreateLabel("Tekan tombol keyboard yang ingin dijadikan shortcut...", 20, 25, 320, 20)
    Local $lbl2 = GUICtrlCreateLabel("Boleh pakai Ctrl / Alt / Shift. ESC untuk batal.", 20, 50, 320, 20)
    Local $preview = GUICtrlCreateLabel("Menunggu input...", 20, 78, 320, 20)
    GUISetState(@SW_SHOW, $hCap)

    Local $result[2]
    $result[0] = ""
    $result[1] = ""

    While True
        Local $msg = GUIGetMsg()
        If $msg = $GUI_EVENT_CLOSE Then ExitLoop

        If _IsPressed("1B", $g_hDll) Then ExitLoop ; ESC

        Local $keyInfo = DetectPressedHotkey()
        If IsArray($keyInfo) Then
            GUICtrlSetData($preview, "Dipilih: " & $keyInfo[1])
            Sleep(250)
            $result[0] = $keyInfo[0]
            $result[1] = $keyInfo[1]
            ExitLoop
        EndIf
        Sleep(30)
    WEnd

    GUIDelete($hCap)
    Return $result
EndFunc

Func DetectPressedHotkey()
    Local $ctrl = (_IsPressed("11", $g_hDll) Or _IsPressed("A2", $g_hDll) Or _IsPressed("A3", $g_hDll))
    Local $alt = (_IsPressed("12", $g_hDll) Or _IsPressed("A4", $g_hDll) Or _IsPressed("A5", $g_hDll))
    Local $shift = (_IsPressed("10", $g_hDll) Or _IsPressed("A0", $g_hDll) Or _IsPressed("A1", $g_hDll))

    ; Function keys F1-F12
    Local $i
    For $i = 112 To 123
        Local $hex = Hex($i, 2)
        If _IsPressed($hex, $g_hDll) Then Return BuildHotkeyResult($ctrl, $alt, $shift, "{F" & ($i - 111) & "}", "F" & ($i - 111))
    Next

    ; Number row 0-9
    For $i = 48 To 57
        $hex = Hex($i, 2)
        If _IsPressed($hex, $g_hDll) Then Return BuildHotkeyResult($ctrl, $alt, $shift, Chr($i), Chr($i))
    Next

    ; Letters A-Z
    For $i = 65 To 90
        $hex = Hex($i, 2)
        If _IsPressed($hex, $g_hDll) Then Return BuildHotkeyResult($ctrl, $alt, $shift, StringLower(Chr($i)), Chr($i))
    Next

    ; Common keys
    Local $special[14][3] = [["20", "{SPACE}", "Space"], ["09", "{TAB}", "Tab"], ["2D", "{INSERT}", "Insert"], ["2E", "{DELETE}", "Delete"], ["24", "{HOME}", "Home"], ["23", "{END}", "End"], ["21", "{PGUP}", "PageUp"], ["22", "{PGDN}", "PageDown"], ["25", "{LEFT}", "Left"], ["26", "{UP}", "Up"], ["27", "{RIGHT}", "Right"], ["28", "{DOWN}", "Down"], ["2C", "{PRINTSCREEN}", "PrintScreen"], ["13", "{ENTER}", "Enter"]]
    For $i = 0 To UBound($special) - 1
        If _IsPressed($special[$i][0], $g_hDll) Then Return BuildHotkeyResult($ctrl, $alt, $shift, $special[$i][1], $special[$i][2])
    Next

    Return SetError(1, 0, 0)
EndFunc

Func BuildHotkeyResult($ctrl, $alt, $shift, $keySyntax, $keyDisplay)
    Local $syntax = ""
    Local $display = ""
    If $ctrl Then
        $syntax &= "^"
        $display &= "Ctrl+"
    EndIf
    If $alt Then
        $syntax &= "!"
        $display &= "Alt+"
    EndIf
    If $shift Then
        $syntax &= "+"
        $display &= "Shift+"
    EndIf
    $syntax &= $keySyntax
    $display &= $keyDisplay

    Local $arr[2]
    $arr[0] = $syntax
    $arr[1] = $display
    Return $arr
EndFunc

; =========================
; Single clicker functions
; =========================
Func ToggleClicker()
    If $g_clickRunning Then
        StopClicker()
    Else
        StartClicker()
    EndIf
EndFunc

Func StartClicker()
    SaveSettingsFromGui()
    $g_clickRunning = True
    $g_clickStartTimer = TimerInit()
    $g_clickCountDone = 0
    GUICtrlSetData($idStartStopClick, "Stop")
    GUICtrlSetData($idClickStatus, "Status: running")
    If _IsChecked($idClickHide) Then GUISetState(@SW_MINIMIZE, $g_hGui)
EndFunc

Func StopClicker()
    $g_clickRunning = False
    GUICtrlSetData($idStartStopClick, "Start")
    GUICtrlSetData($idClickStatus, "Status: stopped")
    If _IsChecked($idClickHide) Then GUISetState(@SW_RESTORE, $g_hGui)
EndFunc

Func ClickerTick()
    If Not $g_clickRunning Then Return

    If _IsChecked($idEmergencyEnabled) Then
        Local $pos = MouseGetPos()
        If $pos[0] <= 2 And $pos[1] <= 2 Then
            StopClicker()
            Return
        EndIf
    EndIf

    If _IsChecked($idAutoStopEnabled) Then
        Local $limit = (Number(GUICtrlRead($idStopH)) * 3600 + Number(GUICtrlRead($idStopM)) * 60 + Number(GUICtrlRead($idStopS))) * 1000
        If $limit > 0 And TimerDiff($g_clickStartTimer) >= $limit Then
            StopClicker()
            Return
        EndIf
    EndIf

    If _IsChecked($idStopAfterClicksEnabled) Then
        Local $maxClicks = Number(GUICtrlRead($idStopAfterClicks))
        If $maxClicks > 0 And $g_clickCountDone >= $maxClicks Then
            StopClicker()
            Return
        EndIf
    EndIf

    If _IsChecked($idRepeatFixed) Then
        Local $repeatMax = Number(GUICtrlRead($idRepeatCount))
        If $repeatMax > 0 And $g_clickCountDone >= $repeatMax Then
            StopClicker()
            Return
        EndIf
    EndIf

    Local $delay = GetClickIntervalMs()
    DoSingleAutoClick()
    $g_clickCountDone += 1
    GUICtrlSetData($idClickStatus, "Status: running | clicks: " & $g_clickCountDone)
    Sleep($delay)
EndFunc

Func GetClickIntervalMs()
    Local $base = Number(GUICtrlRead($idHours)) * 3600000 + Number(GUICtrlRead($idMins)) * 60000 + Number(GUICtrlRead($idSecs)) * 1000 + Number(GUICtrlRead($idMs))
    If $base < 1 Then $base = 1
    If _IsChecked($idRandomEnabled) Then
        Local $off = Number(GUICtrlRead($idRandomMs))
        If $off > 0 Then $base += Random(-$off, $off, 1)
    EndIf
    If $base < 1 Then $base = 1
    Return $base
EndFunc

Func DoSingleAutoClick()
    Local $button = StringLower(GUICtrlRead($idMouseButton))
    Local $clickType = GUICtrlRead($idClickType)
    Local $clicks = 1
    If $clickType = "Double" Then $clicks = 2

    If _IsChecked($idUseFixed) Then
        Local $x = Number(GUICtrlRead($idX))
        Local $y = Number(GUICtrlRead($idY))
        MouseClick($button, $x, $y, $clicks, 0)
    Else
        MouseClick($button, Default, Default, $clicks, 0)
    EndIf
EndFunc

Func PickLocation()
    Local $oldTitle = WinGetTitle($g_hGui)
    WinSetTitle($g_hGui, "", "Pick location: klik kiri target, ESC batal")
    GUISetState(@SW_MINIMIZE, $g_hGui)
    Sleep(250)

    While True
        If _IsPressed("1B", $g_hDll) Then ExitLoop
        If _IsPressed("01", $g_hDll) Then
            Local $pos = MouseGetPos()
            GUICtrlSetData($idX, $pos[0])
            GUICtrlSetData($idY, $pos[1])
            GUICtrlSetState($idUseFixed, $GUI_CHECKED)
            GUICtrlSetState($idUseCurrent, $GUI_UNCHECKED)
            SaveSettingsFromGui()
            ExitLoop
        EndIf
        Sleep(20)
    WEnd

    GUISetState(@SW_RESTORE, $g_hGui)
    WinSetTitle($g_hGui, "", $oldTitle)
EndFunc

; =========================
; Macro functions
; =========================
Func ToggleRecord()
    If $g_recording Then
        StopRecord()
    Else
        StartRecord()
    EndIf
EndFunc

Func StartRecord()
    If $g_macroPlaying Then Return
    ReDim $g_macro[0][4]
    $g_recording = True
    $g_lastRecordTimer = TimerInit()
    $g_recordLastX = -99999
    $g_recordLastY = -99999
    $g_lastLeft = False
    $g_lastRight = False
    $g_lastMiddle = False
    GUICtrlSetData($idRecordToggle, "■ Stop Rec")
    GUICtrlSetData($idMacroStatus, "Status: recording")
    GUICtrlSetData($idMacroCount, "Recorded events: 0")
    If _IsChecked($idMacroHide) Then GUISetState(@SW_MINIMIZE, $g_hGui)
EndFunc

Func StopRecord()
    ; Penting: rekam jeda terakhir sebelum hotkey/tombol stop ditekan.
    ; Tanpa ini, macro langsung loop ke awal dan timing akhir jadi rusak.
    AddFinalMacroPause()

    $g_recording = False
    GUICtrlSetData($idRecordToggle, "● Record")
    GUICtrlSetData($idMacroStatus, "Status: recorded (unsaved)")
    If _IsChecked($idMacroHide) Then GUISetState(@SW_RESTORE, $g_hGui)
EndFunc

Func RecordTick()
    If Not $g_recording Then Return

    Local $pos = MouseGetPos()
    Local $x = $pos[0]
    Local $y = $pos[1]

    If _IsChecked($idMacroIgnoreSelf) Then
        Local $hUnder = _WinAPI_WindowFromPoint($x, $y)
        If IsHWnd($hUnder) And ($hUnder = $g_hGui Or _WinAPI_GetAncestor($hUnder, 2) = $g_hGui) Then
            Sleep(5)
            Return
        EndIf
    EndIf

    If $x <> $g_recordLastX Or $y <> $g_recordLastY Then
        AddMacroEvent("move", $x, $y)
        $g_recordLastX = $x
        $g_recordLastY = $y
    EndIf

    Local $left = _IsPressed("01", $g_hDll)
    Local $right = _IsPressed("02", $g_hDll)
    Local $middle = _IsPressed("04", $g_hDll)

    If $left <> $g_lastLeft Then
        If $left Then AddMacroEvent("ldown", $x, $y)
        If Not $left Then AddMacroEvent("lup", $x, $y)
        $g_lastLeft = $left
    EndIf
    If $right <> $g_lastRight Then
        If $right Then AddMacroEvent("rdown", $x, $y)
        If Not $right Then AddMacroEvent("rup", $x, $y)
        $g_lastRight = $right
    EndIf
    If $middle <> $g_lastMiddle Then
        If $middle Then AddMacroEvent("mdown", $x, $y)
        If Not $middle Then AddMacroEvent("mup", $x, $y)
        $g_lastMiddle = $middle
    EndIf

    GUICtrlSetData($idMacroCount, "Recorded events: " & UBound($g_macro))
    Sleep(5)
EndFunc

Func AddMacroEvent($type, $x, $y)
    Local $n = UBound($g_macro)
    Local $delay = Int(TimerDiff($g_lastRecordTimer))
    ; Event pertama dibuat delay 0 agar playback/repeat tidak tampak berhenti lama
    ; sebelum gerakan pertama dimulai.
    If $n = 0 Then $delay = 0
    $g_lastRecordTimer = TimerInit()
    ReDim $g_macro[$n + 1][4]
    $g_macro[$n][0] = $type
    $g_macro[$n][1] = $x
    $g_macro[$n][2] = $y
    $g_macro[$n][3] = $delay
EndFunc

Func AddFinalMacroPause()
    If UBound($g_macro) = 0 Then Return

    Local $delay = Int(TimerDiff($g_lastRecordTimer))
    ; Abaikan jeda sangat kecil agar stop record tidak menambah event kosong yang tidak perlu.
    If $delay < 80 Then Return

    Local $pos = MouseGetPos()
    Local $n = UBound($g_macro)
    ReDim $g_macro[$n + 1][4]
    $g_macro[$n][0] = "pause"
    $g_macro[$n][1] = $pos[0]
    $g_macro[$n][2] = $pos[1]
    $g_macro[$n][3] = $delay
    $g_lastRecordTimer = TimerInit()
EndFunc

Func ToggleMacroPlay()
    If $g_macroPlaying Then
        StopMacroPlay()
    Else
        StartMacroPlay()
    EndIf
EndFunc

Func StartMacroPlay()
    If $g_recording Then Return
    If UBound($g_macro) = 0 Then
        MsgBox(48, $APP_TITLE, "Belum ada macro yang bisa dijalankan." & @CRLF & "Record macro baru atau klik Load macro dulu.")
        Return
    EndIf

    SaveSettingsFromGui()
    $g_macroPlaying = True
    $g_stopRequested = False
    GUICtrlSetData($idMacroPlayToggle, "■ Stop Play")
    GUICtrlSetData($idMacroStatus, "Status: playing")
    If _IsChecked($idMacroHide) Then GUISetState(@SW_MINIMIZE, $g_hGui)

    ; v1.9: Saat playback mulai, kursor sekarang berjalan halus dari posisi saat ini
    ; ke titik awal aksi macro. Ini mencegah teleport mendadak ke posisi rekaman.
    ; Titik awal macro tetap dari hasil rekaman; posisi sebelum play tidak disimpan sebagai event.
    SmoothMoveToMacroEntryPoint()
    If Not $g_macroPlaying Then Return

    Local $repeatCount = Number(GUICtrlRead($idMacroRepeatCount))
    If $repeatCount < 1 Then $repeatCount = 1
    Local $repeatUntilStopped = _IsChecked($idMacroRepeatUntilStopped)
    Local $r = 0

    While $g_macroPlaying
        $r += 1
        PlayMacroOnce()
        If Not $g_macroPlaying Then ExitLoop

        ; Repeat until stopped harus mengabaikan repeat count.
        ; Ini juga mencegah radio state yang nyangkut membuat macro berhenti setelah 1 putaran.
        If Not $repeatUntilStopped Then
            If $r >= $repeatCount Then ExitLoop
        EndIf

        If _IsChecked($idMacroReturnToStart) And (UBound($g_macro) > 0) Then
            SmoothReturnToMacroStart()
            If Not $g_macroPlaying Then ExitLoop
        EndIf

        SleepMacroInterruptible(GetMacroRepeatIntervalMs())
    WEnd

    StopMacroPlay()
EndFunc

Func StopMacroPlay()
    $g_macroPlaying = False
    $g_stopRequested = True
    GUICtrlSetData($idMacroPlayToggle, "▶ Play")
    GUICtrlSetData($idMacroStatus, "Status: stopped")
    If _IsChecked($idMacroHide) Then GUISetState(@SW_RESTORE, $g_hGui)
EndFunc

Func PlayMacroOnce()
    Local $speed = Number(GUICtrlRead($idMacroSpeed))
    If $speed <= 0 Then $speed = 1

    ; v2.0:
    ; Playback dimulai dari klik pertama/mouse-down pertama, bukan dari gerakan mouse
    ; pertama saat rekam dimulai. Gerakan awal sebelum klik pertama dianggap sebagai
    ; "persiapan tangan" dan sudah digantikan oleh SmoothMoveToMacroEntryPoint().
    ; Ini mencegah kursor sudah bergerak halus ke klik pertama, lalu tiba-tiba teleport
    ; balik ke titik gerakan awal rekaman.
    Local $startIndex = GetMacroStartIndex()

    Local $i
    For $i = $startIndex To UBound($g_macro) - 1
        If Not $g_macroPlaying Then Return
        Local $delay = Int(Number($g_macro[$i][3]) / $speed)
        If $i = $startIndex Then $delay = 0
        If $delay > 0 Then SleepMacroInterruptible($delay)
        If Not $g_macroPlaying Then Return
        Local $type = $g_macro[$i][0]
        Local $x = Number($g_macro[$i][1])
        Local $y = Number($g_macro[$i][2])

        Switch $type
            Case "pause"
                ; Delay untuk pause sudah dijalankan sebelum switch. Tidak perlu aksi mouse.
            Case "move"
                MouseMove($x, $y, 0)
            Case "ldown"
                ForceMouseAt($x, $y)
                MouseDown("left")
            Case "lup"
                ForceMouseAt($x, $y)
                MouseUp("left")
            Case "rdown"
                ForceMouseAt($x, $y)
                MouseDown("right")
            Case "rup"
                ForceMouseAt($x, $y)
                MouseUp("right")
            Case "mdown"
                ForceMouseAt($x, $y)
                MouseDown("middle")
            Case "mup"
                ForceMouseAt($x, $y)
                MouseUp("middle")
        EndSwitch
    Next
EndFunc

Func GetMacroRepeatIntervalMs()
    Return (Number(GUICtrlRead($idMacroIntervalH)) * 3600 + Number(GUICtrlRead($idMacroIntervalM)) * 60 + Number(GUICtrlRead($idMacroIntervalS))) * 1000
EndFunc

Func SleepMacroInterruptible($ms)
    Local $remain = Int($ms)
    While $g_macroPlaying And $remain > 0
        Local $chunk = 20
        If $remain < $chunk Then $chunk = $remain
        Sleep($chunk)
        $remain -= $chunk
    WEnd
EndFunc

Func SmoothReturnToMacroStart()
    If UBound($g_macro) = 0 Then Return
    ; v2.5: saat looping, pakai jalur pembuka yang sama seperti awal play.
    ; Macro utama tetap dimulai dari klik pertama, tetapi kursor diberi kesempatan
    ; menyentuh titik pemicu sebelum klik jika titik itu memang ada saat rekaman.
    SmoothMoveToMacroEntryPoint()
EndFunc

Func SmoothMoveToMacroEntryPoint()
    If UBound($g_macro) = 0 Then Return

    Local $startIndex = GetMacroStartIndex()
    Local $targetX = Number($g_macro[$startIndex][1])
    Local $targetY = Number($g_macro[$startIndex][2])

    ; v2.5:
    ; Titik klik pertama tetap menjadi awal macro sebenarnya.
    ; Namun untuk GUI auto-hide/hover, klik pertama kadang bukan titik pemicu.
    ; Contoh: taskbar auto-hide perlu kursor menyentuh sisi bawah layar dulu,
    ; lalu baru ikon taskbar bisa diklik. Karena gerakan awal rekaman tidak boleh
    ; diputar utuh lagi, kita ambil hanya 1 titik pemicu paling penting sebelum
    ; klik pertama: titik yang lebih dekat ke tepi layar dibanding titik klik.
    Local $anchor = GetPreClickTriggerPoint($startIndex, $targetX, $targetY)
    If IsArray($anchor) And $anchor[0] = 1 Then
        SmoothMoveToPoint(Number($anchor[1]), Number($anchor[2]), 80)
        ; Waktu kecil agar GUI auto-hide/hover sempat terbuka sebelum lanjut ke klik.
        Sleep(180)
    EndIf

    SmoothMoveToPoint($targetX, $targetY, 140)
    ForceMouseAt($targetX, $targetY)
EndFunc

Func GetMacroStartIndex()
    If UBound($g_macro) = 0 Then Return 0

    Local $i
    For $i = 0 To UBound($g_macro) - 1
        Local $t = $g_macro[$i][0]
        If $t = "ldown" Or $t = "rdown" Or $t = "mdown" Then Return $i
    Next

    ; Fallback untuk macro yang cuma berisi gerakan tanpa klik.
    For $i = 0 To UBound($g_macro) - 1
        If $g_macro[$i][0] <> "pause" Then Return $i
    Next

    Return 0
EndFunc

Func GetPreClickTriggerPoint($startIndex, $clickX, $clickY)
    Local $result[3] = [0, 0, 0]
    If $startIndex <= 0 Then Return $result

    Local $screenW = @DesktopWidth
    Local $screenH = @DesktopHeight
    Local $clickEdge = _Min4($clickX, ($screenW - 1) - $clickX, $clickY, ($screenH - 1) - $clickY)

    Local $bestIndex = -1
    Local $bestEdge = 999999
    Local $i

    For $i = 0 To $startIndex - 1
        If $g_macro[$i][0] <> "move" Then ContinueLoop
        Local $x = Number($g_macro[$i][1])
        Local $y = Number($g_macro[$i][2])
        Local $edge = _Min4($x, ($screenW - 1) - $x, $y, ($screenH - 1) - $y)

        ; Ambil titik yang paling dekat ke sisi layar, tapi hanya kalau memang
        ; jauh lebih "memicu" dibanding titik klik pertama. Ini menjaga v2.0:
        ; gerakan random awal tetap tidak diputar ulang.
        If $edge < $bestEdge Then
            $bestEdge = $edge
            $bestIndex = $i
        EndIf
    Next

    If $bestIndex >= 0 Then
        Local $ax = Number($g_macro[$bestIndex][1])
        Local $ay = Number($g_macro[$bestIndex][2])
        Local $distFromClick = Sqrt((($ax - $clickX) * ($ax - $clickX)) + (($ay - $clickY) * ($ay - $clickY)))

        ; Syarat anchor:
        ; 1) lebih dekat ke tepi layar daripada titik klik, dan
        ; 2) cukup berbeda dari titik klik agar bukan noise posisi yang sama.
        If ($bestEdge + 8 < $clickEdge) And ($distFromClick > 10) Then
            $result[0] = 1
            $result[1] = $ax
            $result[2] = $ay
        EndIf
    EndIf

    Return $result
EndFunc

Func _Min4($a, $b, $c, $d)
    Local $m = $a
    If $b < $m Then $m = $b
    If $c < $m Then $m = $c
    If $d < $m Then $m = $d
    Return $m
EndFunc

Func SmoothMoveToPoint($targetX, $targetY, $settleMs = 120)
    Local $pos = MouseGetPos()
    Local $startX = Number($pos[0])
    Local $startY = Number($pos[1])
    Local $dx = Number($targetX) - $startX
    Local $dy = Number($targetY) - $startY
    Local $dist = Sqrt(($dx * $dx) + ($dy * $dy))
    If $dist <= 2 Then Return

    Local $speed = Number(GUICtrlRead($idMacroReturnSpeed))
    If $speed < 1 Then $speed = 20
    If $speed > 100 Then $speed = 100

    ; v2.4:
    ; Jangan pakai MouseMove($x,$y,$speed) bawaan untuk gerakan pembuka/penutup.
    ; Pada beberapa GUI auto-hide/hover, gerakan bawaan terlalu "bersih"/cepat sehingga
    ; event hover tidak selalu sempat diproses. Di sini kursor digerakkan lewat titik
    ; kecil bertahap + Sleep singkat agar target GUI menerima WM_MOUSEMOVE/hover lebih
    ; mirip gerakan manusia, tanpa mengembalikan gerakan awal rekaman v1.9.
    Local $stepPx = 4 + Int((100 - $speed) / 5) ; speed besar = step lebih kecil/halus
    If $stepPx < 3 Then $stepPx = 3
    If $stepPx > 22 Then $stepPx = 22

    Local $steps = Int($dist / $stepPx)
    If $steps < 1 Then $steps = 1

    Local $delay = Int(18 - ($speed / 8))
    If $delay < 3 Then $delay = 3
    If $delay > 18 Then $delay = 18

    Local $i
    For $i = 1 To $steps
        If Not $g_macroPlaying Then Return
        Local $nx = Int($startX + ($dx * $i / $steps))
        Local $ny = Int($startY + ($dy * $i / $steps))
        MouseMove($nx, $ny, 0)
        Sleep($delay)
    Next

    ForceMouseAt($targetX, $targetY)
    ; Beri waktu kecil agar GUI yang dipicu hover/auto-hide sempat muncul sebelum klik.
    If $settleMs > 0 Then Sleep($settleMs)
EndFunc

Func ForceMouseAt($targetX, $targetY)
    ; AutoIt kadang berhenti 1-3 px dari target saat DPI/GUI tertentu.
    ; Paksa posisi akhir agar event klik/down/up memakai koordinat yang sama
    ; dengan titik click pertama yang terekam.
    Local $tries
    For $tries = 1 To 3
        MouseMove(Int($targetX), Int($targetY), 0)
        Sleep(10)
        Local $pos = MouseGetPos()
        If Abs($pos[0] - Int($targetX)) <= 1 And Abs($pos[1] - Int($targetY)) <= 1 Then ExitLoop
    Next
EndFunc

Func EnsureMacroDir()
    If Not FileExists($MACRO_DIR) Then DirCreate($MACRO_DIR)
EndFunc

Func BuildDefaultMacroName()
    Return "macro_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC & ".sacm"
EndFunc

Func NormalizeMacroPath($path)
    Local $clean = StringStripWS($path, 3)
    If $clean = "" Then Return ""
    If StringRight(StringLower($clean), 5) <> ".sacm" Then $clean &= ".sacm"
    Return $clean
EndFunc

Func SaveMacroDialog()
    If UBound($g_macro) = 0 Then
        MsgBox(48, $APP_TITLE, "Belum ada macro yang bisa disimpan.")
        Return
    EndIf

    EnsureMacroDir()
    Local $defaultName = BuildDefaultMacroName()
    Local $path = FileSaveDialog("Save macro", $MACRO_DIR, "Safe Auto Clicker Macro (*.sacm)", $FD_PROMPTOVERWRITE, $defaultName, $g_hGui)
    If @error Then Return

    $path = NormalizeMacroPath($path)
    If $path = "" Then Return

    If SaveMacroToFile($path, True) Then
        IniWrite($INI_FILE, "macro", "last_macro_path", $path)
        GUICtrlSetData($idMacroStatus, "Status: saved")
    EndIf
EndFunc

Func LoadMacroDialog()
    EnsureMacroDir()
    Local $lastPath = IniRead($INI_FILE, "macro", "last_macro_path", "")
    Local $startDir = $MACRO_DIR
    If $lastPath <> "" Then
        Local $slash = StringInStr($lastPath, "\", 0, -1)
        If $slash > 0 Then $startDir = StringLeft($lastPath, $slash - 1)
    EndIf

    Local $path = FileOpenDialog("Load macro", $startDir, "Safe Auto Clicker Macro (*.sacm)|All files (*.*)", BitOR($FD_FILEMUSTEXIST, $FD_PATHMUSTEXIST), "", $g_hGui)
    If @error Then Return

    If LoadMacroFromFile($path, True) Then
        IniWrite($INI_FILE, "macro", "last_macro_path", $path)
        GUICtrlSetData($idMacroStatus, "Status: loaded")
    EndIf
EndFunc

Func SaveMacroToFile($path, $showMessage = False)
    EnsureMacroDir()
    $path = NormalizeMacroPath($path)
    If $path = "" Then Return 0

    Local $fh = FileOpen($path, 2)
    If $fh = -1 Then
        If $showMessage Then MsgBox(16, $APP_TITLE, "Gagal menyimpan macro ke:" & @CRLF & $path)
        Return 0
    EndIf

    FileWriteLine($fh, "SACM_V2")
    Local $i
    For $i = 0 To UBound($g_macro) - 1
        FileWriteLine($fh, $g_macro[$i][0] & "|" & $g_macro[$i][1] & "|" & $g_macro[$i][2] & "|" & $g_macro[$i][3])
    Next
    FileClose($fh)

    If $showMessage Then MsgBox(64, $APP_TITLE, "Macro tersimpan:" & @CRLF & $path)
    Return 1
EndFunc

Func LoadMacroFromFile($path, $showMessage = False)
    If Not FileExists($path) Then
        If $showMessage Then MsgBox(48, $APP_TITLE, "File macro tidak ditemukan:" & @CRLF & $path)
        Return 0
    EndIf

    Local $content = FileRead($path)
    If $content = "" Then
        If $showMessage Then MsgBox(48, $APP_TITLE, "File macro kosong atau tidak bisa dibaca.")
        Return 0
    EndIf

    Local $lines = StringSplit(StringStripCR($content), @LF, 1)
    If $lines[0] < 1 Then Return 0

    ReDim $g_macro[0][4]
    Local $startLine = 1
    If StringLeft(StringUpper(StringStripWS($lines[1], 3)), 4) = "SACM" Then $startLine = 2

    Local $i
    For $i = $startLine To $lines[0]
        If StringStripWS($lines[$i], 3) = "" Then ContinueLoop
        Local $p = StringSplit($lines[$i], "|", 2)
        If UBound($p) >= 4 Then
            Local $n = UBound($g_macro)
            ReDim $g_macro[$n + 1][4]
            $g_macro[$n][0] = $p[0]
            $g_macro[$n][1] = $p[1]
            $g_macro[$n][2] = $p[2]
            $g_macro[$n][3] = $p[3]
        EndIf
    Next

    GUICtrlSetData($idMacroCount, "Recorded events: " & UBound($g_macro))
    If UBound($g_macro) = 0 Then
        If $showMessage Then MsgBox(48, $APP_TITLE, "File terbaca, tapi tidak ada event macro di dalamnya.")
        Return 0
    EndIf

    If $showMessage Then MsgBox(64, $APP_TITLE, "Macro dimuat:" & @CRLF & $path)
    Return 1
EndFunc

; =========================
; Helpers
; =========================
Func _IsChecked($ctrl)
    ; v2.8:
    ; Jangan return Boolean True/False karena saat ditulis ke INI AutoIt bisa menyimpan
    ; sebagai teks "True"/"False". Versi lama LoadSettings hanya membaca angka 1/0,
    ; sehingga checkbox/radio terlihat tidak tersimpan setelah aplikasi dibuka ulang.
    ; Sekarang fungsi ini selalu mengembalikan 1 atau 0.
    If BitAND(GUICtrlRead($ctrl), $GUI_CHECKED) = $GUI_CHECKED Then Return 1
    Return 0
EndFunc

Func _SetCheck($ctrl, $value)
    ; v2.8:
    ; Kompatibel dengan INI lama yang mungkin sudah berisi True/False
    ; dan INI baru yang berisi 1/0.
    Local $text = StringLower(StringStripWS(String($value), 3))
    If Number($value) = 1 Or $text = "true" Or $text = "checked" Then
        GUICtrlSetState($ctrl, $GUI_CHECKED)
    Else
        GUICtrlSetState($ctrl, $GUI_UNCHECKED)
    EndIf
EndFunc

; Minimal WinAPI helpers to avoid depending on extra UDF behavior.
Func _WinAPI_WindowFromPoint($x, $y)
    Local $aRet = DllCall($g_hDll, "hwnd", "WindowFromPoint", "long", $x, "long", $y)
    If @error Or Not IsArray($aRet) Then Return 0
    Return $aRet[0]
EndFunc

Func _WinAPI_GetAncestor($hWnd, $gaFlags)
    Local $aRet = DllCall($g_hDll, "hwnd", "GetAncestor", "hwnd", $hWnd, "uint", $gaFlags)
    If @error Or Not IsArray($aRet) Then Return 0
    Return $aRet[0]
EndFunc
