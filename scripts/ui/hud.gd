extends CanvasLayer
## Интерфейс: деньги, время, сытость и бодрость, приборы машины,
## подсказка действия и всплывающие сообщения.

var _top: Label
var _food_pct: Label
var _energy_pct: Label
var _snacks: Label
var _food_bar: ProgressBar
var _energy_bar: ProgressBar
var _car: Label
var _prompt: Label
var _msg: Label
var _msg_time := 0.0


func _ready() -> void:
	layer = 10
	_top = _label(Vector2(16, 12), 20)
	_label(Vector2(16, 42), 17).text = "Сытость"
	_food_bar = _bar_node(Vector2(100, 49), Color(0.85, 0.6, 0.2))
	_food_pct = _label(Vector2(238, 42), 17)
	_label(Vector2(300, 42), 17).text = "Бодрость"
	_energy_bar = _bar_node(Vector2(392, 49), Color(0.35, 0.65, 0.95))
	_energy_pct = _label(Vector2(530, 42), 17)
	_snacks = _label(Vector2(600, 42), 17)
	_car = _label(Vector2(16, 0), 22)
	_car.anchor_top = 1.0
	_car.anchor_bottom = 1.0
	_car.offset_top = -70
	_prompt = _label(Vector2(0, 0), 20)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.offset_top = 60
	_msg = _label(Vector2(0, 0), 20)
	_msg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.offset_left = -400
	_msg.offset_right = 400
	_msg.offset_top = 80
	var hint := _label(Vector2(0, 12), 15)
	hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -230
	hint.text = "F1 — управление\nF5 — сохранить  F9 — загрузить"
	# Прицел-точка
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.7)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(2, 2)
	add_child(dot)
	GameManager.message.connect(show_message)


func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	add_child(l)
	return l


func show_message(text: String) -> void:
	_msg.text = text
	_msg_time = 4.0


func _process(delta: float) -> void:
	_top.text = "%s     %d грн" % [TimeManager.clock_text(), GameManager.money]
	_food_bar.value = NeedsManager.food
	_energy_bar.value = NeedsManager.energy
	_food_pct.text = "%d%%" % int(NeedsManager.food)
	_energy_pct.text = "%d%%" % int(NeedsManager.energy)
	_snacks.text = "Еда в запасе: %d (Q)" % NeedsManager.snacks
	var car := GameManager.car as Car
	var p := GameManager.player as Player
	if car and car.driver:
		_car.visible = true
		_car.text = "%3d км/ч   %4d об/мин   Передача: %s   %s   Сцепление: %s" % [
			int(car.speed_kmh()), int(car.rpm), car.gear_name(),
			"Мотор работает" if car.engine_on else "Мотор заглушен (R)",
			"выжато" if car.clutch < 0.2 else ("схватывает" if car.clutch < 0.8 else "отпущено")]
		_prompt.text = ""
	else:
		_car.visible = false
		_prompt.text = p.current_prompt() if p else ""
	if _msg_time > 0.0:
		_msg_time -= delta
		_msg.modulate.a = clampf(_msg_time, 0.0, 1.0)
	else:
		_msg.text = ""


func _bar_node(pos: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = Vector2(130, 14)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	add_child(bar)
	return bar
