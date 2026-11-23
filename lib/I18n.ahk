; Interface languages. English is built in (lib\I18n.Strings.ahk); every other language is a
; lang\<code>.ini file with the same keys. A key missing from a file is shown in English.
; Language files live next to HushDot (lang\) or, when that folder is not writable, in
; %APPDATA%\HushDot\lang. Files are UTF-8, one "key=value" per line, ";" starts a comment.
#Include %A_LineFile%\..\I18n.Strings.ahk

; Translated text for a key, with {1}, {2}... replaced by the arguments.
T(key, args*) => I18n.T(key, args*)

class I18n {
static Code    := "en"
static Current := Map()
static EnglishMap := ""
; Folder that holds lang\ (HushDot's own folder; the tests point it at the repository).
static BaseDir := A_ScriptDir

static LangDirs() => [this.BaseDir "\lang", A_AppData "\HushDot\lang"]

static English() {
if !IsObject(this.EnglishMap) {
m := Map()
for pair in I18nEnglish.Pairs
m[pair[1]] := pair[2]
this.EnglishMap := m
}
return this.EnglishMap
}

static T(key, args*) {
if this.Current.Has(key)
text := this.Current[key]
else if this.English().Has(key)
text := this.English()[key]
else
text := key
return this.FormatText(text, args*)
}

; One pass, so a value that itself contains "{2}" (a device name, say) is not replaced again.
static FormatText(text, args*) {
if !args.Length
return text
out := "", pos := 1
while RegExMatch(text, "\{(\d+)\}", &m, pos) {
n := Integer(m[1])
out .= SubStr(text, pos, m.Pos - pos) (n >= 1 && n <= args.Length ? args[n] : m[0])
pos := m.Pos + m.Len
}
return out SubStr(text, pos)
}

; Language codes become file names and part of a web address, so only letters, digits and
; one region/script part are accepted ("pt-BR", "zh-CN", "mni-Mtei", "ab"). Windows device
; names (con, nul...) are refused: "con.ini" would not be a file.
static IsValidCode(code) => RegExMatch(code, "^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})?\z") > 0
&& !RegExMatch(code, "i)^(con|prn|aux|nul)(-|\z)")

; Switches the interface language. Unknown codes and missing files fall back to English.
; Returns true when the requested language was loaded.
static Load(code) {
this.Code := "en"
this.Current := Map()
if (code = "" || code = "en" || !this.IsValidCode(code))
return code = "en" || code = ""
path := this.FindFile(code)
if (path = "")
return false
try {
parsed := this.ParseText(FileRead(path, "UTF-8"))
} catch {
return false
}
this.Current := this.WithoutDuplicateMenuTexts(parsed.Strings)
this.Code := code              ; the file name, which is what the language list shows and saves
return true
}

; Menu items are identified by their text, so two menu entries translated alike would merge
; into one. A repeated menu text falls back to English.
static WithoutDuplicateMenuTexts(strings) {
seen := Map()
for pair in I18nEnglish.Pairs {
key := pair[1]
if (SubStr(key, 1, 5) != "menu." || !strings.Has(key))
continue
if seen.Has(strings[key])
strings.Delete(key)
else
seen[strings[key]] := true
}
return strings
}

static FindFile(code) {
if !this.IsValidCode(code)
return ""
for dir in this.LangDirs() {
if FileExist(dir "\" code ".ini")
return dir "\" code ".ini"
}
return ""
}

; {Meta: Map from [Language], Strings: Map from [Strings]}
static ParseText(text) {
meta := Map(), strings := Map()
section := ""
for line in StrSplit(text, "`n", "`r") {
line := Trim(line, " `t" Chr(0xFEFF))
if (line = "" || SubStr(line, 1, 1) = ";")
continue
if RegExMatch(line, "^\[(.+)\]$", &m) {
section := m[1]
continue
}
eq := InStr(line, "=")
if !eq
continue
key := Trim(SubStr(line, 1, eq - 1)), value := Trim(SubStr(line, eq + 1))
if (section = "Language")
meta[key] := value
else if (section = "Strings" && key != "")
strings[key] := value
}
return {Meta: meta, Strings: strings}
}

; File text for a language. meta: array of [name, value]; strings: Map of key -> text.
; Keys follow the English order; keys without a translation are left out (shown in English).
static Serialize(meta, strings) {
text := "; HushDot language file: one key=value per line. Keep {1}, {2}... in the texts.`n"
. "; Keys left out are shown in English. The English texts are in en.ini.`n`n[Language]`n"
for pair in meta
text .= pair[1] "=" this.OneLine(pair[2]) "`n"
text .= "`n[Strings]`n"
for pair in I18nEnglish.Pairs {
if strings.Has(pair[1])
text .= pair[1] "=" this.OneLine(strings[pair[1]]) "`n"
}
return text
}

static OneLine(s) => Trim(RegExReplace(s, "[`r`n]+", " "))

static EnglishFileText() => this.Serialize([["Code", "en"], ["Name", "English"]], this.English())

; Keeps lang\en.ini equal to the built-in English texts (the list to translate from).
; Skipped silently when the program folder is not writable.
static EnsureEnglishFile() {
path := this.BaseDir "\lang\en.ini"
text := this.EnglishFileText()
try {
if (FileExist(path) && FileRead(path, "UTF-8") == text)
return
DirCreate(this.BaseDir "\lang")
this.WriteUtf8(path, text)
}
}

; Saves a language file next to HushDot, or in %APPDATA% when that folder is not writable.
; Returns the path. Throws when neither place can be written.
static SaveFile(code, text) {
if !this.IsValidCode(code)
throw ValueError("invalid language code: " code)
lastError := ""
for dir in this.LangDirs() {
try {
DirCreate(dir)
this.WriteUtf8(dir "\" code ".ini", text)
return dir "\" code ".ini"
} catch as e {
lastError := e.Message
}
}
throw Error(lastError)
}

static WriteUtf8(path, text) {
f := FileOpen(path, "w", "UTF-8")
if !IsObject(f)
throw OSError(A_LastError, , path)
f.Write(text)
f.Close()
}

; Languages to offer: English first, then every language file found, sorted by name.
; Returns an array of {Code, Name}.
static Available() {
found := Map()
found.CaseSense := "Off"
for dir in this.LangDirs() {
Loop Files dir "\*.ini" {
code := RegExReplace(A_LoopFileName, "i)\.ini$")
if (code = "en" || !this.IsValidCode(code) || found.Has(code))
continue
try {
meta := this.ParseText(FileRead(A_LoopFileFullPath, "UTF-8")).Meta
} catch {
continue
}
found[code] := this.DisplayName(meta, code)
}
}
sorted := ""
for code, name in found
sorted .= name "`t" code "`n"
list := [{Code: "en", Name: "English"}]
for line in StrSplit(Sort(RTrim(sorted, "`n")), "`n") {
if (line = "")
continue
parts := StrSplit(line, "`t")
list.Push({Code: parts[2], Name: parts[1]})
}
return list
}

; "Português (Brasil)"; machine-made files also show the English name ("Аҧсуа — Abkhaz").
static DisplayName(meta, code) {
name := meta.Has("Name") && meta["Name"] != "" ? meta["Name"] : code
english := meta.Has("EnglishName") ? meta["EnglishName"] : ""
if (english != "" && english != name && !InStr(name, "("))
name .= " — " english
return StrReplace(name, "`t", " ")
}
}
