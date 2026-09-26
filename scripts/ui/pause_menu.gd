extends CanvasLayer
## Главное меню при запуске и пауза по Esc: продолжить, сохранить, загрузить,
## чувствительность мыши, громкость, новая игра, выход.
##
## Пока меню открыто, игра стоит на паузе. Для автотестов меню при запуске
## можно пропустить: godot ... -- --no-menu

## Главное меню показываем один раз за запуск, не после «Новой игры».
static var _started := false

var _panel: PanelContainer
var _title: Label
var _resume: Button
var _continue: Button
var _save: Button
var _new: Button
var _load: Button
var _main_mode := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	if not _started and not "--no-menu" in OS.get_cmdline_user_args():
		_open(true)
	else:
		_started = true
		_panel.visible = false


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.1, 0.92)
	style.set_content_margin_all(28)
	style.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	center.add_child(_panel)
	# Затемнение видно только вместе с панелью
	_panel.visibility_changed.connect(func() -> void: dim.visible = _panel.visible)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(380, 0)
	_panel.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	box.add_child(_title)
	var sub := Label.new()
	sub.text = "Жизнь в Каменке на первой передаче"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.6)
	box.add_child(sub)
	box.add_child(HSeparator.new())

	_resume = _button(box, "Продолжить", _close)
	_continue = _button(box, "Продолжить с сохранения", func() -> void:
		_close()
		SaveManager.load_game())
	_new = _button(box, "Новая игра", _new_game)
	_save = _button(box, "Сохранить (F5)", func() -> void:
		SaveManager.save_game()
		_refresh())
	_load = _button(box, "Загрузить (F9)", func() -> void:
		_close()
		SaveManager.load_game())

	box.add_child(HSeparator.new())
	_slider(box, "Чувствительность мыши", 0.2, 3.0, SettingsManager.mouse_sens, SettingsManager.set_mouse_sens)
	_slider(box, "Громкость", 0.0, 1.0, SettingsManager.volume, SettingsManager.set_volume)
	box.add_child(HSeparator.new())
	_button(box, "Выйти из игры", func() -> void: get_tree().quit())
	var hint := Label.new()
	hint.text = "F1 — управление"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.5)
	box.add_child(hint)


func _button(box: VBoxContainer, text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func() -> void:
		SoundLibrary.play("click", -6.0)
		fn.call())
	box.add_child(b)
	return b


func _slider(box: VBoxContainer, text: String, lo: float, hi: float, value: float, fn: Callable) -> void:
	var label := Label.new()
	box.add_child(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(0, 24)
	var set_label := func(v: float) -> void: label.text = "%s: %d%%" % [text, int(round(v * 100.0))]
	set_label.call(value)
	s.value_changed.connect(func(v: float) -> void:
		set_label.call(v)
		fn.call(v))
	box.add_child(s)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE:
		if _panel.visible and not _main_mode:
			_close()
		elif not _panel.visible:
			_open(false)
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _panel.visible


func _open(main: bool) -> void:
	_main_mode = main
	_title.text = "FIRST GEAR" if main else "Пауза"
	_refresh()
	_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _refresh() -> void:
	_resume.text = "Начать" if _main_mode and not SaveManager.has_save() else "Продолжить"
	_continue.visible = _main_mode and SaveManager.has_save()
	_resume.visible = not (_main_mode and SaveManager.has_save())
	_new.visible = not (_main_mode and not SaveManager.has_save())
	_save.visible = not _main_mode
	_load.visible = not _main_mode and SaveManager.has_save()


func _close() -> void:
	_started = true
	_main_mode = false
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Новая игра: сбросить деньги, время, потребности, погоду и цели, мир — заново.
func _new_game() -> void:
	_started = true
	GameManager.load_state({})
	TimeManager.load_state({})
	NeedsManager.load_state({})
	WeatherManager.load_state({})
	Progress.load_state({})
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()
