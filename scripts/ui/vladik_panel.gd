class_name VladikPanel
extends CanvasLayer
## Разговор с Дядей Владиком: что он сказал, доверие и меню —
## поговорить, что есть из запчастей, ремонт, продать запчасти, продать
## технику, купить запчасти, работа, уйти. Пункты открываются постепенно:
## торговля и работа — после «Оживить Карпаты», ремонт — с уровня доверия.
## Пока окно открыто, игра на паузе. Кнопки крупные — под палец.

var vladik: Vladik
var page := "main"
var car: Vehicle
var _title: Label
var _bar: ProgressBar
var _said: Label
var _buttons: VBoxContainer
var _first := false


func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var root := PanelContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 30
	root.offset_right = -30
	root.offset_top = 14
	root.offset_bottom = -14
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.15, 0.16, 0.97)
	sb.border_color = Color(0.85, 0.6, 0.25)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	root.add_theme_stylebox_override("panel", sb)
	add_child(root)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = _label("", 20, Color(1.0, 0.82, 0.5))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := _button("Уйти", Color(0.4, 0.3, 0.25))
	close.pressed.connect(close_panel)
	head.add_child(close)
	_bar = ProgressBar.new()
	_bar.max_value = 100
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.6, 0.25)
	fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)
	v.add_child(_bar)
	_said = _label("", 18, Color.WHITE)
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_said)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	v.add_child(_buttons)


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
	b.add_theme_font_size_override("font_size", 19)
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
	var dis := st.duplicate() as StyleBoxFlat
	dis.bg_color = Color(0.25, 0.25, 0.26)
	b.add_theme_stylebox_override("disabled", dis)
	return b


func open() -> void:
	visible = true
	get_tree().paused = true
	page = "main"
	car = null
	if not vladik.met:
		_first = true
		var lines: Array = vladik.first_meeting()
		var t := ""
		for l in lines:
			t += "%s: «%s»\n" % [l[0], l[1]]
		_said.text = t.strip_edges() + "\n(Новое задание: «Оживить Карпаты» — J)"
	else:
		var h := TimeManager.hour()
		_said.text = "Дядя Владик: «%s»" % ("Здоров. Чего надо?" if h < 17.0 else "Давай быстро, я скоро закрываюсь.")
	_refresh()


func _say(t: String) -> void:
	_said.text = "Дядя Владик: «%s»" % t


func _refresh() -> void:
	var l := vladik.level()
	_title.text = "ДЯДЯ ВЛАДИК · доверие %d/100 · уровень %d — %s" % [vladik.rep, l, VladikData.LEVEL_TEXT[l - 1]]
	_bar.value = vladik.rep
	for c in _buttons.get_children():
		c.queue_free()
	match page:
		"main":
			_main()
		"stock":
			_stock()
		"buy":
			_buy()
		"repair":
			_repair()
		"sell":
			_sell()
		"vehicle":
			_vehicle()


## Главное меню: 8 пунктов, закрытые — серые с подсказкой, когда откроются.
func _main() -> void:
	var done := vladik.first_done()
	var after := " (после «Оживить Карпаты»)"
	_add("1. Поговорить", Color(0.3, 0.32, 0.45), func() -> void:
		_say(vladik.chat())
		_refresh())
	_add("2. Что есть из запчастей?", Color(0.3, 0.38, 0.32), func() -> void: _open("stock"))
	var rep_ok := done and vladik.level() >= 2
	_add("3. Отремонтировать транспорт" + ("" if rep_ok else (after if not done else " (с уровня 2)")), Color(0.45, 0.35, 0.2), func() -> void: _open("repair"), not rep_ok)
	_add("4. Продать запчасти" + ("" if done else after), Color(0.45, 0.3, 0.25), func() -> void: _open("sell"), not done)
	_add("5. Продать транспорт" + ("" if done else after), Color(0.5, 0.25, 0.2), func() -> void: _open("vehicle"), not done)
	_add("6. Купить запчасти", Color(0.28, 0.42, 0.25), func() -> void: _open("buy"))
	_add("7. Получить работу" + ("" if done else after), Color(0.25, 0.38, 0.5), func() -> void:
		_say(vladik.offer_job())
		_refresh(), not done)
	if vladik.can_hire():
		_add("Позвать Владика на своё СТО (+250 грн в день)", Color(0.6, 0.45, 0.15), func() -> void:
			vladik.hire()
			_say("На твоё СТО? Ну… пойду. Только чай — мой, и табурет — мой.")
			_refresh())
	_add("8. Уйти", Color(0.35, 0.3, 0.28), close_panel)


func _open(p: String) -> void:
	page = p
	var cars := vladik.nearby_vehicles()
	car = cars[0] if not cars.is_empty() else null
	_refresh()


func _back() -> void:
	_add("← Назад", Color(0.3, 0.3, 0.32), func() -> void: _open("main"))


## «Что есть из запчастей?» — список с ценами по состоянию и уровнями.
func _stock() -> void:
	_back()
	var l := vladik.level()
	var t := "Расходники (новая / б/у / старая):\n"
	for id in VladikData.GOODS:
		var g: Array = VladikData.GOODS[id]
		t += "• %s — %d / %d / %d грн\n" % [g[0], Vladik.good_price(id, "new"), Vladik.good_price(id, "used"), Vladik.good_price(id, "old")]
	t += "\nРедкое:\n"
	for id in VladikData.RARE:
		var r: Array = VladikData.RARE[id]
		t += "• %s — %d грн%s\n" % [r[0], int(r[1]), "" if l >= int(r[2]) else " (уровень %d)" % int(r[2])]
	t += "\nРемонт узлов: мотоциклы — с уровня 2, машины — с уровня 4. Новый узел — дешевле, чем на СТО; б/у — вдвое дешевле; старый — почти даром."
	_buttons.add_child(_wrapped(t))
	_say("Чего нет — найдём. Чего не найдём — сделаем.")


func _wrapped(t: String) -> Label:
	var lab := _label(t, 16, Color(0.92, 0.9, 0.85))
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lab


## «Купить запчасти»: расходники в запас и редкие детали на технику рядом.
func _buy() -> void:
	_back()
	for id in VladikData.GOODS:
		var g: Array = VladikData.GOODS[id]
		var have := int(QuestManager.items.get(id, 0))
		_buttons.add_child(_label("%s%s" % [g[0], " (в запасе %d)" % have if have > 0 else ""], 17, Color.WHITE))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 6)
		_buttons.add_child(row)
		for q in VladikData.QUALITY:
			var b := _button("%s — %d грн" % [VladikData.QUALITY[q][0], Vladik.good_price(id, q)], Color(0.28, 0.42, 0.25).darkened(0.15 * VladikData.QUALITY.keys().find(q)))
			b.pressed.connect(func() -> void:
				if vladik.buy_good(id, q):
					_say("Держи. %s" % ("Новая — она и есть новая." if q == "new" else "Не новая, но послужит."))
				else:
					_say("Денег не хватает? Бывает. Приходи с деньгами.")
				_refresh())
			row.add_child(b)
	_car_picker()
	if car == null:
		return
	for id in VladikData.RARE:
		var r: Array = VladikData.RARE[id]
		if (r[3] == "moto") != bool(car.spec.two_wheels):
			continue
		var lock := vladik.level() < int(r[2])
		var has := car.has_part(r[4])
		var text := "%s — %d грн" % [r[0], int(r[1])]
		if lock:
			text += " (уровень %d)" % int(r[2])
		elif has:
			text += " (уже стоит)"
		_add(text, Color(0.55, 0.42, 0.15), func() -> void:
			_say("Поставил. Вещь редкая — не продавай кому попало." if vladik.buy_rare(id, car) else "Не получается: денег мало или уже стоит.")
			_refresh(), lock or has)


## Выбор своей техники у гаража.
func _car_picker() -> void:
	var cars := vladik.nearby_vehicles()
	if cars.is_empty():
		_buttons.add_child(_wrapped("Своей техники у гаража нет — подгони машину или мотоцикл к воротам."))
		return
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	_buttons.add_child(row)
	for v in cars:
		var b := _button(v.spec.title, Color(0.3, 0.26, 0.2) if v != car else Color(0.55, 0.42, 0.2))
		b.pressed.connect(func() -> void:
			car = v
			_refresh())
		row.add_child(b)


## «Отремонтировать транспорт»: узлы новые, б/у или старые — цена по состоянию.
func _repair() -> void:
	_back()
	_car_picker()
	if car == null:
		return
	if not vladik.can_repair(car):
		_buttons.add_child(_wrapped("Дядя Владик: «%s пока не возьму — %s»" % [car.spec.title, "мотоциклы смотрю со второго уровня" if car.spec.two_wheels else "машины — с четвёртого уровня доверия"]))
		return
	for n in Vehicle.WEAR:
		var h: float = car.part_health(n)
		var col := Color(0.95, 0.92, 0.85) if h >= 50.0 else (Color(1.0, 0.8, 0.4) if h >= 25.0 else Color(1.0, 0.5, 0.4))
		_buttons.add_child(_label("%s — ресурс %d%%" % [Vehicle.WEAR[n][0], int(h)], 17, col))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 6)
		_buttons.add_child(row)
		for q in VladikData.QUALITY:
			var hp: float = VladikData.QUALITY[q][2]
			var b := _button("%s %d%% — %d грн" % [VladikData.QUALITY[q][0], int(hp), Vladik.repair_price(car, n, q)], Color(0.45, 0.35, 0.2))
			b.disabled = h >= hp
			b.pressed.connect(func() -> void:
				_say("Сделано. Езди." if vladik.repair_part(car, n, q) else "Денег не хватает.")
				_refresh())
			row.add_child(b)


## «Продать запчасти»: что Владик купит из запаса.
func _sell() -> void:
	_back()
	var list := vladik.sellable()
	if list.is_empty():
		_buttons.add_child(_wrapped("Продать нечего. Лом, старые колёса, аккумуляторы, моторы — всё это Владик берёт. Найти можно на разборке у гаража и на свалке."))
		return
	for e in list:
		var id: String = e[0]
		_add("%s ×%d — продать за %d грн" % [VladikData.BUYS[id][0], int(e[1]), int(VladikData.BUYS[id][1])], Color(0.45, 0.3, 0.25), func() -> void:
			if vladik.sell_item(id):
				_say("Беру. Честно — значит честно.")
			_refresh())


## «Продать транспорт»: своя техника у гаража, кроме мопеда.
func _vehicle() -> void:
	_back()
	var any := false
	for v in vladik.nearby_vehicles():
		if not JunkPanel.can_sell(v):
			continue
		any = true
		_add("Продать «%s» за %d грн" % [v.spec.title, vladik.vehicle_price(v)], Color(0.55, 0.22, 0.18), func() -> void:
			if vladik.sell_vehicle(v):
				_say("Беру. Не переживай — у меня она не пропадёт.")
			_refresh())
	if not any:
		_buttons.add_child(_wrapped("Дядя Владик: «Подгони к воротам, что продаёшь. Мопед свой не отдавай — на нём полсела ездит»"))


func _add(text: String, color: Color, fn: Callable, disabled := false) -> void:
	var b := _button(text, color)
	b.disabled = disabled
	b.pressed.connect(fn)
	_buttons.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()


func close_panel() -> void:
	visible = false
	get_tree().paused = false
