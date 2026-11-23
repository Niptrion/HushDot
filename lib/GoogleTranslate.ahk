; Machine translation of HushDot's interface through Google Translate's free web endpoint
; (translate.googleapis.com, client=gtx). It needs no account or key, but it is not an official
; API: Google may limit or change it. It is called only from the "Add a language" window, after
; the user clicks Translate, and only HushDot's built-in English texts are sent.
class GoogleTranslate {
static Endpoint := "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&dt=t"
; Longest encoded query per request; a few short requests are more reliable than one long one.
static MaxQueryLength := 1800
static PauseMs := 250

; Translates every English interface text into `target`. progress(batch, batches) is called
; before each request. Returns a Map key -> text; a text whose {1}, {2}... did not survive the
; translation keeps its English version. Throws when Google cannot be reached.
static TranslateAll(target, progress := "") {
pairs := I18nEnglish.Pairs
batches := this.MakeBatches(pairs)
result := Map()
for bi, batch in batches {
if progress
progress.Call(bi, batches.Length)
lines := []
for i in batch
lines.Push(pairs[i][2])
out := this.TranslateLines(lines, target)
for j, i in batch
result[pairs[i][1]] := this.Accept(pairs[i][2], out[j])
if (bi < batches.Length)
Sleep(this.PauseMs)
}
return result
}

; Groups text indexes so each request stays under MaxQueryLength.
static MakeBatches(pairs) {
batches := [], current := [], length := 0
for i, pair in pairs {
n := StrLen(this.UriEncode(pair[2])) + 3          ; + the encoded line break
if (current.Length && length + n > this.MaxQueryLength) {
batches.Push(current)
current := [], length := 0
}
current.Push(i)
length += n
}
if current.Length
batches.Push(current)
return batches
}

; One request for several lines (joined by line breaks). If Google merges or splits lines,
; the lines are sent again one by one, so every text keeps its own translation.
static TranslateLines(lines, target) {
out := this.Request(this.JoinLines(lines), target)
if (out.Length = lines.Length)
return out
out := []
for line in lines {
Sleep(this.PauseMs)
out.Push(this.JoinLines(this.Request(line, target), " "))
}
return out
}

static JoinLines(lines, sep := "`n") {
s := ""
for i, line in lines
s .= (i > 1 ? sep : "") line
return s
}

; Returns the translated text split into lines.
static Request(text, target) {
if !I18n.IsValidCode(target)
throw ValueError("invalid language code: " target)
req := ComObject("WinHttp.WinHttpRequest.5.1")
req.Open("GET", this.Endpoint "&tl=" target "&q=" this.UriEncode(text), false)
req.SetTimeouts(10000, 10000, 15000, 20000)
req.Send()
if (req.Status != 200)
throw Error("HTTP " req.Status)
return this.ParseResponse(this.ResponseUtf8(req))
}

; The body as UTF-8, whatever charset the server announces.
static ResponseUtf8(req) {
try {
body := req.ResponseBody                              ; SAFEARRAY of bytes
size := body.MaxIndex() + 1
pData := NumGet(ComObjValue(body), 8 + A_PtrSize, "Ptr") ; SAFEARRAY.pvData
return StrGet(pData, size, "UTF-8")
}
return req.ResponseText
}

; [[["translated","original",...],...],...] -> lines of the joined translated segments.
static ParseResponse(body) {
data := Json.Parse(body)
if !(data is Array) || data.Length < 1 || !(data[1] is Array)
throw Error("unexpected answer from Google Translate")
out := ""
for seg in data[1] {
if (seg is Array && seg.Length >= 1 && seg[1] is String)
out .= seg[1]
}
return StrSplit(out, "`n", "`r")
}

; A translation is used only if it is not empty and kept every {n} of the English text.
static Accept(english, translated) {
t := Trim(RegExReplace(translated, "\{\s*(\d+)\s*\}", "{$1}"))
t := Trim(RegExReplace(t, "[`r`n]+", " "))
if (t = "")
return english
pos := 1
while RegExMatch(english, "\{\d+\}", &m, pos) {
if !InStr(t, m[0])
return english
pos := m.Pos + m.Len
}
return t
}

static UriEncode(s) {
buf := Buffer(StrPut(s, "UTF-8"))
StrPut(s, buf, "UTF-8")
out := ""
loop buf.Size - 1 {
b := NumGet(buf, A_Index - 1, "UChar")
if ((b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A)
|| b = 0x2D || b = 0x2E || b = 0x5F || b = 0x7E)
out .= Chr(b)
else
out .= Format("%{:02X}", b)
}
return out
}

; Languages offered in the "Add a language" list: [code, English name], sorted by name.
; Any other code Google Translate supports can be typed in the window.
static Languages() {
static list := ""
if IsObject(list)
return list
raw := "
(
ab|Abkhaz
ace|Acehnese
ach|Acholi
af|Afrikaans
sq|Albanian
alz|Alur
am|Amharic
ar|Arabic
hy|Armenian
as|Assamese
av|Avar
awa|Awadhi
ay|Aymara
az|Azerbaijani
ban|Balinese
bm|Bambara
ba|Bashkir
eu|Basque
be|Belarusian
bn|Bengali
bho|Bhojpuri
bs|Bosnian
br|Breton
bg|Bulgarian
my|Burmese
ca|Catalan
ceb|Cebuano
ch|Chamorro
ce|Chechen
ny|Chichewa
zh-CN|Chinese (Simplified)
zh-TW|Chinese (Traditional)
cv|Chuvash
co|Corsican
crh|Crimean Tatar
hr|Croatian
cs|Czech
da|Danish
dv|Dhivehi
doi|Dogri
nl|Dutch
dz|Dzongkha
eo|Esperanto
et|Estonian
ee|Ewe
fo|Faroese
fj|Fijian
tl|Filipino
fi|Finnish
fr|French
fy|Frisian
fur|Friulian
ff|Fulani
gl|Galician
ka|Georgian
de|German
el|Greek
gn|Guarani
gu|Gujarati
ht|Haitian Creole
ha|Hausa
haw|Hawaiian
iw|Hebrew
hi|Hindi
hmn|Hmong
hu|Hungarian
is|Icelandic
ig|Igbo
ilo|Ilocano
id|Indonesian
ga|Irish
it|Italian
ja|Japanese
jw|Javanese
kn|Kannada
kk|Kazakh
km|Khmer
rw|Kinyarwanda
gom|Konkani
ko|Korean
kri|Krio
ku|Kurdish (Kurmanji)
ckb|Kurdish (Sorani)
ky|Kyrgyz
lo|Lao
la|Latin
lv|Latvian
li|Limburgish
ln|Lingala
lt|Lithuanian
lg|Luganda
lb|Luxembourgish
mk|Macedonian
mai|Maithili
mg|Malagasy
ms|Malay
ml|Malayalam
mt|Maltese
gv|Manx
mi|Maori
mr|Marathi
mni-Mtei|Meiteilon (Manipuri)
lus|Mizo
mn|Mongolian
ne|Nepali
no|Norwegian
oc|Occitan
or|Odia (Oriya)
om|Oromo
os|Ossetian
ps|Pashto
fa|Persian
pl|Polish
pt|Portuguese (Brazil)
pt-PT|Portuguese (Portugal)
pa|Punjabi
qu|Quechua
ro|Romanian
ru|Russian
sm|Samoan
sa|Sanskrit
gd|Scots Gaelic
nso|Sepedi
sr|Serbian
st|Sesotho
sn|Shona
sd|Sindhi
si|Sinhala
sk|Slovak
sl|Slovenian
so|Somali
es|Spanish
su|Sundanese
sw|Swahili
sv|Swedish
tg|Tajik
ta|Tamil
tt|Tatar
te|Telugu
th|Thai
bo|Tibetan
ti|Tigrinya
ts|Tsonga
tn|Tswana
tr|Turkish
tk|Turkmen
ak|Twi
uk|Ukrainian
ur|Urdu
ug|Uyghur
uz|Uzbek
vi|Vietnamese
cy|Welsh
wo|Wolof
xh|Xhosa
sah|Yakut
yi|Yiddish
yo|Yoruba
zu|Zulu
)"
list := []
for line in StrSplit(raw, "`n", "`r") {
parts := StrSplit(line, "|")
if (parts.Length = 2)
list.Push([parts[1], parts[2]])
}
return list
}
}

; Minimal JSON reader for Google's answer: arrays, objects (as Map), strings, numbers,
; true/false and null (as "").
class Json {
static Parse(text) {
pos := 1
value := this.Value(text, &pos)
this.SkipSpace(text, &pos)
if (pos <= StrLen(text))
throw Error("unexpected text after JSON at " pos)
return value
}

static SkipSpace(text, &pos) {
if RegExMatch(text, "A)\s+", &m, pos)
pos += m.Len
}

static Value(text, &pos) {
this.SkipSpace(text, &pos)
ch := SubStr(text, pos, 1)
if (ch = "[")
return this.ArrayValue(text, &pos)
if (ch = "{")
return this.ObjectValue(text, &pos)
if (ch = '"')
return this.StringValue(text, &pos)
if RegExMatch(text, "A)-?\d+(\.\d+)?([eE][+-]?\d+)?", &m, pos) {
pos += m.Len
return m[0] + 0
}
for word, value in Map("true", true, "false", false, "null", "") {
if (SubStr(text, pos, StrLen(word)) == word) {
pos += StrLen(word)
return value
}
}
throw Error("invalid JSON at " pos)
}

static ArrayValue(text, &pos) {
arr := []
pos++
this.SkipSpace(text, &pos)
if (SubStr(text, pos, 1) = "]") {
pos++
return arr
}
loop {
arr.Push(this.Value(text, &pos))
this.SkipSpace(text, &pos)
ch := SubStr(text, pos, 1)
pos++
if (ch = "]")
return arr
if (ch != ",")
throw Error("invalid JSON array at " pos)
}
}

static ObjectValue(text, &pos) {
obj := Map()
pos++
this.SkipSpace(text, &pos)
if (SubStr(text, pos, 1) = "}") {
pos++
return obj
}
loop {
this.SkipSpace(text, &pos)
if (SubStr(text, pos, 1) != '"')
throw Error("invalid JSON key at " pos)
key := this.StringValue(text, &pos)
this.SkipSpace(text, &pos)
if (SubStr(text, pos, 1) != ":")
throw Error("invalid JSON object at " pos)
pos++
obj[key] := this.Value(text, &pos)
this.SkipSpace(text, &pos)
ch := SubStr(text, pos, 1)
pos++
if (ch = "}")
return obj
if (ch != ",")
throw Error("invalid JSON object at " pos)
}
}

static StringValue(text, &pos) {
pos++                                                     ; opening quote
out := ""
loop {
if RegExMatch(text, 'A)[^"\\]+', &m, pos) {
out .= m[0]
pos += m.Len
}
ch := SubStr(text, pos, 1)
if (ch = "")
throw Error("unterminated JSON string")
if (ch = '"') {
pos++
return out
}
esc := SubStr(text, pos + 1, 1)                         ; ch is a backslash
switch esc, true {
case '"', "\", "/": out .= esc
case "b": out .= "`b"
case "f": out .= "`f"
case "n": out .= "`n"
case "r": out .= "`r"
case "t": out .= "`t"
case "u":
hex := SubStr(text, pos + 2, 4)
if !RegExMatch(hex, "^[0-9A-Fa-f]{4}$")
throw Error("invalid JSON escape at " pos)
out .= Chr(Integer("0x" hex))
pos += 4
default: throw Error("invalid JSON escape at " pos)
}
pos += 2
}
}
}
