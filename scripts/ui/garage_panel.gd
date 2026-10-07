class_name GaragePanel
extends CanvasLayer
## Окно личного гаража: вся своя техника списком — что в гараже, что на
## улице, сколько бензина и какое состояние. «Выкатить» — встанет на дорожку
## у дома; «В гараж» — загнать; внизу — «Загнать всё». Игра на паузе.

var garage: MyGarage
var _list: VBoxContainer
var _status: Label


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
	sb.bg_color = Color(0.13, 0.15, 0.14, 0.97)
	sb.border_color = Color(0.35, 0.6, 0.45)
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
	var title := _label("Мой гараж", 22, Color(0.75, 1.0, 0.8))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := _button("Закрыть", Color(0.35, 0.3, 0.27))
	close.pressed.connect(close_panel)
	head.add_child(close)
	_status = _label("", 16, Color(1.0, 0.85, 0.55))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	v.add_child(_list)
	var all := _button("Загнать всю технику в гараж", Color(0.25, 0.38, 0.3))
	all.pressed.connect(func() -> void:
		var n := garage.store_all()
		_status.text = "Загнал в гараж: %d" % n if n > 0 else "Вся техника уже в гараже"
		_refresh())
	v.add_child(all)


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
	return b


func open() -> void:
	visible = true
	get_tree().paused = true
	_status.text = "Выбери, на чём ехать — выкатится на дорожку у дома"
	_refresh()


func close_panel() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


## Строка на каждую технику: название, где стоит, бензин, состояние, кнопка.
func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var list: Array = garage.vehicles()
	if list.is_empty():
		_list.add_child(_label("Своей техники пока нет — купи мопед, мотоцикл или машину", 17, Color.WHITE))
		return
	for item in list:
		var v := item as Vehicle
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var where := "в гараже" if v.garaged else ("едешь на ней" if v.driver else "на улице")
		var info := _label("%s — %s, бензин %d л, состояние %d%%" % [v.spec.title, where, int(v.fuel), int(v.condition)], 17, Color.WHITE)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info)
		if v.driver == null:
			var out := _button("Выкатить" if v.garaged else "К дому", Color(0.3, 0.45, 0.6))
			out.pressed.connect(func() -> void:
				garage.take_out(v)
				close_panel())
			row.add_child(out)
		if not v.garaged and v.driver == null:
			var put := _button("В гараж", Color(0.3, 0.4, 0.3))
			put.pressed.connect(func() -> void:
				garage.store(v)
				_status.text = "«%s» — в гараже" % v.spec.title
				_refresh())
			row.add_child(put)
		_list.add_child(row)
