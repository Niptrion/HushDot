; Tests for the language files and the Google Translate answer reader. No window is shown and
; nothing is sent to the internet. Run from PowerShell:
;   & "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut=UTF-8 tests\i18n_test.ahk | Out-String
; Prints one line per failure and a summary; the exit code is the number of failures.
#Requires AutoHotkey v2.0
#NoTrayIcon
#Include %A_LineFile%\..\..\lib\I18n.ahk
#Include %A_LineFile%\..\..\lib\GoogleTranslate.ahk

global Failures := 0, Passed := 0
Check(name, condition, detail := "") {
global Failures, Passed
if condition {
Passed++
return
}
Failures++
FileAppend("FAIL " name (detail != "" ? ": " detail : "") "`n", "*", "UTF-8")
}
Placeholders(text) {
found := "", pos := 1
while RegExMatch(text, "\{\d+\}", &m, pos) {
found .= m[0]
pos := m.Pos + m.Len
}
return found
}
RepoDir := RegExReplace(A_LineFile, "\\tests\\[^\\]+$")
I18n.BaseDir := RepoDir

; T(): English fallback, placeholders, unknown keys
I18n.Load("en")
Check("T returns English", T("menu.exit") = "Exit")
Check("T fills placeholders", T("device.active", "USB Mic") = "Active: USB Mic")
Check("T shows unknown keys as the key", T("no.such.key") = "no.such.key")
I18n.Current := Map("menu.exit", "Sair")
Check("T uses the loaded language", T("menu.exit") = "Sair")
Check("T falls back to English for missing keys", T("menu.settings") = "Settings")
I18n.Load("en")

; English list: unique keys, one line each
seen := Map()
for pair in I18nEnglish.Pairs {
Check("unique key " pair[1], !seen.Has(pair[1]))
seen[pair[1]] := true
Check("single-line text " pair[1], !InStr(pair[2], "`n") && pair[2] = Trim(pair[2]))
}

; Language codes (they become file names and part of a URL)
for code in ["en", "pt-BR", "zh-CN", "mni-Mtei", "ab", "gom"]
Check("valid code " code, I18n.IsValidCode(code))
Check("T replaces each placeholder once", I18n.FormatText("{1} / {2}", "a{2}", "b") = "a{2} / b")
Check("T leaves unknown placeholders", I18n.FormatText("{1} {3}", "x") = "x {3}")
Check("T without arguments keeps the text", I18n.FormatText("{1}") = "{1}")
dup := I18n.WithoutDuplicateMenuTexts(Map("menu.toggleMic", "Alternar", "menu.toggleSpk", "Alternar", "tip.micActive", "Alternar"))
Check("duplicate menu texts fall back to English", dup.Has("menu.toggleMic") && !dup.Has("menu.toggleSpk") && dup.Has("tip.micActive"))
for code in ["", "..\x", "pt/BR", "pt-BR-x", "a", "en.ini", "pt BR", "e&n", "con", "NUL", "aux-BR", "pt-BR`n"]
Check("invalid code " code, !I18n.IsValidCode(code))

; Parser
parsed := I18n.ParseText(Chr(0xFEFF) "; comment`r`n[Language]`r`nCode=xx`r`nName = Test`r`n[Strings]`r`n"
. "a.b = one = two`r`n; skipped=1`r`nbad line`r`nc.d=`r`n[Other]`r`ne.f=x`r`n")
Check("parser reads meta", parsed.Meta["Code"] = "xx" && parsed.Meta["Name"] = "Test")
Check("parser keeps = in values", parsed.Strings["a.b"] = "one = two")
Check("parser skips comments", !parsed.Strings.Has("; skipped"))
Check("parser reads empty values", parsed.Strings.Has("c.d") && parsed.Strings["c.d"] = "")
Check("parser ignores other sections", !parsed.Strings.Has("e.f"))

; en.ini text round-trips to the built-in English
roundTrip := I18n.ParseText(I18n.EnglishFileText())
Check("English file has every key", roundTrip.Strings.Count = I18nEnglish.Pairs.Length)
same := true
for pair in I18nEnglish.Pairs
same := same && roundTrip.Strings.Has(pair[1]) && roundTrip.Strings[pair[1]] == pair[2]
Check("English file round-trips", same)
Check("English file is up to date", FileExist(RepoDir "\lang\en.ini")
&& FileRead(RepoDir "\lang\en.ini", "UTF-8") == I18n.EnglishFileText(), "run HushDot once to rewrite lang\en.ini")

; Every shipped language file: known keys only, same placeholders as English
english := I18n.English()
Loop Files RepoDir "\lang\*.ini" {
code := RegExReplace(A_LoopFileName, "i)\.ini$")
langFile := I18n.ParseText(FileRead(A_LoopFileFullPath, "UTF-8"))
Check(code ": valid code", I18n.IsValidCode(code))
Check(code ": Code matches the file name", langFile.Meta.Has("Code") && langFile.Meta["Code"] = code)
Check(code ": has a Name", langFile.Meta.Has("Name") && langFile.Meta["Name"] != "")
for key, text in langFile.Strings {
Check(code ": known key " key, english.Has(key))
if english.Has(key)
Check(code ": placeholders of " key, Placeholders(text) == Placeholders(english[key]), text)
}
}
ptBR := I18n.ParseText(FileRead(RepoDir "\lang\pt-BR.ini", "UTF-8"))
missing := ""
for pair in I18nEnglish.Pairs {
if !ptBR.Strings.Has(pair[1]) || ptBR.Strings[pair[1]] = ""
missing .= pair[1] " "
}
Check("pt-BR translates every text", missing = "", missing)
Check("pt-BR loads", I18n.Load("pt-BR") && I18n.Code = "pt-BR" && T("menu.exit") = "Sair")
Check("missing language falls back to English", !I18n.Load("xx-YY") && I18n.Code = "en" && T("menu.exit") = "Exit")
Check("Available lists English first and pt-BR", AvailableHas("pt-BR") && I18n.Available()[1].Code = "en")
AvailableHas(code) {
for l in I18n.Available() {
if (l.Code = code)
return true
}
return false
}
Check("display name of a machine translation", I18n.DisplayName(Map("Name", "Аҧсуа", "EnglishName", "Abkhaz"), "ab") = "Аҧсуа — Abkhaz")
Check("display name keeps a name with a region", I18n.DisplayName(Map("Name", "Português (Brasil)", "EnglishName", "Portuguese (Brazil)"), "pt-BR") = "Português (Brasil)")

; Serialize writes keys in English order, one line each
text := I18n.Serialize([["Code", "xx"], ["Name", "X`nY"]], Map("menu.exit", "A`nB", "menu.toggleMic", "C"))
Check("serialize keeps one line per value", InStr(text, "Name=X Y`n") && InStr(text, "menu.exit=A B`n"))
Check("serialize follows the English order", InStr(text, "menu.toggleMic=") < InStr(text, "menu.exit="))

; URL encoding
Check("UriEncode UTF-8", GoogleTranslate.UriEncode("á b/{1}") = "%C3%A1%20b%2F%7B1%7D")
Check("UriEncode keeps unreserved", GoogleTranslate.UriEncode("Az09-._~") = "Az09-._~")

; Google answer reader
body := '[[["Olá mundo\n","Hello world\n",null,null,10],["Ativo: {1}","Active: {1}",null,null,3]],null,"en",null,null,null,1]'
lines := GoogleTranslate.ParseResponse(body)
Check("response: two lines", lines.Length = 2, lines.Length)
Check("response: text", lines.Length = 2 && lines[1] = "Olá mundo" && lines[2] = "Ativo: {1}")
lines := GoogleTranslate.ParseResponse('[[["É \"x\" \\ y","E",null]],null,"en"]')
Check("response: escapes", lines.Length = 1 && lines[1] = 'É "x" \ y', lines[1])
Check("json: object and numbers", Json.Parse('{"a": [1, -2.5e1, true, null], "b": {}}')["a"][2] = -25)
threw := false
try Json.Parse('[1, 2')
catch
threw := true
Check("json: rejects broken input", threw)
threw := false
try GoogleTranslate.ParseResponse('{"error": 1}')
catch
threw := true
Check("response: rejects unexpected answers", threw)

; Accepting a translation
Check("accept: keeps a good translation", GoogleTranslate.Accept("Active: {1}", "Ativo: {1}") = "Ativo: {1}")
Check("accept: repairs spaced placeholders", GoogleTranslate.Accept("Active: {1}", "Ativo: { 1 }") = "Ativo: {1}")
Check("accept: lost placeholder keeps English", GoogleTranslate.Accept("Active: {1}", "Ativo: um") = "Active: {1}")
Check("accept: empty keeps English", GoogleTranslate.Accept("Exit", "  ") = "Exit")

; Batches stay under the request limit and cover every text once
batches := GoogleTranslate.MakeBatches(I18nEnglish.Pairs)
count := 0, okSize := true
for batch in batches {
size := 0
for i in batch {
count++
size += StrLen(GoogleTranslate.UriEncode(I18nEnglish.Pairs[i][2])) + 3
}
okSize := okSize && (size <= GoogleTranslate.MaxQueryLength || batch.Length = 1)
}
Check("batches cover every text", count = I18nEnglish.Pairs.Length)
Check("batches stay under the limit", okSize)

; Language list
codes := Map()
dupes := ""
for l in GoogleTranslate.Languages() {
if codes.Has(l[1])
dupes .= l[1] " "
codes[l[1]] := true
Check("language code " l[1], I18n.IsValidCode(l[1]))
}
Check("language list has no duplicates", dupes = "", dupes)
Check("language list has Abkhaz", codes.Has("ab"))

FileAppend((Failures ? "FAILED " Failures : "OK") " (" Passed " passed)`n", "*", "UTF-8")
ExitApp(Failures)
