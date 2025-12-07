#RequireAdmin
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <Date.au3>
#include <Timers.au3>
#include <ColorConstants.au3>
#include <Array.au3>

Global $shutdownTime = 0, $force = False, $timerRunning = False

; ====== MODERN UI COLORS ======
Global Const $BG = 0x222831
Global Const $PANEL = 0x31363F
Global Const $BTN1 = 0x0081C9
Global Const $BTN2 = 0xD53636
Global Const $TEXT = 0xE8E8E8

; ================= UI ===================
GUICreate("Shutdown Scheduler PRO", 450, 480)
GUISetBkColor($BG)
GUISetFont(10, 400, 0, "Segoe UI")

GUICtrlCreateLabel("⚙ ตั้งเวลาปิดคอม + บันทึกงาน MSOffice / VSCode / Visual Studio", 20, 10, 430)
GUICtrlSetColor(-1, $TEXT)
GUICtrlSetFont(-1, 12, 800)

; --- Time setup ---
GUICtrlCreateGroup("", 10, 50, 430, 120)
GUICtrlSetBkColor(-1, $PANEL)

GUICtrlCreateLabel("ปิดเครื่องในอีก:", 25, 75)
GUICtrlSetColor(-1, $TEXT)
Global $inpHour = GUICtrlCreateInput("0", 150, 70, 40)
GUICtrlCreateLabel("ชม.", 195, 75)
GUICtrlSetColor(-1, $TEXT)

Global $inpMin = GUICtrlCreateInput("0", 240, 70, 40)
GUICtrlCreateLabel("นาที", 285, 75)
GUICtrlSetColor(-1, $TEXT)

GUICtrlCreateLabel("หรือปิดเวลา (HH:MM):", 25, 110)
GUICtrlSetColor(-1, $TEXT)
Global $inpTime = GUICtrlCreateInput("22:30", 170, 105, 70)

Global $chkForce = GUICtrlCreateCheckbox("บังคับปิดเครื่อง (Force Shutdown)", 25, 145)
GUICtrlSetColor(-1, $TEXT)

; Status Panel
GUICtrlCreateGroup("", 10, 180, 430, 140)
GUICtrlSetBkColor(-1, $PANEL)
GUICtrlCreateLabel("สถานะระบบ:", 25, 200)
GUICtrlSetColor(-1, $TEXT)

Global $lblStatus = GUICtrlCreateLabel("ยังไม่ได้ตั้งเวลา", 25, 220, 380)
GUICtrlSetColor($lblStatus, 0x00FF80)
GUICtrlSetFont($lblStatus, 11, 600)

Global $lblCountdown = GUICtrlCreateLabel("", 25, 250, 380)
GUICtrlSetColor(-1, 0x00D5FF)
GUICtrlSetFont(-1, 14, 800)

; Buttons
Global $btnSet = GUICtrlCreateButton("ตั้งเวลา", 40, 345, 160, 45)
GUICtrlSetBkColor($btnSet, $BTN1)
GUICtrlSetColor($btnSet, 0xFFFFFF)
GUICtrlSetFont($btnSet, 11, 600)

Global $btnCancel = GUICtrlCreateButton("ยกเลิก", 230, 345, 160, 45)
GUICtrlSetBkColor($btnCancel, $BTN2)
GUICtrlSetColor($btnCancel, 0xFFFFFF)
GUICtrlSetFont($btnCancel, 11, 600)

GUISetState(@SW_SHOW)


; ========= SAVE ONLY NECESSARY PROGRAMS ==========
Func SmartSaveWindows()
    Local $ListSave = ["devenv.exe", "code.exe", "WINWORD.EXE", "EXCEL.EXE", "POWERPNT.EXE", "notepad++.exe"]

    Local $Wins = WinList()

    For $i = 1 To $Wins[0][0]
        Local $title = $Wins[$i][0]
        Local $handle = $Wins[$i][1]

        If $title = "" Or $handle = "" Then ContinueLoop
        If Not BitAND(WinGetState($handle), 2) Then ContinueLoop

        Local $proc = WinGetProcess($handle)

        For $x = 0 To UBound($ListSave) - 1
            If ProcessExists($ListSave[$x]) = $proc Then
                ConsoleWrite("Saving: " & $title & @CRLF)
                WinActivate($handle)
                Sleep(300)
                Send("^s")
                Sleep(500)
            EndIf
        Next
    Next
EndFunc

Func ExecuteShutdown()
    SmartSaveWindows()
    Sleep(1500)

    If $force Then
        Run("shutdown.exe /s /f /t 0")
    Else
        Run("shutdown.exe /s /t 0")
    EndIf
EndFunc

Func ScheduleShutdown()
    Local $hrs = Number(GUICtrlRead($inpHour))
    Local $mins = Number(GUICtrlRead($inpMin))
    Local $tTime = GUICtrlRead($inpTime)
    $force = (GUICtrlRead($chkForce) = $GUI_CHECKED)

    If ($hrs > 0 Or $mins > 0) Then
        $shutdownTime = TimerInit() + (($hrs * 3600) + ($mins * 60)) * 1000
        $timerRunning = True
        GUICtrlSetData($lblStatus, "กำลังนับถอยหลัง...")
        Return
    EndIf

    If StringRegExp($tTime, "^\d{2}:\d{2}") Then
        Local $now = _NowCalc()
        Local $target = @YEAR & "/" & @MON & "/" & @MDAY & " " & $tTime & ":00"
        Local $diffSec = _DateDiff('s', $now, $target)
        If $diffSec <= 0 Then
            MsgBox(48, "ผิดพลาด", "เวลาใหม่ต้องมากกว่าปัจจุบัน")
            Return
        EndIf

        $shutdownTime = TimerInit() + ($diffSec * 1000)
        $timerRunning = True
        GUICtrlSetData($lblStatus, "ปิดเครื่องตามเวลา")
    Else
        MsgBox(48, "Error", "รูปแบบต้องเป็น HH:MM เช่น 23:40")
    EndIf
EndFunc

Func CancelShutdown()
    Run("shutdown.exe /a")
    $timerRunning = False
    GUICtrlSetData($lblStatus, "ยกเลิกคำสั่งแล้ว")
    GUICtrlSetData($lblCountdown, "")
EndFunc


; ================= MAIN LOOP ======================
While True
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            Exit
        Case $btnSet
            ScheduleShutdown()
        Case $btnCancel
            CancelShutdown()
    EndSwitch

    If $timerRunning Then
        Local $remain = Int(($shutdownTime - TimerInit()) / 1000)
        If $remain <= 0 Then
            GUICtrlSetData($lblCountdown, "กำลังปิดเครื่อง...")
            ExecuteShutdown()
            Exit
        EndIf

        Local $h = Int($remain / 3600)
        Local $m = Int(($remain Mod 3600) / 60)
        Local $s = $remain Mod 60

        GUICtrlSetData($lblCountdown, StringFormat("⏳ เหลือเวลา %02d:%02d:%02d", $h, $m, $s))
    EndIf
    Sleep(300)
WEnd