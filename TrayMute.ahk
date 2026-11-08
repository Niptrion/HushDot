; <COMPILER: v1.1.37.02a2>
#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-SetName TrayMute
;@Ahk2Exe-SetDescription TrayMute - mute microphones and speakers from the system tray
;@Ahk2Exe-SetVersion 1.1.0
;@Ahk2Exe-SetCopyright Copyright (c) 2026 Raja Mukherjee (MuteGuard). TrayMute fork - MIT License.
;@Ahk2Exe-SetMainIcon icons\app.ico
#UseHook true
Persistent
class MicController {
static AvailableMics    := Map()
static CurrentMicName   := ""
static CurrentMicId     := ""
static IsMuted          := false
static LastMicMuteState := -1
; Apps currently using a microphone (shown as an orange dot on the mic icon, names in the tooltip).
static MicUsers             := []
static AvailableSpeakers    := Map()
static CurrentSpeakerName   := ""
static CurrentSpeakerId     := ""
static IsSpeakerMuted       := false
static LastSpeakerMuteState := -1
static IconPathUnmuted := A_ScriptDir "\icons\light\unmute.ico"
static IconIdxUnmuted  := 0
static IconPathMuted   := A_ScriptDir "\icons\light\mute.ico"
static IconIdxMuted    := 0
static SpkIconPathOn   := A_ScriptDir "\icons\light\spk_on.ico"
static SpkIconIdxOn    := 0
static SpkIconPathOff  := A_ScriptDir "\icons\light\spk_off.ico"
static SpkIconIdxOff   := 0
static MicShortcutKey       := "#!m"
static SpkShortcutKey       := "#!s"
static EnableMiniWindow     := false
static DarkMode             := false
static RunOnStart           := false
static MuteAllMics          := true
static MuteAllSpeakers      := true
; "Mute all" runtime state per device group. Flow: 1 = microphones, 0 = speakers.
; Section is the .ini section that stores it ([MuteAll] kept for existing mic state).
static MicAll := {Flow: 1, Section: "MuteAll",    Active: false, RestoreIds: [], PendingIds: [], KnownIds: Map()}
static SpkAll := {Flow: 0, Section: "MuteAllSpk", Active: false, RestoreIds: [], PendingIds: [], KnownIds: Map()}
; Speakers follow the selected output while "mute all" is not engaged: its icon shows that
; output, and if it was muted elsewhere (e.g. keyboard mute key) a click unmutes it. Mics
; keep "any mic live = active" for privacy.
static SpkFollowsSelected := true
static MiniWindowSize       := 120
static MiniWindowBorder     := false
static ShowMiniMicIcon      := true
static ShowMiniSpkIcon      := true
static MainGui       := ""
static MiniGui       := ""
static SettingsGui   := ""
static TextMicStatus := ""
static TextSpkStatus := ""
static BtnTrayMute  := ""
static BtnSpkToggle  := ""
static DropdownMics  := ""
static DropdownSpks  := ""
static MiniMicIconCtrl := ""
static MiniSpkIconCtrl := ""
static MiniMenu := ""
static MiniWindowCenterX := ""
static MiniWindowCenterY := ""
static MiniWindowSavedX := ""
static MiniWindowSavedY := ""
static MiniHitTestHandler := ""
static MiniCursorHandler := ""
static MiniMoveHandler := ""
static SpeakerGui    := ""
static SpeakerNID    := ""
static SpeakerMsg    := 0
static SpeakerMsgHandler := ""
static SpeakerLastToggleTime := 0
static SpeakerTraySetupInProgress := false
static SpeakerContextMenu := ""
static SettingsDdMic        := ""
static SettingsDdSpk        := ""
static SettingsLblMicStatus := ""
static SettingsLblSpkStatus := ""
static DeviceCheckCounter   := 0
static PendingRefreshTimer  := ""
static IniPath  := ""
static AppName  := "TrayMute"
; Shown in the tray menu, Settings and About. Keep ;@Ahk2Exe-SetVersion at the top in sync.
static Version  := "1.1"
static SettingsSavedLbl := ""
static ThemeBg      := ""
static ThemeCard    := ""
static ThemeFg      := ""
static ThemeSub     := ""
static ThemeAccent  := ""
static ThemeBorder  := ""
static ThemeHover   := ""
__New() {
throw Error("Static class")
}
static ApplyTheme() {
if this.DarkMode {
this.ThemeBg     := "202020"
this.ThemeCard   := "2D2D2D"
this.ThemeFg     := "FFFFFF"
this.ThemeSub    := "9E9E9E"
this.ThemeAccent := "60CDFF"
this.ThemeBorder := "3D3D3D"
this.ThemeHover  := "383838"
} else {
this.ThemeBg     := "F3F3F3"
this.ThemeCard   := "FFFFFF"
this.ThemeFg     := "1A1A1A"
this.ThemeSub    := "616161"
this.ThemeAccent := "0078D4"
this.ThemeBorder := "E0E0E0"
this.ThemeHover  := "E8E8E8"
}
iconTheme := this.TaskbarUsesLightTheme() ? "light" : "dark"
otherTheme := (iconTheme = "light") ? "dark" : "light"
this.IconPathUnmuted := StrReplace(this.IconPathUnmuted, "\icons\" otherTheme "\", "\icons\" iconTheme "\")
this.IconPathMuted   := StrReplace(this.IconPathMuted,   "\icons\" otherTheme "\", "\icons\" iconTheme "\")
this.SpkIconPathOn   := StrReplace(this.SpkIconPathOn,   "\icons\" otherTheme "\", "\icons\" iconTheme "\")
this.SpkIconPathOff  := StrReplace(this.SpkIconPathOff,  "\icons\" otherTheme "\", "\icons\" iconTheme "\")
this.IconPathUnmuted := StrReplace(this.IconPathUnmuted, "\icons\unmute.ico", "\icons\" iconTheme "\unmute.ico")
this.IconPathMuted   := StrReplace(this.IconPathMuted,   "\icons\mute.ico",   "\icons\" iconTheme "\mute.ico")
this.SpkIconPathOn   := StrReplace(this.SpkIconPathOn,   "\icons\spk_on.ico", "\icons\" iconTheme "\spk_on.ico")
this.SpkIconPathOff  := StrReplace(this.SpkIconPathOff,  "\icons\spk_off.ico","\icons\" iconTheme "\spk_off.ico")
}
static TaskbarUsesLightTheme() {
return RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "SystemUsesLightTheme", 0) = 1
}
static Init() {
this.LoadSettings()
this.ApplyTheme()
this.EnumerateDevices()
this.SyncAllGroups()
this.SetupTray()
try this.RefreshMicUsers()
this.UpdateState()
this.RegisterHotkeys()
if (this.EnableMiniWindow)
this.ShowMiniWindow()
SetTimer((*) => this.UpdateState(), 1000)
SetTimer((*) => MicController.CheckMicUsers(), 2000)
this.SetupSpeakerTray()
OnMessage(0x0219, (wp, lp, *) => MicController.OnDeviceChangeMsg(wp, lp))
this.ExitHandler := ObjBindMethod(this, "OnExitHandler")
OnExit((*) => MicController.OnExitHandler())
}
static DetermineIniPath() {
localIni := A_ScriptDir "\TrayMute.ini"
appDataDir := A_AppData "\TrayMute"
appDataIni := appDataDir "\TrayMute.ini"
portableMarker := A_ScriptDir "\.portable"
if (FileExist(portableMarker) && this.TestFileWrite(localIni))
return localIni
if (!this.IsProtectedDirectory(A_ScriptDir) && this.TestFileWrite(localIni))
return localIni
if !DirExist(appDataDir) {
try DirCreate(appDataDir)
}
if (!FileExist(appDataIni) && FileExist(localIni)) {
try FileCopy(localIni, appDataIni, 0)
}
if this.TestFileWrite(appDataIni)
return appDataIni
return localIni
}
static IsProtectedDirectory(dir) {
if (dir = "")
return false
dir := RTrim(dir, "\")
checkDirs := [
EnvGet("ProgramFiles"),
EnvGet("ProgramFiles(x86)"),
EnvGet("ProgramW6432"),
A_WinDir
]
for p in checkDirs {
if (p != "" && InStr(dir, p) = 1)
return true
}
return false
}
static TestFileWrite(filePath) {
if (filePath = "")
return false
try {
if FileExist(filePath) {
f := FileOpen(filePath, "a-wd")
if IsObject(f) {
f.Close()
return true
}
} else {
dir := RegExReplace(filePath, "\\[^\\]+$", "")
if (dir != "" && !DirExist(dir)) {
try DirCreate(dir)
}
testFile := (dir != "" ? dir : A_ScriptDir) "\~tm_perm_test_" A_TickCount ".tmp"
f := FileOpen(testFile, "w-wd")
if IsObject(f) {
f.Close()
try FileDelete(testFile)
return true
}
}
} catch {
return false
}
return false
}
static GetRelativeIconPath(path) {
if (path = "")
return ""
if (InStr(path, A_ScriptDir "\") = 1)
return SubStr(path, StrLen(A_ScriptDir) + 2)
return path
}
static NotifySettingsSaved() {
if (this.SettingsSavedLbl != "") {
try {
this.SettingsSavedLbl.Value := "✓ Saved (" FormatTime(A_Now, "HH:mm:ss") ")"
SetTimer(() => this.ResetSettingsSavedLbl(), -3000)
}
}
}
static ResetSettingsSavedLbl() {
if (this.SettingsSavedLbl != "") {
try this.SettingsSavedLbl.Value := "✓ All changes save instantly"
}
}
static LoadSettings() {
this.IniPath := this.DetermineIniPath()
if !FileExist(this.IniPath)
return
try {
defaultUnmute := A_ScriptDir "\icons\light\unmute.ico"
defaultMute   := A_ScriptDir "\icons\light\mute.ico"
defaultSpkOn  := A_ScriptDir "\icons\light\spk_on.ico"
defaultSpkOff := A_ScriptDir "\icons\light\spk_off.ico"
rawUnmuted := IniRead(this.IniPath, "Icons", "UnmutedPath", defaultUnmute)
this.IconPathUnmuted := this.ResolveIconPath(rawUnmuted)
this.IconIdxUnmuted  := Integer(IniRead(this.IniPath, "Icons", "UnmutedIndex", 0))
rawMuted := IniRead(this.IniPath, "Icons", "MutedPath", defaultMute)
this.IconPathMuted   := this.ResolveIconPath(rawMuted)
this.IconIdxMuted    := Integer(IniRead(this.IniPath, "Icons", "MutedIndex", 0))
rawSpkOn := IniRead(this.IniPath, "SpkIcons", "OnPath", defaultSpkOn)
this.SpkIconPathOn   := this.ResolveIconPath(rawSpkOn)
this.SpkIconIdxOn    := Integer(IniRead(this.IniPath, "SpkIcons", "OnIndex", 0))
rawSpkOff := IniRead(this.IniPath, "SpkIcons", "OffPath", defaultSpkOff)
this.SpkIconPathOff  := this.ResolveIconPath(rawSpkOff)
this.SpkIconIdxOff   := Integer(IniRead(this.IniPath, "SpkIcons", "OffIndex", 0))
this.MicShortcutKey       := this.CleanShortcutKey(IniRead(this.IniPath, "Settings", "MicShortcutKey",  "#!m"))
this.SpkShortcutKey       := this.CleanShortcutKey(IniRead(this.IniPath, "Settings", "SpkShortcutKey",  "#!s"))
this.EnableMiniWindow     := IniRead(this.IniPath, "Settings", "MiniWindow",       "0") = "1"
this.DarkMode             := IniRead(this.IniPath, "Settings", "DarkMode",         "0") = "1"
this.MiniWindowSize       := Integer(IniRead(this.IniPath, "Settings", "MiniWindowSize", "120"))
this.MiniWindowBorder     := IniRead(this.IniPath, "Settings", "MiniWindowBorder", "0") = "1"
this.ShowMiniMicIcon      := IniRead(this.IniPath, "Settings", "ShowMicIcon",      "1") = "1"
this.ShowMiniSpkIcon      := IniRead(this.IniPath, "Settings", "ShowSpkIcon",      "1") = "1"
this.RunOnStart           := IniRead(this.IniPath, "Settings", "RunOnStart",       "0") = "1"
this.MuteAllMics          := IniRead(this.IniPath, "Settings", "MuteAllMics",      "1") = "1"
this.MuteAllSpeakers      := IniRead(this.IniPath, "Settings", "MuteAllSpeakers",  "1") = "1"
this.LoadGroupState(this.MicAll)
this.LoadGroupState(this.SpkAll)
this.CurrentMicName       := IniRead(this.IniPath, "Settings", "SelectedMic",  "")
this.CurrentSpeakerName   := IniRead(this.IniPath, "Settings", "SelectedSpk",  "")
this.MiniWindowSavedX     := IniRead(this.IniPath, "Settings", "MiniWindowX", "")
this.MiniWindowSavedY     := IniRead(this.IniPath, "Settings", "MiniWindowY", "")
if (this.MiniWindowSavedX != "")
this.MiniWindowSavedX := Integer(this.MiniWindowSavedX)
if (this.MiniWindowSavedY != "")
this.MiniWindowSavedY := Integer(this.MiniWindowSavedY)
}
}
static SaveSettings() {
if (this.IniPath = "" || !this.TestFileWrite(this.IniPath)) {
this.IniPath := this.DetermineIniPath()
}
writeUnmuted := this.GetRelativeIconPath(this.IconPathUnmuted)
writeMuted   := this.GetRelativeIconPath(this.IconPathMuted)
writeSpkOn   := this.GetRelativeIconPath(this.SpkIconPathOn)
writeSpkOff  := this.GetRelativeIconPath(this.SpkIconPathOff)
try {
IniWrite(writeUnmuted, this.IniPath, "Icons", "UnmutedPath")
IniWrite(this.IconIdxUnmuted,  this.IniPath, "Icons", "UnmutedIndex")
IniWrite(writeMuted,   this.IniPath, "Icons", "MutedPath")
IniWrite(this.IconIdxMuted,    this.IniPath, "Icons", "MutedIndex")
IniWrite(writeSpkOn,   this.IniPath, "SpkIcons", "OnPath")
IniWrite(this.SpkIconIdxOn,    this.IniPath, "SpkIcons", "OnIndex")
IniWrite(writeSpkOff,  this.IniPath, "SpkIcons", "OffPath")
IniWrite(this.SpkIconIdxOff,   this.IniPath, "SpkIcons", "OffIndex")
IniWrite(this.MicShortcutKey,      this.IniPath, "Settings", "MicShortcutKey")
IniWrite(this.SpkShortcutKey,      this.IniPath, "Settings", "SpkShortcutKey")
IniWrite(this.EnableMiniWindow ? "1" : "0", this.IniPath, "Settings", "MiniWindow")
IniWrite(this.DarkMode ? "1" : "0",         this.IniPath, "Settings", "DarkMode")
IniWrite(this.MiniWindowSize,       this.IniPath, "Settings", "MiniWindowSize")
IniWrite(this.MiniWindowBorder ? "1" : "0", this.IniPath, "Settings", "MiniWindowBorder")
IniWrite(this.ShowMiniMicIcon ? "1" : "0",  this.IniPath, "Settings", "ShowMicIcon")
IniWrite(this.ShowMiniSpkIcon ? "1" : "0",  this.IniPath, "Settings", "ShowSpkIcon")
IniWrite(this.RunOnStart ? "1" : "0",       this.IniPath, "Settings", "RunOnStart")
IniWrite(this.MuteAllMics ? "1" : "0",      this.IniPath, "Settings", "MuteAllMics")
IniWrite(this.MuteAllSpeakers ? "1" : "0",  this.IniPath, "Settings", "MuteAllSpeakers")
IniWrite(this.CurrentMicName,          this.IniPath, "Settings", "SelectedMic")
IniWrite(this.CurrentSpeakerName,      this.IniPath, "Settings", "SelectedSpk")
IniWrite(this.MiniWindowSavedX,        this.IniPath, "Settings", "MiniWindowX")
IniWrite(this.MiniWindowSavedY,        this.IniPath, "Settings", "MiniWindowY")
} catch as e {
appDataDir := A_AppData "\TrayMute"
if !DirExist(appDataDir)
try DirCreate(appDataDir)
this.IniPath := appDataDir "\TrayMute.ini"
try {
IniWrite(writeUnmuted, this.IniPath, "Icons", "UnmutedPath")
IniWrite(this.IconIdxUnmuted,  this.IniPath, "Icons", "UnmutedIndex")
IniWrite(writeMuted,   this.IniPath, "Icons", "MutedPath")
IniWrite(this.IconIdxMuted,    this.IniPath, "Icons", "MutedIndex")
IniWrite(writeSpkOn,   this.IniPath, "SpkIcons", "OnPath")
IniWrite(this.SpkIconIdxOn,    this.IniPath, "SpkIcons", "OnIndex")
IniWrite(writeSpkOff,  this.IniPath, "SpkIcons", "OffPath")
IniWrite(this.SpkIconIdxOff,   this.IniPath, "SpkIcons", "OffIndex")
IniWrite(this.MicShortcutKey,      this.IniPath, "Settings", "MicShortcutKey")
IniWrite(this.SpkShortcutKey,      this.IniPath, "Settings", "SpkShortcutKey")
IniWrite(this.EnableMiniWindow ? "1" : "0", this.IniPath, "Settings", "MiniWindow")
IniWrite(this.DarkMode ? "1" : "0",         this.IniPath, "Settings", "DarkMode")
IniWrite(this.MiniWindowSize,       this.IniPath, "Settings", "MiniWindowSize")
IniWrite(this.MiniWindowBorder ? "1" : "0", this.IniPath, "Settings", "MiniWindowBorder")
IniWrite(this.ShowMiniMicIcon ? "1" : "0",  this.IniPath, "Settings", "ShowMicIcon")
IniWrite(this.ShowMiniSpkIcon ? "1" : "0",  this.IniPath, "Settings", "ShowSpkIcon")
IniWrite(this.RunOnStart ? "1" : "0",       this.IniPath, "Settings", "RunOnStart")
IniWrite(this.MuteAllMics ? "1" : "0",      this.IniPath, "Settings", "MuteAllMics")
IniWrite(this.MuteAllSpeakers ? "1" : "0",  this.IniPath, "Settings", "MuteAllSpeakers")
IniWrite(this.CurrentMicName,          this.IniPath, "Settings", "SelectedMic")
IniWrite(this.CurrentSpeakerName,      this.IniPath, "Settings", "SelectedSpk")
IniWrite(this.MiniWindowSavedX,        this.IniPath, "Settings", "MiniWindowX")
IniWrite(this.MiniWindowSavedY,        this.IniPath, "Settings", "MiniWindowY")
}
}
; The .ini may have moved (e.g. to %APPDATA%); keep the mute state with it.
this.SaveGroupState(this.MicAll)
this.SaveGroupState(this.SpkAll)
}
static JoinIds(arr) {
ids := ""
for id in arr
ids .= (ids = "" ? "" : "|") id
return ids
}
static LoadGroupState(g) {
g.Active := IniRead(this.IniPath, g.Section, "Active", "0") = "1"
ids := IniRead(this.IniPath, g.Section, "RestoreIds", "")
g.RestoreIds := ids = "" ? [] : StrSplit(ids, "|")
ids := IniRead(this.IniPath, g.Section, "PendingIds", "")
g.PendingIds := ids = "" ? [] : StrSplit(ids, "|")
}
static SaveGroupState(g) {
try {
IniWrite(g.Active ? "1" : "0", this.IniPath, g.Section, "Active")
IniWrite(this.JoinIds(g.RestoreIds), this.IniPath, g.Section, "RestoreIds")
IniWrite(this.JoinIds(g.PendingIds), this.IniPath, g.Section, "PendingIds")
}
}
; Map of active endpoint name -> data flow (0 = output, 1 = input, 2 = same name used by both).
static GetActiveEndpointFlows() {
flows := Map()
pkey := Buffer(20)
DllCall("ole32\CLSIDFromString", "Str", "{a45c254e-df1c-4efd-8020-67d146a850e0}", "Ptr", pkey)
NumPut("UInt", 14, pkey, 16)
enumr := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
ComCall(3, enumr, "Int", 2, "UInt", 1, "Ptr*", &pColl := 0)
coll := ComValue(13, pColl)
ComCall(3, coll, "UInt*", &count := 0)
loop count {
try {
ComCall(4, coll, "UInt", A_Index - 1, "Ptr*", &pDev := 0)
dev := ComValue(13, pDev)
ComCall(4, dev, "UInt", 0, "Ptr*", &pStore := 0)
store := ComValue(13, pStore)
pv := Buffer(24, 0)
ComCall(5, store, "Ptr", pkey, "Ptr", pv)
name := NumGet(pv, 0, "UShort") = 31 ? StrGet(NumGet(pv, 8, "Ptr"), "UTF-16") : ""
DllCall("ole32\PropVariantClear", "Ptr", pv)
if (name = "")
continue
ep := ComObjQuery(dev, "{1BE09788-6894-4089-8586-9A2A6C265AC5}")
ComCall(3, ep, "Int*", &flow := -1)
flows[name] := (flows.Has(name) && flows[name] != flow) ? 2 : flow
}
}
return flows
}
static EnumerateDevices() {
this.AvailableMics.Clear()
this.AvailableSpeakers.Clear()
; Classify by the data flow Windows reports, not by English words in the name, so
; "Fones de ouvido" or a Bluetooth "Headset" output are listed correctly. AutoHotkey's
; device numbers also include unplugged/disconnected devices, which are skipped here.
; The old name rules remain as the fallback if the lookup fails or a name is ambiguous.
flows := ""
try flows := this.GetActiveEndpointFlows()
loop 64 {
try {
devName := SoundGetName(, A_Index)
flow := -1
if IsObject(flows) {
if !flows.Has(devName)
continue
flow := flows[devName]
}
if (flow = 0 || flow = 1) {
isMic := flow = 1 && !(devName ~= "i)(Stereo Mix)")
isSpk := flow = 0
} else {
isMic := (devName ~= "i)(Microphone|Headset|Input|Mic|Array)") && !(devName ~= "i)(Stereo Mix)")
isSpk := (devName ~= "i)(Speaker|Headphone|Output|Realtek|HDMI|Display Audio|Audio Out)") && !(devName ~= "i)(Microphone|Input|Mic)")
}
if isMic {
try {
SoundGetMute(, A_Index)
this.AvailableMics[devName] := A_Index
}
}
if isSpk {
try {
SoundGetMute(, A_Index)
this.AvailableSpeakers[devName] := A_Index
}
}
}
}
this.ValidateMicSelection()
this.ValidateSpeakerSelection()
}
static ValidateMicSelection() {
if this.AvailableMics.Count > 0 {
for name, id in this.AvailableMics {
if (this.CurrentMicName = name || this.CurrentMicName = id || (this.CurrentMicId != "" && this.CurrentMicId = id)) {
this.CurrentMicName := name
this.CurrentMicId   := id
return
}
}
if (this.CurrentMicName != "") {
for name, id in this.AvailableMics {
if InStr(name, this.CurrentMicName) || InStr(this.CurrentMicName, name) {
this.CurrentMicName := name
this.CurrentMicId   := id
return
}
}
}
for name, id in this.AvailableMics {
this.CurrentMicName := name
this.CurrentMicId   := id
break
}
} else {
this.CurrentMicName := ""
this.CurrentMicId   := ""
}
}
static ValidateSpeakerSelection() {
if this.AvailableSpeakers.Count > 0 {
for name, id in this.AvailableSpeakers {
if (this.CurrentSpeakerName = name || this.CurrentSpeakerName = id || (this.CurrentSpeakerId != "" && this.CurrentSpeakerId = id)) {
this.CurrentSpeakerName := name
this.CurrentSpeakerId   := id
return
}
}
try {
defPlay := SoundGetName()
for name, id in this.AvailableSpeakers {
if (name = defPlay || InStr(name, defPlay) || InStr(defPlay, name)) {
this.CurrentSpeakerName := name
this.CurrentSpeakerId   := id
return
}
}
}
if (this.CurrentSpeakerName != "") {
for name, id in this.AvailableSpeakers {
if InStr(name, this.CurrentSpeakerName) || InStr(this.CurrentSpeakerName, name) {
this.CurrentSpeakerName := name
this.CurrentSpeakerId   := id
return
}
}
}
for name, id in this.AvailableSpeakers {
this.CurrentSpeakerName := name
this.CurrentSpeakerId   := id
break
}
} else {
this.CurrentSpeakerName := ""
this.CurrentSpeakerId   := ""
}
}
static SetupTray() {
A_TrayMenu.Delete()
menuTitle := this.AppName " v" this.Version
A_TrayMenu.Add(menuTitle, (*) => this.ShowGUI())
A_TrayMenu.Disable(menuTitle)
this.SafeMenuSetIcon(A_TrayMenu, menuTitle, "shell32.dll", 28)
A_TrayMenu.Add()
A_TrayMenu.Add("Toggle Microphone", (*) => this.ToggleMicMute())
this.SafeMenuSetIcon(A_TrayMenu, "Toggle Microphone", this.IconPathUnmuted, this.IconIdxUnmuted)
A_TrayMenu.Add("Toggle Speaker", (*) => this.ToggleSpeakerMute())
this.SafeMenuSetIcon(A_TrayMenu, "Toggle Speaker", this.SpkIconPathOn, this.SpkIconIdxOn)
A_TrayMenu.Add()
A_TrayMenu.Add("Sound Settings", (*) => Run("ms-settings:sound"))
this.SafeMenuSetIcon(A_TrayMenu, "Sound Settings", "shell32.dll", 278)
A_TrayMenu.Add("Mic Privacy", (*) => Run("ms-settings:privacy-microphone"))
this.SafeMenuSetIcon(A_TrayMenu, "Mic Privacy", "shell32.dll", 48)
A_TrayMenu.Add()
A_TrayMenu.Add("Show Controls", (*) => this.ShowGUI())
this.SafeMenuSetIcon(A_TrayMenu, "Show Controls", "shell32.dll", 22)
A_TrayMenu.Add("Settings", (*) => this.ShowSettings())
this.SafeMenuSetIcon(A_TrayMenu, "Settings", "shell32.dll", 22)
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", (*) => MicController.OnExit())
this.SafeMenuSetIcon(A_TrayMenu, "Exit", "shell32.dll", 132)
A_TrayMenu.Default    := "Toggle Microphone"
A_TrayMenu.ClickCount := 1
this.UpdateTrayMenuIcons()
}
static CleanShortcutKey(key) {
key := Trim(key)
key := RegExReplace(key, "[{}]", "")
return key
}
static RegisterSingleHotkey(key, callback) {
cleanKey := this.CleanShortcutKey(key)
if (cleanKey = "")
return false
try {
Hotkey(cleanKey, callback, "On")
return true
} catch as err1 {
if !InStr(cleanKey, "$") {
try {
Hotkey("$" . cleanKey, callback, "On")
return true
} catch as err2 {
}
}
TrayTip("Shortcut error: " . cleanKey . "`nCould not register hotkey.", this.AppName, "Icon!")
return false
}
}
static UnregisterSingleHotkey(key) {
cleanKey := this.CleanShortcutKey(key)
if (cleanKey = "")
return
try Hotkey(cleanKey, "Off")
try Hotkey("$" . cleanKey, "Off")
}
static RegisterHotkeys() {
if (this.MicShortcutKey != "")
this.RegisterSingleHotkey(this.MicShortcutKey, (*) => this.ToggleMicMute())
if (this.SpkShortcutKey != "")
this.RegisterSingleHotkey(this.SpkShortcutKey, (*) => this.ToggleSpeakerMute())
}
static ReRegisterHotkeys(newMicKey, newSpkKey) {
cleanNewMic := this.CleanShortcutKey(newMicKey)
cleanNewSpk := this.CleanShortcutKey(newSpkKey)
if (this.MicShortcutKey != "")
this.UnregisterSingleHotkey(this.MicShortcutKey)
if (this.SpkShortcutKey != "")
this.UnregisterSingleHotkey(this.SpkShortcutKey)
this.MicShortcutKey := cleanNewMic
this.SpkShortcutKey := cleanNewSpk
if (this.MicShortcutKey != "")
this.RegisterSingleHotkey(this.MicShortcutKey, (*) => this.ToggleMicMute())
if (this.SpkShortcutKey != "")
this.RegisterSingleHotkey(this.SpkShortcutKey, (*) => this.ToggleSpeakerMute())
}
static OnDeviceChangeMsg(wParam, lParam) {
SetTimer(() => MicController.AutoRefreshDevices(), -400)
}
static AutoRefreshDevices() {
this.EnumerateDevices()
this.SyncAllGroups()
this.ValidateMicSelection()
this.ValidateSpeakerSelection()
this.UpdateTrayMenuIcons()
this.UpdateSpeakerTrayIcon()
this.UpdateState()
this.RefreshSettingsDevices()
if (this.MainGui != "")
this.UpdateGui()
}
static RefreshSettingsDevices() {
if (this.SettingsGui = "" || this.SettingsDdMic = "" || this.SettingsDdSpk = "")
return
try {
this.SettingsDdMic.Delete()
micList := []
selMicIdx := 1
ctr := 1
for name, id in this.AvailableMics {
micList.Push(name)
if (name = this.CurrentMicName || id = this.CurrentMicName || (this.CurrentMicId != "" && id = this.CurrentMicId))
selMicIdx := ctr
ctr++
}
if (micList.Length = 0)
micList.Push("(No microphone found)")
this.SettingsDdMic.Add(micList)
this.SettingsDdMic.Choose(selMicIdx)
if (this.SettingsLblMicStatus != "")
this.SettingsLblMicStatus.Value := "Active: " this.GetMicDisplayName()
}
try {
this.SettingsDdSpk.Delete()
spkList := []
selSpkIdx := 1
ctr := 1
for name, id in this.AvailableSpeakers {
spkList.Push(name)
if (name = this.CurrentSpeakerName || id = this.CurrentSpeakerName || (this.CurrentSpeakerId != "" && id = this.CurrentSpeakerId))
selSpkIdx := ctr
ctr++
}
if (spkList.Length = 0)
spkList.Push("(No speaker found)")
this.SettingsDdSpk.Add(spkList)
this.SettingsDdSpk.Choose(selSpkIdx)
if (this.SettingsLblSpkStatus != "")
this.SettingsLblSpkStatus.Value := "Active: " this.GetSpkDisplayName()
}
}
static GetMicDisplayName() {
if (this.CurrentMicName != "")
return this.CurrentMicName
for name, id in this.AvailableMics {
if (id = this.CurrentMicId)
return name
}
return "No microphone selected"
}
static GetSpkDisplayName() {
if (this.CurrentSpeakerName != "")
return this.CurrentSpeakerName
for name, id in this.AvailableSpeakers {
if (id = this.CurrentSpeakerId)
return name
}
return "No speaker selected"
}
static ToggleMicMute() {
; Not interruptible by the 1-second timer while the mute state changes.
Critical
try {
target := this.CurrentMicId != "" ? this.CurrentMicId : this.CurrentMicName
if this.ToggleAllInGroup(this.MicAll, this.MuteAllMics, target) {
this.UpdateState()
return
}
if (target = "") {
this.AutoRefreshDevices()
target := this.CurrentMicId != "" ? this.CurrentMicId : this.CurrentMicName
}
if (target = "")
throw Error("No microphone device found.")
cur := SoundGetMute(, target)
SoundSetMute(!cur,, target)
this.UpdateState()
} catch as e {
TrayTip("Mic Error: " e.Message, this.AppName, "Icon!")
}
}
; ---- Microphone in-use indicator ----------------------------------------------------
; Runs every 2 s. Refreshes the icon right away when the set of apps changes.
static CheckMicUsers() {
try {
if this.RefreshMicUsers()
this.UpdateState()
}
}
; Returns true when the list of apps using a microphone changed.
static RefreshMicUsers() {
found := Map()
found.CaseSense := "Off"
; 1) The per-app flags Windows keeps for its own microphone privacy indicator
;    (covers Store apps, desktop programs and system services).
for root in ["HKCU", "HKLM"] {
base := "Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone"
this.CollectConsentMicUsers(root, base, found)
this.CollectConsentMicUsers(root, base "\NonPackaged", found)
}
; 2) Live capture sessions, per process.
try {
for name in this.GetCaptureSessionApps()
found[name] := true
}
list := []
for name in found
list.Push(name)
changed := this.JoinNames(list) != this.JoinNames(this.MicUsers)
this.MicUsers := list
return changed
}
static CollectConsentMicUsers(root, key, found) {
try {
Loop Reg, root "\" key, "K" {
name := A_LoopRegName
if (name = "NonPackaged")
continue
try {
stop  := this.RegReadQword(root, key "\" name, "LastUsedTimeStop")
start := this.RegReadQword(root, key "\" name, "LastUsedTimeStart")
} catch {
continue
}
; In use = started and not stopped yet. After a power loss or crash Windows may never
; write the stop time, so only trust entries started since the last boot.
if (stop != 0 || start = 0 || start < this.BootFileTime())
continue
if InStr(name, "#") {
name := RegExReplace(name, ".*#")              ; desktop program: exe path with # for \
if !ProcessExist(name)                         ; stale entry: the program is not running
continue
} else {
name := RegExReplace(name, "_[a-z0-9]{13}$")   ; Store app: drop the publisher id
}
found[name] := true
}
}
}
; Boot time as a FILETIME (100 ns units since 1601), the format of the registry timestamps.
static BootFileTime() {
DllCall("GetSystemTimeAsFileTime", "Int64*", &now := 0)
return now - DllCall("GetTickCount64", "Int64") * 10000
}
; AutoHotkey's RegRead cannot read REG_QWORD values, so call the Windows API directly.
static RegReadQword(root, subKey, valueName) {
hRoot := root = "HKLM" ? -2147483646 : -2147483647   ; HKEY_LOCAL_MACHINE / HKEY_CURRENT_USER
buf := Buffer(8, 0), size := 8
r := DllCall("advapi32\RegGetValueW", "Ptr", hRoot, "Str", subKey, "Str", valueName
, "UInt", 0x48, "Ptr", 0, "Ptr", buf, "UInt*", &size, "UInt")      ; RRF_RT_QWORD
if (r != 0)
throw OSError(r)
return NumGet(buf, 0, "Int64")
}
; Processes with an active audio session on any microphone.
static GetCaptureSessionApps() {
apps := []
iidSM2 := Buffer(16)
DllCall("ole32\CLSIDFromString", "Str", "{77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F}", "Ptr", iidSM2)
enumr := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
ComCall(3, enumr, "Int", 1, "UInt", 1, "Ptr*", &pColl := 0)
coll := ComValue(13, pColl)
ComCall(3, coll, "UInt*", &count := 0)
self := DllCall("GetCurrentProcessId", "UInt")
loop count {
try {
ComCall(4, coll, "UInt", A_Index - 1, "Ptr*", &pDev := 0)
dev := ComValue(13, pDev)
ComCall(3, dev, "Ptr", iidSM2, "UInt", 23, "Ptr", 0, "Ptr*", &pSM := 0)
sm := ComValue(13, pSM)
ComCall(5, sm, "Ptr*", &pSE := 0)
se := ComValue(13, pSE)
ComCall(3, se, "Int*", &n := 0)
loop n {
try {
ComCall(4, se, "Int", A_Index - 1, "Ptr*", &pCtl := 0)
ctl := ComValue(13, pCtl)
ComCall(3, ctl, "Int*", &state := 0)
if (state != 1)                                  ; AudioSessionStateActive
continue
c2 := ComObjQuery(ctl, "{bfb7ff88-7239-4fc9-8fa2-07c950be9c6d}")
ComCall(14, c2, "UInt*", &pid := 0)              ; IAudioSessionControl2::GetProcessId
if (pid = 0 || pid = self)
continue
name := ""
try name := ProcessGetName(pid)
apps.Push(name != "" ? name : "PID " pid)
}
}
}
}
return apps
}
; "x.ico" -> "x_inuse.ico" (same icon with the orange dot), if that file exists.
static InUseIconPath(path) {
if !(path ~= "i)\.ico$")
return ""
alt := RegExReplace(path, "i)\.ico$", "_inuse.ico")
return FileExist(alt) ? alt : ""
}
static JoinNames(arr) {
s := ""
for x in arr
s .= (s = "" ? "" : ", ") x
return s
}
; "Mute all" toggle for one group (microphones or speakers). Returns true if it handled the click.
static ToggleAllInGroup(g, enabled, fallbackTarget) {
if !(g.Active || enabled)
return false
; Speakers: the selected output was muted outside TrayMute, so it is what the icon shows
; as muted; unmute it instead of muting everything.
if (g = this.SpkAll && this.SpkFollowsSelected && !g.Active && fallbackTarget != "") {
try {
if SoundGetMute(, fallbackTarget) {
SoundSetMute(false,, fallbackTarget)
return true
}
}
}
allMuted := this.AllInGroupMuted(g)
; Restore when every device is muted (also when muted outside TrayMute: the gray icon
; needs only one click), or when the option was turned off while still muted.
if ((g.Active && (allMuted = 1 || !enabled)) || (enabled && allMuted = 1)) {
this.RestoreGroup(g, fallbackTarget)
return true
}
if enabled {
this.MuteGroup(g)
return true
}
return false
}
; Active endpoints of one data flow (0 = output, 1 = input) with their volume interface.
static GetEndpoints(flow) {
eps := []
enumr := ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
ComCall(3, enumr, "Int", flow, "UInt", 1, "Ptr*", &pColl := 0)
coll := ComValue(13, pColl)
ComCall(3, coll, "UInt*", &count := 0)
iid := Buffer(16)
DllCall("ole32\CLSIDFromString", "Str", "{5CDF2C82-841E-4546-9722-0CF74078229A}", "Ptr", iid)
loop count {
; One failing device (e.g. unplugged mid-call) must not break the others.
try {
ComCall(4, coll, "UInt", A_Index - 1, "Ptr*", &pDev := 0)
dev := ComValue(13, pDev)
ComCall(5, dev, "Ptr*", &pId := 0)
id := StrGet(pId, "UTF-16")
DllCall("ole32\CoTaskMemFree", "Ptr", pId)
ComCall(3, dev, "Ptr", iid, "UInt", 23, "Ptr", 0, "Ptr*", &pVol := 0)
eps.Push({Id: id, Vol: ComValue(13, pVol)})
}
}
return eps
}
static EndpointIsMuted(ep) {
ComCall(15, ep.Vol, "Int*", &m := 0)
return m != 0
}
static SetEndpointMute(ep, mute) {
ComCall(14, ep.Vol, "Int", mute ? 1 : 0, "Ptr", 0)
}
static AllInGroupMuted(g) {
checked := 0
for ep in this.GetEndpoints(g.Flow) {
try {
muted := this.EndpointIsMuted(ep)
} catch {
continue
}
checked++
if !muted
return 0
}
return checked = 0 ? -1 : 1
}
static AddUniqueId(arr, id) {
for x in arr {
if (x = id)
return
}
arr.Push(id)
}
static ListHasId(arr, id) {
for x in arr {
if (x = id)
return true
}
return false
}
static MuteGroup(g) {
; Mark the state first, so a failure halfway still leaves "mute all" active.
g.Active := true
; Devices still waiting to be restored from a previous round keep their claim.
for id in g.PendingIds {
if !this.ListHasId(g.RestoreIds, id)
g.RestoreIds.Push(id)
}
g.PendingIds := []
known := Map()
for ep in this.GetEndpoints(g.Flow) {
try {
if !this.EndpointIsMuted(ep) {
this.SetEndpointMute(ep, true)
if !this.ListHasId(g.RestoreIds, ep.Id)
g.RestoreIds.Push(ep.Id)
}
; Only devices handled successfully count as known; the rest are retried by SyncGroup.
known[ep.Id] := true
}
}
g.KnownIds := known
this.SaveGroupState(g)
}
static RestoreGroup(g, fallbackTarget) {
Critical
hadList := g.RestoreIds.Length > 0
present := Map()
restored := 0
; Keep devices still waiting from an earlier round (e.g. gray-icon click while one is unplugged).
pending := g.PendingIds.Clone()
for ep in this.GetEndpoints(g.Flow) {
present[ep.Id] := true
if !this.ListHasId(g.RestoreIds, ep.Id)
continue
try {
this.SetEndpointMute(ep, false)
restored++
} catch {
this.AddUniqueId(pending, ep.Id)
}
}
; Devices unplugged while muted are restored when they come back.
for id in g.RestoreIds {
if !present.Has(id)
this.AddUniqueId(pending, id)
}
; Fallback: no list at all (muted outside TrayMute, or the .ini was lost), or nothing
; on the list could be restored and every device is still muted (avoids a second click).
if (!hadList || (restored = 0 && this.AllInGroupMuted(g) = 1)) {
if (fallbackTarget != "")
try SoundSetMute(false,, fallbackTarget)
}
g.Active := false
g.RestoreIds := []
g.PendingIds := pending
g.KnownIds := Map()
this.SaveGroupState(g)
}
static MuteNewInGroup(g) {
if !g.Active
return
changed := false
for ep in this.GetEndpoints(g.Flow) {
if g.KnownIds.Has(ep.Id)
continue
try {
if !this.EndpointIsMuted(ep) {
this.SetEndpointMute(ep, true)
if !this.ListHasId(g.RestoreIds, ep.Id) {
g.RestoreIds.Push(ep.Id)
changed := true
}
}
g.KnownIds[ep.Id] := true
}
}
if changed
this.SaveGroupState(g)
}
static RestorePendingInGroup(g) {
if (g.Active || g.PendingIds.Length = 0)
return
byId := Map()
for ep in this.GetEndpoints(g.Flow)
byId[ep.Id] := ep
remaining := []
for id in g.PendingIds {
if byId.Has(id) {
try {
this.SetEndpointMute(byId[id], false)
continue
}
}
remaining.Push(id)
}
if (remaining.Length != g.PendingIds.Length) {
g.PendingIds := remaining
this.SaveGroupState(g)
}
}
static SyncGroup(g) {
; Not interruptible by a click, so a mute/restore cannot interleave with this pass.
Critical
if g.Active
this.MuteNewInGroup(g)
else
this.RestorePendingInGroup(g)
}
; Runs on startup, on device notifications and every second from UpdateState. Catches
; devices that appear without a notification (e.g. enabled in the Sound panel).
static SyncAllGroups() {
for g in [this.MicAll, this.SpkAll] {
if (g.Active || g.PendingIds.Length > 0)
try this.SyncGroup(g)
}
}
static ToggleSpeakerMute(source := "") {
; Not interruptible by the 1-second timer while the mute state changes.
Critical
try {
if (source = "tray") {
last := this.SpeakerLastToggleTime ? this.SpeakerLastToggleTime : 0
if (A_TickCount - last < 300)
return
this.SpeakerLastToggleTime := A_TickCount
}
target := this.CurrentSpeakerId != "" ? this.CurrentSpeakerId : this.CurrentSpeakerName
if this.ToggleAllInGroup(this.SpkAll, this.MuteAllSpeakers, target) {
this.UpdateState()
return
}
if (target = "") {
this.AutoRefreshDevices()
target := this.CurrentSpeakerId != "" ? this.CurrentSpeakerId : this.CurrentSpeakerName
}
if (target = "")
throw Error("No speaker device found.")
cur := SoundGetMute(, target)
SoundSetMute(!cur,, target)
this.UpdateState()
} catch as e {
TrayTip("Speaker Error: " e.Message, this.AppName, "Icon!")
}
}
static SetupSpeakerTray() {
if (this.SpeakerTraySetupInProgress)
return
this.SpeakerTraySetupInProgress := true
if (this.SpeakerNID) {
DllCall("shell32\Shell_NotifyIconW", "UInt", 2, "Ptr", this.SpeakerNID)
this.SpeakerNID := ""
}
if (this.SpeakerMsgHandler) {
try OnMessage(this.SpeakerMsg, this.SpeakerMsgHandler, 0)
this.SpeakerMsgHandler := ""
}
if (this.SpeakerGui != "") {
try this.SpeakerGui.Destroy()
this.SpeakerGui := ""
}
g := Gui("-Caption +ToolWindow")
g.BackColor := "FFFFFF"
g.Show("x-32000 y-32000 w1 h1 Hide")
this.SpeakerGui := g
hwnd := g.hwnd
msgId := 0x405
this.SpeakerMsg := msgId
cbSize := A_PtrSize == 8 ? 976 : 956
nid := Buffer(cbSize, 0)
NumPut("UInt", cbSize, nid, 0)
hwndOffset := A_PtrSize == 8 ? 8 : 4
NumPut("Ptr", hwnd, nid, hwndOffset)
uidOffset := A_PtrSize == 8 ? 16 : 8
NumPut("UInt", 3, nid, uidOffset)
flagsOffset := A_PtrSize == 8 ? 20 : 12
NumPut("UInt", 0x87, nid, flagsOffset)
msgOffset := A_PtrSize == 8 ? 24 : 16
NumPut("UInt", msgId, nid, msgOffset)
iconOffset := A_PtrSize == 8 ? 32 : 20
idx  := this.IsSpeakerMuted ? this.SpkIconIdxOff : this.SpkIconIdxOn
path := this.IsSpeakerMuted ? this.SpkIconPathOff : this.SpkIconPathOn
resolvedPath := this.ResolveIconPath(path)
NumPut("Ptr", 0, nid, iconOffset)
hIcon := LoadPicture(resolvedPath, "w16 h16 Icon" (idx + 1), &imgtype)
NumPut("Ptr", hIcon, nid, iconOffset)
tipOffset := A_PtrSize == 8 ? 40 : 24
tipText := this.IsSpeakerMuted ? "Speaker : Mute" : "Speaker : Active"
StrPut(tipText, nid.Ptr + tipOffset, 128, "UTF-16")
DllCall("shell32\Shell_NotifyIconW", "UInt", 0, "Ptr", nid)
this.SpeakerNID := nid
versionNid := Buffer(cbSize, 0)
NumPut("UInt", cbSize, versionNid, 0)
NumPut("Ptr", hwnd, versionNid, hwndOffset)
NumPut("UInt", 3, versionNid, uidOffset)
versionOffset := A_PtrSize == 8 ? 552 : 540
NumPut("UInt", 4, versionNid, versionOffset)
DllCall("shell32\Shell_NotifyIconW", "UInt", 4, "Ptr", versionNid)
spkMenu := Menu()
spkMenu.Add("Toggle Speaker", (*) => this.ToggleSpeakerMute())
this.SafeMenuSetIcon(spkMenu, "Toggle Speaker", this.SpkIconPathOn, this.SpkIconIdxOn)
spkMenu.Add("Toggle Microphone", (*) => this.ToggleMicMute())
this.SafeMenuSetIcon(spkMenu, "Toggle Microphone", this.IconPathUnmuted, this.IconIdxUnmuted)
spkMenu.Add()
spkMenu.Add("Show Controls", (*) => this.ShowGUI())
this.SafeMenuSetIcon(spkMenu, "Show Controls", "shell32.dll", 22)
spkMenu.Add("Settings", (*) => this.ShowSettings())
this.SafeMenuSetIcon(spkMenu, "Settings", "shell32.dll", 22)
spkMenu.Add()
spkMenu.Add("Exit", (*) => MicController.OnExit())
this.SafeMenuSetIcon(spkMenu, "Exit", "shell32.dll", 132)
this.SpeakerContextMenu := spkMenu
handler := ObjBindMethod(this, "OnSpeakerTrayMsg")
this.SpeakerMsgHandler := handler
OnMessage(msgId, handler)
this.SpeakerTraySetupInProgress := false
}
static UpdateSpeakerTrayIcon() {
if !this.SpeakerNID
return
nid := this.SpeakerNID
flagsOffset := A_PtrSize == 8 ? 20 : 12
iconOffset  := A_PtrSize == 8 ? 32 : 20
idx  := this.IsSpeakerMuted ? this.SpkIconIdxOff : this.SpkIconIdxOn
path := this.IsSpeakerMuted ? this.SpkIconPathOff : this.SpkIconPathOn
resolvedPath := this.ResolveIconPath(path)
try {
prevIcon := NumGet(nid, iconOffset, "Ptr")
if prevIcon
DllCall("DestroyIcon", "Ptr", prevIcon)
}
try {
hIcon := LoadPicture(resolvedPath, "w16 h16 Icon" (idx + 1), &imgtype)
NumPut("Ptr", hIcon, nid, iconOffset)
}
tipOffset := A_PtrSize == 8 ? 40 : 24
tipText := !this.IsSpeakerMuted ? "Speaker : Active"
: this.SpkAll.Active ? "Speaker : Mute (all)" : "Speaker : Mute"
StrPut(tipText, nid.Ptr + tipOffset, 128, "UTF-16")
NumPut("UInt", 0x86, nid, flagsOffset)
DllCall("shell32\Shell_NotifyIconW", "UInt", 1, "Ptr", nid)
}
static OnSpeakerTrayMsg(wParam, lParam, msg, hwnd) {
event := lParam & 0xFFFF
if (event = 0x202) {
MicController.ToggleSpeakerMute("tray")
} else if (event = 0x205 || event = 0x204) {
if (MicController.SpeakerContextMenu) {
DllCall("SetForegroundWindow", "Ptr", MicController.SpeakerGui.hwnd)
MicController.SpeakerContextMenu.Show()
}
}
}
static OnExitHandler(*) {
if (this.SpeakerNID)
DllCall("shell32\Shell_NotifyIconW", "UInt", 2, "Ptr", this.SpeakerNID)
}
static OnExit() {
ExitApp()
}
static ResolveIconPath(path) {
if !path
return ""
path := StrReplace(path, "/", "\")
path := StrReplace(path, "{app}", A_ScriptDir)
if FileExist(A_ScriptDir "\" path)
return A_ScriptDir "\" path
if FileExist(path)
return path
if RegExMatch(path, "i)\\icons\\(.+)$", &m) {
candidate := A_ScriptDir "\icons\" m[1]
if FileExist(candidate)
return candidate
}
if RegExMatch(path, "i)\\?([^\\]+\.ico)$", &m) {
themeFolder := this.TaskbarUsesLightTheme() ? "light" : "dark"
candidate := A_ScriptDir "\icons\" themeFolder "\" m[1]
if FileExist(candidate)
return candidate
otherFolder := this.TaskbarUsesLightTheme() ? "dark" : "light"
candidateAlt := A_ScriptDir "\icons\" otherFolder "\" m[1]
if FileExist(candidateAlt)
return candidateAlt
}
if !InStr(path, "\") {
sysPath := A_WinDir "\System32\" path
if FileExist(sysPath)
return sysPath
wow64 := A_WinDir "\SysWOW64\" path
if FileExist(wow64)
return wow64
}
return path
}
static SafeMenuSetIcon(menuObj, itemName, path, idx) {
resolved := this.ResolveIconPath(path)
try menuObj.SetIcon(itemName, resolved, idx)
}
static UpdateTrayMenuIcons() {
micPath := this.IsMuted ? this.IconPathMuted : this.IconPathUnmuted
micIdx  := this.IsMuted ? this.IconIdxMuted  : this.IconIdxUnmuted
this.SafeMenuSetIcon(A_TrayMenu, "Toggle Microphone", micPath, micIdx)
spkPath := this.IsSpeakerMuted ? this.SpkIconPathOff : this.SpkIconPathOn
spkIdx  := this.IsSpeakerMuted ? this.SpkIconIdxOff  : this.SpkIconIdxOn
this.SafeMenuSetIcon(A_TrayMenu, "Toggle Speaker", spkPath, spkIdx)
}
static UpdateState() {
micTarget := this.CurrentMicId != "" ? this.CurrentMicId : this.CurrentMicName
spkTarget := this.CurrentSpeakerId != "" ? this.CurrentSpeakerId : this.CurrentSpeakerName
gotMic := false
gotSpk := false
this.SyncAllGroups()
if (this.MuteAllMics || this.MicAll.Active) {
try {
allMuted := this.AllInGroupMuted(this.MicAll)
if (allMuted != -1) {
this.IsMuted := allMuted = 1
gotMic := true
}
}
}
; While "mute all" is not engaged the speaker icon follows the selected output (read below).
if (this.SpkAll.Active || (this.MuteAllSpeakers && !this.SpkFollowsSelected)) {
try {
allMuted := this.AllInGroupMuted(this.SpkAll)
if (allMuted != -1) {
this.IsSpeakerMuted := allMuted = 1
gotSpk := true
}
}
}
loop 3 {
if (!gotMic && micTarget != "") {
try {
this.IsMuted := SoundGetMute(, micTarget)
gotMic := true
}
}
if (!gotSpk && spkTarget != "") {
try {
this.IsSpeakerMuted := SoundGetMute(, spkTarget)
gotSpk := true
}
}
if ((gotMic || micTarget = "") && (gotSpk || spkTarget = ""))
break
if (A_Index < 3)
Sleep(50)
}
if ((!gotMic && micTarget != "") || (!gotSpk && spkTarget != "")) {
SetTimer(() => MicController.AutoRefreshDevices(), -200)
}
this.DeviceCheckCounter++
if (this.DeviceCheckCounter >= 5) {
this.DeviceCheckCounter := 0
micValid := this.CurrentMicName != "" && this.AvailableMics.Has(this.CurrentMicName)
spkValid := this.CurrentSpeakerName != "" && this.AvailableSpeakers.Has(this.CurrentSpeakerName)
if (!micValid || !spkValid)
this.AutoRefreshDevices()
}
if this.IsMuted {
resolvedPath := this.ResolveIconPath(this.IconPathMuted)
iconIdx := this.IconIdxMuted
tip := (this.MuteAllMics || this.MicAll.Active) ? "MIC : Mute (all)" : "MIC : Mute"
} else {
resolvedPath := this.ResolveIconPath(this.IconPathUnmuted)
iconIdx := this.IconIdxUnmuted
tip := "MIC : Active"
}
; Orange dot when any app is using a microphone, muted or not (like the iPhone indicator).
if (this.MicUsers.Length > 0) {
inUsePath := this.InUseIconPath(resolvedPath)
if (inUsePath != "")
resolvedPath := inUsePath
tip .= "`nIn use by: " this.JoinNames(this.MicUsers)
}
try TraySetIcon(resolvedPath, iconIdx)
A_IconTip := StrLen(tip) > 127 ? SubStr(tip, 1, 124) "..." : tip
this.LastMicMuteState := this.IsMuted
this.UpdateTrayMenuIcons()
this.UpdateSpeakerTrayIcon()
this.UpdateGui()
this.UpdateMiniWindow()
}
static ShowGUI() {
if (this.MainGui != "") {
this.MainGui.Show()
return
}
bg   := "F3F3F3"
card := "FFFFFF"
fg   := "1A1A1A"
sub  := "616161"
acc  := "0078D4"
g := Gui("+AlwaysOnTop -MinimizeBox", this.AppName)
g.BackColor := bg
g.MarginX := 16
g.MarginY := 12
g.SetFont("s10", "Segoe UI")
this.MainGui := g
g.SetFont("s14 bold", "Segoe UI")
hdr := g.Add("Text", "xm w368 center", this.AppName)
hdr.Opt("c" fg)
g.SetFont("s8", "Segoe UI")
ver := g.Add("Text", "xm w368 center", "Audio Control Panel")
ver.Opt("c" sub)
g.SetFont("s10", "Segoe UI")
g.Add("Text", "xm y+8 w368 h1 0x10")
g.SetFont("s9 bold", "Segoe UI")
g.Add("Text", "xm y+10 w368 h28 0x200 Background" card, "   Microphone").Opt("c" fg)
g.SetFont("s9 norm", "Segoe UI")
micList := []
selMicIdx := 1
ctr := 1
for name, id in this.AvailableMics {
micList.Push(name)
if (name = this.CurrentMicName || id = this.CurrentMicName || (this.CurrentMicId != "" && id = this.CurrentMicId))
selMicIdx := ctr
ctr++
}
if micList.Length = 0
micList.Push("(No microphone found)")
this.DropdownMics := g.Add("DropDownList", "xm y+4 w368 Choose" selMicIdx, micList)
this.DropdownMics.Opt("Background" card " c" fg)
this.DropdownMics.OnEvent("Change", (*) => this.OnMicDeviceChange())
g.SetFont("s16 bold", "Segoe UI")
this.TextMicStatus := g.Add("Text", "xm y+6 w368 h40 center Background" card, "Checking...")
this.TextMicStatus.Opt("c" sub)
g.SetFont("s10", "Segoe UI")
this.BtnTrayMute := g.Add("Button", "xm y+4 w368 h38", "Toggle Mic")
this.BtnTrayMute.OnEvent("Click", (*) => this.ToggleMicMute())
g.Add("Text", "xm y+12 w368 h1 0x10")
g.SetFont("s9 bold", "Segoe UI")
g.Add("Text", "xm y+10 w368 h28 0x200 Background" card, "   Speaker / Output").Opt("c" fg)
g.SetFont("s9 norm", "Segoe UI")
spkList := []
selSpkIdx := 1
ctr := 1
for name, id in this.AvailableSpeakers {
spkList.Push(name)
if (name = this.CurrentSpeakerName || id = this.CurrentSpeakerName || (this.CurrentSpeakerId != "" && id = this.CurrentSpeakerId))
selSpkIdx := ctr
ctr++
}
if spkList.Length = 0
spkList.Push("(No speaker found)")
this.DropdownSpks := g.Add("DropDownList", "xm y+4 w368 Choose" selSpkIdx, spkList)
this.DropdownSpks.Opt("Background" card " c" fg)
this.DropdownSpks.OnEvent("Change", (*) => this.OnSpeakerDeviceChange())
g.SetFont("s16 bold", "Segoe UI")
this.TextSpkStatus := g.Add("Text", "xm y+6 w368 h40 center Background" card, "Checking...")
this.TextSpkStatus.Opt("c" sub)
g.SetFont("s10", "Segoe UI")
this.BtnSpkToggle := g.Add("Button", "xm y+4 w368 h38", "Toggle Speaker")
this.BtnSpkToggle.OnEvent("Click", (*) => this.ToggleSpeakerMute())
g.Add("Text", "xm y+12 w368 h1 0x10")
btnSettings := g.Add("Button", "xm y+8 w178 h34", "Settings")
btnSettings.OnEvent("Click", (*) => this.ShowSettings())
btnWinSound := g.Add("Button", "x+12 yp w178 h34", "Sound Settings")
btnWinSound.OnEvent("Click", (*) => Run("ms-settings:sound"))
g.OnEvent("Close", (*) => (this.MainGui := "", g.Destroy()))
g.Show("w400 AutoSize")
this.UpdateGui()
}
static OnMicDeviceChange() {
sel := this.DropdownMics.Text
if this.AvailableMics.Has(sel) {
this.CurrentMicName := sel
this.CurrentMicId   := this.AvailableMics[sel]
this.SaveSettings()
this.UpdateState()
}
}
static OnSpeakerDeviceChange() {
sel := this.DropdownSpks.Text
if this.AvailableSpeakers.Has(sel) {
this.CurrentSpeakerName := sel
this.CurrentSpeakerId   := this.AvailableSpeakers[sel]
this.SaveSettings()
this.UpdateState()
}
}
static UpdateGui() {
if (this.MainGui = "")
return
card := this.ThemeCard
try {
if this.IsMuted {
this.TextMicStatus.Value := "  MICROPHONE MUTED"
this.TextMicStatus.Opt("cE81123 Background" card)
this.BtnTrayMute.Text := "Unmute Microphone"
} else {
this.TextMicStatus.Value := "  MICROPHONE LIVE"
this.TextMicStatus.Opt("c0F7B0F Background" card)
this.BtnTrayMute.Text := "Mute Microphone"
}
}
try {
if this.IsSpeakerMuted {
this.TextSpkStatus.Value := "  SPEAKER MUTED"
this.TextSpkStatus.Opt("cE81123 Background" card)
this.BtnSpkToggle.Text := "Unmute Speaker"
} else {
this.TextSpkStatus.Value := "  SPEAKER ACTIVE"
this.TextSpkStatus.Opt("c0F7B0F Background" card)
this.BtnSpkToggle.Text := "Mute Speaker"
}
}
}
static ShowMiniWindow() {
if (this.MiniGui != "")
return
if !(this.ShowMiniMicIcon || this.ShowMiniSpkIcon) {
this.ShowMiniMicIcon := true
this.ShowMiniSpkIcon := true
}
this.ApplyTheme()
bg := this.ThemeCard
borderStyle := this.MiniWindowBorder ? " +Border" : ""
borderExtra := this.MiniWindowBorder ? 2 : 0
dpiScale := A_ScreenDPI / 96.0
sizeScale := Max(0.01, Min(2.0, this.MiniWindowSize / 100.0)) * dpiScale
btnSize := Max(24, Round(32 * sizeScale))
iconSize := Max(16, Round(24 * sizeScale))
margin := Max(4, Round(6 * sizeScale))
if Mod(btnSize, 2) != 0
btnSize++
if Mod(iconSize, 2) != 0
iconSize++
visibleCount := 0
if (this.ShowMiniMicIcon)
visibleCount++
if (this.ShowMiniSpkIcon)
visibleCount++
windowW := margin + (btnSize * visibleCount) + (margin * (visibleCount - 1)) + margin
windowH := margin + btnSize + margin
m := Gui("-Caption +AlwaysOnTop +ToolWindow -DPIScale +E0x08000000" borderStyle, "TrayMuteMini")
m.BackColor := bg
this.MiniGui := m
this.MiniMenu := Menu()
currX := margin
btnRadius := Max(4, Round(8 * sizeScale))
if (this.ShowMiniMicIcon) {
bgCtrl := m.Add("Text", "x" currX " y" margin " w" btnSize " h" btnSize " Background" bg, "")
bgCtrl.OnEvent("Click", (*) => this.ToggleMicMute())
bgCtrl.OnEvent("ContextMenu", (*) => this.MiniMenu.Show())
this.MiniMicBgCtrl := bgCtrl
iconPad := (btnSize - iconSize) // 2
iconX := currX + iconPad
iconY := margin + iconPad
iconPath := this.IsMuted ? this.IconPathMuted : this.IconPathUnmuted
iconIndex := this.IsMuted ? this.IconIdxMuted : this.IconIdxUnmuted
resolvedPath := this.ResolveIconPath(iconPath)
picCtrl := m.Add("Picture", "x" iconX " y" iconY " w" iconSize " h" iconSize " Icon" (iconIndex + 1) " BackgroundTrans", resolvedPath)
picCtrl.OnEvent("Click", (*) => this.ToggleMicMute())
picCtrl.OnEvent("ContextMenu", (*) => this.MiniMenu.Show())
this.MiniMicIconCtrl := picCtrl
this.ApplyMiniWindowRounding(bgCtrl.Hwnd, btnSize, btnSize, btnRadius)
currX += btnSize + margin
} else {
this.MiniMicIconCtrl := ""
this.MiniMicBgCtrl := ""
}
if (this.ShowMiniSpkIcon) {
bgCtrl := m.Add("Text", "x" currX " y" margin " w" btnSize " h" btnSize " Background" bg, "")
bgCtrl.OnEvent("Click", (*) => this.ToggleSpeakerMute())
bgCtrl.OnEvent("ContextMenu", (*) => this.MiniMenu.Show())
this.MiniSpkBgCtrl := bgCtrl
iconPad := (btnSize - iconSize) // 2
iconX := currX + iconPad
iconY := margin + iconPad
iconPath := this.IsSpeakerMuted ? this.SpkIconPathOff : this.SpkIconPathOn
iconIndex := this.IsSpeakerMuted ? this.SpkIconIdxOff : this.SpkIconIdxOn
resolvedPath := this.ResolveIconPath(iconPath)
picCtrl := m.Add("Picture", "x" iconX " y" iconY " w" iconSize " h" iconSize " Icon" (iconIndex + 1) " BackgroundTrans", resolvedPath)
picCtrl.OnEvent("Click", (*) => this.ToggleSpeakerMute())
picCtrl.OnEvent("ContextMenu", (*) => this.MiniMenu.Show())
this.MiniSpkIconCtrl := picCtrl
this.ApplyMiniWindowRounding(bgCtrl.Hwnd, btnSize, btnSize, btnRadius)
} else {
this.MiniSpkIconCtrl := ""
this.MiniSpkBgCtrl := ""
}
this.MiniMenu.Add("Close Mini Window", (*) => this.DestroyMiniWindow())
m.OnEvent("ContextMenu", (*) => this.MiniMenu.Show())
m.OnEvent("Close", (*) => (this.MiniGui := ""))
showOpts := "w" windowW " h" windowH " NoActivate"
if (this.MiniWindowSavedX && this.MiniWindowSavedY) {
showOpts := "x" this.MiniWindowSavedX " y" this.MiniWindowSavedY " " showOpts
} else if (this.MiniWindowCenterX && this.MiniWindowCenterY) {
showOpts := "x" Round(this.MiniWindowCenterX - windowW / 2) " y" Round(this.MiniWindowCenterY - windowH / 2) " " showOpts
}
m.Show(showOpts)
this.ApplyMiniWindowRounding(m.Hwnd, windowW, windowH, Max(8, Round(12 * sizeScale)))
this.MiniLButtonDownHandler := ObjBindMethod(this, "OnMiniLButtonDown")
this.MiniCursorHandler  := ObjBindMethod(this, "OnMiniCursorMessage")
this.MiniMoveHandler    := ObjBindMethod(this, "OnMiniMove")
this.MiniMouseMoveHandler := ObjBindMethod(this, "OnMiniMouseMove")
this.MiniHoverTimerActive := false
this.OnMiniMouseMoveAction := ObjBindMethod(this, "CheckMiniHover")
OnMessage(0x0200, this.MiniMouseMoveHandler)
OnMessage(0x0201, this.MiniLButtonDownHandler)
OnMessage(0x20, this.MiniCursorHandler)
OnMessage(0x3,  this.MiniMoveHandler)
this.UpdateMiniWindow()
}
static ApplyMiniWindowRounding(hwnd, width, height, radius := 12) {
if (!hwnd)
return
hrgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", width + 1, "Int", height + 1, "Int", radius, "Int", radius, "Ptr")
if (hrgn)
DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", hrgn, "Int", true)
}
static BeginMiniDrag() {
if (this.MiniGui = "")
return
DllCall("User32.dll\ReleaseCapture")
DllCall("User32.dll\SendMessageW", "Ptr", this.MiniGui.Hwnd, "UInt", 0x112, "Ptr", 0xF012, "Ptr", 0)
}
static SetMiniCursor(cursorId) {
cursor := DllCall("LoadCursor", "Ptr", 0, "UInt", cursorId, "Ptr")
if cursor
DllCall("SetCursor", "Ptr", cursor)
}
static OnMiniLButtonDown(wParam, lParam, msg, hwnd) {
if (!this.MiniGui)
return
if (hwnd = this.MiniGui.Hwnd) {
DllCall("ReleaseCapture")
DllCall("PostMessage", "Ptr", hwnd, "UInt", 0xA1, "Ptr", 2, "Ptr", 0)
}
}
static OnMiniCursorMessage(wParam, lParam, msg, hwnd) {
if (hwnd = this.MiniGui.Hwnd || DllCall("GetParent", "Ptr", hwnd, "Ptr") = this.MiniGui.Hwnd) {
cursor := DllCall("LoadCursor", "Ptr", 0, "UInt", 32649, "Ptr")
if cursor {
DllCall("SetCursor", "Ptr", cursor)
return true
}
}
return false
}
static OnMiniMove(wParam, lParam, msg, hwnd) {
if (hwnd = this.MiniGui.Hwnd) {
this.MiniWindowSavedX := lParam & 0xFFFF
this.MiniWindowSavedY := lParam >> 16
this.SaveSettings()
}
}
static OnMiniMouseMove(wParam, lParam, msg, hwnd) {
if (!this.MiniGui)
return
if (!this.MiniHoverTimerActive && (hwnd = this.MiniGui.Hwnd || DllCall("GetParent", "Ptr", hwnd, "Ptr") = this.MiniGui.Hwnd)) {
this.MiniHoverTimerActive := true
SetTimer(this.OnMiniMouseMoveAction, 25)
}
}
static CurrentHoverState := ""
static CheckMiniHover() {
if (!this.MiniGui) {
this.MiniHoverTimerActive := false
this.CurrentHoverState := ""
SetTimer(this.OnMiniMouseMoveAction, 0)
return
}
try {
MouseGetPos(,, &mWin, &mCtrl)
if (mWin != this.MiniGui.Hwnd) {
this.UpdateHoverState("")
this.MiniHoverTimerActive := false
SetTimer(this.OnMiniMouseMoveAction, 0)
return
}
if (HasProp(this, "MiniMicIconCtrl") && this.MiniMicIconCtrl && (mCtrl = this.MiniMicIconCtrl.Hwnd || mCtrl = this.MiniMicBgCtrl.Hwnd)) {
this.UpdateHoverState("Mic")
} else if (HasProp(this, "MiniSpkIconCtrl") && this.MiniSpkIconCtrl && (mCtrl = this.MiniSpkIconCtrl.Hwnd || mCtrl = this.MiniSpkBgCtrl.Hwnd)) {
this.UpdateHoverState("Spk")
} else {
this.UpdateHoverState("")
}
} catch {
this.UpdateHoverState("")
this.MiniHoverTimerActive := false
SetTimer(this.OnMiniMouseMoveAction, 0)
}
}
static UpdateHoverState(state) {
if (this.CurrentHoverState == state)
return
this.CurrentHoverState := state
if (HasProp(this, "MiniMicBgCtrl") && this.MiniMicBgCtrl)
this.MiniMicBgCtrl.Opt("Background" (state == "Mic" ? this.ThemeHover : this.ThemeCard))
if (HasProp(this, "MiniSpkBgCtrl") && this.MiniSpkBgCtrl)
this.MiniSpkBgCtrl.Opt("Background" (state == "Spk" ? this.ThemeHover : this.ThemeCard))
}
static DestroyMiniWindow() {
if (this.MiniGui != "") {
try {
rect := Buffer(16, 0)
if DllCall("GetWindowRect", "Ptr", this.MiniGui.Hwnd, "Ptr", rect)
{
left := NumGet(rect, 0, "Int")
top := NumGet(rect, 4, "Int")
right := NumGet(rect, 8, "Int")
bottom := NumGet(rect, 12, "Int")
this.MiniWindowCenterX := Round((left + right) / 2)
this.MiniWindowCenterY := Round((top + bottom) / 2)
this.MiniWindowSavedX := left
this.MiniWindowSavedY := top
this.SaveSettings()
}
} catch {
this.MiniWindowCenterX := ""
this.MiniWindowCenterY := ""
this.MiniWindowSavedX := ""
this.MiniWindowSavedY := ""
}
if HasProp(this, "MiniLButtonDownHandler") && this.MiniLButtonDownHandler
OnMessage(0x0201, this.MiniLButtonDownHandler, 0)
if this.MiniCursorHandler
OnMessage(0x20, this.MiniCursorHandler, 0)
if this.MiniMoveHandler
OnMessage(0x3, this.MiniMoveHandler, 0)
if HasProp(this, "MiniMouseMoveHandler") && this.MiniMouseMoveHandler
OnMessage(0x0200, this.MiniMouseMoveHandler, 0)
if HasProp(this, "OnMiniMouseMoveAction") && this.OnMiniMouseMoveAction
try SetTimer(this.OnMiniMouseMoveAction, 0)
this.MiniGui.Destroy()
this.MiniGui := ""
this.MiniMicIconCtrl := ""
this.MiniMicBgCtrl := ""
this.MiniSpkIconCtrl := ""
this.MiniSpkBgCtrl := ""
this.MiniMenu := ""
this.MiniLButtonDownHandler := ""
this.MiniCursorHandler := ""
this.MiniMoveHandler := ""
this.MiniMouseMoveHandler := ""
this.OnMiniMouseMoveAction := ""
}
}
static UpdateMiniWindow() {
if (this.MiniGui = "")
return
bg := this.ThemeCard
this.MiniGui.BackColor := bg
try {
if (HasProp(this, "MiniMicIconCtrl") && this.ShowMiniMicIcon && this.MiniMicIconCtrl) {
iconIndex := this.IsMuted ? this.IconIdxMuted : this.IconIdxUnmuted
iconPath := this.IsMuted ? this.IconPathMuted : this.IconPathUnmuted
resolvedPath := this.ResolveIconPath(iconPath)
this.MiniMicIconCtrl.Opt("Icon" (iconIndex + 1))
this.MiniMicIconCtrl.Value := resolvedPath
}
}
try {
if (HasProp(this, "MiniSpkIconCtrl") && this.ShowMiniSpkIcon && this.MiniSpkIconCtrl) {
iconIndex := this.IsSpeakerMuted ? this.SpkIconIdxOff : this.SpkIconIdxOn
iconPath := this.IsSpeakerMuted ? this.SpkIconPathOff : this.SpkIconPathOn
resolvedPath := this.ResolveIconPath(iconPath)
this.MiniSpkIconCtrl.Opt("Icon" (iconIndex + 1))
this.MiniSpkIconCtrl.Value := resolvedPath
}
}
}
static ShowSettings() {
if (this.SettingsGui != "") {
this.SettingsGui.Show()
return
}
g := Gui("-MinimizeBox -MaximizeBox", "Settings — " this.AppName)
g.BackColor := "FBFBFB"
this.SettingsGui := g
sidebarW := 210
g.Add("Text", "x0 y0 w" sidebarW " h590 BackgroundF2F4F7")
g.SetFont("s12 bold", "Segoe UI")
g.Add("Text", "x20 y18 w170 c1A1A1A BackgroundTrans", this.AppName)
g.SetFont("s8", "Segoe UI")
g.Add("Text", "x20 y40 w170 c707070 BackgroundTrans", "v" this.Version " • Audio Control")
g.Add("Text", "x16 y62 w178 h1 0x10 BackgroundTrans")
pages := [[], [], [], [], []]
g.SetFont("s14 bold", "Segoe UI")
pages[1].Push(g.Add("Text", "x240 y18 w560 c1A1A1A", "Audio Devices"))
g.SetFont("s9", "Segoe UI")
pages[1].Push(g.Add("Text", "x240 y44 w560 c5E5E5E", "Manage active microphone and speaker devices"))
pages[1].Push(g.Add("GroupBox", "x240 y75 w560 h190", "  Microphone Device  "))
pages[1].Push(g.Add("Text", "x256 y100 w400 c1A1A1A", "Select default microphone for muting:"))
micList := []
selMicIdx := 1
ctr := 1
for name, id in this.AvailableMics {
micList.Push(name)
if (name = this.CurrentMicName || id = this.CurrentMicName || (this.CurrentMicId != "" && id = this.CurrentMicId))
selMicIdx := ctr
ctr++
}
if (micList.Length = 0)
micList.Push("(No microphone found)")
ddMic := g.Add("DropDownList", "x256 y122 w424 Choose" selMicIdx, micList)
pages[1].Push(ddMic)
this.SettingsDdMic := ddMic
OnInstantMicChange() {
selMic := ddMic.Text
if this.AvailableMics.Has(selMic) {
this.CurrentMicName := selMic
this.CurrentMicId   := this.AvailableMics[selMic]
if (this.SettingsLblMicStatus != "")
this.SettingsLblMicStatus.Value := "Active: " this.GetMicDisplayName()
if (this.MainGui != "")
this.UpdateGui()
this.SaveSettings()
this.UpdateState()
this.NotifySettingsSaved()
}
}
ddMic.OnEvent("Change", (*) => OnInstantMicChange())
btnRefMic := g.Add("Button", "x688 y121 w96 h28", "🔄 Refresh")
btnRefMic.OnEvent("Click", (*) => this.OnRefreshMics())
pages[1].Push(btnRefMic)
lblMicStatus := g.Add("Text", "x256 y156 w528 c5E5E5E", "Active: " this.GetMicDisplayName())
pages[1].Push(lblMicStatus)
this.SettingsLblMicStatus := lblMicStatus
btnWinRec := g.Add("Button", "x256 y185 w160 h30", "🎙️ Sound Recording")
btnWinRec.OnEvent("Click", (*) => Run("rundll32.exe shell32.dll,Control_RunDLL mmsys.cpl,,1"))
pages[1].Push(btnWinRec)
btnWinMicPriv := g.Add("Button", "x426 y185 w160 h30", "🔒 Mic Privacy")
btnWinMicPriv.OnEvent("Click", (*) => Run("ms-settings:privacy-microphone"))
pages[1].Push(btnWinMicPriv)
chkMuteAll := g.Add("CheckBox", "x256 y228 w528 c1A1A1A", "Mute all microphones (unmute restores each one's previous state)")
chkMuteAll.Value := this.MuteAllMics ? 1 : 0
pages[1].Push(chkMuteAll)
OnInstantMuteAllToggle() {
this.MuteAllMics := chkMuteAll.Value = 1
this.SaveSettings()
this.UpdateState()
this.NotifySettingsSaved()
}
chkMuteAll.OnEvent("Click", (*) => OnInstantMuteAllToggle())
pages[1].Push(g.Add("GroupBox", "x240 y280 w560 h190", "  Speaker Device  "))
pages[1].Push(g.Add("Text", "x256 y305 w400 c1A1A1A", "Select default speaker / output device:"))
spkList := []
selSpkIdx := 1
ctr := 1
for name, id in this.AvailableSpeakers {
spkList.Push(name)
if (name = this.CurrentSpeakerName || id = this.CurrentSpeakerName || (this.CurrentSpeakerId != "" && id = this.CurrentSpeakerId))
selSpkIdx := ctr
ctr++
}
if (spkList.Length = 0)
spkList.Push("(No speaker found)")
ddSpk := g.Add("DropDownList", "x256 y327 w424 Choose" selSpkIdx, spkList)
pages[1].Push(ddSpk)
this.SettingsDdSpk := ddSpk
OnInstantSpkChange() {
selSpk := ddSpk.Text
if this.AvailableSpeakers.Has(selSpk) {
this.CurrentSpeakerName := selSpk
this.CurrentSpeakerId   := this.AvailableSpeakers[selSpk]
if (this.SettingsLblSpkStatus != "")
this.SettingsLblSpkStatus.Value := "Active: " this.GetSpkDisplayName()
if (this.MainGui != "")
this.UpdateGui()
this.SaveSettings()
this.UpdateState()
this.NotifySettingsSaved()
}
}
ddSpk.OnEvent("Change", (*) => OnInstantSpkChange())
btnRefSpk := g.Add("Button", "x688 y326 w96 h28", "🔄 Refresh")
btnRefSpk.OnEvent("Click", (*) => this.OnRefreshSpeakers())
pages[1].Push(btnRefSpk)
lblSpkStatus := g.Add("Text", "x256 y361 w528 c5E5E5E", "Active: " this.GetSpkDisplayName())
pages[1].Push(lblSpkStatus)
this.SettingsLblSpkStatus := lblSpkStatus
btnWinPlay := g.Add("Button", "x256 y390 w160 h30", "🔊 Playback Devices")
btnWinPlay.OnEvent("Click", (*) => Run("rundll32.exe shell32.dll,Control_RunDLL mmsys.cpl,,0"))
pages[1].Push(btnWinPlay)
btnWinSound := g.Add("Button", "x426 y390 w160 h30", "⚙️ Sound Settings")
btnWinSound.OnEvent("Click", (*) => Run("ms-settings:sound"))
pages[1].Push(btnWinSound)
chkMuteAllSpk := g.Add("CheckBox", "x256 y433 w528 c1A1A1A", "Mute all speakers (unmute restores each one's previous state)")
chkMuteAllSpk.Value := this.MuteAllSpeakers ? 1 : 0
pages[1].Push(chkMuteAllSpk)
OnInstantMuteAllSpkToggle() {
this.MuteAllSpeakers := chkMuteAllSpk.Value = 1
this.SaveSettings()
this.UpdateState()
this.NotifySettingsSaved()
}
chkMuteAllSpk.OnEvent("Click", (*) => OnInstantMuteAllSpkToggle())
shortcutOptions := [
"Ctrl+Shift+M",
"Ctrl+Shift+S",
"Ctrl+Alt+M",
"Ctrl+Alt+S",
"Win+Alt+M",
"Win+Alt+S",
"F1",
"F2",
"F3",
"F4",
"F5",
"F6",
"F7",
"F8",
"F9",
"F10",
"F11",
"F12",
"Pause",
"ScrollLock"
]
shortcutKeys := [
"^+m",
"^+s",
"^!m",
"^!s",
"#!m",
"#!s",
"F1",
"F2",
"F3",
"F4",
"F5",
"F6",
"F7",
"F8",
"F9",
"F10",
"F11",
"F12",
"Pause",
"ScrollLock"
]
FindKeyIdx(key) {
clean := MicController.CleanShortcutKey(key)
loop shortcutKeys.Length {
if (StrCompare(shortcutKeys[A_Index], clean, 1) = 0 || StrCompare(shortcutOptions[A_Index], clean, 1) = 0)
return A_Index
}
return 1
}
g.SetFont("s14 bold", "Segoe UI")
pages[2].Push(g.Add("Text", "x240 y18 w560 c1A1A1A", "Keyboard Shortcuts"))
g.SetFont("s9", "Segoe UI")
pages[2].Push(g.Add("Text", "x240 y44 w560 c5E5E5E", "Configure global hotkeys and system audio utilities"))
pages[2].Push(g.Add("GroupBox", "x240 y75 w560 h190", "  Global Hotkeys  "))
pages[2].Push(g.Add("Text", "x256 y100 w400 c1A1A1A", "Toggle Microphone Mute Hotkey:"))
ddMicKey := g.Add("DropDownList", "x256 y122 w260 Choose" FindKeyIdx(this.MicShortcutKey), shortcutOptions)
pages[2].Push(ddMicKey)
pages[2].Push(g.Add("Text", "x256 y165 w400 c1A1A1A", "Toggle Speaker Mute Hotkey:"))
ddSpkKey := g.Add("DropDownList", "x256 y187 w260 Choose" FindKeyIdx(this.SpkShortcutKey), shortcutOptions)
pages[2].Push(ddSpkKey)
OnInstantShortcutChange() {
newMicKey := shortcutKeys[ddMicKey.Value]
newSpkKey := shortcutKeys[ddSpkKey.Value]
if (newMicKey = newSpkKey && newMicKey != "") {
MsgBox("Microphone and Speaker shortcuts cannot be the same.", this.AppName, "Icon! 0x30")
ddMicKey.Choose(FindKeyIdx(this.MicShortcutKey))
ddSpkKey.Choose(FindKeyIdx(this.SpkShortcutKey))
return
}
this.ReRegisterHotkeys(newMicKey, newSpkKey)
this.SaveSettings()
this.NotifySettingsSaved()
}
ddMicKey.OnEvent("Change", (*) => OnInstantShortcutChange())
ddSpkKey.OnEvent("Change", (*) => OnInstantShortcutChange())
pages[2].Push(g.Add("Text", "x256 y230 w528 c5E5E5E", "ℹ️ Hotkeys function globally even when games and full-screen apps are focused."))
pages[2].Push(g.Add("GroupBox", "x240 y280 w560 h190", "  Windows Audio Shortcuts  "))
btnRec2 := g.Add("Button", "x256 y315 w160 h32", "🎙️ Recording Devices")
btnRec2.OnEvent("Click", (*) => Run("rundll32.exe shell32.dll,Control_RunDLL mmsys.cpl,,1"))
pages[2].Push(btnRec2)
btnPlay2 := g.Add("Button", "x426 y315 w160 h32", "🔊 Playback Devices")
btnPlay2.OnEvent("Click", (*) => Run("rundll32.exe shell32.dll,Control_RunDLL mmsys.cpl,,0"))
pages[2].Push(btnPlay2)
btnPriv2 := g.Add("Button", "x256 y365 w160 h32", "🔒 Mic Privacy Settings")
btnPriv2.OnEvent("Click", (*) => Run("ms-settings:privacy-microphone"))
pages[2].Push(btnPriv2)
btnSnd2 := g.Add("Button", "x426 y365 w160 h32", "⚙️ Windows Sound Settings")
btnSnd2.OnEvent("Click", (*) => Run("ms-settings:sound"))
pages[2].Push(btnSnd2)
g.SetFont("s14 bold", "Segoe UI")
pages[3].Push(g.Add("Text", "x240 y18 w560 c1A1A1A", "Mini Overlay"))
g.SetFont("s9", "Segoe UI")
pages[3].Push(g.Add("Text", "x240 y44 w560 c5E5E5E", "Configure the floating status widget"))
pages[3].Push(g.Add("GroupBox", "x240 y75 w560 h395", "  Overlay Appearance && Behavior  "))
chkMini := g.Add("CheckBox", "x256 y105 w300 c1A1A1A", "Enable Floating Mini Overlay")
chkMini.Value := this.EnableMiniWindow ? 1 : 0
pages[3].Push(chkMini)
OnInstantMiniToggle() {
this.EnableMiniWindow := chkMini.Value = 1
if this.EnableMiniWindow {
if (this.MiniGui != "")
this.DestroyMiniWindow()
this.ShowMiniWindow()
} else {
this.DestroyMiniWindow()
}
this.SaveSettings()
this.NotifySettingsSaved()
}
chkMini.OnEvent("Click", (*) => OnInstantMiniToggle())
chkDark := g.Add("CheckBox", "x256 y140 w300 c1A1A1A", "Mini Window Dark Mode")
chkDark.Value := this.DarkMode ? 1 : 0
pages[3].Push(chkDark)
OnInstantDarkToggle() {
this.DarkMode := chkDark.Value = 1
this.ApplyTheme()
if (this.MiniGui != "") {
this.DestroyMiniWindow()
this.ShowMiniWindow()
}
this.SaveSettings()
this.UpdateTrayMenuIcons()
this.UpdateSpeakerTrayIcon()
this.NotifySettingsSaved()
}
chkDark.OnEvent("Click", (*) => OnInstantDarkToggle())
chkBorder := g.Add("CheckBox", "x256 y175 w300 c1A1A1A", "Mini Window Border")
chkBorder.Value := this.MiniWindowBorder ? 1 : 0
pages[3].Push(chkBorder)
OnInstantBorderToggle() {
this.MiniWindowBorder := chkBorder.Value = 1
if (this.MiniGui != "") {
this.DestroyMiniWindow()
this.ShowMiniWindow()
}
this.SaveSettings()
this.NotifySettingsSaved()
}
chkBorder.OnEvent("Click", (*) => OnInstantBorderToggle())
chkShowMic := g.Add("CheckBox", "x256 y210 w300 c1A1A1A", "Show Mic Icon")
chkShowMic.Value := this.ShowMiniMicIcon ? 1 : 0
pages[3].Push(chkShowMic)
chkShowSpk := g.Add("CheckBox", "x256 y245 w300 c1A1A1A", "Show Speaker Icon")
chkShowSpk.Value := this.ShowMiniSpkIcon ? 1 : 0
pages[3].Push(chkShowSpk)
OnInstantMiniIconToggle() {
if (chkShowMic.Value = 0 && chkShowSpk.Value = 0) {
chkShowMic.Value := 1
MsgBox("At least one icon must remain enabled on the mini overlay.", this.AppName, "Icon! 0x30")
}
this.ShowMiniMicIcon := chkShowMic.Value = 1
this.ShowMiniSpkIcon := chkShowSpk.Value = 1
if (this.MiniGui != "") {
this.DestroyMiniWindow()
this.ShowMiniWindow()
}
this.SaveSettings()
this.NotifySettingsSaved()
}
chkShowMic.OnEvent("Click", (*) => OnInstantMiniIconToggle())
chkShowSpk.OnEvent("Click", (*) => OnInstantMiniIconToggle())
pages[3].Push(g.Add("Text", "x256 y285 w140 c1A1A1A", "Mini Window Size:"))
sldMiniSize := g.Add("Slider", "x256 y305 w300 Range1-200", this.MiniWindowSize)
pages[3].Push(sldMiniSize)
lblSize := g.Add("Text", "x570 y305 w60 c1A1A1A", this.MiniWindowSize "%")
pages[3].Push(lblSize)
OnInstantSizeChange() {
lblSize.Value := sldMiniSize.Value "%"
this.MiniWindowSize := sldMiniSize.Value
SetTimer(() => OnApplySizeChange(), -150)
}
OnApplySizeChange() {
if (this.MiniGui != "") {
this.DestroyMiniWindow()
this.ShowMiniWindow()
}
this.SaveSettings()
this.NotifySettingsSaved()
}
sldMiniSize.OnEvent("Change", (*) => OnInstantSizeChange())
pages[3].Push(g.Add("Text", "x256 y360 w520 c5E5E5E", "Tip: Click and drag the mini overlay anywhere on screen to reposition it."))
g.SetFont("s14 bold", "Segoe UI")
pages[4].Push(g.Add("Text", "x240 y18 w560 c1A1A1A", "Tray Icons"))
g.SetFont("s9", "Segoe UI")
pages[4].Push(g.Add("Text", "x240 y44 w560 c5E5E5E", "Customize system tray notification icons"))
pages[4].Push(g.Add("GroupBox", "x240 y75 w560 h190", "  Microphone Tray Icons  "))
picUnmuted := g.Add("Picture", "x256 y108 w24 h24 Icon" (this.IconIdxUnmuted + 1), this.IconPathUnmuted)
pages[4].Push(picUnmuted)
pages[4].Push(g.Add("Text", "x290 y112 w120 c1A1A1A", "Unmuted"))
btnChgUn := g.Add("Button", "x426 y107 w100 h28", "Change...")
btnChgUn.OnEvent("Click", (*) => this.OnChangeIcon(1, picUnmuted))
pages[4].Push(btnChgUn)
picMuted := g.Add("Picture", "x256 y162 w24 h24 Icon" (this.IconIdxMuted + 1), this.IconPathMuted)
pages[4].Push(picMuted)
pages[4].Push(g.Add("Text", "x290 y166 w120 c1A1A1A", "Muted"))
btnChgMu := g.Add("Button", "x426 y161 w100 h28", "Change...")
btnChgMu.OnEvent("Click", (*) => this.OnChangeIcon(0, picMuted))
pages[4].Push(btnChgMu)
pages[4].Push(g.Add("GroupBox", "x240 y280 w560 h190", "  Speaker Tray Icons  "))
picSpkOn := g.Add("Picture", "x256 y313 w24 h24 Icon" (this.SpkIconIdxOn + 1), this.SpkIconPathOn)
pages[4].Push(picSpkOn)
pages[4].Push(g.Add("Text", "x290 y317 w120 c1A1A1A", "Speaker Active"))
btnChgSpkOn := g.Add("Button", "x426 y312 w100 h28", "Change...")
btnChgSpkOn.OnEvent("Click", (*) => this.OnChangeSpkIcon(1, picSpkOn))
pages[4].Push(btnChgSpkOn)
picSpkOff := g.Add("Picture", "x256 y367 w24 h24 Icon" (this.SpkIconIdxOff + 1), this.SpkIconPathOff)
pages[4].Push(picSpkOff)
pages[4].Push(g.Add("Text", "x290 y371 w120 c1A1A1A", "Speaker Muted"))
btnChgSpkOff := g.Add("Button", "x426 y366 w100 h28", "Change...")
btnChgSpkOff.OnEvent("Click", (*) => this.OnChangeSpkIcon(0, picSpkOff))
pages[4].Push(btnChgSpkOff)
g.SetFont("s14 bold", "Segoe UI")
pages[5].Push(g.Add("Text", "x240 y18 w560 c1A1A1A 0x80", "System & About"))
g.SetFont("s9", "Segoe UI")
pages[5].Push(g.Add("Text", "x240 y44 w560 c5E5E5E", "Manage startup settings and application information"))
pages[5].Push(g.Add("GroupBox", "x240 y75 w560 h130", "  System Integration  "))
chkStart := g.Add("CheckBox", "x256 y105 w300 c1A1A1A", "Run TrayMute on Windows Startup")
chkStart.Value := this.RunOnStart ? 1 : 0
pages[5].Push(chkStart)
OnInstantStartupToggle() {
this.RunOnStart := chkStart.Value = 1
this.ApplyStartup(this.RunOnStart)
this.SaveSettings()
this.NotifySettingsSaved()
}
chkStart.OnEvent("Click", (*) => OnInstantStartupToggle())
btnSponsor := g.Add("Button", "x256 y145 w160 h32", "💖 Sponsor")
btnSponsor.OnEvent("Click", (*) => Run("https://github.com/sponsors/Niptrion"))
pages[5].Push(btnSponsor)
pages[5].Push(g.Add("GroupBox", "x240 y210 w560 h280", "  About TrayMute  "))
g.SetFont("s12 bold", "Segoe UI")
pages[5].Push(g.Add("Text", "x256 y236 w528 c1A1A1A", this.AppName " v" this.Version))
g.SetFont("s9 bold", "Segoe UI")
pages[5].Push(g.Add("Text", "x256 y262 w528 c5E5E5E", "Modern Windows 11 Audio && Microphone Controller"))
g.SetFont("s9", "Segoe UI")
pages[5].Push(g.Add("Text", "x256 y288 w528 c1A1A1A", "TrayMute provides instant, unified control over your microphone and speaker devices. Designed with a sleek Windows 11 native interface, it offers low-latency global muting, real-time hardware status indicators, and background resilience."))
pages[5].Push(g.Add("Text", "x256 y342 w528 c5E5E5E", "• Global hotkeys with full-screen game and application compatibility`n• Intelligent device detection with auto-select and auto-refresh`n• Floating mini overlay widget and independent dual tray icons"))
btnCredits := g.Add("Button", "x256 y432 w160 h34", "📜 Créditos")
btnCredits.OnEvent("Click", (*) => Run("https://github.com/xionraj/MuteGuard"))
pages[5].Push(btnCredits)
loop 4 {
pIdx := A_Index + 1
for c in pages[pIdx]
c.Visible := false
}
navItems := ["🎙️   Audio Devices", "⌨️   Shortcuts", "🪟   Mini Overlay", "🎨   Tray Icons", "⚙️   System && About"]
navBtns := []
activeIndicator := g.Add("Text", "x10 y76 w4 h36 Background0067C0")
currentPage := 1
SelectPage(arg1, arg2 := 0) {
idx := (arg2 = 0 ? arg1 : arg2)
if (idx = currentPage)
return
for c in pages[currentPage]
c.Visible := false
for c in pages[idx]
c.Visible := true
currentPage := idx
activeIndicator.Move(10, 74 + (idx - 1) * 44)
loop navBtns.Length {
navBtns[A_Index].SetFont((A_Index = idx ? "s9 bold" : "s9 norm"), "Segoe UI")
}
}
this.SelectSettingsPage := SelectPage
btnY := 74
loop navItems.Length {
idx := A_Index
btn := g.Add("Button", "x16 y" btnY " w182 h36 Left", " " navItems[idx])
btn.OnEvent("Click", ((i, *) => SelectPage(i)).Bind(idx))
navBtns.Push(btn)
btnY += 44
}
navBtns[1].SetFont("s9 bold", "Segoe UI")
g.Add("Text", "x240 y525 w560 h1 0x10")
lblSavedStatus := g.Add("Text", "x240 y546 w420 c0F7B0F", "✓ All changes save instantly")
lblSavedStatus.SetFont("s9", "Segoe UI")
this.SettingsSavedLbl := lblSavedStatus
btnDone := g.Add("Button", "x680 y538 w120 h34 Default", "Done")
btnDone.SetFont("s9 bold", "Segoe UI")
CloseSettings(*) {
this.SettingsGui := ""
this.SettingsDdMic := ""
this.SettingsDdSpk := ""
this.SettingsLblMicStatus := ""
this.SettingsLblSpkStatus := ""
this.SettingsSavedLbl := ""
try g.Destroy()
}
btnDone.OnEvent("Click", (*) => CloseSettings())
g.OnEvent("Close", (*) => CloseSettings())
g.OnEvent("Escape", (*) => CloseSettings())
g.Show("w830 h590")
}
static OnRefreshMics(*) {
this.AutoRefreshDevices()
TrayTip("Microphone list refreshed.", this.AppName, "Iconi")
}
static OnRefreshSpeakers(*) {
this.AutoRefreshDevices()
TrayTip("Speaker list refreshed.", this.AppName, "Iconi")
}
static ApplyStartup(enable) {
shortcut := A_Startup "\TrayMute.lnk"
if enable {
; Point at the AutoHotkey interpreter, not at the .ahk file: per-user installs may not
; associate .ahk files with AutoHotkey, and a shortcut to the script would then do nothing.
; A compiled TrayMute.exe is its own interpreter (and carries the app icon), so it is the
; target itself. The script version uses icons\app.ico for the shortcut icon.
if A_IsCompiled {
FileCreateShortcut(A_ScriptFullPath, shortcut, A_ScriptDir, "", "TrayMute", A_ScriptFullPath, "", 1)
} else {
appIcon := A_ScriptDir "\icons\app.ico", appIdx := 1
if !FileExist(appIcon)
appIcon := this.ResolveIconPath(this.IconPathUnmuted), appIdx := this.IconIdxUnmuted + 1
FileCreateShortcut(A_AhkPath, shortcut, A_ScriptDir, '"' A_ScriptFullPath '"', "TrayMute", appIcon, "", appIdx)
}
} else if FileExist(shortcut) {
FileDelete(shortcut)
}
}
static ChooseIcon(&path, &idx, hParent := 0) {
buf := Buffer(520, 0)
StrPut(path, buf, "UTF-16")
if DllCall("shell32\PickIconDlg", "Ptr", hParent, "Ptr", buf, "UInt", 260, "Int*", &idx) {
path := StrGet(buf, "UTF-16")
return true
}
return false
}
static OnChangeIcon(isUnmuted, picCtrl) {
path := (isUnmuted ? this.IconPathUnmuted : this.IconPathMuted)
idx  := (isUnmuted ? this.IconIdxUnmuted  : this.IconIdxMuted)
if this.ChooseIcon(&path, &idx) {
try picCtrl.Value := "*Icon" (idx + 1) " " path
if isUnmuted {
this.IconPathUnmuted := path
this.IconIdxUnmuted  := idx
} else {
this.IconPathMuted := path
this.IconIdxMuted  := idx
}
this.SaveSettings()
this.UpdateTrayMenuIcons()
this.UpdateState()
this.NotifySettingsSaved()
}
}
static ToggleStartup() {
this.RunOnStart := !this.RunOnStart
this.ApplyStartup(this.RunOnStart)
this.SaveSettings()
this.NotifySettingsSaved()
}
static OnChangeSpkIcon(isOn, picCtrl) {
path := isOn ? this.SpkIconPathOn : this.SpkIconPathOff
idx  := isOn ? this.SpkIconIdxOn  : this.SpkIconIdxOff
if this.ChooseIcon(&path, &idx) {
try picCtrl.Value := "*Icon" (idx + 1) " " path
if isOn {
this.SpkIconPathOn := path
this.SpkIconIdxOn  := idx
} else {
this.SpkIconPathOff := path
this.SpkIconIdxOff  := idx
}
this.SaveSettings()
this.UpdateSpeakerTrayIcon()
this.NotifySettingsSaved()
}
}
}
MicController.Init()