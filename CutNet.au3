#RequireAdmin
#include <GUIConstantsEx.au3>
#include <MsgBoxConstants.au3>
#include <FileConstants.au3>

Global $SelectedEXE = ""
Global $RuleName = "AutoIt_Block_Net_Rule"

#Region ### GUI ###
$gui = GUICreate("โปรแกรมตัดเน็ตด้วย AutoIt", 430, 220)

$btnChoose = GUICtrlCreateButton("เลือกไฟล์ EXE", 30, 30, 160, 40)
$lblFile   = GUICtrlCreateLabel("ยังไม่ได้เลือกไฟล์...", 30, 80, 360, 30)

$btnBlock  = GUICtrlCreateButton("บล็อคอินเทอร์เน็ต", 30, 130, 160, 40)
$btnUnblock = GUICtrlCreateButton("ปลดบล็อคอินเทอร์เน็ต", 230, 130, 160, 40)

GUISetState(@SW_SHOW)
#EndRegion ### GUI ###

While 1
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            Exit

        Case $btnChoose
            _ChooseEXE()

        Case $btnBlock
            _BlockNet()

        Case $btnUnblock
            _UnblockNet()
    EndSwitch
WEnd


; ================================
; ฟังก์ชันเลือกโปรแกรม
; ================================
Func _ChooseEXE()
    Local $file = FileOpenDialog("เลือกไฟล์ EXE", @ScriptDir, "Programs (*.exe)", $FD_FILEMUSTEXIST)

    If @error Then Return

    $SelectedEXE = $file
    GUICtrlSetData($lblFile, "เลือกไฟล์: " & $file)
EndFunc


; ================================
; ฟังก์ชันบล็อคอินเทอร์เน็ต
; ================================
Func _BlockNet()
    If $SelectedEXE = "" Then
        MsgBox($MB_ICONWARNING, "ผิดพลาด", "กรุณาเลือกไฟล์ EXE ก่อน")
        Return
    EndIf

    Local $cmd = 'netsh advfirewall firewall add rule name="' & $RuleName & '" dir=out action=block program="' & $SelectedEXE & '" enable=yes'
    RunWait(@ComSpec & " /c " & $cmd, "", @SW_HIDE)

    MsgBox($MB_ICONINFORMATION, "สำเร็จ", "บล็อคเน็ตเรียบร้อยแล้วสำหรับ" & @CRLF & $SelectedEXE)
EndFunc


; ================================
; ฟังก์ชันปลดบล็อค
; ================================
Func _UnblockNet()
    Local $cmd = 'netsh advfirewall firewall delete rule name="' & $RuleName & '"'
    RunWait(@ComSpec & " /c " & $cmd, "", @SW_HIDE)

    MsgBox($MB_ICONINFORMATION, "คืนค่า", "ปลดบล็อคอินเทอร์เน็ตแล้ว")
EndFunc
