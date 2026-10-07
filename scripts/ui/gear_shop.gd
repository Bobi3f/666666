class_name GearShop
extends CanvasLayer
## GEARCOIN — монеты для доната. Окно: баланс, пакеты монет с ценой в
## гривнах, рублях или долларах (оплата подключится позже — пока кнопки
## «Скоро»), магазин эксклюзива за монеты — техника, клубы, жильё — и ввод
## кода. Пока окно открыто, игра на паузе.

## Пакеты: монет, цена в гривнах (как на картинке).
const PACKS := [[100, 49], [500, 229], [1200, 449], [3000, 1099], [7500, 2199], [15000, 3999]]
## Валюты: знак и цены пакетов (рубли и доллары — по курсу, округлены).
const CURRENCIES := {
	"грн": [49, 229, 449, 1099, 2199, 3999],
	"₽": [109, 499, 990, 2390, 4790, 8690],
	"$": [1.19, 5.49, 10.99, 26.99, 53.99, 97.99],
}
## Эксклюзив: id, название, что даёт, цена в GEARCOIN, раздел.
const ITEMS := [
	["volga:black", "«Волга» Чёрная", "ГАЗ-24 в чёрном лаке, золотые диски, форсированный мотор", 800, "Техника"],
	["moto:gold", "«Ява» Золотая", "золотой бак и диски, прямоток — слышно на всю Каменку", 600, "Техника"],
	["niva:hunter", "«Нива» Охотник", "хаки, большие колёса и бак — по любому бездорожью", 700, "Техника"],
	["club_v", "Клуб «Каменка»", "твой клуб: +900 грн каждое утро, вход бесплатный", 1500, "Клубы"],
	["club_t", "Клуб «Метелица» в городе", "твой клуб: +1800 грн каждое утро, вход бесплатный", 3000, "Клубы"],
	["penthouse", "Квартира на 9-м этаже у бурсы", "ночевать в городе, вид на всю улицу Заводскую", 900, "Жильё"],
	["mansion", "Особняк в Каменке-Северной", "два этажа, гараж и свой участок, спать у двери", 2500, "Жильё"],
]

static var currency := "грн"

var _root: PanelContainer
var _balance: Label
var _body: VBoxContainer
var _status: Label
var _tab := "coins"
var _icon: Texture2D


func _init() -> void:
	layer = 61
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("gear_shop")


func _ready() -> void:
	_icon = Assets.texture("ui/gearcoin", func() -> Image:
		var im := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		im.fill(Color(0.9, 0.7, 0.25))
		return im)
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = 24
	_root.offset_right = -24
	_root.offset_top = 12
	_root.offset_bottom = -12
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.97)
	sb.border_color = Color(0.85, 0.66, 0.25)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	_root.add_theme_stylebox_override("panel", sb)
	add_child(_root)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_root.add_child(v)
	# Шапка: монета, название, баланс, закрыть
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var ic := TextureRect.new()
	ic.texture = _icon
	ic.custom_minimum_size = Vector2(40, 40)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(ic)
	var t := _label("GEARCOIN", 24, Color(0.98, 0.78, 0.3))
	head.add_child(t)
	_balance = _label("", 18, Color(1, 0.92, 0.7))
	_balance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_balance)
	var close := _button("Закрыть", Color(0.45, 0.2, 0.18))
	close.pressed.connect(close_panel)
	head.add_child(close)
	# Вкладки
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for tb in [["coins", "Купить монеты"], ["shop", "Эксклюзив"], ["code", "Ввести код"]]:
		var b := _button(tb[1], Color(0.3, 0.24, 0.12))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_tab = tb[0]
			_refresh())
		tabs.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)
	_status = _label("", 15, Color(1, 0.85, 0.5))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 17)
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(6)
	st.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", st)
	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = color.lightened(0.15)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", hv)
	b.add_theme_stylebox_override("disabled", st)
	return b


func open(tab := "coins") -> void:
	_tab = tab
	visible = true
	get_tree().paused = true
	_status.text = ""
	_refresh()


func close_panel() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()


## Цена пакета i в выбранной валюте, строкой.
static func price_text(i: int, cur := "") -> String:
	var c := cur if cur != "" else currency
	var p: float = CURRENCIES[c][i]
	if c == "$":
		return "$%.2f" % p
	return "%s %s" % [_thousands(int(p)), c]


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _refresh() -> void:
	var who := SettingsManager.full_name()
	_balance.text = ("%s · " % who if who != "" else "") + "У тебя: %s GEARCOIN" % _thousands(Progress.gearcoins)
	for c in _body.get_children():
		c.queue_free()
	match _tab:
		"coins":
			_page_coins()
		"shop":
			_page_shop()
		_:
			_page_code()


func _page_coins() -> void:
	# Выбор валюты
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_body.add_child(row)
	row.add_child(_label("Цены в:", 16, Color(0.9, 0.85, 0.75)))
	for c in CURRENCIES:
		var b := _button(c, Color(0.55, 0.42, 0.12) if c == currency else Color(0.22, 0.2, 0.17))
		b.custom_minimum_size.x = 64
		b.pressed.connect(func() -> void:
			currency = c
			_refresh())
		row.add_child(b)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(grid)
	for i in PACKS.size():
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 2)
		grid.add_child(card)
		var pic := TextureRect.new()
		pic.texture = Assets.texture("ui/gear_pack_%d" % i, func() -> Image: return _icon.get_image())
		pic.custom_minimum_size = Vector2(0, 70)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(pic)
		var n := _label("%s GEARCOIN" % _thousands(int(PACKS[i][0])), 15, Color.WHITE)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(n)
		var b := _button(price_text(i), Color(0.45, 0.33, 0.1))
		b.pressed.connect(buy_pack.bind(i))
		card.add_child(b)
	var note := _label("Оплата подключится скоро — в гривнах, рублях и долларах. Цены в рублях и долларах примерные.", 13, Color(0.75, 0.72, 0.65))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(note)


## Купить пакет монет: оплаты пока нет — говорим, что скоро.
func buy_pack(i: int) -> bool:
	_status.text = "Покупка %s GEARCOIN за %s появится скоро — оплату ещё подключаем." % [_thousands(int(PACKS[i][0])), price_text(i)]
	return false


func _page_shop() -> void:
	var section := ""
	for it in ITEMS:
		if it[4] != section:
			section = it[4]
			_body.add_child(_label(section, 18, Color(0.98, 0.78, 0.3)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_body.add_child(row)
		var have := owns(it[0])
		var b := _button("Есть" if have else "%s GC" % _thousands(int(it[3])), Color(0.25, 0.25, 0.25) if have else Color(0.45, 0.33, 0.1))
		b.custom_minimum_size.x = 110
		b.disabled = have
		b.pressed.connect(buy.bind(it[0]))
		row.add_child(b)
		var l := _label("%s — %s" % [it[1], it[2]], 15, Color(0.95, 0.92, 0.85))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)


func _page_code() -> void:
	var l := _label("Код с оплаты или подарочный код:", 16, Color(0.9, 0.85, 0.75))
	_body.add_child(l)
	var edit := LineEdit.new()
	edit.name = "CodeEdit"
	edit.placeholder_text = "XXXX-XXXX-XXXX"
	edit.custom_minimum_size = Vector2(0, 44)
	edit.add_theme_font_size_override("font_size", 18)
	edit.max_length = 20
	TextInput.attach(edit, "Код с оплаты или подарочный код")
	_body.add_child(edit)
	var b := _button("Активировать", Color(0.45, 0.33, 0.1))
	b.pressed.connect(func() -> void: redeem(edit.text))
	edit.text_submitted.connect(func(t: String) -> void: redeem(t))
	_body.add_child(b)


## Подарочные коды: sha256 кода → [GEARCOIN, гривны]. Сам код в игре
## не хранится — только отпечаток. Каждый — раз на сохранение.
static var CODES := {
	"816e671fa3df16c28510cd7edb84b09f34f32c69de5bd4cc958c7cf83cc8ef35": [1000000, 1000000],
}


## Русские буквы, похожие на латинские: код набирают в любой раскладке.
## (коды букв: А В С Е Н К М О Р Т Х У І — чтобы их не брался переводить словарь)
const LOOKALIKE := {0x410: "A", 0x412: "B", 0x421: "C", 0x415: "E", 0x41D: "H", 0x41A: "K", 0x41C: "M", 0x41E: "O", 0x420: "P", 0x422: "T", 0x425: "X", 0x423: "Y", 0x406: "I"}


## Код как в списке: только буквы и цифры, заглавные, по 4 через дефис —
## пробелы, дефисы и русские буквы-двойники при вводе не мешают.
static func normalize(code: String) -> String:
	var raw := ""
	for ch in code.to_upper():
		var c: String = LOOKALIKE.get(ch.unicode_at(0), ch)
		if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			raw += c
	var parts: PackedStringArray = []
	for i in range(0, raw.length(), 4):
		parts.append(raw.substr(i, 4))
	return "-".join(parts)


## Ввести код: верный — монеты и деньги на счёт, один раз на сохранение.
func redeem(code: String) -> bool:
	var c := normalize(code)
	if c == "":
		_status.text = "Введи код"
		return false
	var h := c.sha256_text()
	if not CODES.has(h):
		_status.text = "Такого кода нет: %s — проверь буквы и цифры" % c
		return false
	if Progress.codes.has(h):
		_status.text = "Этот код уже активирован"
		return false
	var gift: Array = CODES[h]
	Progress.codes.append(h)
	Progress.gearcoins += int(gift[0])
	GameManager.add_money(int(gift[1]))
	SoundLibrary.play("cash")
	_status.text = "Код принят: +%s GEARCOIN и +%s грн" % [_thousands(int(gift[0])), _thousands(int(gift[1]))]
	GameManager.notify(_status.text)
	_refresh()
	return true


static func item(id: String) -> Array:
	for it in ITEMS:
		if it[0] == id:
			return it
	return []


## Есть ли уже эта вещь у игрока.
static func owns(id: String) -> bool:
	if id.contains(":"):
		return Progress.owns(id)
	if id.begins_with("club_"):
		return Daily.owns(id)
	return Progress.has_item(id)


## Купить эксклюзив за GEARCOIN. true — куплено.
func buy(id: String) -> bool:
	var it := item(id)
	if it.is_empty() or owns(id):
		return false
	var cost: int = it[3]
	if Progress.gearcoins < cost:
		_status.text = "Не хватает GEARCOIN: «%s» стоит %s, у тебя %s" % [it[1], _thousands(cost), _thousands(Progress.gearcoins)]
		return false
	Progress.gearcoins -= cost
	grant(id)
	SoundLibrary.play("quest", -2.0)
	_status.text = "Куплено: %s!" % it[1]
	GameManager.notify("GEARCOIN: %s — твоё!" % it[1])
	_refresh()
	return true


## Выдать вещь id (после покупки или по коду).
static func grant(id: String) -> void:
	if id.contains(":"):
		Progress.buy_car(id)
	elif id.begins_with("club_"):
		Daily.grant(id)
	else:
		Progress.add_item(id)
