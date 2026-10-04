extends CanvasLayer
## Карта по M: дороги, лес, поля, сёла, город и важные места.
## Стрелка — игрок, квадрат — машина. Во время развоза горит сельмаг.
## M первый раз — окрестности (около 400 м вокруг), второй — весь район,
## третий — закрыть.
##
## Места берутся из констант world.gd и region.gd, чтобы карта не расходилась с миром.
##
## Две текстуры карты рисуются заранее: весь район целиком (для карты района)
## и подробно 800 м вокруг игрока (мини-карта и окрестности). Вторая
## перерисовывается, только когда игрок отъехал от её середины.

const SIZE := 560.0
const WORLD := Region.HALF * 2.0
## Окрестности на большой карте: столько метров по стороне.
const LOCAL_M := 420.0

var _canvas: Control
var _world: Node
## Куда сейчас рисуем и в каком размере: большая карта или текстура мини-карты
var _t: Control
var _size := SIZE
## Мини-карта: сколько метров видно по стороне и размер текстуры карты
const MINI_M := 160.0
const TEX := 2048.0
## Подробная текстура окрестностей: сторона в метрах и в точках
const NEAR_M := 800.0
const NEAR_TEX := 1024.0
var _mini: Control
## Сдвиг точек при рисовании: город рисуется в своих координатах (Town.SHIFT)
var _sh := Vector2.ZERO
var _tex_vp: SubViewport
var _near_vp: SubViewport
## Подробная текстура рисуется полосами: при переезде — по одной полосе за
## кадр, а показывается новая, когда готовы все (иначе на телефоне рывок).
const BANDS := 4
var _near_bands: Array[Control] = []
var _near_c := Vector2(INF, INF)
## Куда перерисовываем и какая полоса следующая (-1 — не перерисовываем).
var _pending_c := Vector2(INF, INF)
var _band := -1
## Какой кусок мира сейчас рисуем (X, Z мира) и что открыто: 0 — ничего,
## 1 — окрестности, 2 — весь район.
var _view := Rect2(-WORLD * 0.5, -WORLD * 0.5, WORLD, WORLD)
var mode := 0


func _ready() -> void:
	layer = 30
	_world = get_parent()
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_CENTER)
	_canvas.custom_minimum_size = Vector2(SIZE, SIZE)
	_canvas.size = Vector2(SIZE, SIZE)
	_canvas.position = -Vector2(SIZE, SIZE) * 0.5
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.clip_contents = true
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
		_view = Rect2(-WORLD * 0.5, -WORLD * 0.5, WORLD, WORLD)
		_draw_static(false)
		_t = _canvas
		_size = SIZE)
	_tex_vp.add_child(painter)
	add_child(_tex_vp)
	_near_vp = SubViewport.new()
	_near_vp.size = Vector2i(int(NEAR_TEX), int(NEAR_TEX))
	_near_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_near_vp.disable_3d = true
	for i in BANDS:
		var band := Control.new()
		band.size = Vector2(NEAR_TEX, NEAR_TEX / BANDS)
		band.position = Vector2(0, NEAR_TEX / BANDS * i)
		band.clip_contents = true
		band.draw.connect(func() -> void:
			_t = band
			_size = NEAR_TEX
			var h := NEAR_M / BANDS
			_view = Rect2(_pending_c - Vector2(NEAR_M, NEAR_M) * 0.5 + Vector2(0, h * i), Vector2(NEAR_M, h))
			_draw_static(false)
			_t = _canvas
			_size = SIZE)
		_near_vp.add_child(band)
		_near_bands.append(band)
	add_child(_near_vp)
	_recenter(_player_pos2())
	_mini = Control.new()
	_mini.add_to_group("minimap")
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini.draw.connect(_draw_mini)
	add_child(_mini)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_M:
		# Закрыта — окрестности, окрестности — весь район, район — закрыть.
		# Если карту закрыли в обход (меню), следующее M снова открывает окрестности
		if not _canvas.visible:
			mode = 0
		mode = (mode + 1) % 3
		_canvas.visible = mode > 0
		if mode == 1:
			QuestManager.event("map")


## Где сейчас подробная текстура (X, Z мира).
func _near_rect() -> Rect2:
	return Rect2(_near_c - Vector2(NEAR_M, NEAR_M) * 0.5, Vector2(NEAR_M, NEAR_M))


## Перерисовать подробную текстуру вокруг точки (не заходя за край района).
func _recenter(p: Vector2) -> void:
	var h := WORLD * 0.5 - NEAR_M * 0.5
	var want := Vector2(clampf(snappedf(p.x, 50.0), -h, h), clampf(snappedf(p.y, 50.0), -h, h))
	# У края района середина упирается в край — лишний раз не перерисовываем
	if want == _near_c or (_band >= 0 and want == _pending_c):
		return
	_pending_c = want
	# Игрок за краем текстуры (перенёсся, загрузил игру) — сразу целиком;
	# по дороге — полосами, по одной за кадр (_next_band)
	if maxf(absf(p.x - _near_c.x), absf(p.y - _near_c.y)) > NEAR_M * 0.5 - 20.0:
		for b in _near_bands:
			b.queue_redraw()
		_band = BANDS
	else:
		_band = 0
	_next_band()


## Следующая полоса подробной текстуры; все готовы — один раз отрисовать
## текстуру и показывать её вокруг новой середины.
func _next_band() -> void:
	if _band < 0:
		return
	if _band < BANDS:
		_near_bands[_band].queue_redraw()
		_band += 1
		return
	_near_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_near_c = _pending_c
	_band = -1


func _player_pos2() -> Vector2:
	var p := _player_pos()
	return Vector2(p.x, p.z)


func _process(_delta: float) -> void:
	# Отъехал от середины подробной текстуры — перерисовать её вокруг себя
	if _near_vp:
		_next_band()
		var d := _player_pos2() - _near_c
		if maxf(absf(d.x), absf(d.y)) > NEAR_M * 0.5 - LOCAL_M * 0.5 - 10.0:
			_recenter(_player_pos2())
	if _canvas.visible:
		_canvas.queue_redraw()
	if _mini:
		var show := SettingsManager.minimap and not _canvas.visible and not get_tree().paused and GameManager.in_game
		_mini.visible = show
		if show:
			var vs := _mini.get_viewport_rect().size
			var side := 160.0
			if GameManager.touch_mode:
				# Ниже — кнопки действий (верхняя — «Присесть», на 290 от низа):
				# на низком экране мини-карта меньше, чтобы на них не заходить
				side = clampf(vs.y - 290.0 - 6.0 - 92.0, 80.0, 118.0)
			_mini.size = Vector2(side, side)
			# На телефоне справа сверху — столбик кнопок: встаём левее него
			_mini.position = Vector2(vs.x - side - (100.0 if GameManager.touch_mode else 16.0), 92.0 if GameManager.touch_mode else 84.0)
			_mini.queue_redraw()


## Мини-карта: кусок большой карты вокруг игрока, север сверху, игрок — стрелка.
func _draw_mini() -> void:
	var side := _mini.size.x
	var pos := _player_pos()
	var k := NEAR_TEX / NEAR_M
	var o := _near_rect().position
	var half := MINI_M * 0.5 * k
	var c := (Vector2(pos.x, pos.z) - o) * k
	c = c.clamp(Vector2(half, half), Vector2(NEAR_TEX - half, NEAR_TEX - half))
	var src := Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0)
	_mini.draw_rect(Rect2(Vector2(-3, -3), Vector2(side + 6, side + 6)), Color(0, 0, 0, 0.6))
	_mini.draw_texture_rect_region(_near_vp.get_texture(), Rect2(Vector2.ZERO, Vector2(side, side)), src, Color(1, 1, 1, 0.9))
	var to_mini := func(x: float, z: float) -> Vector2:
		return ((Vector2(x, z) - o) * k - src.position) * (side / src.size.x)
	# Свои машины
	for n in get_tree().get_nodes_in_group("vehicles"):
		var v := n as Vehicle
		if v and v.owned() and not v.school and v.kind != "tractor" and v != GameManager.vehicle:
			var mp: Vector2 = to_mini.call(v.global_position.x, v.global_position.z)
			if Rect2(Vector2.ZERO, Vector2(side, side)).has_point(mp):
				_mini.draw_rect(Rect2(mp - Vector2(3, 3), Vector2(6, 6)), Color(0.95, 0.9, 0.6))
	# Цель навигатора: ромб, за краем — прижат к краю мини-карты
	var nav := get_tree().get_first_node_in_group("nav")
	if nav:
		var tgt: Vector3 = nav.current()[1]
		if tgt != Vector3.INF:
			var tp: Vector2 = to_mini.call(tgt.x, tgt.z)
			tp = tp.clamp(Vector2(6, 6), Vector2(side - 6, side - 6))
			_mini.draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -7), tp + Vector2(6, 0), tp + Vector2(0, 7), tp + Vector2(-6, 0)]), Color(1.0, 0.78, 0.3))
			_mini.draw_polyline(PackedVector2Array([tp + Vector2(0, -7), tp + Vector2(6, 0), tp + Vector2(0, 7), tp + Vector2(-6, 0), tp + Vector2(0, -7)]), Color(0.2, 0.15, 0.05), 1.5)
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
	# В селе — его название под мини-картой
	var here := Region.village_at(pos.x, pos.z)
	if here != "":
		var w := font.get_string_size(here, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		_mini.draw_string_outline(font, Vector2((side - w) * 0.5, side + 15), here, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
		_mini.draw_string(font, Vector2((side - w) * 0.5, side + 15), here, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


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
	return (Vector2(x, z) + _sh - _view.position) / _view.size.x * _size


const PAPER := Color(0.91, 0.87, 0.77)
const FOREST_COL := Color(0.72, 0.8, 0.6)
const FOREST_EDGE := Color(0.62, 0.72, 0.52)
const WATER := Color(0.45, 0.56, 0.62)
const WATER_EDGE := Color(0.32, 0.41, 0.47)
const ROAD := Color(0.72, 0.64, 0.52)
const ROAD_MAIN := Color(0.6, 0.56, 0.5)
const ROAD_EDGE := Color(0.45, 0.4, 0.34)
const HOUSE := Color(0.5, 0.42, 0.36)


## Метры мира → точки карты.
func _m(meters: float) -> float:
	return meters / _view.size.x * _size


## Линия толщиной в метрах (не тоньше полутора точек), с круглыми концами.
func _line(pts: PackedVector2Array, width_m: float, c: Color) -> void:
	var w := maxf(_m(width_m), 1.5)
	_t.draw_polyline(pts, c, w, true)
	for p in [pts[0], pts[pts.size() - 1]]:
		_t.draw_circle(p, w * 0.5, c)


## Пятно с неровным краем: прямоугольник, засыпанный кругами; у края круги
## меньше и со сдвигом. edge — цвет каймы (рисуется чуть шире под пятном).
func _blob(r: Rect2, c: Color, seed: int, edge := Color(0, 0, 0, 0)) -> void:
	if not _seen(r.position.x, r.position.y, r.end.x, r.end.y):
		return
	var rng := RandomNumberGenerator.new()
	var step := 9.0
	for pass_i in (2 if edge.a > 0.0 else 1):
		rng.seed = seed
		var grow := 2.5 if pass_i == 0 and edge.a > 0.0 else 0.0
		var col := edge if pass_i == 0 and edge.a > 0.0 else c
		# Середина — сплошная, кругами — только неровный край
		var inner := r.grow(-step * 0.6 + grow)
		_rect(inner.position.x, inner.position.y, inner.end.x, inner.end.y, col)
		var x := r.position.x
		while x <= r.end.x:
			var zz := r.position.y
			while zz <= r.end.y:
				# Ближе к краю — круги мельче и случайнее: край «гуляет»
				var d := minf(minf(x - r.position.x, r.end.x - x), minf(zz - r.position.y, r.end.y - zz))
				if d > step * 1.5:
					zz += step
					continue
				var rad := rng.randf_range(3.0, step * 0.9)
				var j := Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)) if d <= step else Vector2.ZERO
				_t.draw_circle(_p(x + j.x, zz + j.y), _m(rad + grow), col)
				zz += step
			x += step


func _label_at(font: Font, text: String, at: Vector2, size: int, italic := false) -> void:
	var p := _p(at.x, at.y)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var col := Color(0.12, 0.1, 0.08) if not italic else Color(0.28, 0.33, 0.24)
	p.x -= w * 0.5
	_t.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(1, 1, 1, 0.85))
	_t.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Роза ветров: стрелка на север в правом верхнем углу.
func _compass(font: Font) -> void:
	var c := Vector2(_size - 34, 40)
	_t.draw_circle(c, 18, Color(1, 1, 1, 0.6))
	_t.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16), c + Vector2(6, 2), c + Vector2(-6, 2)]), Color(0.7, 0.15, 0.1))
	_t.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 16), c + Vector2(6, 2), c + Vector2(-6, 2)]), Color(0.3, 0.28, 0.26))
	_t.draw_string(font, c + Vector2(-5, -20), "С", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.12, 0.1, 0.08))


## Масштаб: полоска на 100 метров (на карте района — на 500) в левом нижнем углу.
func _scale_bar(font: Font) -> void:
	var a := Vector2(14, _size - 30)
	var meters := 100.0 if _view.size.x < 800.0 else 1000.0
	var bar := _m(meters)
	_t.draw_rect(Rect2(a, Vector2(bar, 5)), Color(0.12, 0.1, 0.08))
	_t.draw_rect(Rect2(a + Vector2(bar * 0.5, 1), Vector2(bar * 0.5 - 1, 3)), Color(1, 1, 1))
	_t.draw_string(font, a + Vector2(bar + 6, 7), "%d м" % int(meters), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.12, 0.1, 0.08))


## Видно ли прямоугольник мира (с учётом сдвига _sh) на рисуемом куске.
## Подробная текстура вокруг игрока перерисовывается на ходу — всё, что за
## её краем, не рисуем, иначе на телефоне кадр подвисает.
func _seen(x0: float, z0: float, x1: float, z1: float) -> bool:
	var r := Rect2(minf(x0, x1) + _sh.x, minf(z0, z1) + _sh.y, absf(x1 - x0), absf(z1 - z0))
	return r.grow(12.0).intersects(_view)


func _rect(x0: float, z0: float, x1: float, z1: float, c: Color) -> void:
	if not _seen(x0, z0, x1, z1):
		return
	var a := _p(x0, z0)
	var b := _p(x1, z1)
	_t.draw_rect(Rect2(a, b - a), c)


func _draw_map() -> void:
	_t = _canvas
	_size = SIZE
	if mode == 2:
		_view = Rect2(-WORLD * 0.5, -WORLD * 0.5, WORLD, WORLD)
	else:
		# Окрестности вокруг игрока, не заходя за край района
		var pos := _player_pos()
		var half := LOCAL_M * 0.5
		var c := Vector2(clampf(pos.x, -WORLD * 0.5 + half, WORLD * 0.5 - half), clampf(pos.z, -WORLD * 0.5 + half, WORLD * 0.5 - half))
		_view = Rect2(c - Vector2(half, half), Vector2(LOCAL_M, LOCAL_M))
	var font := ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), PAPER)
	_draw_static(true)
	_draw_dynamic(font)
	_canvas.draw_rect(Rect2(Vector2(1.5, 1.5), Vector2(SIZE - 3, SIZE - 3)), Color(0.35, 0.3, 0.24), false, 3.0)


## Всё неподвижное — в стиле бумажного атласа района: светлая бумага,
## леса зелёными пятнами с неровным краем, вода с береговой линией, дороги
## линиями с обводкой, дома мелкими квадратиками. labels — подписи и значки.
func _draw_static(labels: bool) -> void:
	var font := ThemeDB.fallback_font
	# Большая карта берёт местность из уже нарисованной текстуры мини-карты —
	# тысяча кругов лесов не перерисовывается каждый кадр
	if labels and _tex_vp and _near_rect().encloses(_view):
		# Окрестности — из подробной текстуры
		var kn := NEAR_TEX / NEAR_M
		var src_n := Rect2((_view.position - _near_rect().position) * kn, _view.size * kn)
		_t.draw_texture_rect_region(_near_vp.get_texture(), Rect2(Vector2.ZERO, Vector2(_size, _size)), src_n)
	elif labels and _tex_vp:
		var k := TEX / WORLD
		var src := Rect2((_view.position + Vector2(WORLD, WORLD) * 0.5) * k, _view.size * k)
		_t.draw_texture_rect_region(_tex_vp.get_texture(), Rect2(Vector2.ZERO, Vector2(_size, _size)), src)
	else:
		_draw_terrain()
	var whole := _view.size.x > 800.0
	if labels:
		# Крупные подписи: сёла, город, леса, река — как на районной карте
		var big := 16 if whole else 20
		_label_at(font, "Каменка", Vector2(-110, -60) if whole else Vector2(-140, -70), big)
		_label_at(font, "Город", Town.w2(Vector2(120, 104)), big)
		for v in Region.VILLAGES:
			_label_at(font, v.name, (v.c as Vector2) + Vector2(0, -52.0 if whole else -44.0), big)
		if whole:
			_label_at(font, "р. Быстрая", Vector2(385, -200), 13, true)
			_label_at(font, "оз. Круглое", Region.LAKE + Vector2(-330, 30), 12, true)
			_label_at(font, "Тёмный лес", Vector2(-1000, -1050), 13, true)
			_label_at(font, "Дубрава", Vector2(0, 1000), 13, true)
		else:
			_label_at(font, "Сосновый бор", Vector2(-120, -150), 14, true)
			_label_at(font, "Дубрава", Vector2(-135, 120), 14, true)
			_label_at(font, "колхоз «Заря»", Vector2(62, -150), 13, true)
			_label_at(font, "речка Каменка", Vector2(-100, -175), 12, true)
			_label_at(font, "р. Быстрая", Vector2(348, -30), 13, true)
			_label_at(font, "оз. Круглое", Region.LAKE + Vector2(0, 34), 12, true)
		_compass(font)
		_scale_bar(font)
	_draw_places(labels, font)


func _draw_terrain() -> void:
	_rect(-WORLD * 0.5, -WORLD * 0.5, WORLD * 0.5, WORLD * 0.5, PAPER)
	_draw_region()
	# Поля — чуть темнее бумаги, пашня — коричневатая
	_blob(Rect2(25, -185, 75, 75), Color(0.88, 0.83, 0.66), 11)
	_blob(Rect2(110, -185, 80, 75), Color(0.83, 0.86, 0.7), 12)
	_blob(Rect2(25, -100, 165, 70), Color(0.84, 0.78, 0.66), 13)
	# Леса: пятнами, край неровный
	_blob(Rect2(-200, -195, 180, 115), FOREST_COL, 1, FOREST_EDGE)
	_blob(Rect2(-200, 22, 150, 173), FOREST_COL, 2, FOREST_EDGE)
	# Село — тёплое пятно застройки
	_blob(Rect2(-165, -68, 115, 56), Color(0.93, 0.88, 0.76), 3)
	# Вода: речка с чуть неровными берегами, пруд
	var st: Rect2 = Roads.STREAM
	var river := PackedVector2Array()
	var z := st.position.y
	while z <= st.end.y:
		river.append(_p(st.get_center().x + sin(z * 0.07) * 1.5, z))
		z += 5.0
	_line(river, 7.0, WATER_EDGE)
	_line(river, 5.0, WATER)
	var pond: Vector3 = _world.POND_POS
	_t.draw_circle(_p(pond.x, pond.z), _m(13.5), WATER_EDGE)
	_t.draw_circle(_p(pond.x, pond.z), _m(12.0), WATER)
	# Дороги: трасса шире, остальные тоньше; сначала обводка, потом заливка
	var roads: Array = [
		[[Vector2(-200, 0), Vector2(200, 0)], 8.0, ROAD_MAIN],
		[[Vector2(-165, -40), Vector2(-57, -40)], 5.0, ROAD],
		[[Vector2(-59.5, -40), Vector2(-59.5, -4)], 5.0, ROAD],
	]
	for r in Roads.FIELD + Roads.FOREST:
		var rr: Rect2 = r
		var along_x := rr.size.x > rr.size.y
		var a := Vector2(rr.position.x, rr.get_center().y) if along_x else Vector2(rr.get_center().x, rr.position.y)
		var b := Vector2(rr.end.x, rr.get_center().y) if along_x else Vector2(rr.get_center().x, rr.end.y)
		roads.append([[a, b], 4.0, ROAD])
	for r in roads:
		var pts := PackedVector2Array()
		for v in r[0]:
			pts.append(_p(v.x, v.y))
		_line(pts, float(r[1]) + 2.5, ROAD_EDGE)
	for r in roads:
		var pts := PackedVector2Array()
		for v in r[0]:
			pts.append(_p(v.x, v.y))
		_line(pts, float(r[1]), r[2])
	var br: Rect2 = Roads.BRIDGE
	_rect(br.position.x, br.position.y + 0.5, br.end.x, br.end.y - 0.5, Color(0.55, 0.45, 0.35))
	# Дома: мелкие тёмные квадратики, свой — золотой
	for x in _world.VILLAGE_X:
		for zz in [_world.ROW_A_Z, _world.ROW_B_Z]:
			var own: bool = Vector2(x, zz) == _world.PLAYER_HOUSE
			_rect(x - 4.0, zz - 3.0, x + 4.0, zz + 3.0, Color(0.95, 0.72, 0.2) if own else HOUSE)
	_draw_town()


## Город — в своих координатах, на карте сдвинут туда же, где стоит в мире.
func _draw_town() -> void:
	_sh = Vector2(Town.SHIFT.x, Town.SHIFT.z)
	_blob(Rect2(-42, 8, 234, 94), Color(0.86, 0.84, 0.8), 4)
	_blob(Rect2(40, 100, 160, 92), Color(0.86, 0.84, 0.8), 5)
	for r in [[[Vector2(97, 4), Vector2(97, 177)], 6.0], [[Vector2(40, 58), Vector2(205, 58)], 6.0]]:
		var pts := PackedVector2Array()
		for v in r[0]:
			pts.append(_p(v.x, v.y))
		_line(pts, float(r[1]) + 2.5, ROAD_EDGE)
		_line(pts, float(r[1]), ROAD_MAIN)
	for c in [Vector2(70, 41), Vector2(125, 41), Vector2(70, 74), Vector2(125, 74)]:
		_rect(c.x - 21, c.y - 6, c.x + 21, c.y + 6, HOUSE)
	_rect(165, 54, 177, 96, HOUSE)
	_rect(15.5, 30, 39.5, 44, HOUSE)
	var sq: Rect2 = _world.TOWN_SQUARE
	_rect(sq.position.x, sq.position.y, sq.end.x, sq.end.y, Color(0.8, 0.77, 0.7))
	var ad: Rect2 = _world.AUTODROME
	_rect(ad.position.x, ad.position.y, ad.end.x, ad.end.y, Color(0.72, 0.7, 0.66))
	var ah := AutoSchool.HOUSE
	_rect(ah.x - 5.0, ah.z - 3.75, ah.x + 5.0, ah.z + 3.75, HOUSE)
	for r in [TownSouth.STATION_HALL, TownSouth.SCHOOL, TownSouth.GARAGES, TownSouth.FACTORY]:
		var rr: Rect2 = r
		_rect(rr.position.x, rr.position.y, rr.end.x, rr.end.y, HOUSE)
	_rect(TownSouth.STADIUM.position.x, TownSouth.STADIUM.position.y, TownSouth.STADIUM.end.x - 8.0, TownSouth.STADIUM.end.y - 2.0, Color(0.55, 0.7, 0.45))
	_rect(TownSouth.MARKET.position.x, TownSouth.MARKET.position.y, TownSouth.MARKET.end.x, TownSouth.MARKET.end.y, Color(0.85, 0.8, 0.7))
	# Восточная часть: улица, банк, авторынок, СТО, бурса, дома, участки, парк
	_blob(TownEast.PARK, Color(0.7, 0.8, 0.55), 6)
	for r in [TownEast.EAST_STREET, TownEast.EAST_ROAD]:
		var rr: Rect2 = r
		_rect(rr.position.x, rr.position.y, rr.end.x, rr.end.y, ROAD_MAIN)
	for r in [TownEast.BANK, TownEast.STO, TownEast.COLLEGE, TownEast.MY_GARAGES] + TownEast.FLATS:
		var rr: Rect2 = r
		_rect(rr.position.x, rr.position.y, rr.end.x, rr.end.y, HOUSE)
	_rect(TownEast.CAR_MARKET.position.x, TownEast.CAR_MARKET.position.y, TownEast.CAR_MARKET.end.x, TownEast.CAR_MARKET.end.y, Color(0.72, 0.7, 0.66))
	_rect(TownEast.PLOTS.position.x, TownEast.PLOTS.position.y, TownEast.PLOTS.end.x, TownEast.PLOTS.end.y, Color(0.8, 0.85, 0.65))
	_sh = Vector2.ZERO


## Район вокруг Каменки: поля, леса, озеро, река с мостами, грунтовки, сёла.
func _draw_region() -> void:
	for f in Region.FIELDS:
		var fr: Rect2 = f[0]
		_blob(fr, Color(0.88, 0.83, 0.66) if (f[1] as Color).r > 0.7 else Color(0.84, 0.8, 0.68), 20 + int(fr.position.x))
	# Лоскуты полей и холмы (кольца светлее к вершине)
	for f in Landscape.fields:
		var fr: Rect2 = f[0]
		var col: Color = Landscape.CROPS[f[1]][0]
		_rect(fr.position.x, fr.position.y, fr.end.x, fr.end.y, PAPER.lerp(col, 0.35))
	for h in Landscape.hills:
		var hc: Vector2 = h[0]
		var hr: float = h[1]
		if not _seen(hc.x - hr, hc.y - hr, hc.x + hr, hc.y + hr):
			continue
		for k in 3:
			_t.draw_circle(_p(hc.x, hc.y), _m(hr * (1.0 - k * 0.3)), Color(0.8, 0.74, 0.6, 0.35))
	for pd in Landscape.ponds:
		_t.draw_circle(_p((pd[0] as Vector2).x, (pd[0] as Vector2).y), _m(float(pd[1]) * 1.2), WATER)
	var seed := 30
	for r in Region.FORESTS:
		_blob(r, FOREST_COL, seed, FOREST_EDGE)
		seed += 1
	var lake := PackedVector2Array()
	for i in 29:
		var a := TAU * i / 28.0
		lake.append(_p(Region.LAKE.x + cos(a) * Region.LAKE_R.x, Region.LAKE.y + sin(a) * Region.LAKE_R.y))
	_t.draw_colored_polygon(lake, WATER)
	_t.draw_polyline(lake, WATER_EDGE, 2.0, true)
	var river := PackedVector2Array()
	for q in Region.river():
		river.append(_p(q.x, q.y))
	_line(river, Region.RIVER_HALF * 2.0 + 4.0, WATER_EDGE)
	_line(river, Region.RIVER_HALF * 2.0, WATER)
	for v in Region.VILLAGES:
		var c: Vector2 = v.c
		_blob(Rect2(c.x - 62, c.y - 32, 124, 64), Color(0.93, 0.88, 0.76), int(c.x))
	# Грунтовки, трасса за Каменкой; мосты — светлыми полосками поперёк реки
	var segs := Region.segments()
	for s in segs:
		_line(PackedVector2Array([_p(s[0].x, s[0].y), _p(s[1].x, s[1].y)]), 7.5, ROAD_EDGE)
	for side in [[-WORLD * 0.5, -200.0], [200.0, WORLD * 0.5]]:
		_line(PackedVector2Array([_p(side[0], 0), _p(side[1], 0)]), 10.5, ROAD_EDGE)
	for s in segs:
		_line(PackedVector2Array([_p(s[0].x, s[0].y), _p(s[1].x, s[1].y)]), 5.0, ROAD)
	for side in [[-WORLD * 0.5, -200.0], [200.0, WORLD * 0.5]]:
		_line(PackedVector2Array([_p(side[0], 0), _p(side[1], 0)]), 8.0, ROAD_MAIN)
	for h in Region.houses():
		var c: Vector2 = h[0]
		_rect(c.x - 4.0, c.y - 3.0, c.x + 4.0, c.y + 3.0, HOUSE)
	# Железная дорога: тёмная линия с белыми шашками
	var rail := PackedVector2Array()
	for q in Railway.LINE:
		rail.append(_p((q as Vector2).x, (q as Vector2).y))
	_line(rail, 4.0, Color(0.25, 0.22, 0.2))
	var t := 0.0
	while t < Railway.length():
		var a: Vector2 = Railway.at(t)[0]
		var e: Vector2 = Railway.at(minf(t + 20.0, Railway.length()))[0]
		t += 40.0
		if not _seen(a.x, a.y, e.x, e.y):
			continue
		_t.draw_line(_p(a.x, a.y), _p(e.x, e.y), Color(0.98, 0.97, 0.94), maxf(_m(2.0), 1.0))


func _draw_places(labels: bool, font: Font) -> void:
	var pond: Vector3 = _world.POND_POS
	var shop: Vector3 = _world.SHOP_POS
	var places := [
		["Дом", Vector3(_world.PLAYER_HOUSE.x, 0, _world.PLAYER_HOUSE.y), Color(1.0, 0.85, 0.3)],
		["Сельмаг", shop, Color(0.95, 0.35, 0.3)],
		["Колхоз", _world.BARN_POS, Color(0.9, 0.8, 0.5)],
		["АЗС", _world.FUEL_POS, Color(0.4, 0.85, 0.5)],
		["СТО", _world.GARAGE_POS, Color(0.5, 0.65, 1.0)],
		["Автобус", _world.STOP_VILLAGE, Color(1.0, 0.9, 0.3)],
		["Автобус", Town.w(_world.STOP_TOWN), Color(1.0, 0.9, 0.3)],
		["Склад", Town.w(Vector3(27.5, 0, 37)), Color(0.9, 0.9, 0.9)],
		["Ларёк", Town.w(Vector3(25, 0, 9)), Color(0.5, 0.7, 1.0)],
		["Пруд", pond, Color(0.6, 0.85, 1.0)],
		["Автошкола", Town.w(AutoSchool.HOUSE), Color(0.95, 0.7, 0.25)],
		["Колька", _world.RACE_START, Color(0.95, 0.45, 0.35)],
		["Площадь", Town.w(Vector3(122, 0, 21)), Color(0.95, 0.9, 0.7)],
		["Кафе", Town.w(Vector3(84.5, 0, 16.5)), Color(0.95, 0.6, 0.45)],
		["Хозтовары", Town.w(Vector3(84.5, 0, 28)), Color(0.55, 0.85, 0.6)],
		["Мост", Vector3(-110, 0, -86.5), Color(0.8, 0.65, 0.45)],
		["Такси", Town.w(Vector3(103, 0, 13)), Color(0.95, 0.8, 0.15)],
		["Автосалон", Town.w(Vector3(60, 0, 22)), Color(0.85, 0.55, 0.95)],
		["Пахота", Vector3(70, 0, -80), Color(0.6, 0.45, 0.3)],
		["ГАИ", Vector3(-100, 0, -9.2), Color(0.3, 0.45, 0.9)],
		["Банк", Town.w(Vector3(201, 0, 19)), Color(0.3, 0.8, 0.5)],
		["Бурса", Town.w(Vector3(243, 0, 120)), Color(0.85, 0.6, 0.35)],
		["Авторынок", Town.w(Vector3(237, 0, 30)), Color(0.85, 0.55, 0.95)],
		["СТО", Town.w(Vector3(248, 0, 67)), Color(0.5, 0.65, 1.0)],
		["Гараж", Town.w(Vector3(278, 0, 185)), Color(0.6, 0.4, 0.3)],
		["Парк", Town.w(Vector3(-2, 0, 165)), Color(0.35, 0.7, 0.35)],
		["Милиция", Town.w(Police.STATION + Vector3(-8, 0, 0)), Color(0.2, 0.35, 0.8)],
		["Кафе у трассы", Roadside.CAFE + Vector3(0, 0, 6), Color(0.95, 0.6, 0.45)],
		["АЗС", Roadside.FUEL2 + Vector3(0, 0, 3), Color(0.4, 0.85, 0.5)],
		["Сельсовет", Civic.COUNCIL + Vector3(0, 0, 5), Color(0.8, 0.3, 0.25)],
		["Больница", Town.w(Civic.HOSPITAL + Vector3(0, 0, 6)), Color(0.95, 0.95, 0.95)],
		["Клуб", _world.CLUB_VILLAGE + Vector3(0, 0, 6), Color(0.85, 0.3, 0.8)],
		["Дискотека", Town.w(_world.CLUB_TOWN + Vector3(0, 0, -8)), Color(0.85, 0.3, 0.8)],
		["Районный", _world.STOP_VILLAGE + Vector3(-5, 0, 0), Color(0.3, 0.7, 0.4)],
		["Вокзал", Town.w(Vector3(97, 0, 186)), Color(0.3, 0.6, 0.9)],
		["Попутчик", _world.HITCH_POS, Color(1.0, 0.8, 0.3)],
		["Колонка", _world.PUMP_POS, Color(0.3, 0.75, 0.85)],
		["Рынок", Town.w(Vector3(64, 0, 144)), Color(0.95, 0.55, 0.2)],
		["Стадион", Town.w(Vector3(156, 0, 160)), Color(0.4, 0.75, 0.35)],
		["Школа", School.at(Vector3(School.DOOR_X, 0, School.Z0 - 6.0)), Color(0.9, 0.75, 0.6)],
		["Гаражи", Town.w(Vector3(220, 0, 80)), Color(0.6, 0.4, 0.3)],
		["Завод", Town.w(Vector3(178, 0, 228)), Color(0.7, 0.3, 0.25)],
		["Рыбалка", Vector3(Region.LAKE.x + Region.LAKE_R.x, 0, Region.LAKE.y), Color(0.6, 0.85, 1.0)],
	]
	# Почта: отделения в Каменке, городе и ближних сёлах (если мир построен)
	var post := _world.get_node_or_null("Post")
	if post:
		for o in post.offices:
			places.append(["Почта", o.window, Color(0.2, 0.4, 0.85)])
	for s in Landmarks.sites():
		places.append([s[3], Vector3((s[0] as Vector2).x, 0, (s[0] as Vector2).y), Color(0.75, 0.55, 0.35)])
	for i in Region.VILLAGES.size():
		places.append(["Магазин", Region.shop_pos(i), Color(0.95, 0.35, 0.3)])
		places.append(["Автобус", Region.stop_pos(i), Color(1.0, 0.9, 0.3)])
	# На карте всего района — только дом и магазины сёл, иначе значки слипаются
	if labels and _view.size.x > 800.0:
		places = places.filter(func(pl: Array) -> bool: return pl[0] == "Дом" or pl[0] == "Магазин")
	var blink := fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0
	for pl in places:
		var v: Vector3 = pl[1]
		var at := _p(v.x, v.z)
		if labels and not Rect2(Vector2(-20, -20), Vector2(_size + 40, _size + 40)).has_point(at):
			continue
		var r := 6.0 if labels else 10.0
		if labels and pl[0] == "Сельмаг" and Progress.delivery_active and blink:
			r = 10.0
		# Значок: белый кружок с тёмной каймой и цветной точкой
		_t.draw_circle(at, r + 1.5, Color(0.25, 0.22, 0.2))
		_t.draw_circle(at, r, Color(0.98, 0.97, 0.94))
		_t.draw_circle(at, r * 0.55, pl[2])
		if not labels or _view.size.x > 800.0:
			continue
		# Подписи соседних мест разводим: ларёк — слева, АЗС — сверху,
		# районный автобус — под обычным
		var off := Vector2(8, 5)
		if pl[0] == "Ларёк":
			off = Vector2(-48, 5)
		elif pl[0] == "АЗС":
			off = Vector2(-14, -9)
		elif pl[0] == "Районный":
			off = Vector2(-60, 16)
		elif pl[0] == "Автобус" and absf(v.x) > 200.0:
			# В сёлах остановка рядом с магазином — подпись ниже
			off = Vector2(8, 18)
		_t.draw_string_outline(font, at + off, pl[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(1, 1, 1, 0.9))
		_t.draw_string(font, at + off, pl[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.12, 0.1, 0.08))


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
	# Оля — розовое сердечко-точка, когда её видно
	var girl := get_tree().get_first_node_in_group("girl") as Girl
	if girl and girl.doll and girl.doll.is_visible_in_tree():
		var gp := _p(girl.doll.global_position.x, girl.doll.global_position.z)
		_canvas.draw_circle(gp, 5.0, Color(1, 1, 1))
		_canvas.draw_circle(gp, 3.6, Color(0.95, 0.35, 0.6))
	var pos := _player_pos()
	var yaw := _player_yaw()
	var at := _p(pos.x, pos.z)
	# Вперёд — это -Z мира, на карте — вверх; поворот yaw против часовой
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(fwd.y, -fwd.x)
	_canvas.draw_colored_polygon(PackedVector2Array([at + fwd * 11.0, at - fwd * 6.0 + side * 6.0, at - fwd * 6.0 - side * 6.0]), Color(1, 0.2, 0.2))
	var key := "Карта" if GameManager.touch_mode else "M"
	var hint := ("%s — весь район" if mode != 2 else "%s — закрыть карту") % key
	var w := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	_canvas.draw_string_outline(font, Vector2(SIZE - w - 10, SIZE - 12), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(1, 1, 1, 0.8))
	_canvas.draw_string(font, Vector2(SIZE - w - 10, SIZE - 12), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.3, 0.26, 0.22))
