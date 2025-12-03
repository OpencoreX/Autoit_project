#RequireAdmin

#include <GUIConstantsEx.au3>
#include <ProgressConstants.au3>
#include <WindowsConstants.au3>
#include <MsgBoxConstants.au3>
#include <AutoItConstants.au3>

; --------------------------------------------------------
; CONFIG
; --------------------------------------------------------
Global $ProcessName = "app.exe"
Global $ProcessPath = "C:\Users\" & @UserName & "\AppData\Local\Seliware\app.exe"

Global $CheckInterval = 5       ; ทุกกี่วินาทีให้เช็คสถานะโปรเซส
Global $Counter = 0

Global $NetTimeoutSec = 60      ; ถ้าไม่มี connection นานกี่วินาทีให้ถือว่าเน็ตตาย
Global $NoNetCount = 0          ; ตัวนับเวลาที่ไม่มี connection (ทีละ CheckInterval)

; --------------------------------------------------------
; GUI ขนาดเล็ก
; --------------------------------------------------------
$gui = GUICreate("Seliware Watchdog", 520, 260, -1, -1)

GUICtrlCreateLabel("กำลังตรวจสอบโปรเซส: " & $ProcessName, 20, 20, 300, 25)

; label สถานะหลัก
Global $lblStatus = GUICtrlCreateLabel("สถานะ: รอเริ่มทำงาน...", 20, 50, 460, 25)

GUICtrlCreateLabel("Progress:", 20, 90, 100, 20)
Global $Progress = GUICtrlCreateProgress(20, 115, 480, 22)

Global $btnStart = GUICtrlCreateButton("เริ่ม Watchdog", 80, 170, 150, 40)
Global $btnStop  = GUICtrlCreateButton("หยุด Watchdog", 280, 170, 150, 40)

GUISetState(@SW_SHOW)

Global $Running = False

; --------------------------------------------------------
; MAIN LOOP
; --------------------------------------------------------
While True
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            Exit

        Case $btnStart
            $Running = True
            GUICtrlSetData($lblStatus, "สถานะ: Watchdog ทำงานแล้ว")
            _StartWatchdog()

        Case $btnStop
            $Running = False
            GUICtrlSetData($lblStatus, "สถานะ: หยุดแล้ว")
    EndSwitch

    Sleep(50)
WEnd


; --------------------------------------------------------
; เริ่ม watchdog loop
; --------------------------------------------------------
Func _StartWatchdog()
    AdlibRegister("_CheckLoop", 1000) ; เรียกทุก 1 วินาที
EndFunc


; --------------------------------------------------------
; LOOP check ทุก 1 วินาที
; --------------------------------------------------------
Func _CheckLoop()
    If Not $Running Then
        GUICtrlSetData($Progress, 0)
        $Counter = 0
        $NoNetCount = 0
        Return
    EndIf

    ; นับเวลาเพื่อเช็คโปรเซส
    $Counter += 1
    GUICtrlSetData($Progress, Int(($Counter / $CheckInterval) * 100))

    If $Counter >= $CheckInterval Then
        $Counter = 0
        GUICtrlSetData($Progress, 0)
        _VerifyProcessAndNet()
    EndIf
EndFunc


; --------------------------------------------------------
; ตรวจโปรเซส + ตรวจการใช้เน็ต
; --------------------------------------------------------
Func _VerifyProcessAndNet()
    Local $list = ProcessList($ProcessName)

    ; ---------- ไม่พบโปรเซส ----------
    If $list[0][0] = 0 Then
        GUICtrlSetData($lblStatus, "สถานะ: ไม่พบโปรเซส → เปิดใหม่")
        _RestartApp()
        $NoNetCount = 0
        Return
    EndIf

    Local $pid = $list[1][1]

    ; ---------- เช็คว่าค้าง ----------
    If _IsHung($pid) Then
        GUICtrlSetData($lblStatus, "สถานะ: ค้าง → Restart")
        ProcessClose($pid)
        Sleep(800)
        _RestartApp()
        $NoNetCount = 0
        Return
    EndIf

    ; ---------- เช็ค Network ----------
    If _HasActiveNetConnection($pid) Then
        ; มี connection ปกติ
        $NoNetCount = 0
        GUICtrlSetData($lblStatus, "สถานะ: ทำงานปกติ (PID=" & $pid & ", NET OK)")
    Else
        ; ไม่มี connection รอบนี้
        $NoNetCount += $CheckInterval

        GUICtrlSetData($lblStatus, "สถานะ: ไม่มีการเชื่อมต่อเน็ตมา " & $NoNetCount & " วินาที")

        If $NoNetCount >= $NetTimeoutSec Then
            GUICtrlSetData($lblStatus, "สถานะ: เน็ตไม่ขยับเกิน " & $NetTimeoutSec & " วิ → Restart")
            _ForceRestart()
            $NoNetCount = 0
        EndIf
    EndIf
EndFunc


; --------------------------------------------------------
; เช็คว่ามี TCP connection ของ PID นี้อยู่ไหม (ผ่าน netstat)
; --------------------------------------------------------
Func _HasActiveNetConnection($pid)
    ; netstat -ano | find "PID"
    Local $cmd = 'netstat -ano | find " ' & $pid & '"'
    Local $hProc = Run(@ComSpec & " /c " & $cmd, "", @SW_HIDE, $STDOUT_CHILD)

    If $hProc = 0 Then Return False

    Local $sOut = ""
    While 1
        Local $chunk = StdoutRead($hProc)
        If @error Then ExitLoop
        If $chunk = "" Then
            If Not ProcessExists($hProc) Then ExitLoop
            Sleep(10)
        Else
            $sOut &= $chunk
        EndIf
    WEnd

    ; ถ้ามีผลลัพธ์ แสดงว่ามี connection อย่างน้อย 1 รายการ
    $sOut = StringStripWS($sOut, 8)
    If $sOut = "" Then
        Return False
    Else
        ; จะไม่ฟิลเตอร์ state (ESTABLISHED/อื่นๆ) แล้ว ใช้แค่มี/ไม่มีพอ
        Return True
    EndIf
EndFunc


; --------------------------------------------------------
; Detect Hung (ค้าง)
; --------------------------------------------------------
Func _IsHung($pid)
    Local $hWnd = WinGetHandle("[PID:" & $pid & "]")
    If $hWnd = 0 Then Return False

    Local $ret = DllCall("user32.dll", "bool", "IsHungAppWindow", "hwnd", $hWnd)
    If @error Then Return False
    Return $ret[0]
EndFunc


; --------------------------------------------------------
; เปิดโปรแกรมและ Resize 1130×650
; --------------------------------------------------------
Func _RestartApp()
    If Not FileExists($ProcessPath) Then
        GUICtrlSetData($lblStatus, "สถานะ: ERROR – หาไฟล์ไม่พบ!")
        Return
    EndIf

    Run($ProcessPath)
    Sleep(1500)
    _ForceResizeWindow()
    GUICtrlSetData($lblStatus, "สถานะ: เปิดใหม่สำเร็จ")
EndFunc


; --------------------------------------------------------
; Force restart: ปิดก่อนแล้วเปิดใหม่ + Resize
; --------------------------------------------------------
Func _ForceRestart()
    Local $list = ProcessList($ProcessName)
    If $list[0][0] > 0 Then
        ProcessClose($ProcessName)
        Sleep(800)
    EndIf

    _RestartApp()
EndFunc


; --------------------------------------------------------
; Resize app.exe window to 1130×650
; --------------------------------------------------------
Func _ForceResizeWindow()
    ; Electron / Seliware ส่วนใหญ่เป็นคลาสนี้
    Local $hWnd = WinWait("[CLASS:Chrome_WidgetWin_1]", "", 10)
    If $hWnd <> "" Then
        WinMove($hWnd, "", 100, 50, 1130, 650)
    EndIf
EndFunc
