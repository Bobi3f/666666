class_name PlatePanel
extends CanvasLayer
## Окошко ГАИ в отделении милиции: регистрация номера для своей машины.
## Выбираешь машину, потом номер: обычный (дёшево), «красивый» — одинаковые
## цифры, 77-77, 00-07 (дорого) — или набираешь свой. Пока окно открыто,
## игра на паузе. Кнопки крупные — под палец.

const PLAIN_PRICE := 50
const NICE_PRICE := 300
const CUSTOM_PRICE := 200

signal closed

var _vehicles: Array = []
var _car: Vehicle
var _root: PanelContainer
var _title: Label
var _cars_box: HFlowContainer
var _numbers_box: VBoxContainer
var _current: Label
var _plain_box: HFlowContainer
var _nice_box: HFlowContainer
var _edit: LineEdit
var _status: Label
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	# Выше мини-карты и кнопок телефона
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	_rng.randomize()
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = 30
	_root.offset_right = -30
	_root.offset_top = 14
	_root.offset_bottom = -14
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.14, 0.24, 0.97)
	sb.border_color = Color(0.85, 0.85, 0.82)
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
	_title = _label("ГАИ — регистрация номера", 20, Color(0.95, 0.85, 0.5))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := _button("Закрыть", Color(0.5, 0.25, 0.22))
	close.pressed.connect(close_panel)
	head.add_child(close)
	v.add_child(_label("Какую машину регистрируем:", 16, Color(0.85, 0.85, 0.9)))
	_cars_box = HFlowContainer.new()
	_cars_box.add_theme_constant_override("h_separation", 8)
	_cars_box.add_theme_constant_override("v_separation", 6)
	v.add_child(_cars_box)
	_numbers_box = VBoxContainer.new()
	_numbers_box.add_theme_constant_override("separation", 6)
	v.add_child(_numbers_box)
	_current = _label("", 18, Color(1, 1, 1))
	_numbers_box.add_child(_current)
	_numbers_box.add_child(_label("Обычный номер — %d грн:" % PLAIN_PRICE, 16, Color(0.85, 0.85, 0.9)))
	_plain_box = HFlowContainer.new()
	_plain_box.add_theme_constant_override("h_separation", 8)
	_numbers_box.add_child(_plain_box)
	_numbers_box.add_child(_label("Красивый номер — %d грн:" % NICE_PRICE, 16, Color(0.95, 0.85, 0.5)))
	_nice_box = HFlowContainer.new()
	_nice_box.add_theme_constant_override("h_separation", 8)
	_numbers_box.add_child(_nice_box)
	_numbers_box.add_child(_label("Свой номер — %d грн (буква, 4 цифры, 2 буквы области):" % CUSTOM_PRICE, 16, Color(0.85, 0.85, 0.9)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_numbers_box.add_child(row)
	_edit = LineEdit.new()
	_edit.placeholder_text = "а 12-34 КМ"
	_edit.custom_minimum_size = Vector2(220, 46)
	_edit.add_theme_font_size_override("font_size", 22)
	_edit.max_length = 14
	TextInput.attach(_edit, "Свой номер: буква, 4 цифры, 2 буквы области")
	_edit.text_submitted.connect(func(_t: String) -> void: _buy_custom())
	row.add_child(_edit)
	var mine := _button("Взять свой", Color(0.25, 0.4, 0.3))
	mine.pressed.connect(_buy_custom)
	row.add_child(mine)
	_status = _label("", 16, Color(1.0, 0.75, 0.5))
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
	return b


## Открыть окно со списком своих машин.
func open(vehicles: Array) -> void:
	_vehicles = vehicles
	visible = true
	get_tree().paused = true
	_status.text = ""
	_refresh_cars()
	select(vehicles[0] if not vehicles.is_empty() else null)


func _refresh_cars() -> void:
	for c in _cars_box.get_children():
		c.queue_free()
	for car in _vehicles:
		var b := _button("%s · %s" % [car.spec.title, car.plate()], Color(0.22, 0.28, 0.42))
		b.pressed.connect(select.bind(car))
		_cars_box.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()


func close_panel() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


## Выбрана машина — показать её номер и варианты новых.
func select(car: Vehicle) -> void:
	_car = car
	_numbers_box.visible = car != null
	if car == null:
		_status.text = "Своих машин пока нет — номер регистрировать нечему"
		return
	_current.text = "%s — сейчас: %s" % [car.spec.title, car.plate()]
	for box in [_plain_box, _nice_box]:
		for c in box.get_children():
			c.queue_free()
	for i in 3:
		var t := Plates.number(_rng.randi())
		var b := _button(t, Color(0.3, 0.32, 0.36))
		b.pressed.connect(buy.bind(t, PLAIN_PRICE))
		_plain_box.add_child(b)
	for t in Plates.nice_numbers(_rng.randi(), 3):
		var b := _button(t, Color(0.45, 0.36, 0.16))
		b.pressed.connect(buy.bind(t, NICE_PRICE))
		_nice_box.add_child(b)


func _buy_custom() -> void:
	var t := Plates.parse(_edit.text)
	if t == "":
		_status.text = "Так номер не пишут. Нужно: буква, четыре цифры и две буквы области — например «а 12-34 КМ»"
		return
	buy(t, CUSTOM_PRICE)


## Зарегистрировать номер t на выбранную машину. true — получилось.
func buy(t: String, price: int) -> bool:
	if _car == null:
		return false
	for car in get_tree().get_nodes_in_group("vehicles"):
		if car != _car and car.plate() == t:
			_status.text = "Номер «%s» уже занят — выбери другой" % t
			return false
	if t == _car.plate():
		_status.text = "Этот номер и так у твоей машины"
		return false
	if not GameManager.spend(price):
		_status.text = "Не хватает денег: номер стоит %d грн" % price
		return false
	_car.set_plate(t)
	SoundLibrary.play("cash")
	QuestManager.event("plate")
	GameManager.notify("ГАИ: «%s» зарегистрирован с номером %s (−%d грн)" % [_car.spec.title, t, price])
	_refresh_cars()
	select(_car)
	_status.text = "Готово: у «%s» теперь номер %s" % [_car.spec.title, t]
	return true
