extends CanvasLayer
## Сенсорное управление для телефонов (Android и браузер на телефоне).
##
## Пешком экран делится пополам: левая половина — ходьба (плавающий
## джойстик появляется там, куда поставил палец, у края — бег), правая —
## камера (веди пальцем — смотришь по сторонам). Кнопки справа внизу —
## действие, прыжок, присесть, еда, вид (со спины / из глаз). Первые секунды
## игры на экране подписаны обе половины. Под левую руку — наоборот.
## В машине — как в Car Parking: слева настоящий руль, его крутят пальцем
## (отпустил — сам возвращается), в центре руля сигнал. Справа педали газа
## и тормоза, рычаг D/R — вперёд или назад, ручник, выход и вид — всё можно
## жать одновременно разными пальцами. Сверху справа всегда меню, карта, журнал.
##
## Кнопки и джойстик не управляют игрой напрямую: они «нажимают» те же
## клавиши, что и клавиатура (Input.parse_input_event), поэтому вся
## остальная игра о телефоне ничего не знает. Камеру крутим через Player._look.

const STICK_R := 95.0
const LOOK_SENS := 0.0045
const WHEEL_R := 112.0
const HUB_R := 34.0
## Руль поворачивается на 200° в каждую сторону — как в машине, не рывком
const WHEEL_MAX := deg_to_rad(200.0)
## Отпустил руль — возвращается к центру (радиан в секунду)
const WHEEL_RETURN := 7.0

var _stick_center := Vector2.ZERO
var _stick_index := -1
var _stick_vec := Vector2.ZERO
var _look_index := -1
var _held := {}  # physical keycode → зажата ли джойстиком
var _buttons: Array[Dictionary] = []  # {"node": TouchScreenButton, "key": ..., "mode": ..., "rect": Rect2, ...}
var _base: Control
var _knob: Control
var _was_driving := false
var _wheel: Control
var _wheel_center := Vector2.ZERO
var _wheel_index := -1
var _wheel_last := 0.0
var _wheel_rot := 0.0
var _horn_index := -1
## Подсказка «ходить | камера» в начале игры: сколько секунд ещё видна
const SPLIT_HINT_S := 10.0
var _split_hint: Control
var _split_left := SPLIT_HINT_S


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_base = _circle_control(STICK_R, Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.35))
	root.add_child(_base)
	_knob = _circle_control(40.0, Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.6))
	root.add_child(_knob)
	_wheel = Control.new()
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.size = Vector2(WHEEL_R, WHEEL_R) * 2.0
	_wheel.draw.connect(_draw_wheel)
	root.add_child(_wheel)
	_split_hint = Control.new()
	_split_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_split_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_split_hint.draw.connect(_draw_split_hint)
	root.add_child(_split_hint)
	# Кнопки: подпись, клавиша, когда видна (walk / drive / all), угол экрана, место, радиус
	_add_button("E", KEY_E, "walk", "br", Vector2(-110, -120), 52)
	_add_button("Прыжок", KEY_SPACE, "walk", "br", Vector2(-230, -70), 44)
	_add_button("Присесть", KEY_C, "walk", "br", Vector2(-120, -250), 40)
	_add_button("Еда", KEY_Q, "walk", "br", Vector2(-240, -190), 36)
	# Вверху справа, над мини-картой: внизу место занято обучением и кнопками
	_add_button("Вид", KEY_V, "walk", "tr", Vector2(-200, 48), 28)
	# Педали — прямоугольные, как в машине: газ узкий и высокий, тормоз шире
	_add_button("Газ", KEY_W, "drive", "br", Vector2(-72, -118), 0, Vector2(76, 160))
	_add_button("Тормоз", KEY_S, "drive", "br", Vector2(-190, -92), 0, Vector2(120, 108))
	_add_button("D", -1, "drive", "br", Vector2(-298, -98), 0, Vector2(62, 104))
	_add_button("Ручник", KEY_SPACE, "drive", "br", Vector2(-298, -222), 38)
	_add_button("Вид", KEY_V, "drive", "br", Vector2(-190, -222), 34)
	_add_button("Выйти", KEY_E, "drive", "br", Vector2(-72, -262), 38)
	_add_button("Радио", KEY_B, "drive", "br", Vector2(-298, -318), 32)
	_add_button("Меню", KEY_ESCAPE, "all", "tr", Vector2(-50, 130), 30)
	_add_button("Карта", KEY_M, "all", "tr", Vector2(-50, 205), 30)
	_add_button("Журнал", KEY_J, "all", "tr", Vector2(-50, 280), 30)
	get_viewport().size_changed.connect(_layout)
	SettingsManager.changed.connect(_layout)
	_layout()
	_apply_mode()


func _circle_control(r: float, fill: Color, rim: Color) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(r, r) * 2.0
	c.draw.connect(func() -> void:
		c.draw_circle(Vector2(r, r), r, fill)
		c.draw_arc(Vector2(r, r), r - 1.5, 0.0, TAU, 48, rim, 3.0))
	return c


## Кнопка: круглая радиусом r или прямоугольная размером box (педаль, рычаг).
## key −1 — не клавиша, а рычаг D/R.
func _add_button(text: String, key: int, mode: String, anchor: String, offset: Vector2, r: float, box := Vector2.ZERO) -> void:
	var b := TouchScreenButton.new()
	var half := box * 0.5 if box != Vector2.ZERO else Vector2(r, r)
	if box != Vector2.ZERO:
		var grooves := text == "Газ" or text == "Тормоз"
		b.texture_normal = _pedal_texture(box, Color(0.12, 0.12, 0.13, 0.6), grooves)
		b.texture_pressed = _pedal_texture(box, Color(0.95, 0.7, 0.25, 0.75), grooves)
		var rect := RectangleShape2D.new()
		rect.size = box
		b.shape = rect
	else:
		b.texture_normal = _disc_texture(int(r), Color(0.1, 0.1, 0.1, 0.45))
		b.texture_pressed = _disc_texture(int(r), Color(0.95, 0.7, 0.25, 0.7))
		var shape := CircleShape2D.new()
		shape.radius = r
		b.shape = shape
	b.shape_centered = true
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = half * 2.0
	label.add_theme_font_size_override("font_size", 34 if text.length() == 1 else (22 if text.length() <= 3 else 15))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	b.add_child(label)
	add_child(b)
	var entry := {"node": b, "label": label, "text": text, "key": key, "mode": mode, "anchor": anchor, "offset": offset, "half": half, "down": false}
	b.pressed.connect(func() -> void:
		if entry.key < 0:
			_toggle_reverse()
			return
		entry.down = true
		_key(entry.key, true))
	b.released.connect(func() -> void:
		if entry.down:
			entry.down = false
			_key(entry.key, false))
	_buttons.append(entry)


## Рычаг: D — вперёд, R — назад. Переключается сразу, а поедет в другую
## сторону, когда машина остановится (газ до этого тормозит).
func _toggle_reverse() -> void:
	GameManager.pedal_reverse = not GameManager.pedal_reverse
	SoundLibrary.play("click", -6.0)
	_update_lever()


func _update_lever() -> void:
	for e in _buttons:
		if e.key < 0:
			var l := e.label as Label
			l.text = "R" if GameManager.pedal_reverse else "D"
			l.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if GameManager.pedal_reverse else Color(0.6, 1.0, 0.6))


func _pedal_texture(box: Vector2, color: Color, grooves: bool) -> ImageTexture:
	var w := int(box.x)
	var h := int(box.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rad := 12.0
	for y in h:
		for x in w:
			# Скруглённые углы
			var cx := clampf(x + 0.5, rad, w - rad)
			var cy := clampf(y + 0.5, rad, h - rad)
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d > rad:
				continue
			var edge := d > rad - 3.0 or x < 3 or y < 3 or x >= w - 3 or y >= h - 3
			var c := color
			# Рифлёная резина, как на настоящей педали
			if grooves and not edge and x > 10 and x < w - 10 and (y % 18) < 5 and y > 10 and y < h - 10:
				c = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, color.a + 0.1)
			img.set_pixel(x, y, Color(1, 1, 1, 0.55) if edge else c)
	return ImageTexture.create_from_image(img)


func _draw_wheel() -> void:
	var c := Vector2(WHEEL_R, WHEEL_R)
	var rim := Color(0.08, 0.08, 0.09, 0.8)
	var held := _wheel_index >= 0
	# Обод
	_wheel.draw_arc(c, WHEEL_R - 13.0, 0.0, TAU, 64, rim, 24.0, true)
	_wheel.draw_arc(c, WHEEL_R - 1.5, 0.0, TAU, 64, Color(1, 1, 1, 0.45), 2.5, true)
	_wheel.draw_arc(c, WHEEL_R - 25.5, 0.0, TAU, 64, Color(1, 1, 1, 0.25), 2.0, true)
	# Три спицы, повернутые вместе с рулём
	for a in [0.0, PI, PI * 0.5]:
		var dir := Vector2.RIGHT.rotated(a + _wheel_rot)
		_wheel.draw_line(c + dir * HUB_R, c + dir * (WHEEL_R - 20.0), rim, 16.0, true)
	# Метка верха руля — видно, насколько повёрнут
	var top := Vector2.UP.rotated(_wheel_rot)
	_wheel.draw_line(c + top * (WHEEL_R - 24.0), c + top * (WHEEL_R - 2.0), Color(0.95, 0.7, 0.25, 0.95 if held else 0.7), 8.0, true)
	# Ступица — сигнал
	var horn := _horn_index >= 0
	_wheel.draw_circle(c, HUB_R, Color(0.95, 0.7, 0.25, 0.75) if horn else Color(0.15, 0.15, 0.16, 0.85))
	_wheel.draw_arc(c, HUB_R - 1.5, 0.0, TAU, 40, Color(1, 1, 1, 0.5), 2.5, true)
	var font := ThemeDB.fallback_font
	var txt := "Бип"
	var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	_wheel.draw_string_outline(font, c + Vector2(-ts.x * 0.5, 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
	_wheel.draw_string(font, c + Vector2(-ts.x * 0.5, 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _disc_texture(r: int, color: Color) -> ImageTexture:
	var d := r * 2
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	for y in d:
		for x in d:
			var dist := Vector2(x - r + 0.5, y - r + 0.5).length()
			if dist <= r:
				var rim := dist > r - 3.0
				img.set_pixel(x, y, Color(1, 1, 1, 0.55) if rim else color)
	return ImageTexture.create_from_image(img)


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	# Под левую руку всё нижнее зеркально: джойстик и руль справа
	var lefty := SettingsManager.left_hand
	_stick_center = Vector2(STICK_R + 50.0, size.y - STICK_R - 50.0)
	_wheel_center = Vector2(WHEEL_R + 34.0, size.y - WHEEL_R - 30.0)
	if lefty:
		_stick_center.x = size.x - _stick_center.x
		_wheel_center.x = size.x - _wheel_center.x
	_base.position = _stick_center - Vector2(STICK_R, STICK_R)
	_base.modulate.a = 0.55
	_set_knob(Vector2.ZERO)
	_wheel.position = _wheel_center - Vector2(WHEEL_R, WHEEL_R)
	for e in _buttons:
		var half: Vector2 = e.half
		var base := Vector2(size.x, 0.0)
		var off: Vector2 = e.offset
		var anchor: String = e.anchor
		if lefty and anchor != "tr":
			anchor = "bl" if anchor == "br" else "br"
			off.x = -off.x
		match anchor:
			"br":
				base = size
			"bl":
				base = Vector2(0.0, size.y)
		var center: Vector2 = base + off
		(e.node as TouchScreenButton).position = center - half
		e["rect"] = Rect2(center - half, half * 2.0)


## Где кончается половина для ходьбы (по X): ровно середина экрана.
func split_x() -> float:
	return get_viewport().get_visible_rect().size.x * 0.5


## На левой ли (для ходьбы) половине касание — с учётом левой руки.
func walk_side(pos: Vector2) -> bool:
	return pos.x > split_x() if SettingsManager.left_hand else pos.x < split_x()


## Подсказка: тонкая черта посередине и подписи половин внизу.
func _draw_split_hint() -> void:
	var a := clampf(_split_left / 2.0, 0.0, 1.0)
	if a <= 0.0:
		return
	var vs := _split_hint.get_viewport_rect().size
	var x := split_x()
	var y := 110.0
	while y < vs.y - 30.0:
		_split_hint.draw_line(Vector2(x, y), Vector2(x, y + 14.0), Color(1, 1, 1, 0.35 * a), 2.0)
		y += 26.0
	var font := ThemeDB.fallback_font
	var walk := "ХОДИТЬ — веди пальцем"
	var look := "КАМЕРА — веди пальцем"
	var lx := x * 0.5 if not SettingsManager.left_hand else x * 1.5
	var rx := x * 1.5 if not SettingsManager.left_hand else x * 0.5
	for t in [[walk, lx], [look, rx]]:
		var w := font.get_string_size(t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var at := Vector2(float(t[1]) - w * 0.5, vs.y * 0.42)
		_split_hint.draw_string_outline(font, at, t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.6 * a))
		_split_hint.draw_string(font, at, t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.9 * a))


func _driving() -> bool:
	return GameManager.vehicle != null


## Пешком — джойстик и свои кнопки, в машине — руль и педали.
func _apply_mode() -> void:
	var drive := _driving()
	for e in _buttons:
		var on: bool = e.mode == "all" or (e.mode == "drive") == drive
		# Рычаг D/R — только с автоматом, на механике передачи свои
		if e.key < 0:
			on = on and SettingsManager.auto_gearbox
		(e.node as TouchScreenButton).visible = on
	_base.visible = not drive
	_knob.visible = not drive
	_wheel.visible = drive
	_split_hint.visible = not drive
	# Сели в машину — рычаг на D
	GameManager.pedal_reverse = false
	_update_lever()


func button(text: String) -> TouchScreenButton:
	for e in _buttons:
		if e.text == text:
			return e.node
	return null


func _process(delta: float) -> void:
	# Сели в машину или вышли — меняем набор кнопок. Всё зажатое
	# отпускаем, иначе «Газ» останется нажатым уже пешком
	var drive := _driving()
	if drive != _was_driving:
		_was_driving = drive
		_release_all()
		_apply_mode()
	# Меню или журнал открыты — управление скрываем, чтобы не мешало нажимать,
	# и отпускаем всё зажатое: иначе после паузы персонаж пойдёт сам
	var show := not get_tree().paused
	if visible and not show:
		_release_all()
	visible = show
	GameManager.pedal_mode = drive and show
	if _split_left > 0.0 and show and not drive:
		_split_left -= delta
		_split_hint.queue_redraw()
	if drive:
		var lever := button("D")
		if lever and lever.visible != SettingsManager.auto_gearbox:
			_apply_mode()
		# Отпустил руль — плавно возвращается к центру
		if _wheel_index < 0 and _wheel_rot != 0.0:
			_wheel_rot = move_toward(_wheel_rot, 0.0, delta * WHEEL_RETURN)
			GameManager.steer_axis = -_wheel_rot / WHEEL_MAX
			_wheel.queue_redraw()


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			if _over_button(touch.position):
				return
			# В машине: палец на руле крутит его, в центре — сигнал
			if _driving():
				var d := touch.position.distance_to(_wheel_center)
				if d < HUB_R and _horn_index < 0:
					_horn_index = touch.index
					_hold(KEY_H, true)
					_wheel.queue_redraw()
				elif d < WHEEL_R + 40.0 and _wheel_index < 0:
					_wheel_index = touch.index
					_wheel_last = (touch.position - _wheel_center).angle()
					_wheel.queue_redraw()
				return
			# Левая половина — ходьба, правая — камера (под левую руку наоборот)
			if walk_side(touch.position) and _stick_index < 0:
				_stick_index = touch.index
				# Плавающий джойстик: центр там, где коснулся пальцем, но не
				# за серединой экрана — там уже половина камеры
				var vs := get_viewport().get_visible_rect().size
				var m := STICK_R + 12.0
				var x0 := split_x() + m if SettingsManager.left_hand else m
				var x1 := vs.x - m if SettingsManager.left_hand else split_x() - m
				_stick_center = Vector2(clampf(touch.position.x, x0, maxf(x0, x1)), clampf(touch.position.y, m + 80.0, vs.y - m))
				_base.position = _stick_center - Vector2(STICK_R, STICK_R)
				_base.modulate.a = 1.0
				_update_stick(touch.position)
			elif not walk_side(touch.position) and _look_index < 0:
				_look_index = touch.index
		else:
			if touch.index == _wheel_index:
				_wheel_index = -1
				_wheel.queue_redraw()
			elif touch.index == _horn_index:
				_horn_index = -1
				_hold(KEY_H, false)
				_wheel.queue_redraw()
			elif touch.index == _stick_index:
				_stick_index = -1
				_update_stick(_stick_center)
				# Отпустил — джойстик возвращается на место и бледнеет
				_layout()
			elif touch.index == _look_index:
				_look_index = -1
		return
	var drag := event as InputEventScreenDrag
	if drag:
		if drag.index == _wheel_index:
			_turn_wheel(drag.position)
		elif drag.index == _stick_index:
			_update_stick(drag.position)
		elif drag.index == _look_index:
			var p := GameManager.player as Player
			if p and not _driving():
				p._look(-drag.relative.x * LOOK_SENS * SettingsManager.mouse_sens, -drag.relative.y * LOOK_SENS * SettingsManager.mouse_sens)


## Руль крутится за пальцем: поворот — на сколько палец обошёл центр руля.
func _turn_wheel(pos: Vector2) -> void:
	var off := pos - _wheel_center
	# У самого центра угол скачет — там не крутим
	if off.length() < 18.0:
		return
	var a := off.angle()
	_wheel_rot = clampf(_wheel_rot + wrapf(a - _wheel_last, -PI, PI), -WHEEL_MAX, WHEEL_MAX)
	_wheel_last = a
	# По часовой стрелке — направо
	GameManager.steer_axis = -_wheel_rot / WHEEL_MAX
	_wheel.queue_redraw()


func _release_all() -> void:
	GameManager.move_axis = Vector2.ZERO
	GameManager.steer_axis = 0.0
	_wheel_index = -1
	_horn_index = -1
	_wheel_rot = 0.0
	if _wheel:
		_wheel.queue_redraw()
	_stick_index = -1
	_look_index = -1
	_set_knob(Vector2.ZERO)
	for k in _held:
		if _held[k]:
			_key(k, false)
	_held.clear()
	for e in _buttons:
		if e.down:
			_key(e.key, false)
			e.down = false


func _over_button(pos: Vector2) -> bool:
	for e in _buttons:
		if (e.node as TouchScreenButton).visible and (e.rect as Rect2).grow(6.0).has_point(pos):
			return true
	return false


## Джойстик → плавное движение (GameManager.move_axis), у самого края — бег.
func _update_stick(pos: Vector2) -> void:
	var v := (pos - _stick_center) / STICK_R
	if v.length() > 1.0:
		v = v.normalized()
	_stick_vec = v
	_set_knob(v)
	# Мёртвая зона в центре, дальше скорость растёт от нуля до полной
	var dead := 0.15
	var mag := v.length()
	GameManager.move_axis = Vector2.ZERO if mag < dead else v / mag * minf((mag - dead) / (0.85 - dead), 1.0)
	_hold(KEY_SHIFT, not _driving() and mag > 0.92)


func _set_knob(v: Vector2) -> void:
	_knob.position = _stick_center + v * STICK_R - Vector2(40, 40)


func _hold(key: int, down: bool) -> void:
	if bool(_held.get(key, false)) == down:
		return
	_held[key] = down
	_key(key, down)


func _key(key: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = key
	e.keycode = key
	e.pressed = down
	Input.parse_input_event(e)
