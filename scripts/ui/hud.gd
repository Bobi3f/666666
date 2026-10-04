extends CanvasLayer
## Интерфейс: деньги, время, сытость и бодрость, приборы машины,
## подсказка действия и всплывающие сообщения.

var _top: Label
## Сытость, бодрость, вода — круглые кольца в одну строку с временем и деньгами
var _needs: Control
const RING_R := 15.0
const RINGS := [["сытость", Color(0.95, 0.65, 0.2)], ["бодрость", Color(0.4, 0.7, 1.0)], ["вода", Color(0.35, 0.85, 0.9)]]
var _snacks: Label
var _car: Label
var _prompt: Label
var _msg: Label
var _msg_time := 0.0
## Сообщения, пришедшие почти одновременно, показываем по очереди: каждое —
## хотя бы пару секунд, иначе второе стирает первое, не дав прочитать.
var _queue: Array[String] = []
const MSG_TIME := 4.0
const MSG_MIN := 2.2
var _goal: Label
var _keys_hint: Label
## Стрелка-навигатор к цели задания.
var nav: Control


func _ready() -> void:
	layer = 10
	add_child(preload("res://scripts/ui/speedometer.gd").new())
	nav = preload("res://scripts/ui/nav_arrow.gd").new()
	add_child(nav)
	_top = _label(Vector2(16, 12), 19)
	_needs = Control.new()
	_needs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_needs.size = Vector2(RINGS.size() * (RING_R * 2.0 + 30.0), RING_R * 2.0 + 14.0)
	_needs.draw.connect(_draw_needs)
	add_child(_needs)
	_snacks = _label(Vector2(0, 12), 17)
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
	# Длинные сообщения — в две строки, а не за край экрана
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal = _label(Vector2(16, 56), 16)
	_goal.modulate = Color(1.0, 0.92, 0.6)
	# Длинные строки заданий переносятся, а не уходят под кнопки справа
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Всплывающая сумма у денег: +500 зелёным, −45 красным
	_money_pop = _label(Vector2(0, 30), 18)
	_money_pop.visible = false
	_last_money = GameManager.money
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


var _money_pop: Label
var _last_money := 0
var _pop_t := 0.0


func _update_money_pop(delta: float) -> void:
	var m := GameManager.money
	if m != _last_money:
		var d := m - _last_money
		_last_money = m
		# Пока пишем подряд (заправка по литру) — копим одну сумму
		var prev := int(_money_pop.get_meta("sum", 0)) if _pop_t > 0.0 else 0
		var sum := prev + d
		_money_pop.set_meta("sum", sum)
		_money_pop.text = ("+%d" % sum) if sum > 0 else ("−%d" % -sum)
		_money_pop.add_theme_color_override("font_color", Color(0.55, 1.0, 0.5) if sum > 0 else Color(1.0, 0.5, 0.4))
		var font := _top.get_theme_font("font")
		var clock_w := font.get_string_size(TimeManager.clock_text() + "     ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		_money_pop.position = Vector2(16.0 + clock_w, 34.0)
		_money_pop.visible = sum != 0
		_pop_t = 1.6
	if _pop_t > 0.0:
		_pop_t -= delta
		_money_pop.modulate.a = clampf(_pop_t, 0.0, 1.0)
		_money_pop.position.y = 34.0 + (1.6 - _pop_t) * 6.0
		if _pop_t <= 0.0:
			_money_pop.visible = false


func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	add_child(l)
	return l


func show_message(text: String) -> void:
	var t := GameManager.touch_text(text)
	if t == _msg.text or _queue.has(t):
		return
	# Текущее висит меньше MSG_MIN — новое ждёт своей очереди
	if _msg_time > MSG_TIME - MSG_MIN and _msg.text != "":
		if _queue.size() >= 4:
			_queue.pop_front()
		_queue.append(t)
		return
	_msg.text = t
	_msg_time = MSG_TIME


func _process(delta: float) -> void:
	_top.text = "%s    %d грн    %s" % [TimeManager.clock_text(), GameManager.money, WeatherManager.name_text()]
	# В ту же строку — кольца сытости, бодрости и воды, за ними запас еды
	var tw := _top.get_combined_minimum_size().x
	_needs.position = Vector2(16.0 + tw + 14.0, 6.0)
	_needs.queue_redraw()
	_snacks.position = Vector2(_needs.position.x + (RINGS.size() - 1) * (RING_R * 2.0 + 30.0) + RING_R * 2.0 + 18.0, 14.0)
	# Трекер: развоз (если идёт), сюжетное задание и просьбы жителей
	var lines: Array[String] = []
	if GameManager.challenge_line != "":
		lines.append("» " + GameManager.challenge_line)
	if Progress.delivery_active:
		lines.append(Progress.goal_text())
	lines.append_array(QuestManager.tracker_lines())
	var daily := Daily.tracker_line()
	if daily != "":
		lines.append(daily)
	_goal.text = GameManager.touch_text("\n".join(lines))
	var vw := get_viewport().get_visible_rect().size.x
	# Справа — кнопки (телефон) и мини-карта: строки заданий их не заходят
	var right := 140.0 if GameManager.touch_mode else 270.0
	if SettingsManager.minimap and GameManager.touch_mode:
		right = 240.0
	_goal.size.x = vw - right
	_goal.size.y = 0.0
	_update_money_pop(delta)
	# Подсказка по клавишам на телефоне не нужна — там кнопки
	_keys_hint.visible = not GameManager.touch_mode
	_snacks.text = "Еды: %d" % NeedsManager.snacks if GameManager.touch_mode else "Еды: %d (Q)" % NeedsManager.snacks
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
		# Скорость, обороты, передачу и бензин показывает спидометр
		_car.text = "%s   %s\n%s   Бензин: %d л   Состояние: %d%%   %s%s" % [
			box, motor,
			car.spec.title, int(ceilf(car.fuel)), int(car.condition),
			"T — коробка, V — вид", slide]
		_car.text = GameManager.touch_text(_car.text)
		# Слева внизу на телефоне — руль: приборы держим наверху, сразу под трекером
		if GameManager.touch_mode:
			if _car.anchor_top != 0.0:
				_car.anchor_top = 0.0
				_car.anchor_bottom = 0.0
				_car.add_theme_font_size_override("font_size", 16)
			var below := _goal.position.y + _goal.get_combined_minimum_size().y + 6.0
			_car.offset_top = below
			_car.offset_bottom = below
		_prompt.text = ""
	else:
		_car.visible = false
		_prompt.text = p.current_prompt() if p else ""
	# На телефоне приборы машины стоят под трекером — сообщения опускаем ниже них
	var msg_y := 150.0
	if GameManager.touch_mode and car and car.driver:
		msg_y = _car.offset_top + 50.0
	_msg.offset_top = maxf(msg_y, _goal.position.y + _goal.get_combined_minimum_size().y + 8.0)
	if not _queue.is_empty() and _msg_time <= MSG_TIME - MSG_MIN:
		_msg.text = _queue.pop_front()
		_msg_time = MSG_TIME
	if _msg_time > 0.0:
		_msg_time -= delta
		_msg.modulate.a = clampf(_msg_time, 0.0, 1.0)
	else:
		_msg.text = ""


## Три кольца: доля заполнения дугой, процент в середине, подпись справа
## мелко. Меньше 20% — кольцо краснеет.
func _draw_needs() -> void:
	var font := ThemeDB.fallback_font
	var vals := [NeedsManager.food, NeedsManager.energy, NeedsManager.water]
	var step := RING_R * 2.0 + 30.0
	for i in RINGS.size():
		var c := Vector2(RING_R + 2.0 + i * step, RING_R + 2.0)
		var v: float = clampf(vals[i], 0.0, 100.0)
		var col: Color = RINGS[i][1]
		if v < 20.0:
			col = Color(0.95, 0.3, 0.25)
		_needs.draw_circle(c, RING_R, Color(0, 0, 0, 0.45))
		_needs.draw_arc(c, RING_R - 3.0, 0.0, TAU, 32, Color(1, 1, 1, 0.15), 4.0, true)
		if v > 0.5:
			_needs.draw_arc(c, RING_R - 3.0, -PI * 0.5, -PI * 0.5 + TAU * v / 100.0, 32, col, 4.0, true)
		var t := str(int(v))
		var fs := 11
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_needs.draw_string_outline(font, c + Vector2(-w * 0.5, 4.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.8))
		_needs.draw_string(font, c + Vector2(-w * 0.5, 4.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		var cap: String = SettingsManager.t(RINGS[i][0])
		var cw := font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		_needs.draw_string_outline(font, c + Vector2(-cw * 0.5, RING_R + 11.0), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0, 0, 0, 0.8))
		_needs.draw_string(font, c + Vector2(-cw * 0.5, RING_R + 11.0), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.85))


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
