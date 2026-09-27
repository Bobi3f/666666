extends CanvasLayer
## Сенсорное управление для телефонов (Android и браузер на телефоне).
##
## Пешком: слева джойстик (у края — бег), справа палец по экрану
## поворачивает камеру, кнопки справа внизу — действие, прыжок, присесть, еда.
## В машине джойстик прячется: слева руль — «Влево» и «Вправо», справа
## педали «Газ» и «Тормоз», рядом ручник, выход, вид и сигнал — всё можно
## жать одновременно разными пальцами. Сверху справа всегда меню, карта, журнал.
##
## Кнопки и джойстик не управляют игрой напрямую: они «нажимают» те же
## клавиши, что и клавиатура (Input.parse_input_event), поэтому вся
## остальная игра о телефоне ничего не знает. Камеру крутим через Player._look.

const STICK_R := 95.0
const LOOK_SENS := 0.0045

var _stick_center := Vector2.ZERO
var _stick_index := -1
var _stick_vec := Vector2.ZERO
var _look_index := -1
var _held := {}  # physical keycode → зажата ли джойстиком
var _buttons: Array[Dictionary] = []  # {"node": TouchScreenButton, "key": ..., "mode": ..., "rect": Rect2, ...}
var _base: Control
var _knob: Control
var _was_driving := false


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
	# Кнопки: подпись, клавиша, когда видна (walk / drive / all), угол экрана, место, радиус
	_add_button("E", KEY_E, "walk", "br", Vector2(-110, -120), 52)
	_add_button("Прыжок", KEY_SPACE, "walk", "br", Vector2(-230, -70), 44)
	_add_button("Присесть", KEY_C, "walk", "br", Vector2(-120, -250), 40)
	_add_button("Еда", KEY_Q, "walk", "br", Vector2(-240, -190), 36)
	_add_button("Газ", KEY_W, "drive", "br", Vector2(-100, -110), 62)
	_add_button("Тормоз", KEY_S, "drive", "br", Vector2(-245, -85), 50)
	_add_button("Ручник", KEY_SPACE, "drive", "br", Vector2(-250, -215), 38)
	_add_button("Выйти", KEY_E, "drive", "br", Vector2(-120, -255), 36)
	_add_button("Вид", KEY_V, "drive", "br", Vector2(-360, -60), 32)
	_add_button("Сигнал", KEY_H, "drive", "br", Vector2(-365, -150), 32)
	_add_button("Влево", KEY_A, "drive", "bl", Vector2(90, -100), 62)
	_add_button("Вправо", KEY_D, "drive", "bl", Vector2(240, -100), 62)
	_add_button("Меню", KEY_ESCAPE, "all", "tr", Vector2(-50, 130), 30)
	_add_button("Карта", KEY_M, "all", "tr", Vector2(-50, 205), 30)
	_add_button("Журнал", KEY_J, "all", "tr", Vector2(-50, 280), 30)
	get_viewport().size_changed.connect(_layout)
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


func _add_button(text: String, key: int, mode: String, anchor: String, offset: Vector2, r: float) -> void:
	var b := TouchScreenButton.new()
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
	label.size = Vector2(r, r) * 2.0
	label.add_theme_font_size_override("font_size", 22 if text.length() <= 3 else 15)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	b.add_child(label)
	add_child(b)
	var entry := {"node": b, "text": text, "key": key, "mode": mode, "anchor": anchor, "offset": offset, "r": r, "down": false}
	b.pressed.connect(func() -> void:
		entry.down = true
		_key(entry.key, true))
	b.released.connect(func() -> void:
		if entry.down:
			entry.down = false
			_key(entry.key, false))
	_buttons.append(entry)


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
	_stick_center = Vector2(STICK_R + 50.0, size.y - STICK_R - 50.0)
	_base.position = _stick_center - Vector2(STICK_R, STICK_R)
	_set_knob(Vector2.ZERO)
	for e in _buttons:
		var r: float = e.r
		var base := Vector2(size.x, 0.0)
		match e.anchor:
			"br":
				base = size
			"bl":
				base = Vector2(0.0, size.y)
		var center: Vector2 = base + (e.offset as Vector2)
		(e.node as TouchScreenButton).position = center - Vector2(r, r)
		e["rect"] = Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)


func _driving() -> bool:
	return GameManager.vehicle != null


## Пешком — джойстик и свои кнопки, в машине — руль и педали.
func _apply_mode() -> void:
	var drive := _driving()
	for e in _buttons:
		(e.node as TouchScreenButton).visible = e.mode == "all" or (e.mode == "drive") == drive
	_base.visible = not drive
	_knob.visible = not drive


func button(text: String) -> TouchScreenButton:
	for e in _buttons:
		if e.text == text:
			return e.node
	return null


func _process(_delta: float) -> void:
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


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			# В машине экран вне кнопок ничего не делает: там только руль и педали
			if _over_button(touch.position) or _driving():
				return
			if touch.position.x < get_viewport().get_visible_rect().size.x * 0.4 and _stick_index < 0:
				_stick_index = touch.index
				_update_stick(touch.position)
			elif _look_index < 0:
				_look_index = touch.index
		else:
			if touch.index == _stick_index:
				_stick_index = -1
				_update_stick(_stick_center)
			elif touch.index == _look_index:
				_look_index = -1
		return
	var drag := event as InputEventScreenDrag
	if drag:
		if drag.index == _stick_index:
			_update_stick(drag.position)
		elif drag.index == _look_index:
			var p := GameManager.player as Player
			if p and not _driving():
				p._look(-drag.relative.x * LOOK_SENS * SettingsManager.mouse_sens, -drag.relative.y * LOOK_SENS * SettingsManager.mouse_sens)


func _release_all() -> void:
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


## Джойстик → клавиши W A S D (и бег у края).
func _update_stick(pos: Vector2) -> void:
	var v := (pos - _stick_center) / STICK_R
	if v.length() > 1.0:
		v = v.normalized()
	_stick_vec = v
	_set_knob(v)
	var dead := 0.3
	_hold(KEY_W, v.y < -dead)
	_hold(KEY_S, v.y > dead)
	_hold(KEY_A, v.x < -dead)
	_hold(KEY_D, v.x > dead)
	_hold(KEY_SHIFT, not _driving() and v.length() > 0.92)


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
