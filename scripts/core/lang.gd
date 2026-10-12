class_name LangTranslation
extends Translation
## Английский и украинский языки игры — перевод «на лету», когда текст
## попадает на экран. Один и тот же переводчик, свой словарь у каждого языка.
##
## В коде все строки русские и собираются как угодно: "Купил %s — будет %s" %
## [что, где]. Godot показывает текст надписей, кнопок и табличек через
## TranslationServer, и сюда приходит уже собранная строка. Её ищем так:
##   * целиком в словаре (lang_en.gd / lang_uk.gd);
##   * по шаблону: русская строка с %s/%d → регулярное выражение, подставленные
##     куски переводятся отдельно (имена, названия — тоже из словаря);
##   * многострочный текст — по строкам, длинное сообщение — по предложениям.
## Что не нашлось — остаётся по-русски. Найденное кэшируется: одна и та же
## подсказка не ищется заново каждый кадр.

## Словари — по пути, а не preload: грузится только выбранный язык. Иначе
## 5 тысяч строк переводов собирались при каждом запуске — в браузере на
## телефоне это секунды замершей страницы.
const DICTS := {"en": ["res://scripts/core/lang_en.gd", "EN"], "uk": ["res://scripts/core/lang_uk.gd", "UK"]}
const CACHE_MAX := 4000

var _exact := {}
var _lower := {}
## Шаблоны по первым трём буквам неизменной части: [RegEx, части перевода]
var _by_head := {}
## Шаблоны, что начинаются с подстановки — проверяются для любой строки
var _loose: Array = []
var _cache := {}
var _cyr := RegEx.create_from_string("[А-Яа-яЁёІіЇїЄє]")
var _ph := RegEx.create_from_string("%(%|[-+0 #]*\\d*(?:\\.\\d+)?[sdfixXc])")
var _sentence := RegEx.create_from_string("(?<=[.!?…»)])\\s+(?=[«А-ЯЁA-Z(])")
var _tags := RegEx.create_from_string("^((?:\\[[^\\]/]+\\])*)(.*?)((?:\\[/[^\\]]+\\])*)$")
var _built := false
## Словарь этого языка: русская строка → перевод
var _dict: Dictionary


## code — "en" или "uk".
func _init(code := "en") -> void:
	locale = code
	var d: Array = DICTS.get(code, DICTS["en"])
	_dict = (load(d[0]) as Script).get_script_constant_map()[d[1]]


func _get_message(src: StringName, _context: StringName) -> StringName:
	var s := String(src)
	if s.is_empty() or _cyr.search(s) == null:
		return src
	if _cache.has(s):
		return _cache[s]
	if not _built:
		_build()
	var out := _text(s)
	if _cache.size() > CACHE_MAX:
		_cache.clear()
	_cache[s] = out
	return out


## Перевести строку (для своих нужд: рисование текста, проверки).
func text(s: String) -> String:
	return String(_get_message(s, &""))


func _build() -> void:
	_built = true
	for ru in _dict:
		var en: String = _dict[ru]
		if _ph.search(ru) == null:
			_exact[ru] = en
			_lower[ru.to_lower()] = en
			continue
		_add_template(ru, en)
	# Сначала — самые длинные шаблоны: «%s: «%s»» не должен перехватить точный
	var longer := func(a: Array, b: Array) -> bool: return int(a[2]) > int(b[2])
	_loose.sort_custom(longer)
	for k in _by_head:
		(_by_head[k] as Array).sort_custom(longer)


## Русский шаблон → регулярка; перевод — на куски: текст и номера подстановок.
func _add_template(ru: String, en: String) -> void:
	var pattern := "^"
	var at := 0
	var head := ""
	var first := true
	for m in _ph.search_all(ru):
		var lit := ru.substr(at, m.get_start() - at)
		pattern += _escape(lit)
		if first:
			head = lit
			first = false
		var kind := m.get_string(1)
		if kind == "%":
			pattern += "%"
		elif kind.ends_with("s"):
			pattern += "(.*?)"
		elif kind.ends_with("f"):
			pattern += "(-?[\\d.,]+)"
		else:
			pattern += "(-?\\d+)"
		at = m.get_end()
	pattern += _escape(ru.substr(at)) + "$"
	var re := RegEx.create_from_string(pattern)
	if not re.is_valid():
		return
	var parts: Array = []
	at = 0
	var n := 0
	for m in _ph.search_all(en):
		parts.append(en.substr(at, m.get_start() - at))
		if m.get_string(1) == "%":
			parts.append("%")
		else:
			parts.append(n)
			n += 1
		at = m.get_end()
	parts.append(en.substr(at))
	var entry := [re, parts, _ph.sub(ru, "", true).length()]
	if head.length() >= 3:
		var key := head.left(3)
		if not _by_head.has(key):
			_by_head[key] = []
		_by_head[key].append(entry)
	else:
		_loose.append(entry)


static func _escape(t: String) -> String:
	var out := ""
	for c in t:
		if "\\^$.|?*+()[]{}".contains(c):
			out += "\\"
		out += c
	return out


## Многострочный текст — по строкам, сохраняя отступы.
func _text(s: String) -> String:
	if not s.contains("\n"):
		return _keep_spaces(s)
	var lines := s.split("\n")
	for i in lines.size():
		lines[i] = _keep_spaces(lines[i])
	return "\n".join(lines)


func _keep_spaces(line: String) -> String:
	var core := line.strip_edges()
	if core.is_empty() or _cyr.search(core) == null:
		return line
	var a := line.find(core)
	var t := _line(core)
	# Строка журнала в тегах оформления: [b]» Первое утро[/b] — переводим середину
	if t == core:
		var m := _tags.search(core)
		if m and m.get_string(2) != core:
			t = m.get_string(1) + _keep_spaces(m.get_string(2)) + m.get_string(3)
	return line.left(a) + t + line.substr(a + core.length())


## Одна строка: словарь, шаблон, а длинное сообщение — по предложениям.
func _line(s: String) -> String:
	var t := _piece(s)
	if t != s:
		return t
	var parts := _sentence.search_all(s)
	if not parts.is_empty():
		var out := ""
		var at := 0
		for m in parts:
			out += _glued(s.substr(at, m.get_start() - at), 1) + m.get_string()
			at = m.get_end()
		out += _glued(s.substr(at), 1)
		if out != s:
			return out
	return _glued(s, 0)


## Склеено в коде из кусков: «» Первое утро: Позавтракай… — 1 / 3»,
## «1: день 3, 1500 грн». Ищем слева кусок, который знаем, правое — так же.
func _glued(s: String, depth: int) -> String:
	if depth > 4:
		return s
	var lead := ""
	for p in ["» ", "• ", "+ ", "· "]:
		if s.begins_with(p):
			lead = p
			s = s.substr(p.length())
	var whole := _piece(s)
	if whole != s:
		return lead + whole
	for sep in [": ", " — ", " · ", "   ", ", "]:
		var at := s.find(sep)
		while at > 0:
			var left := s.left(at)
			var t := _piece(left)
			if t != left:
				return lead + t + sep + _glued(s.substr(at + sep.length()), depth + 1)
			var right := s.substr(at + sep.length())
			var r := _piece(right)
			if r != right:
				return lead + _glued(left, depth + 1) + sep + r
			at = s.find(sep, at + 1)
	return lead + s

func _piece(s: String) -> String:
	if _exact.has(s):
		return _exact[s]
	var low := s.to_lower()
	if _lower.has(low):
		var en: String = _lower[low]
		# Русское было со строчной (после to_lower) — и перевод со строчной
		return en.left(1).to_lower() + en.substr(1) if s.left(1) == low.left(1) else en
	var list: Array = _by_head.get(s.left(3), [])
	for entry in list + _loose:
		var m: RegExMatch = (entry[0] as RegEx).search(s)
		if m:
			return _fill(entry[1], m)
	return s


func _fill(parts: Array, m: RegExMatch) -> String:
	var out := ""
	for p in parts:
		if p is int:
			out += _arg(m.get_string(p + 1))
		else:
			out += p
	return out


## Подставленный кусок: имя или название — из словаря, перечисление — по частям.
func _arg(a: String) -> String:
	if a.is_empty() or _cyr.search(a) == null:
		return a
	var t := _piece(a)
	if t != a:
		return t
	if a.contains(", "):
		var bits := a.split(", ")
		for i in bits.size():
			bits[i] = _piece(bits[i])
		return ", ".join(bits)
	return _line(a)
