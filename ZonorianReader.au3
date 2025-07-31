#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=Include\RogueReader.ico
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Res_Description=Trainer for ProjectRogue
#AutoIt3Wrapper_Res_Fileversion=6.2.2.4
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_ProductName=Rogue Reader
#AutoIt3Wrapper_Res_ProductVersion=6
#AutoIt3Wrapper_Res_CompanyName=Training Trainers.LLC
#AutoIt3Wrapper_Res_LegalCopyright=Use only for authorized security testing.
#AutoIt3Wrapper_Res_LegalTradeMarks=TrainingTrainersLLC
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Run_AU3Check=n
#AutoIt3Wrapper_Run_Tidy=y
#AutoIt3Wrapper_Tidy_Stop_OnError=n
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****


#include <GUIConstantsEx.au3>
#include <File.au3>
#include <WindowsConstants.au3>
#include <WinAPI.au3>
#include <Process.au3>
#include <Array.au3> ; For _ArraySearch
#include <Misc.au3>

Global $bHotkeyDown = False
; ---------------------------------------------------------------------------------
; 1) Define fallback constants for Lock/Unlock if your AutoIt version doesn't have them
; ---------------------------------------------------------------------------------
If Not IsDeclared("SW_LOCKDRAW") Then
	Global Const $SW_LOCKDRAW = 133   ; numeric values introduced in v3.3.17
EndIf

If Not IsDeclared("SW_UNLOCKDRAW") Then
	Global Const $SW_UNLOCKDRAW = 134
EndIf

Opt("MouseCoordMode", 2)
Global $Beep = 1
Global $version = FileGetVersion(@ScriptFullPath)
Global Const $locationFile = @ScriptDir & "\Locations.ini"
Global $currentLocations = 1
Global $maxLocations = 20000
Global Const $sButtonConfigFile = @ScriptDir & "\NewButtonConfig.ini"

ConsoleWrite("Script Version: " & $version & @CRLF)

; --- Load Config Settings ---
Global $aTempBlocked[0][2]

If Not FileExists($sButtonConfigFile) Then CreateButtonDefaultConfig()
LoadButtonConfig()

Global $iCurrentIndex = 0
Global $aLocations = LoadLocations()                ; This may show error if the file is missing
Global $Debug = False
Global $LootIdleTimer = TimerInit()
Global $LootIdleWaiting = False
Global $LastMovementTime = TimerInit()
Global $LootQueued = False
Global $LootCount = 0
Global $LootReady = False
Global $LootTimer = TimerInit()
Global $PausedWalkerForLoot = False
Global $LastPlayerX = 0
Global $LastPlayerY = 0
Global $HadTarget = False
Global $LastTargetHeld = TimerInit()
Global $LastTargetTime = TimerInit()
Global $LootingCheckbox
Global $LootCheckX = -1
Global $LootCheckY = -1
Global $LootClickQueue[100][3] ; X, Y, ClickCount
Global $LootClickQueueSize = 0


; Define the game process and memory offsets
Global $ProcessName = "Project Rogue Client.exe"
Global $WindowName = "Project Rogue"
Global $TypeOffset = 0xBF91C8        ;  ---- ; 0=Player, 1=Monster, etc
Global $AttackModeOffset = 0xB6D458  ; ----
Global $PosXOffset = 0xBFBE68        ; ----
Global $PosYOffset = 0xBFBE60        ; ----
Global $HPOffset = 0x8DC70         ; ----
Global $MaxHPOffset = 0x8DC74      ; ----
Global $ChattOpenOffset = 0xB79130  ;  ----
Global $SicknessOffset = 0x8DE54    ; ----
Global $BackPack = 0x751E0         ; ----
Global $BackPackMax = 0x751E4         ;
Global $LastProcessID = 0

Global $MovmentSlider = 200 ;walk after removed from gui turned to solid state,
Global $AutoResumeWalker = False
Global $currentTime = TimerInit()
Global $LastHealTime = TimerInit()
Global $lastX = 0
Global $lastY = 0
Global $Running = True
Global $HealerStatus = 0
Global $CureStatus = 0
Global $TargetStatus = 0
Global $MoveToLocationsStatus = 0
Global $iPrevValue = 95
Global $MPrevValue = " "
Global $hProcess = 0
Global $BaseAddress = 0
Global $TypeAddress, $AttackModeAddress, $PosXAddress, $PosYAddress
Global $HPAddress, $MaxHPAddress, $ChattOpenAddress, $SicknessAddress
Global $Type, $Chat, $Sickness, $AttackMode

Global $sicknessArray = [ _
		1, 2, 65, 66, 67, 68, 69, 72, 73, 81, 97, 98, 99, 129, 130, 257, 258, 513, 514, 515, 577, 641, 642, _
		4097, 4098, 8193, 8194, 8195, 8257, 8258, 8705, 8706, 8707, 8708, 8709, 8712, 8713, _
		8721, 8737, 8769, 8770, 16385, 16386, 16449, 16450, 16451, 16452, 16897, _
		16898, 24577, 24578, 24579, 24581, 24582, 24583, 24585, 24609, 24641, _
		24642, 24643, 24645, 24646, 24647, 24649, 25089, 25090, 25091, 25093, _
		25094, 25095, 25097, 25121, 33283, 33284, 33285, 33286, 33287, 33288, _
		33289, 33291, 33293, 33294, 33295, 33793, 41985, 41986, 41987, 41988, _
		41989, 41990, 41991, 41993, 41995]

Global $TargetDelay = 400, $HealDelay = 1700

; -------------------
; Create the GUI
; -------------------
;...;
; Create the main GUI window
Global $Gui = GUICreate($version, 248, 360, 15, 15)

; Create labels
Global $TypeLabel = GUICtrlCreateLabel("Target: N/A", 105, 21, 115, 15)
GUICtrlSetFont($TypeLabel, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($TypeLabel, 0xBEBEBE)

Global $AttackModeLabel = GUICtrlCreateLabel("Attack: N/A", 105, 37, 115, 15)
GUICtrlSetFont($AttackModeLabel, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($AttackModeLabel, 0xBEBEBE)

Global $PosXLabel = GUICtrlCreateLabel("X: N/A", 11, 23, 75, 15)
GUICtrlSetFont($PosXLabel, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($PosXLabel, 0xBEBEBE)

Global $PosYLabel = GUICtrlCreateLabel("Y: N/A", 11, 39, 75, 15)
GUICtrlSetFont($PosYLabel, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($PosYLabel, 0xBEBEBE)

Global $HPLabel = GUICtrlCreateLabel("HP: N/A /", 10, 187, 45, 15)
GUICtrlSetFont($HPLabel, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($HPLabel, 0xBEBEBE)

Global $ChatLabel = GUICtrlCreateLabel("Chat: N/A", 105, 69, 115, 15)
GUICtrlSetFont($ChatLabel, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($ChatLabel, 0xBEBEBE)

Global $SicknessLabel = GUICtrlCreateLabel("Sickness: N/A", 105, 53, 115, 15)
GUICtrlSetFont($SicknessLabel, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($SicknessLabel, 0xBEBEBE)

Global $MaxHPLabel = GUICtrlCreateLabel("N/A", 55, 187, 30, 15)
GUICtrlSetFont($MaxHPLabel, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($MaxHPLabel, 0xBEBEBE)

Global $TargetLabel = GUICtrlCreateLabel("Target: Off", 10, 124, 75, 15)
GUICtrlSetFont($TargetLabel, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($TargetLabel, 0xBEBEBE)

Global $HealerLabel = GUICtrlCreateLabel("Healer: Off", 10, 92, 75, 15)
GUICtrlSetFont($HealerLabel, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($HealerLabel, 0xBEBEBE)

Global $WalkerLabel = GUICtrlCreateLabel("Walker: Off", 10, 140, 75, 15)
GUICtrlSetFont($WalkerLabel, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($WalkerLabel, 0xBEBEBE)

Global $BackPackLabel = GUICtrlCreateLabel("Weight: N/A", 10, 203, 75, 15)
GUICtrlSetFont($BackPackLabel, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($BackPackLabel, 0xBEBEBE)

Global $CureLabel = GUICtrlCreateLabel("Cure: Off", 10, 108, 75, 15)
GUICtrlSetFont($CureLabel, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($CureLabel, 0xBEBEBE)

; Create buttons
Global $KillButton = GUICtrlCreateButton("Kill Rogue", 10, 315, 110, 30)
Global $ExitButton = GUICtrlCreateButton("Exit", 120, 315, 110, 30)

; Create checkboxes
Global $MayhamCheckbox = GUICtrlCreateCheckbox("Mayham", 105, 175, 60, 20)
GUICtrlSetFont($MayhamCheckbox, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetState($MayhamCheckbox, $GUI_CHECKED)

Global $JugernautCheckbox = GUICtrlCreateCheckbox("Jugernaut", 170, 175, 115, 20)
GUICtrlSetFont($JugernautCheckbox, 8.5, 400, $GUI_FONTNORMAL)


Global $ReverseLoopCheckbox = GUICtrlCreateCheckbox("Reversed Walker", 105, 215, 115, 20)
GUICtrlSetFont($ReverseLoopCheckbox, 8.5, 400, $GUI_FONTNORMAL)

Global $LootingCheckbox = GUICtrlCreateCheckbox("Autoloot", 105, 195, 115, 20)
GUICtrlSetFont($LootingCheckbox, 8.5, 400, $GUI_FONTNORMAL)

Global $Checkbox = GUICtrlCreateCheckbox("Old Style Pothack", 105, 235, 115, 20)
GUICtrlSetFont($Checkbox, 8.5, 400, $GUI_FONTNORMAL)

; Create labels for sections
Global $Helpers = GUICtrlCreateLabel("HELPERS", 8, 75, 80, 15)
GUICtrlSetFont($Helpers, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($Helpers, 0x808080)

Global $Character = GUICtrlCreateLabel("CHARACTER", 8, 170, 80, 15)
GUICtrlSetFont($Character, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($Character, 0x808080)

Global $Position = GUICtrlCreateLabel("POSITION", 8, 5, 80, 15)
GUICtrlSetFont($Position, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($Position, 0x808080)

Global $Information = GUICtrlCreateLabel("INFORMATION", 103, 4, 120, 15)
GUICtrlSetFont($Information, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($Information, 0x808080)

Global $Options = GUICtrlCreateLabel("OPTIONS", 105, 160, 120, 11)
GUICtrlSetFont($Options, 8.5, 400, $GUI_FONTNORMAL)
GUICtrlSetBkColor($Options, 0x808080)

; Create toggle buttons
Global $HealToggle = GUICtrlCreateButton("HEAL", 95, 92, 60, 15)
GUICtrlSetFont($HealToggle, 8.5, 400, $GUI_FONTNORMAL)

Global $CureToggle = GUICtrlCreateButton("CURE", 95, 108, 60, 15)
GUICtrlSetFont($CureToggle, 8.5, 400, $GUI_FONTNORMAL)

Global $TargetToggle = GUICtrlCreateButton("TARGET", 95, 124, 60, 15)
GUICtrlSetFont($TargetToggle, 8.5, 400, $GUI_FONTNORMAL)

Global $WalkerToggle = GUICtrlCreateButton("WALKER", 95, 140, 60, 15)
GUICtrlSetFont($WalkerToggle, 8.5, 400, $GUI_FONTNORMAL)

Global $ToggleAll = GUICtrlCreateButton("ToggleAll", 155, 94, 71, 60)
GUICtrlSetFont($ToggleAll, 8.5, 400, $GUI_FONTNORMAL)

; Create a label for real HP
Global $HP2Label = GUICtrlCreateLabel("RealHp: N/A", 11, 224, 76, 21)
GUICtrlSetBkColor($HP2Label, 0x9D9597)

; Create a slider for healing
Global $healSlider = GUICtrlCreateSlider(10, 270, 226, 36)
GUICtrlSetData($healSlider, 85)

; Show the GUI
GUISetState(@SW_SHOW)

; --------------------------------------------------------------------------
;   :                      STREAMLINED MAIN LOOP
; --------------------------------------------------------------------------
While $Running
	Local $msg = GUIGetMsg()
	; ---- Handle GUI messages first ----
	Switch $msg
		Case $ExitButton, $GUI_EVENT_CLOSE
			_WinAPI_CloseHandle($hProcess)
			GUIDelete($Gui)
			Exit

		Case $KillButton
			Local $hWnd = WinGetHandle($WindowName)
			If $hWnd Then
				ProcessClose($ProcessName)
			EndIf

		Case $HealToggle
			ToggleHealer()

		Case $CureToggle
			ToggleCure()

		Case $TargetToggle
			ToggleTarget()

		Case $WalkerToggle
			ToggleWalker()

		Case $ToggleAll
			ToggleAllHelpers()
	EndSwitch

	; ---- Background processing ----
	; Check current process
	Local $CurrentPID = ProcessExists($ProcessName)

	If $CurrentPID = 0 Then
		If $hProcess <> 0 Then _WinAPI_CloseHandle($hProcess)
		$hProcess = 0
		$BaseAddress = 0
		$LastProcessID = 0
		Sleep(100)
		ContinueLoop
	EndIf

	; Check if new process instance launched
	If $CurrentPID <> $LastProcessID Then
		ConsoleWrite("[Watcher] Detected new process (PID changed): Reconnecting..." & @CRLF)
		If $hProcess <> 0 Then _WinAPI_CloseHandle($hProcess)
		$hProcess = 0
		$BaseAddress = 0
		$LastProcessID = $CurrentPID
		ConnectToBaseAddress()
	EndIf

	If $hProcess = 0 Or $BaseAddress = 0 Then
		Sleep(100)
		ContinueLoop
	EndIf


	GUIReadMemory()

	If $Chat = 0 Then
		If $CureStatus = 1 Then CureMe()
		If $HealerStatus = 1 Then TimeToHeal()
		If $TargetStatus = 1 Then AttackModeReader()
		If GUICtrlRead($LootingCheckbox) = $GUI_CHECKED And $AttackMode = +1 Then ScanAndLootNearbyItems()

		; ---- Mayham mode ----

		If GUICtrlRead($MayhamCheckbox) = $GUI_CHECKED And _IsPressed("12") And _IsPressed("04") Then ; ALT + MMB
			Local $Mouse = MouseGetPos()
			;ConsoleWrite("ALT + MMB" & @CRLF)
			;BackPack Drop Location 730, 320
			MouseClickDrag("left", $Mouse[0], $Mouse[1], 730, 320, 0)
			MouseMove($Mouse[0], $Mouse[1], 0)


		ElseIf GUICtrlRead($MayhamCheckbox) = $GUI_CHECKED And _IsPressed("04") Then
			;ConsoleWrite("MMB" & @CRLF)
			MouseClick("right")
			Sleep(10)

		EndIf

		; ---- Walker execution ----
		If $MoveToLocationsStatus = 1 And Not $LootQueued And $Chat = 0 Then
			Local $result = MoveToLocationsStep($aLocations, $iCurrentIndex)
			If @error Then $MoveToLocationsStatus = 0
		EndIf
	EndIf

	Sleep(50)
WEnd

GUIDelete($Gui)
_WinAPI_CloseHandle($hProcess)
ConsoleWrite("[Debug] Trainer closed by script end" & @CRLF)
Exit

; ------------------------------------------------------------------------------
;                               LOAD CONFIG
; ------------------------------------------------------------------------------
Func LoadButtonConfig()
	Local $sButtonConfigFile = @ScriptDir & "\NewButtonConfig.ini"

	; Define the hotkeys and default values
	Local $aKeys[8][2] = [ _
			["HealHotkey", "{" & Chr(96) & "}"], _
			["CureHotkey", "{-}"], _
			["TargetHotkey", "{=}"], _
			["ExitHotkey", "{/}"], _
			["SaveLocationHotkey", "{F7}"], _
			["EraseLocationsHotkey", "{F8}"], _
			["MoveToLocationsHotkey", "{!}"], _
			["LootHotkey", "{@}"] _
			]

	Local $bMissingKeys = False
	For $i = 0 To UBound($aKeys) - 1
		Local $sKey = IniRead($sButtonConfigFile, "Hotkeys", $aKeys[$i][0], "")
		If $sKey = "" Then
			ConsoleWrite("[Warning] Missing key: " & $aKeys[$i][0] & ". Will create default config." & @CRLF)
			$bMissingKeys = True
			ExitLoop
		EndIf
	Next

	; If any key was missing, recreate the default configuration
	If $bMissingKeys Then
		CreateButtonDefaultConfig()
	EndIf

	; Re-read keys
	For $i = 0 To UBound($aKeys) - 1
		Local $sKey = IniRead($sButtonConfigFile, "Hotkeys", $aKeys[$i][0], $aKeys[$i][1])

		Switch $aKeys[$i][0]
			Case "HealHotkey"
				HotKeySet($sKey, "Hotkeyshit")
			Case "CureHotkey"
				HotKeySet($sKey, "CureKeyShit")
			Case "TargetHotkey"
				HotKeySet($sKey, "TargetKeyShit")
			Case "ExitHotkey"
				HotKeySet($sKey, "KilledWithFire")
			Case "SaveLocationHotkey"
				HotKeySet($sKey, "SaveLocation")
			Case "EraseLocationsHotkey"
				HotKeySet($sKey, "EraseLocations")
			Case "MoveToLocationsHotkey"
				HotKeySet($sKey, "MoveToLocations")
			Case "LootHotkey"
				HotKeySet($sKey, "ToggleLooter")
		EndSwitch

		ConsoleWrite("[Info] Hotkey for " & $aKeys[$i][0] & " set to " & $sKey & @CRLF)
	Next
EndFunc   ;==>LoadButtonConfig


Func Min($a, $b)
	If $a < $b Then
		Return $a
	Else
		Return $b
	EndIf
EndFunc   ;==>Min

Func ScanAndLootNearbyItems()
	Global $hProcess, $BaseAddress, $WindowName
	Global $PosXAddress, $PosYAddress
	Global $Beep ; <-- This must be declared globally elsewhere

	Local Const $iniPath = @ScriptDir & "\Loot.ini"

	; ✅ NEW MEMORY OFFSETS
	Local $mouseXAddr = $BaseAddress + 0xA78248
	Local $mouseYAddr = $BaseAddress + 0xB6D464
	Local $itemBase = $BaseAddress + 0xA44254
	Local $typeBase = $BaseAddress + 0xA4425C

	Local $stride = 0x3C
	Local $maxItems = 100

	Local $origMemX = _ReadMemory($hProcess, $mouseXAddr)
	Local $origMemY = _ReadMemory($hProcess, $mouseYAddr)

	Local $px = _ReadMemory($hProcess, $PosXAddress)
	Local $py = _ReadMemory($hProcess, $PosYAddress)

	Local $dxArr[9] = [-1, 0, 1, -1, 0, 1, -1, 0, 1]
	Local $dyArr[9] = [-1, -1, -1, 0, 0, 0, 1, 1, 1]
	Local $clickX[9] = [320, 350, 380, 320, 350, 380, 320, 350, 380]
	Local $clickY[9] = [320, 320, 320, 350, 350, 350, 380, 380, 380]
	Local $memX[9] = [160, 175, 190, 160, 175, 190, 160, 175, 190]
	Local $memY[9] = [160, 160, 160, 175, 175, 175, 190, 190, 190]
	Local $dirName[9] = ["NW", "N", "NE", "W", "CENTER", "E", "SW", "S", "SE"]

	For $i = 0 To $maxItems - 1
		Local $addr = $itemBase + ($i * $stride)
		If _ReadMemory($hProcess, $addr) = 0 Then ContinueLoop

		Local $packed = _ReadMemory($hProcess, $addr + 0xC)
		Local $ix = BitAND($packed, 0xFFFF)
		Local $iy = BitShift($packed, 16)

		Local $TypeOffset = $typeBase + ($i * $stride)
		Local $itemID = Hex(_ReadMemory($hProcess, $TypeOffset), 6)

		; 🔄 Read Loot.ini
		Local $lootValue = IniRead($iniPath, "Loot", $itemID, "UNTRACKED")

		If $lootValue = "UNTRACKED" Then
			IniWrite($iniPath, "Loot", $itemID, "Item|True")
			ConsoleWrite("[Loot] 📥 New item added: " & $itemID & @CRLF)

			;If $Beep = 1 Then
			;	If FileExists(@ScriptDir & "\Include\Click.wav") Then
			;		SoundPlay(@ScriptDir & "\Include\Click.wav")
			;	EndIf
			;EndIf

			$lootValue = "Item|True"
		EndIf

		; ✅ FIXED: Always re-split lootValue after updating
		Local $parts = StringSplit($lootValue, "|", 2)
		If @error Or UBound($parts) < 2 Then ContinueLoop

		Local $itemName = $parts[0]
		Local $isLootable = ($parts[1] = "True")

		Local $dx = $ix - $px
		Local $dy = $iy - $py

		If Not $isLootable Then
			Local $newX = $ix + ($dx * 10)
			Local $newY = $iy + ($dy * 10)

			For $j = 0 To $maxItems - 1
				If $j = $i Then ContinueLoop
				Local $otherPacked = _ReadMemory($hProcess, $itemBase + ($j * $stride) + 0xC)
				Local $ox = BitAND($otherPacked, 0xFFFF)
				Local $oy = BitShift($otherPacked, 16)
				If $ox = $newX And $oy = $newY Then
					$newX += 1
					$newY += 1
				EndIf
			Next

			Local $newPacked = BitOR(BitShift($newY, -16), $newX)
			_WriteMemory($hProcess, $addr + 0xC, $newPacked)

			ConsoleWrite(StringFormat("[Denied] ❌ %s moved to (%d,%d) [%s]" & @CRLF, $itemID, $newX, $newY, $itemName))
			ContinueLoop
		EndIf

		For $d = 0 To 8
			If $dx = $dxArr[$d] And $dy = $dyArr[$d] Then
				_WriteMemory($hProcess, $mouseXAddr, $memX[$d])
				_WriteMemory($hProcess, $mouseYAddr, $memY[$d])

				ControlClick($WindowName, "", "", "right", 1, $clickX[$d], $clickY[$d])

				_WriteMemory($hProcess, $mouseXAddr, $origMemX)
				_WriteMemory($hProcess, $mouseYAddr, $origMemY)

				ConsoleWrite(StringFormat("[Loot] ✅ %s (%s) at (%d,%d)" & @CRLF, $itemID, $dirName[$d], $ix, $iy))
				ExitLoop
			EndIf
		Next
	Next
EndFunc   ;==>ScanAndLootNearbyItems

Func ClickTile($x, $y)
	MouseClick("right", $x, $y, 1, 0)
EndFunc   ;==>ClickTile

Func GetDirectionIndex($tileX, $tileY)
	Global $hProcess, $PosXAddress, $PosYAddress
	Local $playerX = _ReadMemory($hProcess, $PosXAddress)
	Local $playerY = _ReadMemory($hProcess, $PosYAddress)
	Local $dx = $tileX - $playerX
	Local $dy = $tileY - $playerY

	Local $dxArr[8] = [1, 0, -1, -1, -1, 0, 1, 1]
	Local $dyArr[8] = [0, -1, 0, -1, 1, 1, 1, -1]

	For $i = 0 To 7
		If $dx = $dxArr[$i] And $dy = $dyArr[$i] Then Return $i
	Next
	Return -1
EndFunc   ;==>GetDirectionIndex

Func CreateButtonDefaultConfig()
	Local $sButtonConfigFile = @ScriptDir & "\NewButtonConfig.ini"
	Local $aKeys[8][2] = [ _
			["HealHotkey", "{" & Chr(96) & "}"], _
			["CureHotkey", "{-}"], _
			["TargetHotkey", "{=}"], _
			["ExitHotkey", "{/}"], _
			["SaveLocationHotkey", "{F7}"], _
			["EraseLocationsHotkey", "{F8}"], _
			["MoveToLocationsHotkey", "{!}"], _
			["LootHotkey", "{@}"] _
			]
	For $i = 0 To UBound($aKeys) - 1
		IniWrite($sButtonConfigFile, "Hotkeys", $aKeys[$i][0], $aKeys[$i][1])
	Next
	ConsoleWrite("[Info] Default ButtonConfig.ini created with hotkeys." & @CRLF)
EndFunc   ;==>CreateButtonDefaultConfig

; ------------------------------------------------------------------------------
;   Function to Open Process & Retrieve Base Address
; ------------------------------------------------------------------------------
Func ConnectToBaseAddress()
	Global $hProcess, $BaseAddress

	Local $ProcessID = ProcessExists($ProcessName)
	If $ProcessID = 0 Then
		ConsoleWrite("[Reconnect] Game process not found." & @CRLF)
		Return SetError(1)
	EndIf

	$hProcess = _WinAPI_OpenProcess(0x1F0FFF, False, $ProcessID)
	If $hProcess = 0 Then
		ConsoleWrite("[Reconnect] Failed to open process! Try running as admin." & @CRLF)
		Return SetError(2)
	EndIf

	$BaseAddress = _GetModuleBase_EnumModules($hProcess)
	If $BaseAddress = 0 Then
		ConsoleWrite("[Reconnect] Failed to obtain base address!" & @CRLF)
		_WinAPI_CloseHandle($hProcess)
		$hProcess = 0
		Return SetError(3)
	EndIf

	ChangeAddressToBase()
	ConsoleWrite("[Reconnect] Successfully reconnected to new game instance." & @CRLF)
	Return 1
EndFunc   ;==>ConnectToBaseAddress

; ------------------------------------------------------------------------------
;                       READ AND UPDATE GUI FROM MEMORY
; ------------------------------------------------------------------------------
Func GUIReadMemory()
	Global $hProcess
	Global $Type, $TypeAddress
	Global $WalkerLabel, $MoveToLocationsStatus
	Global $AttackMode, $AttackModeAddress
	Global $PosXAddress, $PosYAddress
	Global $HPAddress, $MaxHPAddress
	Global $ChattOpenAddress, $Chat
	Global $SicknessAddress, $Sickness
	Global $BackPack, $BackPackMax
	Global $BackPackAddress, $BackPackMaxAddress
	Global $HealerStatus, $CureStatus, $TargetStatus
	Global $HealerLabel, $CureLabel, $TargetLabel
	Global $LootQueued, $LootCount, $LootReady, $LootIdleWaiting

	If $hProcess = 0 Then Return

	; Read Type
	$Type = _ReadMemory($hProcess, $TypeAddress)
	If $Type = 0 Then
		GUICtrlSetData($TypeLabel, "Type: Player")
	ElseIf $Type = 1 Then
		GUICtrlSetData($TypeLabel, "Type: Monster")
	ElseIf $Type = 2 Then
		GUICtrlSetData($TypeLabel, "Type: NPC")
	ElseIf $Type = 65535 Then
		GUICtrlSetData($TypeLabel, "Type: No Target")
	Else
		GUICtrlSetData($TypeLabel, "Type: Unknown (" & $Type & ")")
	EndIf

	; Walker On/Off or Paused
	Switch $MoveToLocationsStatus
		Case 0
			GUICtrlSetData($WalkerLabel, "Walker: Off")
		Case 1
			GUICtrlSetData($WalkerLabel, "Walker: On")
		Case 2
			GUICtrlSetData($WalkerLabel, "Walker: Paused")
		Case Else
			GUICtrlSetData($WalkerLabel, "Walker: Error")
	EndSwitch

	; Attack Mode
	$AttackMode = _ReadMemory($hProcess, $AttackModeAddress)
	If $AttackMode = 0 Then
		GUICtrlSetData($AttackModeLabel, "Attack Mode: Safe")
	ElseIf $AttackMode = 1 Then
		GUICtrlSetData($AttackModeLabel, "Attack Mode: Attack")
	Else
		GUICtrlSetData($AttackModeLabel, "Attack Mode: No Target")
	EndIf

	; Position
	Local $PosX = _ReadMemory($hProcess, $PosXAddress)
	Local $PosY = _ReadMemory($hProcess, $PosYAddress)
	GUICtrlSetData($PosXLabel, "Pos X: " & $PosX)
	GUICtrlSetData($PosYLabel, "Pos Y: " & $PosY)

	; HP
	Local $HP = _ReadMemory($hProcess, $HPAddress)
	GUICtrlSetData($HPLabel, "HP: " & $HP)
	GUICtrlSetData($HP2Label, "RealHp: " & ($HP / 65536))

	; MaxHP
	Local $MaxHP = _ReadMemory($hProcess, $MaxHPAddress)
	GUICtrlSetData($MaxHPLabel, "MaxHP: " & $MaxHP)

	; Chat
	Local $ChatVal = _ReadMemory($hProcess, $ChattOpenAddress)
	$Chat = $ChatVal
	GUICtrlSetData($ChatLabel, "Chat: " & $ChatVal)

	; Sickness
	Local $SickVal = _ReadMemory($hProcess, $SicknessAddress)
	$Sickness = $SickVal
	Local $SicknessDescription = GetSicknessDescription($SickVal)
	GUICtrlSetData($SicknessLabel, "Sickness: " & $SicknessDescription)

	; Backpack Weight
	Local $bpWeight = _ReadMemory($hProcess, $BackPackAddress)
	Local $bpMax = _ReadMemory($hProcess, $BackPackMaxAddress)
	GUICtrlSetData($BackPackLabel, "Weight " & $bpWeight & " / " & $bpMax)

	; --- Death Detection via sudden teleport ---
	Static $lastX = -1, $lastY = -1
	If $lastX <> -1 And $lastY <> -1 Then
		Local $dx = Abs($PosX - $lastX)
		Local $dy = Abs($PosY - $lastY)
		If $dx > 25 Or $dy > 25 Then
			ConsoleWrite("[DeathDetect] Large movement detected: ΔX=" & $dx & ", ΔY=" & $dy & ". Assuming death." & @CRLF)

			; Turn off walker
			If $MoveToLocationsStatus <> 0 Then
				$MoveToLocationsStatus = 0
				GUICtrlSetData($WalkerLabel, "Walker: Off")
				ConsoleWrite("[DeathDetect] Walker turned OFF." & @CRLF)
			EndIf

			; Clear loot status
			$LootQueued = False
			$LootCount = 0
			$LootReady = False
			$LootIdleWaiting = False
		EndIf
	EndIf
	$lastX = $PosX
	$lastY = $PosY
EndFunc   ;==>GUIReadMemory

Func _ReadMemory($hProc, $pAddress)
	If $hProc = 0 Or $pAddress = 0 Then Return 0

	Local $tBuffer = DllStructCreate("dword")
	Local $aRead = DllCall("kernel32.dll", "bool", "ReadProcessMemory", _
			"handle", $hProc, _
			"ptr", $pAddress, _
			"ptr", DllStructGetPtr($tBuffer), _
			"dword", DllStructGetSize($tBuffer), _
			"ptr", 0)
	If @error Or Not $aRead[0] Then Return 0
	Return DllStructGetData($tBuffer, 1)
EndFunc   ;==>_ReadMemory

Func _GetModuleBase_EnumModules($hProc)
	Local $hPsapi = DllOpen("psapi.dll")
	If $hPsapi = 0 Then Return 0

	Local $tModules = DllStructCreate("ptr[1024]")
	Local $tBytesNeeded = DllStructCreate("dword")
	Local $aCall = DllCall("psapi.dll", "bool", "EnumProcessModules", _
			"handle", $hProc, _
			"ptr", DllStructGetPtr($tModules), _
			"dword", DllStructGetSize($tModules), _
			"ptr", DllStructGetPtr($tBytesNeeded))
	If @error Or Not $aCall[0] Then
		DllClose($hPsapi)
		Return 0
	EndIf

	; The first module in the list is usually the main EXE
	Local $pBaseAddress = DllStructGetData($tModules, 1, 1)
	DllClose($hPsapi)
	Return $pBaseAddress
EndFunc   ;==>_GetModuleBase_EnumModules

Func ChangeAddressToBase()
	Global $BaseAddress
	Global $TypeOffset, $AttackModeOffset, $PosXOffset, $PosYOffset
	Global $HPOffset, $MaxHPOffset, $ChattOpenOffset, $SicknessOffset
	Global $BackPack, $BackPackMax
	Global $TypeAddress, $AttackModeAddress, $PosXAddress, $PosYAddress
	Global $HPAddress, $MaxHPAddress, $ChattOpenAddress, $SicknessAddress
	Global $BackPackAddress, $BackPackMaxAddress

	$TypeAddress = $BaseAddress + $TypeOffset
	$AttackModeAddress = $BaseAddress + $AttackModeOffset
	$PosXAddress = $BaseAddress + $PosXOffset
	$PosYAddress = $BaseAddress + $PosYOffset
	$HPAddress = $BaseAddress + $HPOffset
	$MaxHPAddress = $BaseAddress + $MaxHPOffset
	$ChattOpenAddress = $BaseAddress + $ChattOpenOffset
	$SicknessAddress = $BaseAddress + $SicknessOffset
	$BackPackAddress = $BaseAddress + $BackPack
	$BackPackMaxAddress = $BaseAddress + $BackPackMax
EndFunc   ;==>ChangeAddressToBase

; --------------------------------------------------------------------------
;                           Hotkey Toggle Functions
; --------------------------------------------------------------------------
#Region ;toggles;
Func Hotkeyshit()
	Global $HealerStatus
	$HealerStatus = Not $HealerStatus
	GUICtrlSetData($HealerLabel, "Healer: " & ($HealerStatus ? "On" : "Off"))
EndFunc   ;==>Hotkeyshit

Func CureKeyShit()
	Global $CureStatus
	$CureStatus = Not $CureStatus
	GUICtrlSetData($CureLabel, "Cure: " & ($CureStatus ? "On" : "Off"))
EndFunc   ;==>CureKeyShit

Func TargetKeyShit()
	Global $TargetStatus
	$TargetStatus = Not $TargetStatus
	GUICtrlSetData($TargetLabel, "Target: " & ($TargetStatus ? "On" : "Off"))
	ConsoleWrite("[Hotkey] Target toggled to: " & ($TargetStatus ? "On" : "Off") & @CRLF)
EndFunc   ;==>TargetKeyShit

Func ToggleLooter()
	; Read the current state of the checkbox
	Local $checked = GUICtrlRead($LootingCheckbox)

	; Toggle the checkbox
	If $checked = $GUI_CHECKED Then
		GUICtrlSetState($LootingCheckbox, $GUI_UNCHECKED)
		ConsoleWrite("AutoLoot Toggled OFf" & @CRLF)
	Else
		GUICtrlSetState($LootingCheckbox, $GUI_CHECKED)
		ConsoleWrite("AutoLoot Toggled on" & @CRLF)
	EndIf
EndFunc   ;==>ToggleLooter


Func KilledWithFire()
	Global $Debug
	If $Debug Then ConsoleWrite("Killed with fire" & @CRLF)
	Exit
EndFunc   ;==>KilledWithFire


Func ToggleHealer()
	Global $HealerStatus
	Global $LastMovementTime
	$HealerStatus = Not $HealerStatus
	GUICtrlSetData($HealerLabel, "Healer: " & ($HealerStatus ? "On" : "Off"))
	ConsoleWrite("[GUI] Healer toggled to: " & ($HealerStatus ? "On" : "Off") & @CRLF)

	If $HealerStatus Then
		$LastMovementTime = TimerInit() ; Reset movement timer when healing turned on
	EndIf
EndFunc   ;==>ToggleHealer


Func ToggleCure()
	Global $CureStatus
	$CureStatus = Not $CureStatus
	GUICtrlSetData($CureLabel, "Cure: " & ($CureStatus ? "On" : "Off"))
	ConsoleWrite("[GUI] Cure toggled to: " & ($CureStatus ? "On" : "Off") & @CRLF)
EndFunc   ;==>ToggleCure

Func ToggleTarget()
	Global $TargetStatus
	$TargetStatus = Not $TargetStatus
	GUICtrlSetData($TargetLabel, "Target: " & ($TargetStatus ? "On" : "Off"))
	ConsoleWrite("[GUI] Target toggled to: " & ($TargetStatus ? "On" : "Off") & @CRLF)
EndFunc   ;==>ToggleTarget


Func ToggleWalker()
	Global $MoveToLocationsStatus, $aLocations, $iCurrentIndex

	If $MoveToLocationsStatus = 0 Then
		MoveToLocations()
		MoveToLocationsStep($aLocations, $iCurrentIndex) ; <<< NEW LINE!
		GUICtrlSetData($WalkerLabel, "Walker: On")
		ConsoleWrite("[GUI] Walker toggled to: On" & @CRLF)
	Else
		$MoveToLocationsStatus = 0
		GUICtrlSetData($WalkerLabel, "Walker: Off")
		ConsoleWrite("[GUI] Walker toggled to: Off" & @CRLF)
	EndIf
EndFunc   ;==>ToggleWalker

Func ToggleAllHelpers()
	Global $HealerStatus, $CureStatus, $TargetStatus, $MoveToLocationsStatus
	Local $LootCheckBox = GUICtrlRead($LootingCheckbox)
	Local $TotalOn = 0
	If $HealerStatus Then $TotalOn += 1
	If $CureStatus Then $TotalOn += 1
	If $TargetStatus Then $TotalOn += 1
	If $MoveToLocationsStatus = 1 Then $TotalOn += 1
	If $LootCheckBox = 1 Then $TotalOn += 1

	If $TotalOn >= 1 Then
		; Turn all OFF
		$HealerStatus = 0
		$CureStatus = 0
		$TargetStatus = 0
		$MoveToLocationsStatus = 0
		GUICtrlSetState($LootingCheckbox, $GUI_UNCHECKED)
		GUICtrlSetData($HealerLabel, "Healer: Off")
		GUICtrlSetData($CureLabel, "Cure: Off")
		GUICtrlSetData($TargetLabel, "Target: Off")
		GUICtrlSetData($WalkerLabel, "Walker: Off")

		ConsoleWrite("[GUI] ToggleAll: All turned OFF" & @CRLF)
	Else
		; Turn all ON
		$HealerStatus = 1
		$CureStatus = 1
		$TargetStatus = 1
		;$MoveToLocationsStatus = 1
		GUICtrlSetState($MayhamCheckbox, $GUI_CHECKED)
		GUICtrlSetState($LootingCheckbox, $GUI_CHECKED)
		GUICtrlSetData($HealerLabel, "Healer: On")
		GUICtrlSetData($CureLabel, "Cure: On")
		GUICtrlSetData($TargetLabel, "Target: On")
		;GUICtrlSetData($WalkerLabel, "Walker: On")

		ConsoleWrite("[GUI] ToggleAll: All turned ON" & @CRLF)
	EndIf
EndFunc   ;==>ToggleAllHelpers
#EndRegion ;toggles;
; ------------------------------------------------------------------------------
; Optional: Return a more human label for some “Sick” codes
; ------------------------------------------------------------------------------
Func GetSicknessDescription($Sick)
	Local $SicknessDescription = "Unknown"
	Switch $Sick
		Case 1
			$SicknessDescription = "Poison1 (" & $Sick & ")"
		Case 2
			$SicknessDescription = "Disease1 (" & $Sick & ")"
			; ...
		Case Else
			$SicknessDescription = $Sick
	EndSwitch
	Return $SicknessDescription
EndFunc   ;==>GetSicknessDescription

; ------------------------------------------------------------------------------
;                                LOCATION LOADING
; ------------------------------------------------------------------------------
Func LoadLocations()
	If Not FileExists($locationFile) Then
		ConsoleWrite("[Error] Location file not found: " & $locationFile & @CRLF)
		Return SetError(1, 0, 0)
	EndIf

	Local $aLines = FileReadToArray($locationFile)
	If @error Then
		ConsoleWrite("[Error] Failed to read file: " & $locationFile & @CRLF)
		Return SetError(2, 0, 0)
	EndIf

	Local $iLocationCount = 0
	Dim $aTempLocations[UBound($aLines)][2]

	For $i = 0 To UBound($aLines) - 1
		Local $aMatches = StringRegExp($aLines[$i], "X:(\d+);Y:(\d+)", 3)
		If Not @error And UBound($aMatches) = 2 Then
			$aTempLocations[$iLocationCount][0] = Int($aMatches[0])
			$aTempLocations[$iLocationCount][1] = Int($aMatches[1])
			$iLocationCount += 1
		Else
			ConsoleWrite("[Warning] Failed to parse line " & $i & ": " & $aLines[$i] & @CRLF)
		EndIf
	Next

	If $iLocationCount = 0 Then
		ConsoleWrite("[Warning] No valid locations found in " & $locationFile & @CRLF)
		Return SetError(3, 0, 0)
	EndIf

	ReDim $aTempLocations[$iLocationCount][2]
	ConsoleWrite("[Success] Loaded " & $iLocationCount & " locations." & @CRLF)
	Return $aTempLocations
EndFunc   ;==>LoadLocations

Func SaveLocation()
	Global $hProcess, $PosXAddress, $PosYAddress
	Global $currentLocations, $maxLocations
	Global $aLocations  ; <<< Need this to reload

	Local $x = _ReadMemory($hProcess, $PosXAddress)
	Local $y = _ReadMemory($hProcess, $PosYAddress)
	ConsoleWrite("Attempting to read X: " & $x & " Y: " & $y & @CRLF)

	If @error Then
		ConsoleWrite("[Error] Failed to read memory. Error code: " & @error & @CRLF)
		Return
	EndIf
	If $x == 0 And $y == 0 Then
		ConsoleWrite("[Warning] Read zero for both coordinates. Possibly a bad read." & @CRLF)
		Return
	EndIf

	If Not FileExists($locationFile) Then
		Local $file = FileOpen($locationFile, $FO_CREATEPATH + $FO_OVERWRITE)
		If $file == -1 Then
			ConsoleWrite("[Error] Failed to create file: " & $locationFile & @CRLF)
			Return
		EndIf
		FileClose($file)
		ConsoleWrite("[Info] File created: " & $locationFile & @CRLF)
	EndIf

	Local $data = " : Location" & $currentLocations & "=X:" & $x & ";Y:" & $y & @CRLF
	If $currentLocations < $maxLocations Then
		_FileWriteLog($locationFile, $data)
		If @error Then
			ConsoleWrite("[Error] Failed to write to file: " & $locationFile & @CRLF)
		Else
			ConsoleWrite("[Info] Data written: " & $data)
			$currentLocations += 1

			; ===== FIX: Reload locations after save =====
			$aLocations = LoadLocations()
			If @error Then
				ConsoleWrite("[Error] Failed to reload locations after save!" & @CRLF)
			Else
				ConsoleWrite("[Info] Locations reloaded successfully after save." & @CRLF)
			EndIf
		EndIf
	Else
		ConsoleWrite("[Info] Maximum locations reached. Stop pressing the button!" & @CRLF)
	EndIf
EndFunc   ;==>SaveLocation

Func EraseLocations()
	FileDelete($locationFile)
	$currentLocations = 1
	ConsoleWrite("Success - All locations erased." & @CRLF)
EndFunc   ;==>EraseLocations

; ------------------------------------------------------------------------------
;                           LOCATION WALKING
; ------------------------------------------------------------------------------
Func MoveToLocations()
	Global $MoveToLocationsStatus, $hProcess, $PosXAddress, $PosYAddress, $iCurrentIndex, $aLocations

	If $MoveToLocationsStatus = 0 Then
		Local $currentX = _ReadMemory($hProcess, $PosXAddress)
		Local $currentY = _ReadMemory($hProcess, $PosYAddress)
		$iCurrentIndex = FindClosestLocationIndex($currentX, $currentY, $aLocations)

		If $iCurrentIndex = -1 Then
			ConsoleWrite("[Walker] Error: No valid location found." & @CRLF)
			Return
		EndIf

		$MoveToLocationsStatus = 1
		GUICtrlSetData($WalkerLabel, "Walker: On")
		ConsoleWrite("[Walker] Activated." & @CRLF)

	Else
		$MoveToLocationsStatus = 0
		GUICtrlSetData($WalkerLabel, "Walker: Off")
		ConsoleWrite("[Walker] Deactivated." & @CRLF)
	EndIf
EndFunc   ;==>MoveToLocations

Func IsBlockedCoord($x, $y)
	For $i = 0 To UBound($aTempBlocked) - 1
		If $aTempBlocked[$i][0] = $x And $aTempBlocked[$i][1] = $y Then
			Return True
		EndIf
	Next
	Return False
EndFunc   ;==>IsBlockedCoord

Func MarkCoordAsBlocked($x, $y)
	ReDim $aTempBlocked[UBound($aTempBlocked) + 1][2]
	$aTempBlocked[UBound($aTempBlocked) - 1][0] = $x
	$aTempBlocked[UBound($aTempBlocked) - 1][1] = $y
	ConsoleWrite("Marked (" & $x & ", " & $y & ") as blocked." & @CRLF)
EndFunc   ;==>MarkCoordAsBlocked

Func NextIndex($iCurrent, $iBound, $reverse)
	If $reverse Then
		$iCurrent -= 1
		If $iCurrent < 0 Then $iCurrent = $iBound - 1
	Else
		$iCurrent += 1
		If $iCurrent >= $iBound Then $iCurrent = 0
	EndIf
	Return $iCurrent
EndFunc   ;==>NextIndex

Func MoveToLocationsStep($aLocations, ByRef $iCurrentIndex)
	Global $hProcess, $PosXAddress, $PosYAddress, $TypeAddress
	Global $WindowName, $lastX, $lastY
	Global $aTempBlocked[0][2], $ReverseLoopCheckbox
	Global $MoveToLocationsStatus
	Global $TargetStatus, $LootingCheckbox
	Global $LootQueued, $LootCount, $LootIdleWaiting, $LootIdleTimer
	Global $PausedWalkerForLoot, $Type
	Global $JugernautCheckbox

	If $MoveToLocationsStatus <> 1 Then Return SetError(1, 0, "Walker not active")

	If Not IsArray($aLocations) Then Return SetError(2, 0, "Invalid input")
	If $iCurrentIndex < 0 Or $iCurrentIndex >= UBound($aLocations) Then Return SetError(3, 0, "Index out of range")

	Local $reverse = (GUICtrlRead($ReverseLoopCheckbox) = $GUI_CHECKED)
	Local $targetX = $aLocations[$iCurrentIndex][0]
	Local $targetY = $aLocations[$iCurrentIndex][1]

	If IsBlockedCoord($targetX, $targetY) Then
		ConsoleWrite("Skipping blocked coordinate (" & $targetX & ", " & $targetY & ")" & @CRLF)
		$iCurrentIndex = NextIndex($iCurrentIndex, UBound($aLocations), $reverse)
		Return True
	EndIf

	Local $currentX = _ReadMemory($hProcess, $PosXAddress)
	Local $currentY = _ReadMemory($hProcess, $PosYAddress)

	; Jugernaut Mode Block Detection
	If GUICtrlRead($JugernautCheckbox) = $GUI_CHECKED Then
		Static $BlockStart = 0
		If $currentX = $lastX And $currentY = $lastY Then
			If $BlockStart = 0 Then $BlockStart = TimerInit()
			If TimerDiff($BlockStart) > 100 Then
				ConsoleWrite("[Jugernaut] Blocked for over 1.5s — initiating combat sweep." & @CRLF)
				JugernautCombatHandler()
				$BlockStart = 0
			EndIf
		Else
			$BlockStart = 0
		EndIf
	EndIf

	If $currentX = $targetX And $currentY = $targetY Then
		ConsoleWrite("Arrived at location index: " & $iCurrentIndex & @CRLF)
		$iCurrentIndex = NextIndex($iCurrentIndex, UBound($aLocations), $reverse)
		Return True
	EndIf

	; Movement
	If $currentX < $targetX Then
		ControlSend($WindowName, "", "", "{d down}")
		Sleep(30)
		ControlSend($WindowName, "", "", "{d up}")
	ElseIf $currentX > $targetX Then
		ControlSend($WindowName, "", "", "{a down}")
		Sleep(30)
		ControlSend($WindowName, "", "", "{a up}")
	EndIf

	If $currentY < $targetY Then
		ControlSend($WindowName, "", "", "{s down}")
		Sleep(30)
		ControlSend($WindowName, "", "", "{s up}")
	ElseIf $currentY > $targetY Then
		ControlSend($WindowName, "", "", "{w down}")
		Sleep(30)
		ControlSend($WindowName, "", "", "{w up}")
	EndIf

	$lastX = $currentX
	$lastY = $currentY

	Return True
EndFunc   ;==>MoveToLocationsStep



Func FindClosestLocationIndex($currentX, $currentY, $aLocations)
	If Not IsArray($aLocations) Or UBound($aLocations, 0) = 0 Then
		ConsoleWrite("FindClosestLocationIndex => no valid array." & @CRLF)
		Return -1
	EndIf

	Local $minDist = 999999
	Local $minIndex = -1
	For $i = 0 To UBound($aLocations) - 1
		Local $dx = $currentX - $aLocations[$i][0]
		Local $dy = $currentY - $aLocations[$i][1]
		Local $dist = $dx * $dx + $dy * $dy
		If $dist < $minDist Then
			$minDist = $dist
			$minIndex = $i
		EndIf
	Next

	If $minIndex = -1 Then
		ConsoleWrite("FindClosestLocationIndex => No valid locations found." & @CRLF)
	Else
		ConsoleWrite("FindClosestLocationIndex => Found index: " & $minIndex & " Dist=" & $minDist & @CRLF)
	EndIf
	Return $minIndex
EndFunc   ;==>FindClosestLocationIndex

; ------------------------------------------------------------------------------
;                                  CURE FUNCTION
; ------------------------------------------------------------------------------
Func CureMe()
	Global $Chat, $Checkbox, $Sickness, $sicknessArray
	Global $HealDelay, $LastHealTime, $elapsedTimeSinceHeal
	Global $MovmentSlider, $PosXLabel, $PosYLabel

	If $Chat <> 0 Then Return

	; Check if we have a sickness that is in the array
	If _ArraySearch($sicknessArray, $Sickness) = -1 Then Return

	Local $Healwait = GUICtrlRead($healSlider)

	Local $currentX = Number(StringRegExpReplace(GUICtrlRead($PosXLabel), "[^\d]", ""))
	Local $currentY = Number(StringRegExpReplace(GUICtrlRead($PosYLabel), "[^\d]", ""))
	Static $lastX = $currentX, $lastY = $currentY
	Static $LastMovementTime = TimerInit()

	$elapsedTimeSinceHeal = TimerDiff($LastHealTime)

	; Detect movement
	If $currentX <> $lastX Or $currentY <> $lastY Then
		$lastX = $currentX
		$lastY = $currentY
		$LastMovementTime = TimerInit()
	EndIf

	Local $TimeSinceLastMove = TimerDiff($LastMovementTime)

	; Old style
	If GUICtrlRead($Checkbox) = $GUI_CHECKED Then
		If $elapsedTimeSinceHeal >= $HealDelay Then
			ControlSend("Project Rogue", "", "", "{3}")
			ConsoleWrite("Cure triggered (old style)" & @CRLF)
			$LastHealTime = TimerInit()
		EndIf
	Else
		If $elapsedTimeSinceHeal >= $HealDelay Then
			If $TimeSinceLastMove >= $Healwait Then
				ControlSend("Project Rogue", "", "", "{3}")
				ConsoleWrite("Cure triggered: Stationary for " & $TimeSinceLastMove & "ms." & @CRLF)
				$LastHealTime = TimerInit()
			Else
				ConsoleWrite("No cure: Only stationary for " & $TimeSinceLastMove & "ms." & @CRLF)
			EndIf
		EndIf
	EndIf
EndFunc   ;==>CureMe

; ------------------------------------------------------------------------------
;                                   HEALER
; ------------------------------------------------------------------------------
Func TimeToHeal()
	Global $MovmentSlider, $PosXLabel, $PosYLabel, $Checkbox, $HPAddress, $MaxHPAddress
	Global $HealerLabel, $HealDelay, $LastHealTime, $elapsedTimeSinceHeal, $sicknessArray, $Sickness
	Global $Chat, $ChattOpenAddress, $healSlider
	Global $hProcess

	Local $Healwait = 200 ; ms to wait after no movement (Fixed 500ms you said)
	Local $HP = _ReadMemory($hProcess, $HPAddress)
	Local $RealHP = $HP / 65536
	Local $MaxHP = _ReadMemory($hProcess, $MaxHPAddress)
	Local $ChatVal = _ReadMemory($hProcess, $ChattOpenAddress)
	Local $HealThreshold = GUICtrlRead($healSlider) / 100

	Local $currentX = Number(StringRegExpReplace(GUICtrlRead($PosXLabel), "[^\d]", ""))
	Local $currentY = Number(StringRegExpReplace(GUICtrlRead($PosYLabel), "[^\d]", ""))

	; Make these STATIC so they remember across calls
	Static $lastX = $currentX, $lastY = $currentY
	Static $LastMovementTime = TimerInit()
	Static $HasMoved = False

	$elapsedTimeSinceHeal = TimerDiff($LastHealTime)

	; --- Detect movement ---
	If $currentX <> $lastX Or $currentY <> $lastY Then
		$lastX = $currentX
		$lastY = $currentY
		$LastMovementTime = TimerInit()
		$HasMoved = True
	EndIf

	Local $TimeSinceLastMove = TimerDiff($LastMovementTime)

	; --- Old style (checkbox) ---
	If GUICtrlRead($Checkbox) = $GUI_CHECKED Then
		If $ChatVal = 0 And _ArraySearch($sicknessArray, $Sickness) = -1 Then
			If $RealHP < ($MaxHP * $HealThreshold) And $elapsedTimeSinceHeal > $HealDelay Then
				ControlSend("Project Rogue", "", "", "{2}")
				ConsoleWrite("Heal triggered (old style): HP < threshold" & @CRLF)
				$LastHealTime = TimerInit()
			EndIf
		EndIf
	Else
		; --- Normal logic (requires stationary) ---
		If $ChatVal = 0 And _ArraySearch($sicknessArray, $Sickness) = -1 Then
			If $RealHP < ($MaxHP * $HealThreshold) And $elapsedTimeSinceHeal > $HealDelay Then
				; HERE IS THE TRUE FIX
				If $HasMoved And $TimeSinceLastMove >= $Healwait Then
					ControlSend("Project Rogue", "", "", "{2}")
					ConsoleWrite("Healed: Stationary for " & $TimeSinceLastMove & "ms | HP < threshold." & @CRLF)
					$LastHealTime = TimerInit()
				Else
					;ConsoleWrite("Waiting: Haven't moved yet OR not stationary long enough." & @CRLF)
				EndIf
			EndIf
		EndIf
	EndIf
EndFunc   ;==>TimeToHeal

; ------------------------------------------------------------------------------
;                                  TARGETING
; ------------------------------------------------------------------------------
Func AttackModeReader()
	Global $hProcess, $WindowName
	Global $Type, $Chat, $AttackMode
	Global $PosXAddress, $PosYAddress
	Global $LootingCheckbox, $TargetStatus
	Global $LootQueued, $LootCount, $LootReady
	Global $LastPlayerX, $LastPlayerY
	Global $HadTarget, $LastTargetHeld
	Global $currentTime, $TargetDelay
	Global $LootIdleTimer, $LootIdleWaiting
	Global $MoveToLocationsStatus, $AutoResumeWalker
	Global $JugernautCheckbox

	Static $noTargetStart = 0

	$Chat = _ReadMemory($hProcess, $ChattOpenAddress)
	$Type = _ReadMemory($hProcess, $TypeAddress)
	$AttackMode = _ReadMemory($hProcess, $AttackModeAddress)

	Local $playerX = _ReadMemory($hProcess, $PosXAddress)
	Local $playerY = _ReadMemory($hProcess, $PosYAddress)

	If $LastPlayerX <> 0 And $LastPlayerY <> 0 Then
		If $playerX <> $LastPlayerX Or $playerY <> $LastPlayerY Then
			$LootQueued = False
			$LootCount = 0
			$LootReady = False
			$LootIdleWaiting = False
		EndIf
	EndIf

	$LastPlayerX = $playerX
	$LastPlayerY = $playerY

	If $TargetStatus = 1 And $Type = 65535 And $Chat = 0 Then
		If TimerDiff($currentTime) >= $TargetDelay Then
			ControlSend($WindowName, "", "", "{TAB}")
			$currentTime = TimerInit()
		EndIf
	EndIf

	If GUICtrlRead($JugernautCheckbox) = $GUI_CHECKED Then
		Return
	EndIf

	If $MoveToLocationsStatus = 1 And $Type = 1 Then
		ConsoleWrite("[Walker] Combat detected — pausing walker." & @CRLF)
		$MoveToLocationsStatus = 2
		$noTargetStart = 0
	EndIf

	If $MoveToLocationsStatus = 2 Then
		If $Type = 65535 Then
			If $noTargetStart = 0 Then $noTargetStart = TimerInit()
			If TimerDiff($noTargetStart) >= 350 Then
				ConsoleWrite("[Walker] No target for 350ms — resuming walker." & @CRLF)
				$MoveToLocationsStatus = 1
				$noTargetStart = 0
			EndIf
		Else
			$noTargetStart = 0
		EndIf
	EndIf
EndFunc   ;==>AttackModeReader

Func _WriteMemory($hProc, $pAddress, $value)
	Local $tBuffer = DllStructCreate("dword")
	DllStructSetData($tBuffer, 1, $value)
	DllCall("kernel32.dll", "bool", "WriteProcessMemory", _
			"handle", $hProc, _
			"ptr", $pAddress, _
			"ptr", DllStructGetPtr($tBuffer), _
			"dword", DllStructGetSize($tBuffer), _
			"ptr", 0)
EndFunc   ;==>_WriteMemory

Func _WriteByte($addr, $byte)
	Global $hProcess
	Local $struct = DllStructCreate("byte")
	DllStructSetData($struct, 1, $byte)
	DllCall("kernel32.dll", "bool", "WriteProcessMemory", _
			"handle", $hProcess, _
			"ptr", $addr, _
			"ptr", DllStructGetPtr($struct), _
			"dword", 1, _
			"ptr", 0)
EndFunc   ;==>_WriteByte

Func JugernautCombatHandler()
	Global $TypeAddress, $WindowName, $hProcess
	Global $Type, $TargetDelay

	Local $TargetHeldStart = 0
	Local $CombatStart = TimerInit()

	Do
		$Type = _ReadMemory($hProcess, $TypeAddress)

		If $Type = 65535 Then
			ControlSend($WindowName, "", "", "{TAB}")
			Sleep(200)
			$TargetHeldStart = 0
		Else
			If $TargetHeldStart = 0 Then $TargetHeldStart = TimerInit()
			If TimerDiff($TargetHeldStart) > 1800 Then
				ConsoleWrite("[Jugernaut] Target held > 3.5s — cycling." & @CRLF)
				ControlSend($WindowName, "", "", "{TAB}")
				$TargetHeldStart = TimerInit()
			EndIf
		EndIf

		Sleep(100)
	Until $Type = 65535
EndFunc   ;==>JugernautCombatHandler
