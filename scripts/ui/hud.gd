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
var _goal: Label
var _keys_hint: Label


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
	_car.offset_top = -95
	if GameManager.touch_mode:
		# Слева внизу — джойстик: приборы уводим наверх под трекер
		_car.anchor_top = 0.0
		_car.anchor_bottom = 0.0
		_car.offset_top = 150
		_car.add_theme_font_size_override("font_size", 16)
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
	_msg.offset_top = 150
	_goal = _label(Vector2(16, 70), 16)
	_goal.modulate = Color(1.0, 0.92, 0.6)
	var hint := _label(Vector2(0, 12), 15)
	_keys_hint = hint
	hint.visible = not GameManager.touch_mode
	hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -230
	hint.text = "F1 — управление   Esc — меню\nJ — журнал   M — карта\nF5 — сохранить  F9 — загрузить"
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
	_msg.text = GameManager.touch_text(text)
	_msg_time = 4.0


func _process(delta: float) -> void:
	_top.text = "%s     %d грн     %s" % [TimeManager.clock_text(), GameManager.money, WeatherManager.name_text()]
	# Трекер: развоз (если идёт), сюжетное задание и просьбы жителей
	var lines: Array[String] = []
	if Progress.delivery_active:
		lines.append(Progress.goal_text())
	lines.append_array(QuestManager.tracker_lines())
	_goal.text = GameManager.touch_text("\n".join(lines))
	# Подсказка по клавишам на телефоне не нужна — там кнопки
	_keys_hint.visible = not GameManager.touch_mode
	_food_bar.value = NeedsManager.food
	_energy_bar.value = NeedsManager.energy
	_food_pct.text = "%d%%" % int(NeedsManager.food)
	_energy_pct.text = "%d%%" % int(NeedsManager.energy)
	_snacks.text = "Еда в запасе: %d" % NeedsManager.snacks if GameManager.touch_mode else "Еда в запасе: %d (Q)" % NeedsManager.snacks
	var car := GameManager.vehicle as Vehicle
	var p := GameManager.player as Player
	if car and car.driver:
		_car.visible = true
		var auto := SettingsManager.auto_gearbox
		var box := "Автомат: %s" % car.gear_name() if auto else "Механика: %s   Сцепление: %s" % [car.gear_name(),
			"выжато" if car.clutch < 0.2 else ("схватывает" if car.clutch < 0.8 else "отпущено")]
		var motor := "Мотор работает" if car.engine_on else ("Мотор заглушен (W — завести)" if auto else "Мотор заглушен (R)")
		var slide := ""
		if absf(car.lateral) > 2.5:
			slide = "   ЗАНОС"
		elif not car.on_asphalt() and WeatherManager.wetness > 0.3:
			slide = "   Грязь — вязнет"
		_car.text = "%3d км/ч   %4d об/мин   %s   %s\n%s   Бензин: %d л   Состояние: %d%%   %s%s" % [
			int(car.speed_kmh()), int(car.rpm), box, motor,
			car.spec.title, int(ceilf(car.fuel)), int(car.condition),
			"T — коробка, V — вид", slide]
		_car.text = GameManager.touch_text(_car.text)
		# Слева внизу на телефоне — руль: приборы держим наверху под трекером
		if GameManager.touch_mode and _car.anchor_top != 0.0:
			_car.anchor_top = 0.0
			_car.anchor_bottom = 0.0
			_car.offset_top = 150
			_car.offset_bottom = 150
			_car.add_theme_font_size_override("font_size", 16)
		_prompt.text = ""
	else:
		_car.visible = false
		_prompt.text = p.current_prompt() if p else ""
	# На телефоне приборы машины стоят под трекером — сообщения опускаем ниже них
	_msg.offset_top = 205.0 if GameManager.touch_mode and car and car.driver else 150.0
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
