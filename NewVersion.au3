#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <GUIConstantsEx.au3>
#include <WinAPIProc.au3>
#include <WinAPIMem.au3>
#include <Array.au3>

Global Const $PROCESS_ALL_ACCESS = 0x1F0FFF
Global $ProcessName = "java.exe"
Global $ModuleName = "jvm.dll"
Global $hProcess = 0

Global $PosXOffsets[7] = [0x18, 0x3C, 0x24, 0x28, 0x4C, 0x4C, 0x4C]
Global $PosYOffsets[7] = [0x20, 0x24, 0x0C, 0x24, 0x0C, 0x24, 0x414]
Global $PosBaseOffset = 0x227B0 ; from your scan

Global $labelX, $labelY
Global $PosXAddress = 0, $PosYAddress = 0

; === Connect to java.exe ===
Func ConnectToProcess()
    Local $pid = ProcessExists($ProcessName)
    If Not $pid Then
        MsgBox(16, "Error", "Process '" & $ProcessName & "' not found!")
        Exit
    EndIf
    $hProcess = _WinAPI_OpenProcess($PROCESS_ALL_ACCESS, False, $pid)
    If @error Or $hProcess = 0 Then
        MsgBox(16, "Error", "Failed to open process!")
        Exit
    EndIf
    ConsoleWrite("[?] Connected to " & $ProcessName & ", Handle: 0x" & Hex($hProcess) & @CRLF)
EndFunc

; === Find base address of module ===
Func _GetModuleBaseAddress($module)
    Local $pid = ProcessExists($ProcessName)
    If $pid = 0 Then Return 0

    Local $hTmpProc = _WinAPI_OpenProcess(0x10 + 0x400, False, $pid)
    If $hTmpProc = 0 Then
        ConsoleWrite("[!] Failed to open temp process for module lookup." & @CRLF)
        Return 0
    EndIf

    Local $aMods = _WinAPI_EnumProcessModules($hTmpProc)
    If @error Or Not IsArray($aMods) Then
        ConsoleWrite("[!] Failed to enumerate modules." & @CRLF)
        Return 0
    EndIf

    For $i = 1 To $aMods[0]
        Local $modName = _WinAPI_GetModuleFileNameEx($hTmpProc, $aMods[$i])
        If StringInStr($modName, $module) Then
            ConsoleWrite("[?] Found base address for " & $module & ": 0x" & Hex($aMods[$i]) & @CRLF)
            Return $aMods[$i]
        EndIf
    Next

    ConsoleWrite("[!] Could not find module: " & $module & @CRLF)
    Return 0
EndFunc

; === Follow pointer chain ===
Func ResolvePointer($module, $baseOffset, $offsets)
    Local $modBase = _GetModuleBaseAddress($module)
    If $modBase = 0 Then Return 0

    Local $ptr = _ReadDWORD($modBase + $baseOffset)
    If $ptr = 0 Then Return 0

    For $i = 0 To UBound($offsets) - 2
        $ptr = _ReadDWORD($ptr + $offsets[$i])
        If $ptr = 0 Then Return 0
    Next

    Return $ptr + $offsets[UBound($offsets) - 1]
EndFunc

; === Read 4-byte int from memory ===
Func _ReadDWORD($addr)
    Local $buff = DllStructCreate("dword")
    Local $read
    If _WinAPI_ReadProcessMemory($hProcess, $addr, DllStructGetPtr($buff), 4, $read) Then
        Return DllStructGetData($buff, 1)
    EndIf
    Return 0
EndFunc

; === Basic GUI ===
Func CreateGUI()
    GUICreate("Zonorian Trainer", 150, 80)
    GUICtrlCreateLabel("X:", 10, 10, 40)
    $labelX = GUICtrlCreateLabel("N/A", 40, 10, 100)
    GUICtrlCreateLabel("Y:", 10, 30, 40)
    $labelY = GUICtrlCreateLabel("N/A", 40, 30, 100)
    GUISetState(@SW_SHOW)
EndFunc

; === MAIN ===
ConnectToProcess()
CreateGUI()

$PosXAddress = ResolvePointer($ModuleName, $PosBaseOffset, $PosXOffsets)
$PosYAddress = ResolvePointer($ModuleName, $PosBaseOffset + 4, $PosYOffsets)

ConsoleWrite("[X] Final X address: 0x" & Hex($PosXAddress) & @CRLF)
ConsoleWrite("[Y] Final Y address: 0x" & Hex($PosYAddress) & @CRLF)

While 1
    Switch GUIGetMsg()
        Case $GUI_EVENT_CLOSE
            Exit
    EndSwitch

    Local $x = _ReadDWORD($PosXAddress)
    Local $y = _ReadDWORD($PosYAddress)

    ConsoleWrite("X: " & $x & " | Y: " & $y & @CRLF)

    If $x > 0 And $y > 0 Then
        GUICtrlSetData($labelX, $x)
        GUICtrlSetData($labelY, $y)
    Else
        GUICtrlSetData($labelX, "-1")
        GUICtrlSetData($labelY, "-1")
    EndIf

    Sleep(100)
WEnd
