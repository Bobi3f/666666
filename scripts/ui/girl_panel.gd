class_name GirlPanel
extends CanvasLayer
## Разговор с Олей: что она сказала, сколько симпатии и что можно сделать —
## поболтать, подарить цветы или конфеты, позвать гулять или отпустить
## домой. Пока окно открыто, игра на паузе. Кнопки крупные — под палец.

var girl: Girl
var _root: PanelContainer
var _title: Label
var _bar: ProgressBar
var _said: Label
var _buttons: HFlowContainer


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
	sb.bg_color = Color(0.25, 0.12, 0.2, 0.96)
	sb.border_color = Color(0.95, 0.6, 0.75)
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
	_title = _label("", 20, Color(1.0, 0.8, 0.88))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := _button("Пока", Color(0.45, 0.25, 0.3))
	close.pressed.connect(close_panel)
	head.add_child(close)
	_bar = ProgressBar.new()
	_bar.max_value = 100
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.35, 0.55)
	fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)
	v.add_child(_bar)
	_said = _label("", 18, Color.WHITE)
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_said)
	_buttons = HFlowContainer.new()
	_buttons.add_theme_constant_override("h_separation", 8)
	_buttons.add_theme_constant_override("v_separation", 6)
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


func open() -> void:
	visible = true
	get_tree().paused = true
	var h := TimeManager.hour()
	if girl.state == Girl.State.FOLLOW:
		_said.text = "Оля: «Ну что, куда идём?»"
	elif h < 7.0 or h >= 23.0:
		_said.text = "Оля: «Тсс… все спят!»"
	else:
		_said.text = "Оля: «Привет!»" if girl.rel > 0 else "Девушка: «Привет! А ты новенький? Я Оля.»"
	_refresh()


func _refresh() -> void:
	_title.text = "Оля — %s · симпатия %d/100" % [girl.level(), girl.rel]
	_bar.value = girl.rel
	for c in _buttons.get_children():
		c.queue_free()
	_add("Поболтать", Color(0.35, 0.3, 0.5), func() -> void: _say(girl.talk()))
	for id in Girl.GIFTS:
		var g: Array = Girl.GIFTS[id]
		_add("Подарить %s — %d грн" % [g[0], g[1]], Color(0.55, 0.25, 0.4), func() -> void: _say(girl.gift(id)))
	if girl.state == Girl.State.LIFE:
		_add("Пойдём гулять / покатаемся", Color(0.25, 0.45, 0.3), func() -> void:
			_say(girl.invite())
			if girl.state == Girl.State.FOLLOW:
				GameManager.notify("Оля идёт с тобой. Сядешь в машину или на мотоцикл — сядет рядом")
				close_panel())
	else:
		_add("Иди домой, до завтра", Color(0.4, 0.35, 0.3), func() -> void:
			girl.send_home(false)
			close_panel())


func _add(text: String, color: Color, fn: Callable) -> void:
	var b := _button(text, color)
	b.pressed.connect(fn)
	_buttons.add_child(b)


func _say(t: String) -> void:
	_said.text = "Оля: «%s»" % t if not t.begins_with("Не хватает") else t
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()


func close_panel() -> void:
	visible = false
	get_tree().paused = false
