class_name MarketPanel
extends CanvasLayer
## Лавки базара: «Для дома» (ковёр, магнитофон, холодильник, кресло) и
## «Автозапчасти» (спидометр, глушитель, бак, колёса, диски) — для своей
## машины, мотоцикла или мопеда. Пока окно открыто, игра на паузе.
## Кнопки крупные — под палец.

## id → [название, цена, что даёт]
const HOME := {
	"rug": ["Ковёр с узором", 150, "на пол в комнату — уютно"],
	"tape": ["Магнитофон «Ветерок»", 300, "играет кассету — включается по E"],
	"fridge": ["Холодильник «Морозко»", 600, "каждое утро +1 еды в запас"],
	"chair": ["Кресло-качалка", 250, "у телевизора, само покачивается"],
}
## К свадьбе — для Оли (сюжет «Свадьба»)
const WEDDING := {
	"ring": ["Золотое кольцо", 1500, "для предложения — сделать в разговоре с Олей"],
	"dress": ["Свадебное платье с фатой", 1200, "без него в ЗАГСе не распишут"],
}
const PARTS := {
	"speedo": ["Спидометр с подсветкой", 200, "зелёные приборы, хромовый обод"],
	"exhaust": ["Прямоточный глушак", 350, "громче, ниже и +6% тяги"],
	"tank": ["Большой бак", 400, "бензина влезает в полтора раза больше"],
	"wheels": ["Большие колёса", 600, "выше и лучше держат на грунте и в грязи"],
	"rims": ["Диски", 250, "хром → чёрные → красные → золотые"],
	"repair_kit": ["Ремнабор", 150, "починить машину или мотоцикл в дороге: +40% к состоянию (инвентарь — I)"],
}

signal closed

## Сельмаг: товары и покупку даёт мир (world.gd → SHOP_MENU, shop_buy).
var shop_fn: Callable

var mode := "home"
## Лавка с едой: базар и что за лавка (Bazaar.FOOD_KINDS)
var bazaar: Bazaar
var food_kind := ""
var _haggle: Button
var _vehicles: Array = []
var _car: Vehicle
var _root: PanelContainer
var _title: Label
var _cars_label: Label
var _cars_box: HFlowContainer
var _goods: VBoxContainer
var _status: Label


func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = 30
	_root.offset_right = -30
	_root.offset_top = 14
	_root.offset_bottom = -14
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.15, 0.1, 0.97)
	sb.border_color = Color(0.9, 0.75, 0.45)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	_root.add_theme_stylebox_override("panel", sb)
	add_child(_root)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = _label("", 20, Color(0.98, 0.85, 0.5))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := _button("Закрыть", Color(0.5, 0.25, 0.22))
	close.pressed.connect(close_panel)
	head.add_child(close)
	_cars_label = _label("Для какой техники:", 16, Color(0.9, 0.85, 0.78))
	v.add_child(_cars_label)
	_cars_box = HFlowContainer.new()
	_cars_box.add_theme_constant_override("h_separation", 8)
	_cars_box.add_theme_constant_override("v_separation", 6)
	v.add_child(_cars_box)
	_haggle = _button("Поторговаться", Color(0.55, 0.38, 0.15))
	_haggle.pressed.connect(func() -> void:
		_status.text = bazaar.haggle(food_kind)
		_refresh())
	v.add_child(_haggle)
	_goods = VBoxContainer.new()
	_goods.add_theme_constant_override("separation", 6)
	v.add_child(_goods)
	_status = _label("", 16, Color(1.0, 0.8, 0.5))
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
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 20)
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(4)
	st.set_content_margin_all(8)
	b.add_theme_stylebox_override("normal", st)
	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = color.lightened(0.15)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", hv)
	b.add_theme_stylebox_override("disabled", st)
	return b


## Открыть лавку: m — "home" или "parts", vehicles — своя техника.
func open(m: String, vehicles: Array = []) -> void:
	mode = m
	_vehicles = vehicles
	visible = true
	get_tree().paused = true
	_status.text = ""
	_title.text = {"home": "Базар — для дома", "wedding": "Базар — к свадьбе", "shop": "Сельмаг «Продукты»"}.get(mode, "Базар — автозапчасти")
	if mode == "shop":
		_status.text = _stock()
	_haggle.visible = mode == "food"
	_cars_label.visible = mode == "parts"
	_cars_box.visible = mode == "parts"
	for c in _cars_box.get_children():
		c.queue_free()
	if mode == "parts":
		for car in vehicles:
			var b := _button(car.spec.title, Color(0.3, 0.26, 0.2))
			b.pressed.connect(select.bind(car))
			_cars_box.add_child(b)
		select(vehicles[0] if not vehicles.is_empty() else null)
	else:
		_refresh()


## Лавка с едой kind на базаре: свой товар, цены по торгу.
func open_food(b: Bazaar, kind: String) -> void:
	bazaar = b
	food_kind = kind
	open("food")
	_title.text = "Базар — %s" % Bazaar.FOOD_TITLE[kind]
	_status.text = _stock()


func select(car: Vehicle) -> void:
	_car = car
	if mode == "parts" and car == null:
		_status.text = "Своей техники пока нет — ставить запчасти некуда"
	_refresh()


func _refresh() -> void:
	for c in _goods.get_children():
		c.queue_free()
	if mode == "parts" and _car == null:
		return
	if mode == "parts":
		_goods.add_child(_label("Ставим на: %s" % _car.spec.title, 18, Color.WHITE))
	var list := _list()
	for id in list:
		var it: Array = list[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_goods.add_child(row)
		var have := _has(id)
		var b := _button("Уже есть" if have else "%d грн" % it[1], Color(0.25, 0.25, 0.25) if have else Color(0.28, 0.45, 0.25))
		b.custom_minimum_size.x = 120
		b.disabled = have
		b.pressed.connect(buy.bind(id))
		row.add_child(b)
		var text := "%s — %s" % [it[0], it[2]]
		if id == "rims" and _car and _car.parts.has("rims"):
			text += " (сейчас %s)" % Vehicle.RIM_NAMES[int(_car.parts["rims"])]
		if id == "repair_kit" and Progress.repair_kits > 0:
			text += " (в запасе %d)" % Progress.repair_kits
		var l := _label(text, 16, Color(0.95, 0.92, 0.85))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)


## Куплено ли уже (диски можно брать снова — другой цвет).
func _list() -> Dictionary:
	if mode == "shop":
		return get_parent().SHOP_MENU
	if mode == "food":
		return bazaar.food_list(food_kind)
	return {"home": HOME, "wedding": WEDDING}.get(mode, PARTS)


## Что у игрока сейчас — под меню сельмага.
func _stock() -> String:
	return "Сытость %d%% · вода %d%% · еды в запасе %d · ремнаборов %d" % [int(NeedsManager.food), int(NeedsManager.water), NeedsManager.snacks, Progress.repair_kits]


func _has(id: String) -> bool:
	if mode == "shop" or mode == "food":
		return false
	if mode == "home" or mode == "wedding":
		return Progress.has_item(id)
	if id == "rims" or id == "repair_kit":
		return false
	return _car != null and _car.has_part(id)


## Купить товар id. true — получилось.
func buy(id: String) -> bool:
	var list := _list()
	if not list.has(id) or _has(id) or (mode == "parts" and _car == null):
		return false
	var it: Array = list[id]
	if mode == "food":
		var got := bazaar.buy_food(food_kind, id)
		_status.text = ("Купил: %s. " % it[0] if got else "Не хватает денег: «%s» стоит %d грн. " % [it[0], it[1]]) + _stock()
		_refresh()
		return got
	if mode == "shop":
		var got: bool = shop_fn.call(id)
		_status.text = ("Купил: %s. " % it[0] if got else "Не хватает денег: «%s» стоит %d грн. " % [it[0], it[1]]) + _stock()
		_refresh()
		return got
	if not GameManager.spend(it[1]):
		_status.text = "Не хватает денег: «%s» стоит %d грн" % [it[0], it[1]]
		return false
	SoundLibrary.play("cash")
	if mode == "home" or mode == "wedding":
		Progress.add_item(id)
		_status.text = "«%s» уже у тебя дома" % it[0]
		if Progress.has_item("ring") and Progress.has_item("dress"):
			QuestManager.event("wedding_set")
	elif id == "repair_kit":
		Progress.repair_kits += 1
		_status.text = "Ремнабор — в запасе (%d). Чинить — в инвентаре (I), рядом со своей техникой" % Progress.repair_kits
	else:
		_car.fit_part(id)
		_status.text = "На «%s» поставили: %s" % [_car.spec.title, it[0]]
		if id == "rims":
			_status.text += " — %s" % Vehicle.RIM_NAMES[int(_car.parts["rims"])]
	QuestManager.event("market_buy")
	GameManager.notify("Базар: %s (−%d грн)" % [it[0], it[1]])
	_refresh()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()


func close_panel() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()
