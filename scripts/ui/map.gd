extends CanvasLayer
## Карта по M: дороги, лес, поля, село, город и важные места.
## Стрелка — игрок, квадрат — машина. Во время развоза горит сельмаг.
##
## Места берутся из констант world.gd, чтобы карта не расходилась с миром.

const SIZE := 560.0
const WORLD := 400.0

var _canvas: Control
var _world: Node


func _ready() -> void:
	layer = 30
	_world = get_parent()
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_CENTER)
	_canvas.custom_minimum_size = Vector2(SIZE, SIZE)
	_canvas.size = Vector2(SIZE, SIZE)
	_canvas.position = -Vector2(SIZE, SIZE) * 0.5
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	_canvas.visible = false
	add_child(_canvas)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_M:
		_canvas.visible = not _canvas.visible


func _process(_delta: float) -> void:
	if _canvas.visible:
		_canvas.queue_redraw()


## Мировые X/Z → точка на карте (север, -Z, — вверху).
func _p(x: float, z: float) -> Vector2:
	return Vector2((x + WORLD * 0.5) / WORLD * SIZE, (z + WORLD * 0.5) / WORLD * SIZE)


func _rect(x0: float, z0: float, x1: float, z1: float, c: Color) -> void:
	var a := _p(x0, z0)
	var b := _p(x1, z1)
	_canvas.draw_rect(Rect2(a, b - a), c)


func _draw_map() -> void:
	var font := ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(Vector2(-8, -8), Vector2(SIZE + 16, SIZE + 16)), Color(0, 0, 0, 0.75))
	_rect(-200, -200, 200, 200, Color(0.36, 0.5, 0.26))
	# Лес и поля
	_rect(-200, -195, -20, -80, Color(0.18, 0.33, 0.18))
	_rect(-200, 22, -50, 195, Color(0.18, 0.33, 0.18))
	_rect(25, -185, 100, -110, Color(0.75, 0.66, 0.35))
	_rect(110, -185, 190, -110, Color(0.4, 0.58, 0.25))
	_rect(25, -100, 190, -30, Color(0.45, 0.34, 0.24))
	# Дороги
	var road := Color(0.3, 0.3, 0.32)
	var dirt := Color(0.62, 0.52, 0.37)
	_rect(-200, -4, 200, 4, road)
	_rect(-165, -42.5, -57, -37.5, dirt)
	_rect(-62, -42.5, -57, -5.5, dirt)
	_rect(94, 4, 100, 100, road)
	_rect(40, 55, 190, 61, road)
	# Пруд
	var pond: Vector3 = _world.POND_POS
	_canvas.draw_circle(_p(pond.x, pond.z), 10.0 / WORLD * SIZE * 1.1, Color(0.25, 0.45, 0.6))
	# Дома села
	for x in _world.VILLAGE_X:
		for z in [_world.ROW_A_Z, _world.ROW_B_Z]:
			var own: bool = Vector2(x, z) == _world.PLAYER_HOUSE
			_rect(x - 4.5, z - 3.5, x + 4.5, z + 3.5, Color(1.0, 0.85, 0.3) if own else Color(0.75, 0.5, 0.4))
	# Город: пятиэтажки и склад
	for c in [Vector2(70, 41), Vector2(125, 41), Vector2(70, 74), Vector2(125, 74)]:
		_rect(c.x - 21, c.y - 6, c.x + 21, c.y + 6, Color(0.7, 0.7, 0.68))
	_rect(165, 54, 177, 96, Color(0.7, 0.7, 0.68))
	_rect(15.5, 30, 39.5, 44, Color(0.6, 0.58, 0.5))

	var shop: Vector3 = _world.SHOP_POS
	var places := [
		["Дом", Vector3(_world.PLAYER_HOUSE.x, 0, _world.PLAYER_HOUSE.y), Color(1.0, 0.85, 0.3)],
		["Сельмаг", shop, Color(0.95, 0.35, 0.3)],
		["Колхоз", _world.BARN_POS, Color(0.9, 0.8, 0.5)],
		["АЗС", _world.FUEL_POS, Color(0.4, 0.85, 0.5)],
		["СТО", _world.GARAGE_POS, Color(0.5, 0.65, 1.0)],
		["Автобус", _world.STOP_VILLAGE, Color(1.0, 0.9, 0.3)],
		["Автобус", _world.STOP_TOWN, Color(1.0, 0.9, 0.3)],
		["Склад", Vector3(27.5, 0, 37), Color(0.9, 0.9, 0.9)],
		["Ларёк", Vector3(25, 0, 9), Color(0.5, 0.7, 1.0)],
		["Пруд", pond, Color(0.6, 0.85, 1.0)],
	]
	var blink := fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0
	for pl in places:
		var v: Vector3 = pl[1]
		var at := _p(v.x, v.z)
		var r := 5.0
		if pl[0] == "Сельмаг" and Progress.delivery_active and blink:
			r = 9.0
		_canvas.draw_circle(at, r, pl[2])
		# Подписи соседних мест разводим: ларёк — слева, АЗС — сверху
		var off := Vector2(8, 5)
		if pl[0] == "Ларёк":
			off = Vector2(-48, 5)
		elif pl[0] == "АЗС":
			off = Vector2(-14, -9)
		_canvas.draw_string(font, at + off, pl[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	# Машина, мотоцикл и игрок
	for pair in [[GameManager.car, Color(0.85, 0.8, 0.55), 4.0], [GameManager.moto, Color(0.85, 0.2, 0.15), 3.0]]:
		var v := pair[0] as Node3D
		if v:
			var cp := _p(v.global_position.x, v.global_position.z)
			var r: float = pair[2]
			_canvas.draw_rect(Rect2(cp - Vector2(r, r), Vector2(r, r) * 2.0), pair[1])
	var who := GameManager.player as Node3D
	var yaw := 0.0
	var pos := Vector3.ZERO
	var car := GameManager.vehicle as Node3D
	if car:
		pos = car.global_position
		yaw = car.rotation.y
	elif who:
		pos = who.global_position
		yaw = who.rotation.y
	var at := _p(pos.x, pos.z)
	# Вперёд — это -Z мира, на карте — вверх; поворот yaw против часовой
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(fwd.y, -fwd.x)
	_canvas.draw_colored_polygon(PackedVector2Array([at + fwd * 11.0, at - fwd * 6.0 + side * 6.0, at - fwd * 6.0 - side * 6.0]), Color(1, 0.2, 0.2))
	_canvas.draw_string(font, Vector2(8, SIZE - 10), "M — закрыть карту", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
