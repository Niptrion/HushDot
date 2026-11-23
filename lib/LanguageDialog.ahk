; "Add a language" window: picks a Google Translate language, translates HushDot's English
; texts into it and saves lang\<code>.ini. onAdded(code, path) runs after the file is saved.
class LanguageDialog {
static Gui := ""

static Show(ownerHwnd, onAdded) {
if (this.Gui != "") {
this.Gui.Show()
return
}
langs := GoogleTranslate.Languages()
g := Gui("-MinimizeBox -MaximizeBox" (ownerHwnd ? " +Owner" ownerHwnd : ""), T("langdlg.title"))
this.Gui := g
g.BackColor := "FBFBFB"
g.MarginX := 18, g.MarginY := 16
g.SetFont("s9 c1A1A1A", "Segoe UI")
g.Add("Text", "w460", T("langdlg.intro"))
names := []
for lang in langs
names.Push(lang[2] "   (" lang[1] ")")
lb := g.Add("ListBox", "w460 r12 y+10", names)
g.Add("Text", "w460 y+12", T("langdlg.code"))
ed := g.Add("Edit", "w180 Limit16")
lb.OnEvent("Change", (*) => (ed.Value := langs[lb.Value][1]))
lb.OnEvent("DoubleClick", (*) => Translate())
g.SetFont("s8 c5E5E5E")
g.Add("Text", "w460 y+14", T("langdlg.privacy", I18nEnglish.Pairs.Length))
g.SetFont("s9 c1A1A1A")
btnGo := g.Add("Button", "w150 h32 y+14 Default", T("langdlg.translate"))
btnCancel := g.Add("Button", "x+10 w110 h32", T("common.cancel"))
status := g.Add("Text", "xm w460 y+10 c0F7B0F", "")
controls := [lb, ed, btnGo, btnCancel]
busy := false

; The window may be closed from outside while a translation runs (Settings closing destroys
; it), so every later use of its controls checks that it is still open.
IsOpen() => LanguageDialog.Gui = g
SetBusy(state) {
busy := state
if IsOpen() {
for c in controls
c.Enabled := !state
}
}
ShowStatus(text) {
if IsOpen()
status.Value := text
}
Message(text, options) {
MsgBox(text, T("langdlg.title"), options (IsOpen() ? " Owner" g.Hwnd : ""))
}
Close(*) {
if busy                                  ; Esc or the close box while translating
return true
LanguageDialog.Gui := ""
try g.Destroy()
}
Translate(*) {
if busy
return
code := Trim(ed.Value)
if !I18n.IsValidCode(code) {
Message(T("langdlg.invalidCode", code), "Icon!")
return
}
englishName := code
for lang in langs {
if (lang[1] = code) {
code := lang[1], englishName := lang[2]
break
}
}
if (I18n.FindFile(code) != "" && MsgBox(T("langdlg.exists", englishName), T("langdlg.title")
, "YesNo Icon? Owner" g.Hwnd) != "Yes")
return
SetBusy(true)
try {
path := LanguageDialog.Create(code, englishName, (i, n) => ShowStatus(T("langdlg.progress", i, n)))
} catch as e {
SetBusy(false)
ShowStatus("")
Message(T("langdlg.failed", e.Message), "Icon!")
return
}
SetBusy(false)
Message(T("langdlg.done", englishName, path), "Iconi")
Close()
onAdded.Call(code, path)
}
btnGo.OnEvent("Click", Translate)
btnCancel.OnEvent("Click", Close)
g.OnEvent("Close", Close)
g.OnEvent("Escape", Close)
g.Show("AutoSize")
}

; Translates the interface and saves the language file. Returns its path.
static Create(code, englishName, progress) {
strings := GoogleTranslate.TranslateAll(code, progress)
nativeName := englishName
try {
lines := GoogleTranslate.Request(englishName, code)
if (lines.Length && Trim(lines[1]) != "")
nativeName := Trim(lines[1])
}
meta := [["Code", code], ["Name", nativeName], ["EnglishName", englishName]
, ["Source", "Google Translate, " FormatTime(, "yyyy-MM-dd")]]
return I18n.SaveFile(code, I18n.Serialize(meta, strings))
}
}
