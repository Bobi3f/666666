extends CanvasLayer
## Карта по M: дороги, лес, поля, село, город и важные места.
## Стрелка — игрок, квадрат — машина. Во время развоза горит сельмаг.
##
## Места берутся из констант world.gd, чтобы карта не расходилась с миром.
##
## Мини-карта в углу экрана: та же карта один раз рисуется в текстуру
## покрупнее, а в углу показывается кусок вокруг игрока — почти даром.

const SIZE := 560.0
const WORLD := 400.0

var _canvas: Control
var _world: Node
## Куда сейчас рисуем и в каком размере: большая карта или текстура мини-карты
var _t: Control
var _size := SIZE
## Мини-карта: сколько метров видно по стороне и размер текстуры карты
const MINI_M := 160.0
const TEX := 1400.0
var _mini: Control
var _tex_vp: SubViewport


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
	_build_minimap.call_deferred()


func _build_minimap() -> void:
	# Текстура: вся карта без подписей, рисуется один раз
	_tex_vp = SubViewport.new()
	_tex_vp.size = Vector2i(int(TEX), int(TEX))
	_tex_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_tex_vp.disable_3d = true
	var painter := Control.new()
	painter.size = Vector2(TEX, TEX)
	painter.draw.connect(func() -> void:
		_t = painter
		_size = TEX
		_draw_static(false)
		_t = _canvas
		_size = SIZE)
	_tex_vp.add_child(painter)
	add_child(_tex_vp)
	_mini = Control.new()
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini.draw.connect(_draw_mini)
	add_child(_mini)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_M:
		_canvas.visible = not _canvas.visible
		if _canvas.visible:
			QuestManager.event("map")


func _process(_delta: float) -> void:
	if _canvas.visible:
		_canvas.queue_redraw()
	if _mini:
		var show := SettingsManager.minimap and not _canvas.visible and not get_tree().paused and GameManager.in_game
		_mini.visible = show
		if show:
			var vs := _mini.get_viewport_rect().size
			var side := 118.0 if GameManager.touch_mode else 160.0
			_mini.size = Vector2(side, side)
			# На телефоне справа сверху — столбик кнопок: встаём левее него
			_mini.position = Vector2(vs.x - side - (100.0 if GameManager.touch_mode else 16.0), 92.0 if GameManager.touch_mode else 84.0)
			_mini.queue_redraw()


## Мини-карта: кусок большой карты вокруг игрока, север сверху, игрок — стрелка.
func _draw_mini() -> void:
	var side := _mini.size.x
	var pos := _player_pos()
	var k := TEX / WORLD
	var half := MINI_M * 0.5 * k
	var c := Vector2((pos.x + WORLD * 0.5) * k, (pos.z + WORLD * 0.5) * k)
	c = c.clamp(Vector2(half, half), Vector2(TEX - half, TEX - half))
	var src := Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0)
	_mini.draw_rect(Rect2(Vector2(-3, -3), Vector2(side + 6, side + 6)), Color(0, 0, 0, 0.6))
	_mini.draw_texture_rect_region(_tex_vp.get_texture(), Rect2(Vector2.ZERO, Vector2(side, side)), src, Color(1, 1, 1, 0.9))
	var to_mini := func(x: float, z: float) -> Vector2:
		return (Vector2((x + WORLD * 0.5) * k, (z + WORLD * 0.5) * k) - src.position) * (side / src.size.x)
	# Свои машины
	for n in get_tree().get_nodes_in_group("vehicles"):
		var v := n as Vehicle
		if v and v.owned() and v.kind != "tractor" and v != GameManager.vehicle:
			var mp: Vector2 = to_mini.call(v.global_position.x, v.global_position.z)
			if Rect2(Vector2.ZERO, Vector2(side, side)).has_point(mp):
				_mini.draw_rect(Rect2(mp - Vector2(3, 3), Vector2(6, 6)), Color(0.95, 0.9, 0.6))
	# Игрок
	var at: Vector2 = to_mini.call(pos.x, pos.z)
	var yaw := _player_yaw()
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var sd := Vector2(fwd.y, -fwd.x)
	_mini.draw_colored_polygon(PackedVector2Array([at + fwd * 9.0, at - fwd * 5.0 + sd * 5.0, at - fwd * 5.0 - sd * 5.0]), Color(1, 0.2, 0.2))
	_mini.draw_rect(Rect2(Vector2.ZERO, Vector2(side, side)), Color(1, 1, 1, 0.5), false, 1.5)
	var font := ThemeDB.fallback_font
	_mini.draw_string_outline(font, Vector2(side * 0.5 - 5, 14), "С", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color.BLACK)
	_mini.draw_string(font, Vector2(side * 0.5 - 5, 14), "С", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


func _player_pos() -> Vector3:
	var car := GameManager.vehicle as Node3D
	if car:
		return car.global_position
	var who := GameManager.player as Node3D
	return who.global_position if who else Vector3.ZERO


func _player_yaw() -> float:
	var car := GameManager.vehicle as Node3D
	if car:
		return car.rotation.y
	var who := GameManager.player as Node3D
	return who.rotation.y if who else 0.0


## Мировые X/Z → точка на карте (север, -Z, — вверху).
func _p(x: float, z: float) -> Vector2:
	return Vector2((x + WORLD * 0.5) / WORLD * _size, (z + WORLD * 0.5) / WORLD * _size)


func _rect(x0: float, z0: float, x1: float, z1: float, c: Color) -> void:
	var a := _p(x0, z0)
	var b := _p(x1, z1)
	_t.draw_rect(Rect2(a, b - a), c)


func _draw_map() -> void:
	_t = _canvas
	_size = SIZE
	var font := ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(Vector2(-8, -8), Vector2(SIZE + 16, SIZE + 16)), Color(0, 0, 0, 0.75))
	_draw_static(true)
	_draw_dynamic(font)


## Всё неподвижное: земля, дороги, дома, места. labels — подписи мест.
func _draw_static(labels: bool) -> void:
	var font := ThemeDB.fallback_font
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
	_t.draw_circle(_p(pond.x, pond.z), 10.0 / WORLD * _size * 1.1, Color(0.25, 0.45, 0.6))
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
	# Речка, полевое кольцо (гравий), лесная дорога, площадь в городе
	var st: Rect2 = Roads.STREAM
	_rect(st.position.x, st.position.y, st.end.x, st.end.y, Color(0.35, 0.55, 0.75))
	for r in Roads.FIELD:
		_rect(r.position.x, r.position.y, r.end.x, r.end.y, Color(0.72, 0.68, 0.6))
	for r in Roads.FOREST:
		_rect(r.position.x, r.position.y, r.end.x, r.end.y, Color(0.55, 0.43, 0.3))
	var br: Rect2 = Roads.BRIDGE
	_rect(br.position.x, br.position.y + 0.5, br.end.x, br.end.y - 0.5, Color(0.6, 0.45, 0.3))
	var sq: Rect2 = _world.TOWN_SQUARE
	_rect(sq.position.x, sq.position.y, sq.end.x, sq.end.y, Color(0.75, 0.73, 0.68))
	var ad: Rect2 = _world.AUTODROME
	_rect(ad.position.x, ad.position.y, ad.end.x, ad.end.y, Color(0.55, 0.55, 0.57))

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
		["Автошкола", Vector3(9, 0, -45), Color(0.95, 0.7, 0.25)],
		["Колька", _world.RACE_START, Color(0.95, 0.45, 0.35)],
		["Площадь", Vector3(122, 0, 21), Color(0.95, 0.9, 0.7)],
		["Кафе", Vector3(84.5, 0, 16.5), Color(0.95, 0.6, 0.45)],
		["Хозтовары", Vector3(84.5, 0, 28), Color(0.55, 0.85, 0.6)],
		["Мост", Vector3(-110, 0, -86.5), Color(0.8, 0.65, 0.45)],
		["Такси", Vector3(103, 0, 13), Color(0.95, 0.8, 0.15)],
		["Автосалон", Vector3(60, 0, 22), Color(0.85, 0.55, 0.95)],
		["Пахота", Vector3(70, 0, -80), Color(0.6, 0.45, 0.3)],
		["ГАИ", Vector3(-100, 0, -9.2), Color(0.3, 0.45, 0.9)],
		["Сберкасса", Vector3(137.8, 0, 21), Color(0.3, 0.8, 0.5)],
	]
	var blink := fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0
	for pl in places:
		var v: Vector3 = pl[1]
		var at := _p(v.x, v.z)
		var r := 5.0 if labels else 9.0
		if labels and pl[0] == "Сельмаг" and Progress.delivery_active and blink:
			r = 9.0
		_t.draw_circle(at, r, pl[2])
		if not labels:
			continue
		# Подписи соседних мест разводим: ларёк — слева, АЗС — сверху
		var off := Vector2(8, 5)
		if pl[0] == "Ларёк":
			off = Vector2(-48, 5)
		elif pl[0] == "АЗС":
			off = Vector2(-14, -9)
		_t.draw_string(font, at + off, pl[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _draw_dynamic(font: Font) -> void:
	# Свои машины, мотоцикл и игрок
	var marks := [[GameManager.car, Color(0.85, 0.8, 0.55), 4.0], [GameManager.moto, Color(0.85, 0.2, 0.15), 3.0]]
	for n in get_tree().get_nodes_in_group("vehicles"):
		var sv := n as Vehicle
		if sv and sv.price > 0 and sv.owned():
			marks.append([sv, Color(0.85, 0.55, 0.95), 4.0])
	for pair in marks:
		var v := pair[0] as Node3D
		if v:
			var cp := _p(v.global_position.x, v.global_position.z)
			var r: float = pair[2]
			_canvas.draw_rect(Rect2(cp - Vector2(r, r), Vector2(r, r) * 2.0), pair[1])
	var pos := _player_pos()
	var yaw := _player_yaw()
	var at := _p(pos.x, pos.z)
	# Вперёд — это -Z мира, на карте — вверх; поворот yaw против часовой
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(fwd.y, -fwd.x)
	_canvas.draw_colored_polygon(PackedVector2Array([at + fwd * 11.0, at - fwd * 6.0 + side * 6.0, at - fwd * 6.0 - side * 6.0]), Color(1, 0.2, 0.2))
	_canvas.draw_string(font, Vector2(8, SIZE - 10), "M — закрыть карту", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
