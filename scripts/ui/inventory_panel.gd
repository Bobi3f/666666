class_name InventoryPanel
extends CanvasLayer
## Инвентарь (I, на телефоне — кнопка «Вещи»): всё, что у игрока есть, —
## списком по разделам. Деньги, еда (можно съесть), вещи для заданий,
## документы и права, своя техника, дом и своё дело. Пока открыт — пауза.
## Вид — как у меню «Спорт»: тёмная панель, красная рамка.

const RED := Color(0.82, 0.1, 0.08)
const CREAM := Color(0.94, 0.9, 0.81)
const GREY := Color(0.62, 0.62, 0.64)
## Вещи для заданий: id → название
const QUEST_ITEMS := {
	"honey": "Банка мёда (для бабы Гали)",
	"berries": "Корзинка ягод",
	"medicine": "Лекарство для тёти Люды",
	"letters": "Письма",
}
## Купленное для дома и прочее: id → название (что не нашлось в лавках)
const OTHER_ITEMS := {
	"garage": "Гараж в ГСК «Мотор»",
	"mechanic": "Корочка автослесаря",
	"town_house": "Дом в городе, у восточной улицы",
	"flat": "Квартира в новой шестиэтажке",
}
const HOUSE_NAMES := ["Старая изба", "Штукатуренный дом под шифером", "Кирпичный дом под черепицей", "Двухэтажный коттедж с беседкой"]

var _panel: PanelContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _was_paused := false


func _ready() -> void:
	layer = 44
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("inventory")
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.13, 0.13, 0.14, 0.97)
	st.border_color = RED
	st.set_border_width_all(4)
	st.set_corner_radius_all(4)
	st.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", st)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Инвентарь"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", RED)
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	var close := _button("Закрыть", RED)
	close.pressed.connect(close_panel)
	box.add_child(close)
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	if _panel.visible:
		close_panel()
	elif not get_tree().paused:
		open()


func open() -> void:
	_was_paused = get_tree().paused
	_panel.visible = true
	get_tree().paused = true
	SoundLibrary.play("click", -6.0)
	refresh()
	_fit()


func close_panel() -> void:
	if not _panel.visible:
		return
	_panel.visible = false
	get_tree().paused = _was_paused


## Высота — по содержимому, но не выше экрана (на телефоне ~460 точек).
## Сначала ширина: строки с переносом знают свою высоту только при ней.
func _fit() -> void:
	var room := get_viewport().get_visible_rect().size
	_scroll.custom_minimum_size = Vector2(minf(620.0, room.x - 80.0), 120.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var need := _list.get_combined_minimum_size()
	_scroll.custom_minimum_size.y = clampf(need.y, 120.0, room.y - 170.0)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_I:
		toggle()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_ESCAPE and _panel.visible:
		close_panel()
		get_viewport().set_input_as_handled()


# --- Содержимое ---------------------------------------------------------------

## Собрать список заново: после «Съесть» и при каждом открытии.
func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	_section("Деньги")
	_row("Наличные: %d грн" % GameManager.money)
	if Daily.deposit > 0:
		_row("На вкладе в банке: %d грн" % Daily.deposit)

	_section("Еда и питьё")
	var eat := _row("Еда в запасе: %d" % NeedsManager.snacks, "Съесть" if NeedsManager.snacks > 0 else "")
	if eat:
		eat.pressed.connect(func() -> void:
			NeedsManager.eat_snack()
			refresh()
			_fit())
	if NeedsManager.fish > 0:
		_row("Рыба: %d" % NeedsManager.fish)
	_row("Сытость %d%%, бодрость %d%%, вода %d%%" % [int(NeedsManager.food), int(NeedsManager.energy), int(NeedsManager.water)], "", GREY)

	var quest := []
	for id in QuestManager.items:
		var n := int(QuestManager.items[id])
		if n <= 0 or id == "fish" or id == "snacks":
			continue
		var name: String = QUEST_ITEMS.get(id, id)
		quest.append(name if n == 1 else "%s — %d" % [name, n])
	if not quest.is_empty():
		_section("Вещи для заданий")
		for q in quest:
			_row(q)

	_section("Документы")
	if Progress.docs.is_empty() and Progress.categories.is_empty():
		_row("Пока никаких — паспорт выдают в сельсовете", "", GREY)
	for d in Progress.docs:
		var t: String = Progress.DOC_NAMES.get(d, d)
		_row(t.left(1).to_upper() + t.substr(1))
	if not Progress.categories.is_empty():
		var lic := _row("Водительское удостоверение: %s" % Progress.categories_text(), "Показать")
		lic.pressed.connect(func() -> void:
			var card := get_tree().get_first_node_in_group("license_card") as LicenseCard
			if card:
				card.open())

	var cars := []
	for v in get_tree().get_nodes_in_group("vehicles"):
		var veh := v as Vehicle
		if veh and veh.owned() and not veh.school and veh.kind != "tractor":
			cars.append(veh)
	_section("Техника")
	if cars.is_empty():
		_row("Своей техники нет", "", GREY)
	for veh: Vehicle in cars:
		var where := "ты за рулём" if veh.driver else "в %d м от тебя" % int(_dist(veh))
		_row("%s — бензин %d/%d л, кузов %d%%, %s" % [veh.spec.title, int(ceilf(veh.fuel)), int(veh.tank()), int(veh.condition), where])

	_section("Дом и хозяйство")
	_row(HOUSE_NAMES[clampi(Progress.house_level, 0, HOUSE_NAMES.size() - 1)])
	for id in Progress.home_items:
		_row(item_name(id))
	for id in Daily.owned:
		_row("Своё дело: %s, %d-й уровень, +%d грн в день до налога" % [Daily.BUSINESSES[id].title, Daily.level(id), Daily.income(id)])


## Название купленной вещи: из лавок базара, «Хозтоваров» мира или списка
## выше. Мир — родитель: прямой preload мира дал бы петлю зависимостей.
func item_name(id: String) -> String:
	for list in [MarketPanel.HOME, MarketPanel.WEDDING]:
		if list.has(id):
			return list[id][0]
	var goods: Dictionary = _world_const("HOME_GOODS", {})
	if goods.has(id):
		var t: String = goods[id].title
		return t.left(1).to_upper() + t.substr(1)
	return OTHER_ITEMS.get(id, id)


func _world_const(n: String, fallback: Variant) -> Variant:
	var w := get_parent()
	if w and w.get_script():
		return (w.get_script() as Script).get_script_constant_map().get(n, fallback)
	return fallback


func _dist(n: Node3D) -> float:
	var p := GameManager.player as Node3D
	return p.global_position.distance_to(n.global_position) if p else 0.0


func _section(text: String) -> void:
	var l := Label.new()
	# Перевод — до заглавных букв: в словаре заголовки обычные
	l.text = SettingsManager.t(text).to_upper()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36))
	_list.add_child(l)


## Строка списка; action — подпись кнопки справа (пусто — без кнопки).
func _row(text: String, action := "", color := CREAM) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_list.add_child(row)
	var l := Label.new()
	l.text = "  " + text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", color)
	row.add_child(l)
	if action.is_empty():
		return null
	var b := _button(action, RED)
	b.custom_minimum_size = Vector2(110, 40)
	row.add_child(b)
	return b


func _button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color.WHITE)
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(3)
	st.set_content_margin_all(6)
	b.add_theme_stylebox_override("normal", st)
	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = color.lightened(0.12)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("focus", hv)
	return b
