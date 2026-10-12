class_name PrincessPanel
extends CanvasLayer
## Окошко Принцессы: что она говорит, настроение (добрая / злая), позвать
## гулять или отпустить, витрина брелочков с ценами и коллекция. Игра на паузе.

var princess: Princess
var _said: Label
var _bar: ProgressBar
var _fill: StyleBoxFlat
var _walk: Button
var _list: VBoxContainer


func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("princess_panel")


func _ready() -> void:
	var root := PanelContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 30
	root.offset_right = -30
	root.offset_top = 14
	root.offset_bottom = -14
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.12, 0.16, 0.97)
	sb.border_color = Color(1.0, 0.6, 0.8)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(8)
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
	var title := _label("Принцесса", 22, Color(1.0, 0.75, 0.88))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := _button("Закрыть", Color(0.35, 0.28, 0.3))
	close.pressed.connect(close_panel)
	head.add_child(close)
	_bar = ProgressBar.new()
	_bar.max_value = 100
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 12)
	_fill = StyleBoxFlat.new()
	_fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", _fill)
	v.add_child(_bar)
	_said = _label("", 18, Color.WHITE)
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_said)
	_walk = _button("", Color(0.55, 0.25, 0.45))
	_walk.pressed.connect(func() -> void:
		var t := princess.walk()
		if princess.following:
			close_panel()
		else:
			_said.text = "Принцесса: «%s»" % t
			_refresh())
	v.add_child(_walk)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	v.add_child(_list)


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
	b.add_theme_font_size_override("font_size", 18)
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
	dis.bg_color = Color(0.25, 0.22, 0.24)
	b.add_theme_stylebox_override("disabled", dis)
	return b


func open(p: Princess) -> void:
	princess = p
	visible = true
	get_tree().paused = true
	_said.text = "Принцесса: «%s»" % p.say()
	_refresh()


func close_panel() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var kind := princess.kind()
	_bar.value = princess.mood
	_fill.bg_color = Color(1.0, 0.55, 0.75) if kind else Color(0.9, 0.2, 0.15)
	_walk.text = "Отпустить домой" if princess.following else ("Позвать гулять" if kind else "Позвать гулять (она злится)")
	if princess.where != Princess.OUT and not princess.following:
		_walk.text = "Гулять — завтра с утра"
	for c in _list.get_children():
		c.queue_free()
	var head := "Брелочки — %d из %d у тебя. %s" % [princess.keychains.size(), Princess.KEYCHAINS.size(),
		"Для тебя скидка!" if kind else "Злая — продаёт втридорога"]
	_list.add_child(_label(head, 17, Color(1.0, 0.85, 0.6)))
	for i in Princess.KEYCHAINS.size():
		var k: Array = Princess.KEYCHAINS[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_l := _label(String(k[1]), 17, Color.WHITE)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var b: Button
		if princess.keychains.has(k[0]):
			b = _button("Есть", Color(0.3, 0.45, 0.3))
			b.disabled = true
		else:
			b = _button("Купить — %d грн" % princess.price(i), Color(0.6, 0.3, 0.5))
			b.pressed.connect(func() -> void:
				if princess.buy(i):
					_said.text = "Принцесса: «%s»" % ("Ой, какой милый! Спасибо, мой рыцарь!" if princess.kind() else "Ну... ладно. Спасибо.")
				else:
					_said.text = "Принцесса: «Денег не хватает? Эх ты...»"
				_refresh())
		row.add_child(b)
		_list.add_child(row)
