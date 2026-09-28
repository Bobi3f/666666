extends CanvasLayer
## Обучение первых минут новой игры: осмотреться, дойти до «Жигулей»,
## сесть, поехать, остановиться. Каждый шаг — одна короткая подсказка
## внизу экрана; шаг засчитывается, когда игрок сделал это сам.
##
## Тексты — под то, чем играют: кнопки на телефоне или клавиатура.
## «Пропустить» — сразу закончить. Пройдено — Progress.tutorial_done,
## сохраняется вместе с игрой, в загруженной игре обучения нет.

var _step := 0
var _panel: PanelContainer
var _title: Label
var _text: Label
var _skip: Button
var _yaw0 := 0.0
var _turned := 0.0
var _done_timer := 0.0


func _ready() -> void:
	layer = 15
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.12, 0.88)
	style.border_color = Color(0.95, 0.7, 0.24)
	style.border_width_left = 4
	style.set_content_margin_all(12)
	style.content_margin_left = 16
	style.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_title = Label.new()
	_title.add_theme_color_override("font_color", Color(0.95, 0.7, 0.24))
	_title.add_theme_font_size_override("font_size", 15)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_skip = Button.new()
	_skip.text = "Пропустить"
	_skip.flat = true
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.add_theme_font_size_override("font_size", 14)
	_skip.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_skip.pressed.connect(_finish)
	head.add_child(_skip)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 18)
	box.add_child(_text)
	_show_step()


func _touch() -> bool:
	return GameManager.touch_mode


## [заголовок, текст для телефона, текст для клавиатуры]
func _texts() -> Array:
	return [
		["Осмотрись", "Проведи пальцем по правой половине экрана", "Подвигай мышью — осмотрись вокруг"],
		["Иди к машине", "Джойстик слева — иди к «Жигулям» на улице", "W A S D — иди к «Жигулям» на улице, Shift — бегом"],
		["Садись за руль", "Подойди к двери и нажми «E»", "Подойди к двери и нажми E"],
		["Поехали", "Жми педаль «Газ», крути руль пальцем", "W — газ, A и D — руль"],
		["Тормози", "«Тормоз» — остановись", "S — тормоз, остановись"],
		["Готово!", "Задание — слева вверху, все дела — в «Журнале». Удачи в Каменке!", "Задание — слева вверху, все дела — в журнале (J). Удачи в Каменке!"],
	]


func _show_step() -> void:
	var t: Array = _texts()[_step]
	_title.text = "%s   %d / 5" % [t[0], mini(_step + 1, 5)] if _step < 5 else t[0]
	_text.text = t[1] if _touch() else t[2]
	_skip.visible = _step < 5
	var p := GameManager.player as Node3D
	if p:
		_yaw0 = p.rotation.y
	_turned = 0.0


func _next() -> void:
	_step += 1
	SoundLibrary.play("click", -4.0, 1.4)
	_show_step()


func _finish() -> void:
	Progress.tutorial_done = true
	queue_free()


func _process(delta: float) -> void:
	if Progress.tutorial_done:
		queue_free()
		return
	_place()
	var p := GameManager.player as Player
	var car := GameManager.car as Vehicle
	if p == null or car == null:
		return
	match _step:
		0:
			_turned += absf(angle_difference(_yaw0, p.rotation.y))
			_yaw0 = p.rotation.y
			if _turned > 0.8:
				_next()
		1:
			if p.global_position.distance_to(car.global_position) < 4.5 or GameManager.vehicle != null:
				_next()
		2:
			if GameManager.vehicle != null:
				_next()
		3:
			if GameManager.vehicle != null and (GameManager.vehicle as Vehicle).speed_kmh() > 15.0:
				_next()
		4:
			if GameManager.vehicle == null or (GameManager.vehicle as Vehicle).speed_kmh() < 2.0:
				_next()
		5:
			_done_timer += delta
			if _done_timer > 6.0:
				_finish()


## Внизу посередине — между джойстиком и кнопками на телефоне.
## На компьютере в машине внизу приборы — тогда подсказка выше.
func _place() -> void:
	var size := get_viewport().get_visible_rect().size
	var driving := GameManager.vehicle != null
	var left := 20.0
	var right := size.x - 20.0
	if _touch():
		left = 320.0 if driving else 260.0
		right = size.x - (400.0 if driving else 300.0)
	var w := clampf(right - left, 240.0, 480.0)
	_panel.custom_minimum_size = Vector2(w, 0)
	_panel.size = Vector2(w, 0)
	_panel.reset_size()
	var x := (left + right - w) * 0.5
	var y := size.y - _panel.size.y - 14.0
	# За рулём внизу — спидометр: подсказка поднимается выше
	if driving:
		y = 250.0
	_panel.position = Vector2(x, y)
