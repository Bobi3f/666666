class_name EliteDistrict
extends RefCounted
## «Липки» — дорогой район на юго-западе, за южным лесом (к югу от Берёзовки): бульвар с фонарями и
## деревьями, пост охраны со шлагбаумом и восемь больших участков — высокие
## заборы с воротами, газоны, мощёные заезды, гаражи, дома четырёх видов
## (классика с колоннами, современный с панорамными окнами, «замок» с
## башенкой, шале), у некоторых бассейн и беседка, у ворот — дорогие машины.
##
## Сюда две дороги: быстрая асфальтовая — с трассы у Каменки на юг, через
## переезд и лес, мимо Тошиков (въезд с востока); и красивая грунтовка из
## Берёзовки — петляет по лесу и выходит к кольцу с запада. Обе — в Region.ROADS (переезды, карта, трафик, лес их
## обходит); быстрая ещё и асфальт (on_asphalt).
##
## Купить можно только дом №1 (Progress.has_item("lipki_house")) — после
## покупки там можно спать. Остальные — «не продаются», но стоят настоящими
## домами: игрок видит, к чему стремиться.

const NAME := "Липки"
## Посёлок: здесь лес не растёт, трава подстрижена.
const AREA := Rect2(-1080, 1232, 360, 165)
## Дорогой район целиком — юго-запад за полосой леса (Region.FOREST_BAND),
## как на плане игрока: на карте своя заливка и граница, на въездах — таблички.
const ZONE := Rect2(-2000, 900, 2100, 1100)
## Бульвар (асфальт) вдоль X: въезд с востока, разворотное кольцо на западе.
const BOULEVARD := Rect2(-1052, 1309, 310, 9)
const RING_C := Vector2(-1063, 1313.5)
const RING_R := 11.0
const SIDEWALK := 2.0
## Быстрая дорога из города (асфальт) и красивая — из Заречья (грунт).
const ROAD_FAST := [Vector2(-560, 4.5), Vector2(-575, 300), Vector2(-600, 560), Vector2(-650, 820), Vector2(-700, 1000),
	Vector2(-745, 1150), Vector2(-746, 1311)]
const ROAD_SCENIC := [Vector2(-955, 750), Vector2(-1010, 800), Vector2(-1050, 880), Vector2(-1110, 940), Vector2(-1140, 1030),
	Vector2(-1115, 1110), Vector2(-1135, 1190), Vector2(-1100, 1270), Vector2(-1074, 1313)]
const FAST_HALF := 3.6
## Леса, через которые идут обе дороги.
const FORESTS := [Rect2(-680, 430, 150, 330), Rect2(-1190, 880, 120, 120)]
## Участки: левый край по X (№1 — у въезда, дальше к кольцу); первые
## четыре — к северу от бульвара, следующие — к югу.
const PLOT_X := [-825.0, -895.0, -965.0, -1035.0]
const PLOT_W := 66.0
const PLOT_D := 70.0
const HOUSE_PRICE := 150000
const STYLES := ["classic", "modern", "castle", "chalet", "modern", "classic", "chalet", "castle"]


## Участок i (0–7): где перед участка на бульваре и куда он уходит.
## Свои координаты участка: x поперёк (−33…33), −z — вглубь от бульвара.
static func plot_xf(i: int) -> Transform3D:
	var north := i < 4
	var x: float = PLOT_X[i % 4] + PLOT_W * 0.5
	if north:
		return Transform3D(Basis.IDENTITY, Vector3(x, 0, BOULEVARD.position.y - SIDEWALK))
	return Transform3D(Basis(Vector3.UP, PI), Vector3(x, 0, BOULEVARD.end.y + SIDEWALK))


## Ворота дома i (в мире) — у ворот номер и табличка.
static func gate_pos(i: int) -> Vector3:
	return plot_xf(i) * Vector3(-18, 0, 0.8)


## Асфальт: бульвар, кольцо, быстрая дорога, заезды к участкам.
static func on_asphalt(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	if x > -520.0 or x < -1090.0 or z < 0.0 or z > 1405.0:
		return false
	if BOULEVARD.grow(0.3).has_point(p) or p.distance_to(RING_C) < RING_R:
		return true
	for i in ROAD_FAST.size() - 1:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, ROAD_FAST[i], ROAD_FAST[i + 1])) < FAST_HALF:
			return true
	return false


static func occupied(x: float, z: float) -> bool:
	return AREA.has_point(Vector2(x, z))


## Всё сразу: дороги (асфальт поверх грунта), бульвар, участки, пост охраны.
static func build(r: Region, glow: MeshBuilder, veg: Vegetation) -> void:
	var d: MeshBuilder = r._d
	veg.block(AREA.position.x, AREA.position.y, AREA.end.x, AREA.end.y)
	_fast_road(d)
	_boulevard(d, glow, veg)
	for i in 8:
		_plot(r, d, glow, veg, i)
	_entrance(r, d, glow)
	for road in [ROAD_FAST, ROAD_SCENIC]:
		_zone_sign(r, d, road)
	_forest_corridor(r, ROAD_FAST, 7.5, 5.0)
	_forest_corridor(r, ROAD_SCENIC, 5.0, 4.2)


## Где дорога идёт по лесу — густые полосы деревьев по обе стороны в три
## ряда (ели и берёзы — те же породы, что в лесу: лишних вызовов отрисовки нет): въехал — и вокруг лес, а не поле с редкими ёлками.
## У быстрой дороги просека шире, у красивой лес подступает вплотную.
static func _forest_corridor(r: Region, road: Array, near: float, step: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909 + road.size()
	var woods: Array = Region.FORESTS + FORESTS + Region.FAR_FORESTS
	for i in road.size() - 1:
		var a: Vector2 = road[i]
		var c: Vector2 = road[i + 1]
		var len := a.distance_to(c)
		var dir := (c - a) / len
		var side := Vector2(-dir.y, dir.x)
		var t := 0.0
		while t < len:
			var p := a + dir * t
			var in_wood := false
			for w in woods:
				if (w as Rect2).grow(25.0).has_point(p):
					in_wood = true
					break
			if in_wood:
				for sd in [-1.0, 1.0]:
					for row in 3:
						var q: Vector2 = p + side * sd * (near + row * 4.5 + rng.randf_range(-1.2, 1.2)) + dir * rng.randf_range(-1.5, 1.5)
						if not Region.tree_ok(q.x, q.y):
							continue
						var roll := rng.randf()
						var kind := Vegetation.TreeKind.SPRUCE if roll < 0.6 else Vegetation.TreeKind.BIRCH
						r._world._tree(r._d, Vector3(q.x, 0, q.y), rng.randf() * TAU, kind)
			t += step + rng.randf_range(-0.8, 0.8)


## Быстрая дорога: асфальт шириной 7 м поверх грунтовки, разметка, обочины.
static func _fast_road(d: MeshBuilder) -> void:
	var asphalt := Color(0.27, 0.27, 0.28)
	var white := Color(0.88, 0.88, 0.85)
	for i in ROAD_FAST.size() - 1:
		var a: Vector2 = ROAD_FAST[i]
		var c: Vector2 = ROAD_FAST[i + 1]
		var dir := c - a
		var mid := (a + c) * 0.5
		var yaw := atan2(dir.x, dir.y)
		d.box_rot(Vector3(mid.x, 0.045, mid.y), Vector3(FAST_HALF * 2.0, 0.03, dir.length() + 3.0), yaw, asphalt)
		# Разметка: прерывистая посередине, сплошные по краям
		var n := int(dir.length() / 6.0)
		for k in n:
			var t := (k + 0.25) / n
			var p := a.lerp(c, t)
			d.box_rot(Vector3(p.x, 0.065, p.y), Vector3(0.15, 0.01, 3.0), yaw, white)
		for s in [-1.0, 1.0]:
			var off: Vector2 = Vector2(dir.y, -dir.x).normalized() * (FAST_HALF - 0.3) * s
			d.box_rot(Vector3(mid.x + off.x, 0.065, mid.y + off.y), Vector3(0.12, 0.01, dir.length()), yaw, white)
		# Знак «Липки →» в начале
	var s0: Vector2 = ROAD_FAST[1]
	d.box(Vector3(s0.x + 5.0, 0, s0.y), Vector3(s0.x + 5.1, 2.6, s0.y + 0.1), Color(0.5, 0.5, 0.52), true)
	d.box(Vector3(s0.x + 4.2, 1.9, s0.y + 0.1), Vector3(s0.x + 5.9, 2.5, s0.y + 0.14), Color(0.15, 0.4, 0.75))


## Бульвар: асфальт, бордюры, тротуары плиткой, фонари, деревья, кольцо с клумбой.
static func _boulevard(d: MeshBuilder, glow: MeshBuilder, veg: Vegetation) -> void:
	var b := BOULEVARD
	var asphalt := Color(0.25, 0.25, 0.26)
	var tile := Color(0.66, 0.63, 0.58)
	var curb := Color(0.78, 0.78, 0.76)
	d.box(Vector3(b.position.x, 0, b.position.y), Vector3(b.end.x, 0.05, b.end.y), asphalt, true)
	var x := b.position.x + 2.0
	while x < b.end.x - 2.0:
		d.box(Vector3(x, 0.05, b.get_center().y - 0.08), Vector3(x + 3.0, 0.06, b.get_center().y + 0.08), Color(0.9, 0.9, 0.86))
		x += 7.0
	for s in [-1.0, 1.0]:
		var z0 := b.position.y - SIDEWALK if s < 0 else b.end.y
		d.box(Vector3(b.position.x, 0, z0), Vector3(b.end.x, 0.1, z0 + SIDEWALK), tile)
		var cz := b.position.y - 0.15 if s < 0 else b.end.y
		d.box(Vector3(b.position.x, 0, cz), Vector3(b.end.x, 0.16, cz + 0.15), curb)
		# Фонари — кованые, с двумя плафонами; между ними — липы
		var lx := b.position.x + 12.0
		var i := 0
		while lx < b.end.x - 4.0:
			var lp := Vector3(lx, 0, z0 + SIDEWALK * 0.5)
			d.box(lp + Vector3(-0.07, 0, -0.07), lp + Vector3(0.07, 4.2, 0.07), Color(0.12, 0.12, 0.13), true)
			d.box(lp + Vector3(-0.6, 4.1, -0.04), lp + Vector3(0.6, 4.18, 0.04), Color(0.12, 0.12, 0.13))
			for ox in [-0.55, 0.55]:
				glow.box(lp + Vector3(ox - 0.14, 3.75, -0.14), lp + Vector3(ox + 0.14, 4.1, 0.14), Color(1.0, 0.88, 0.6))
			if i % 2 == 0:
				var tp := Vector3(lx + 15.0, 0, z0 + SIDEWALK * 0.5)
				veg.add_tree(Vegetation.TreeKind.APPLE, Transform3D(Basis(Vector3.UP, lx).scaled(Vector3.ONE * 1.15), tp))
				d.box(tp + Vector3(-0.6, 0.1, -0.6), tp + Vector3(0.6, 0.13, 0.6), Color(0.3, 0.22, 0.15))
			lx += 30.0
			i += 1
	# Кольцо: асфальт, клумба с туями посередине
	var rc := Vector3(RING_C.x, 0, RING_C.y)
	PersonModel.limb(d, rc, rc + Vector3(0, 0.05, 0), Vector2(RING_R, RING_R), Vector2(RING_R, RING_R), asphalt, true)
	PersonModel.limb(d, rc + Vector3(0, 0.05, 0), rc + Vector3(0, 0.35, 0), Vector2(4.5, 4.5), Vector2(4.5, 4.5), curb, true)
	PersonModel.limb(d, rc + Vector3(0, 0.35, 0), rc + Vector3(0, 0.4, 0), Vector2(4.3, 4.3), Vector2(4.3, 4.3), Color(0.3, 0.5, 0.22), true)
	for k in 6:
		var a := TAU * k / 6.0
		veg.add_tree(Vegetation.TreeKind.SPRUCE, Transform3D(Basis.IDENTITY.scaled(Vector3(0.45, 0.6, 0.45)), rc + Vector3(cos(a) * 3.0, 0.35, sin(a) * 3.0)))
	for k in 10:
		var a := TAU * k / 10.0
		PersonModel.ball(d, rc + Vector3(cos(a) * 1.4, 0.45, sin(a) * 1.4), Vector3(0.22, 0.12, 0.22), [Color(0.85, 0.2, 0.25), Color(0.95, 0.85, 0.3), Color(0.9, 0.9, 0.95)][k % 3], 2, 6)


## Пост охраны на въезде (восточный конец бульвара): будка, шлагбаум
## (поднят), каменная стела «Липки» лицом к дороге.
static func _entrance(r: Region, d: MeshBuilder, glow: MeshBuilder) -> void:
	var ex := BOULEVARD.end.x
	var p := Vector3(ex + 7.0, 0, BOULEVARD.end.y + 6.0)
	var wall := Color(0.86, 0.84, 0.78)
	d.box(p + Vector3(-1.4, 0, -1.6), p + Vector3(1.4, 2.6, 1.6), wall, true)
	d.box(p + Vector3(-1.6, 2.6, -1.8), p + Vector3(1.6, 2.8, 1.8), Color(0.3, 0.3, 0.33))
	glow.box(p + Vector3(-1.43, 1.1, -1.2), p + Vector3(-1.4, 2.1, 1.2), Color(0.8, 0.9, 1.0))
	# Шлагбаум — поднят: днём въезд свободный
	var bp := p + Vector3(-2.4, 0, -2.6)
	d.box(bp + Vector3(-0.15, 0, -0.15), bp + Vector3(0.15, 1.1, 0.15), Color(0.35, 0.35, 0.38), true)
	VehicleModels.tube(d, bp + Vector3(0, 1.05, 0), bp + Vector3(0, 5.2, -0.6), 0.06, Color(0.9, 0.2, 0.15))
	VehicleModels.tube(d, bp + Vector3(0, 2.0, -0.15), bp + Vector3(0, 3.4, -0.35), 0.062, Color(0.95, 0.95, 0.95))
	# Стела из камня с названием — у быстрой дороги
	var st := Vector3(ex + 9.0, 0, BOULEVARD.position.y - 14.0)
	d.box(st + Vector3(-0.4, 0, -2.5), st + Vector3(0.4, 2.4, 2.5), Color(0.45, 0.42, 0.38), true)
	d.box(st + Vector3(-0.5, 2.4, -2.7), st + Vector3(0.5, 2.6, 2.7), Color(0.6, 0.58, 0.52))
	for s in [-1.0, 1.0]:
		var l := Label3D.new()
		l.text = NAME.to_upper()
		l.font_size = 128
		l.pixel_size = 0.008
		l.outline_size = 0
		l.modulate = Color(0.95, 0.85, 0.5)
		l.position = st + Vector3(s * 0.42, 1.3, 0)
		l.rotation.y = s * PI / 2.0
		r.add_child(l)


## Где дорога пересекает границу района (ZONE, z = край) — или INF.
static func zone_entry(road: Array) -> Vector3:
	var z0 := ZONE.position.y
	for i in road.size() - 1:
		var a: Vector2 = road[i]
		var b: Vector2 = road[i + 1]
		if (a.y - z0) * (b.y - z0) <= 0.0 and a.y != b.y:
			var t := (z0 - a.y) / (b.y - a.y)
			var p := a.lerp(b, t)
			return Vector3(p.x, 0, p.y)
	return Vector3.INF


## Синий щит у дороги на въезде в район: «Дорогой район «Липки»».
static func _zone_sign(r: Region, d: MeshBuilder, road: Array) -> void:
	var at := zone_entry(road)
	if at == Vector3.INF:
		return
	# Справа по ходу (едут на юг, +z — справа меньший x)
	var p := at + Vector3(-6.0, 0, -2.0)
	for s in [-1.4, 1.4]:
		d.box(p + Vector3(s - 0.06, 0, -0.06), p + Vector3(s + 0.06, 2.2, 0.06), Color(0.55, 0.55, 0.58), true)
	d.box(p + Vector3(-1.9, 2.2, -0.05), p + Vector3(1.9, 3.5, 0.05), Color(0.12, 0.3, 0.62))
	d.box(p + Vector3(-1.8, 2.3, -0.08), p + Vector3(1.8, 3.4, -0.06), Color(0.95, 0.95, 0.95))
	d.box(p + Vector3(-1.72, 2.36, -0.09), p + Vector3(1.72, 3.34, -0.08), Color(0.12, 0.3, 0.62))
	var l := Label3D.new()
	l.text = "ДОРОГОЙ РАЙОН\n«%s»" % NAME.to_upper()
	l.font_size = 72
	l.pixel_size = 0.006
	l.outline_size = 0
	l.modulate = Color(1, 1, 1)
	l.position = p + Vector3(0, 2.85, -0.1)
	l.rotation.y = PI
	r.add_child(l)


## Участок i: забор с воротами, газон, заезд, гараж, дом, бассейн, деревья, машина.
static func _plot(r: Region, d: MeshBuilder, glow: MeshBuilder, veg: Vegetation, i: int) -> void:
	var xf := plot_xf(i)
	var saved := d.xf
	var gsaved := glow.xf
	d.xf = saved * xf
	glow.xf = gsaved * xf
	var rng := RandomNumberGenerator.new()
	rng.seed = 4400 + i
	var hw := PLOT_W * 0.5 - 0.5
	# Газон, мощёный заезд к гаражу и дорожка к крыльцу
	d.box(Vector3(-hw, 0, -PLOT_D + 0.5), Vector3(hw, 0.03, -0.6), Color(0.3, 0.52, 0.2))
	d.box(Vector3(-21, 0, -24), Vector3(-15, 0.06, -0.3), Color(0.6, 0.56, 0.5))
	d.box(Vector3(2, 0, -24), Vector3(5, 0.06, -0.3), Color(0.68, 0.64, 0.56))
	_fence(d, glow, i, hw)
	var style: String = STYLES[i]
	var wall: Color = [Color(0.62, 0.3, 0.22), Color(0.92, 0.9, 0.86), Color(0.86, 0.72, 0.45), Color(0.72, 0.62, 0.5)][["classic", "modern", "castle", "chalet"].find(style)]
	if i >= 4:
		wall = wall.lerp(Color(0.95, 0.9, 0.8), 0.25)
	var hc := Vector3(4, 0, -34)
	match style:
		"classic":
			_classic(d, glow, hc, wall)
		"modern":
			_modern(d, glow, hc, wall)
		"castle":
			_castle(d, glow, hc, wall)
		_:
			_chalet(d, glow, hc, wall)
	# Гараж на две машины у заезда
	var g := Vector3(-18, 0, -28)
	d.box(g + Vector3(-5, 0, -4), g + Vector3(5, 3.0, 4), wall.darkened(0.06), true)
	d.box(g + Vector3(-5.3, 3.0, -4.3), g + Vector3(5.3, 3.25, 4.3), Color(0.3, 0.3, 0.33))
	for gx in [-2.4, 2.4]:
		d.box(g + Vector3(gx - 2.0, 0, 4.0), g + Vector3(gx + 2.0, 2.5, 4.04), Color(0.78, 0.78, 0.8))
		for k in 5:
			d.box(g + Vector3(gx - 2.0, 0.4 + k * 0.45, 4.04), g + Vector3(gx + 2.0, 0.43 + k * 0.45, 4.06), Color(0.62, 0.62, 0.64))
	# Бассейн и беседка — у каждого второго
	if i % 2 == 0:
		var pc := Vector3(16, 0, -60)
		d.box(pc + Vector3(-6.5, 0, -3.5), pc + Vector3(6.5, 0.25, 3.5), Color(0.9, 0.9, 0.88), true)
		glow.box(pc + Vector3(-6, 0.2, -3), pc + Vector3(6, 0.24, 3), Color(0.35, 0.75, 0.9))
		for k in 2:
			d.box(pc + Vector3(-9 + k * 1.6, 0, 4.5), pc + Vector3(-8 + k * 1.6, 0.35, 6.4), Color(0.95, 0.95, 0.95))
	else:
		var gz := Vector3(18, 0, -62)
		for c in [Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
			d.box(gz + Vector3(c.x - 0.1, 0, c.y - 0.1), gz + Vector3(c.x + 0.1, 2.4, c.y + 0.1), Color(0.45, 0.32, 0.2))
		d.quad(gz + Vector3(-2.5, 2.4, -2.5), gz + Vector3(2.5, 2.4, -2.5), gz + Vector3(0, 3.4, 0), gz + Vector3(0, 3.4, 0), Color(0.5, 0.25, 0.18), true)
		d.quad(gz + Vector3(2.5, 2.4, 2.5), gz + Vector3(-2.5, 2.4, 2.5), gz + Vector3(0, 3.4, 0), gz + Vector3(0, 3.4, 0), Color(0.48, 0.24, 0.17), true)
		d.quad(gz + Vector3(-2.5, 2.4, 2.5), gz + Vector3(-2.5, 2.4, -2.5), gz + Vector3(0, 3.4, 0), gz + Vector3(0, 3.4, 0), Color(0.46, 0.23, 0.16), true)
		d.quad(gz + Vector3(2.5, 2.4, -2.5), gz + Vector3(2.5, 2.4, 2.5), gz + Vector3(0, 3.4, 0), gz + Vector3(0, 3.4, 0), Color(0.46, 0.23, 0.16), true)
		d.box(gz + Vector3(-1.2, 0, -0.6), gz + Vector3(1.2, 0.75, 0.6), Color(0.45, 0.32, 0.2))
	# Садовые фонарики вдоль дорожки
	for z in [-6.0, -12.0, -18.0]:
		d.box(Vector3(1.4, 0, z - 0.05), Vector3(1.5, 0.7, z + 0.05), Color(0.15, 0.15, 0.16))
		glow.box(Vector3(1.32, 0.7, z - 0.1), Vector3(1.58, 0.85, z + 0.1), Color(1.0, 0.9, 0.65))
	# Машина у гаража — у всех, кроме дома №1, пока его не купили
	if i != 0:
		_car(d, Vector3(-18, 0, -16), PI, i)
	d.xf = saved
	glow.xf = gsaved
	# Туи вдоль забора и декоративные деревья в саду (в мире)
	for k in 5:
		var tz := -10.0 - k * 11.5
		for sx in [-hw + 1.5, hw - 1.5]:
			veg.add_tree(Vegetation.TreeKind.SPRUCE, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(0.5, 0.75, 0.5)), xf * Vector3(sx, 0, tz)))
	for k in 3:
		veg.add_tree(Vegetation.TreeKind.APPLE if k != 1 else Vegetation.TreeKind.BIRCH, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), xf * Vector3(rng.randf_range(-20, 24), 0, rng.randf_range(-66, -48))))
	for k in 4:
		veg.add_tree(Vegetation.TreeKind.BUSH, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 0.8), xf * Vector3(-10.0 + k * 6.0, 0, -4.0)))
	_gate_sign(r, i)


## Высокий забор: кирпичные столбы, между ними — кирпичный низ и кованые
## пики; спереди ворота (распахнуты) и калитка.
static func _fence(d: MeshBuilder, glow: MeshBuilder, i: int, hw: float) -> void:
	var brick: Color = [Color(0.6, 0.3, 0.22), Color(0.82, 0.8, 0.76), Color(0.7, 0.55, 0.35), Color(0.4, 0.38, 0.36)][i % 4]
	var iron := Color(0.1, 0.1, 0.11)
	var runs := [[Vector2(-hw, 0), Vector2(-21.5, 0)], [Vector2(-14.5, 0), Vector2(1.0, 0)], [Vector2(6.0, 0), Vector2(hw, 0)],
		[Vector2(-hw, 0), Vector2(-hw, -PLOT_D + 0.5)], [Vector2(hw, 0), Vector2(hw, -PLOT_D + 0.5)],
		[Vector2(-hw, -PLOT_D + 0.5), Vector2(hw, -PLOT_D + 0.5)]]
	for run in runs:
		var a: Vector2 = run[0]
		var c: Vector2 = run[1]
		var n := maxi(int(a.distance_to(c) / 3.0), 1)
		var front := absf(a.y) < 0.1 and absf(c.y) < 0.1
		for k in n + 1:
			var p := a.lerp(c, float(k) / n)
			d.box(Vector3(p.x - 0.25, 0, p.y - 0.25), Vector3(p.x + 0.25, 2.6, p.y + 0.25), brick, true)
			d.box(Vector3(p.x - 0.3, 2.6, p.y - 0.3), Vector3(p.x + 0.3, 2.72, p.y + 0.3), Color(0.55, 0.55, 0.53))
		var lo := Vector3(minf(a.x, c.x) - 0.12, 0, minf(a.y, c.y) - 0.12)
		var hi := Vector3(maxf(a.x, c.x) + 0.12, 1.0 if front else 2.3, maxf(a.y, c.y) + 0.12)
		d.box(lo, hi, brick.darkened(0.05), true)
		if front:
			# Кованые пики над кирпичом — сквозь них виден дом
			var len := a.distance_to(c)
			var m := int(len / 0.25)
			for k in m:
				var p := a.lerp(c, (k + 0.5) / m)
				d.box(Vector3(p.x - 0.015, 1.0, p.y - 0.015), Vector3(p.x + 0.015, 2.3, p.y + 0.015), iron)
			d.box(Vector3(lo.x, 2.2, -0.03), Vector3(hi.x, 2.25, 0.03), iron)
			d.add_collider(Vector3(lo.x, 0, -0.1), Vector3(hi.x, 2.3, 0.1))
	# Ворота: две кованые створки, распахнуты внутрь
	for s in [-1.0, 1.0]:
		var hinge := Vector3(-18.0 + s * 3.5, 0, 0)
		var tip := hinge + Vector3(-s * 1.2, 0, -3.2)
		VehicleModels.tube(d, hinge + Vector3(0, 0.15, 0), tip + Vector3(0, 0.15, 0), 0.03, iron)
		VehicleModels.tube(d, hinge + Vector3(0, 2.2, 0), tip + Vector3(0, 2.2, 0), 0.03, iron)
		for k in 9:
			var p := hinge.lerp(tip, (k + 0.5) / 9.0)
			d.box(p + Vector3(-0.015, 0.15, -0.015), p + Vector3(0.015, 2.3, 0.015), iron)
	# Калитка у дорожки, звонок с лампочкой
	glow.box(Vector3(1.2, 1.5, 0.26), Vector3(1.4, 1.65, 0.3), Color(1.0, 0.85, 0.5))


## Номер дома и табличка у ворот: дом №1 продаётся, остальные — частные.
static func _gate_sign(r: Region, i: int) -> void:
	var l := Label3D.new()
	l.name = "LipkiSign%d" % (i + 1)
	l.font_size = 64
	l.pixel_size = 0.0045
	l.outline_size = 6
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = plot_xf(i) * Vector3(-22.5, 2.9, 0.6)
	l.visibility_range_end = 60.0
	r.add_child(l)
	if i != 0:
		l.text = "%s, %d\nчастное владение" % [NAME, i + 1]
		l.modulate = Color(0.85, 0.85, 0.8)
		return
	var upd := func() -> void:
		var mine := Progress.has_item("lipki_house")
		l.text = "%s, 1\n%s" % [NAME, "ТВОЙ ДОМ" if mine else "ПРОДАЁТСЯ — %d грн" % HOUSE_PRICE]
		l.modulate = Color(0.3, 0.75, 0.3) if mine else Color(0.95, 0.75, 0.25)
	upd.call()
	Progress.home_changed.connect(upd)
	var zone := InteractZone.create("", Vector3(3.0, 2.2, 3.0))
	zone.name = "LipkiHouse1"
	zone.position = plot_xf(0) * Vector3(3.5, 0, -2.0)
	zone.prompt_fn = func() -> String:
		if Progress.has_item("lipki_house"):
			return "E — домой: лечь спать до утра"
		return "Дом №1 в Липках — %d грн. E — купить" % HOUSE_PRICE
	zone.activated.connect(func() -> void:
		if Progress.has_item("lipki_house"):
			r._world._sleep()
		else:
			buy_house())
	r.add_child(zone)
	# У чужих ворот — подсказка, что не продаётся
	for k in range(1, 8):
		var z2 := InteractZone.create("", Vector3(3.0, 2.2, 2.0))
		z2.name = "LipkiPrivate%d" % (k + 1)
		z2.position = gate_pos(k)
		z2.prompt_fn = func() -> String: return "%s, %d — частный дом, не продаётся" % [NAME, k + 1]
		r.add_child(z2)


## Купить дом №1: дорого, зато свой дом в Липках. true — купил.
static func buy_house() -> bool:
	if Progress.has_item("lipki_house"):
		return false
	if not GameManager.spend(HOUSE_PRICE):
		return false
	Progress.add_item("lipki_house")
	QuestManager.event("lipki_house")
	SoundLibrary.play("quest")
	GameManager.notify("Дом №1 в Липках — твой! Здесь можно спать (E у двери)")
	return true


# --- Дома ---------------------------------------------------------------------

## Окна этажа по периметру: светятся вечером.
static func _windows(glow: MeshBuilder, c: Vector3, hx: float, hz: float, y: float, h: float, step: float) -> void:
	var x := -hx + step * 0.6
	while x < hx - step * 0.4:
		for s in [-1.0, 1.0]:
			glow.box(c + Vector3(x - 0.7, y, s * hz - 0.02), c + Vector3(x + 0.7, y + h, s * hz + 0.02), Color(0.95, 0.84, 0.55))
		x += step
	var z := -hz + step * 0.6
	while z < hz - step * 0.4:
		for s in [-1.0, 1.0]:
			glow.box(c + Vector3(s * hx - 0.02, y, z - 0.7), c + Vector3(s * hx + 0.02, y + h, z + 0.7), Color(0.95, 0.84, 0.55))
		z += step


## Четырёхскатная крыша над прямоугольником (центр c, полуразмеры, высота конька).
static func _hip_roof(d: MeshBuilder, c: Vector3, hx: float, hz: float, y: float, h: float, col: Color) -> void:
	var r0 := hx - hz * 0.9
	d.quad(c + Vector3(-hx, y, hz), c + Vector3(hx, y, hz), c + Vector3(r0, y + h, 0), c + Vector3(-r0, y + h, 0), col, true)
	d.quad(c + Vector3(hx, y, -hz), c + Vector3(-hx, y, -hz), c + Vector3(-r0, y + h, 0), c + Vector3(r0, y + h, 0), col.darkened(0.06), true)
	d.tri(c + Vector3(-hx, y, -hz), c + Vector3(-hx, y, hz), c + Vector3(-r0, y + h, 0), col.darkened(0.1), true)
	d.tri(c + Vector3(hx, y, hz), c + Vector3(hx, y, -hz), c + Vector3(r0, y + h, 0), col.darkened(0.1), true)


## Классика: два этажа красного кирпича, белый пояс, черепица, крыльцо с
## колоннами и балконом.
static func _classic(d: MeshBuilder, glow: MeshBuilder, c: Vector3, wall: Color) -> void:
	d.box(c + Vector3(-9, 0, -6.5), c + Vector3(9, 0.6, 6.5), Color(0.6, 0.58, 0.55))
	d.box(c + Vector3(-8.8, 0.6, -6.3), c + Vector3(8.8, 7.0, 6.3), wall, true)
	d.box(c + Vector3(-8.85, 3.7, -6.35), c + Vector3(8.85, 3.95, 6.35), Color(0.94, 0.93, 0.9))
	_hip_roof(d, c, 9.6, 7.1, 7.0, 3.4, Color(0.6, 0.2, 0.15))
	_windows(glow, c, 8.82, 6.32, 1.4, 1.8, 3.2)
	_windows(glow, c, 8.82, 6.32, 4.5, 1.8, 3.2)
	# Крыльцо с колоннами к бульвару (+z) и балкон
	d.box(c + Vector3(-3.4, 0, 6.3), c + Vector3(3.4, 0.6, 9.0), Color(0.88, 0.87, 0.84), true)
	for x in [-2.9, -1.0, 1.0, 2.9]:
		PersonModel.limb(d, c + Vector3(x, 0.6, 8.6), c + Vector3(x, 3.8, 8.6), Vector2(0.2, 0.2), Vector2(0.17, 0.17), Color(0.96, 0.96, 0.93), true)
	d.box(c + Vector3(-3.6, 3.8, 6.3), c + Vector3(3.6, 4.05, 9.2), Color(0.94, 0.93, 0.9))
	for x in range(-7, 8):
		d.box(c + Vector3(x * 0.48 - 0.03, 4.05, 9.05), c + Vector3(x * 0.48 + 0.03, 4.9, 9.12), Color(0.95, 0.95, 0.93))
	d.box(c + Vector3(-3.6, 4.85, 9.0), c + Vector3(3.6, 4.95, 9.2), Color(0.95, 0.95, 0.93))
	d.box(c + Vector3(-0.8, 0.6, 6.3), c + Vector3(0.8, 3.0, 6.34), Color(0.35, 0.2, 0.12))


## Современный: белая штукатурка, плоская крыша, второй этаж нависает,
## панорамные окна, терраса на крыше.
static func _modern(d: MeshBuilder, glow: MeshBuilder, c: Vector3, wall: Color) -> void:
	var dark := Color(0.18, 0.18, 0.2)
	d.box(c + Vector3(-9, 0, -6), c + Vector3(7, 3.4, 6), wall, true)
	d.box(c + Vector3(-7, 3.4, -6.5), c + Vector3(10, 6.8, 7.5), wall.darkened(0.04), true)
	d.box(c + Vector3(-7.3, 6.8, -6.8), c + Vector3(10.3, 7.1, 7.8), dark)
	for x in range(-7, 11):
		d.box(c + Vector3(x - 0.02, 7.1, 7.7), c + Vector3(x + 0.02, 8.0, 7.75), Color(0.75, 0.78, 0.8))
	d.box(c + Vector3(-7.3, 7.95, 7.65), c + Vector3(10.3, 8.02, 7.8), Color(0.75, 0.78, 0.8))
	# Панорамные окна: внизу во всю стену, вверху полосой
	glow.box(c + Vector3(-7, 0.2, 6.0), c + Vector3(5, 3.1, 6.04), Color(0.75, 0.85, 0.92))
	glow.box(c + Vector3(-6, 4.0, 7.5), c + Vector3(9, 6.3, 7.54), Color(0.75, 0.85, 0.92))
	glow.box(c + Vector3(10.0, 4.0, -5.5), c + Vector3(10.04, 6.3, 6.5), Color(0.75, 0.85, 0.92))
	for x in [-7.0, -3.0, 1.0, 5.0]:
		d.box(c + Vector3(x - 0.05, 0.2, 6.04), c + Vector3(x + 0.05, 3.1, 6.08), dark)
	d.box(c + Vector3(-9.1, 0, 6.0), c + Vector3(-8.0, 3.4, 6.1), Color(0.45, 0.32, 0.22))


## «Замок»: три этажа жёлтого кирпича, круглая башенка с островерхой
## крышей, зелёная кровля — мечта новых русских.
static func _castle(d: MeshBuilder, glow: MeshBuilder, c: Vector3, wall: Color) -> void:
	d.box(c + Vector3(-8, 0, -6.5), c + Vector3(8, 0.7, 6.5), Color(0.5, 0.48, 0.45))
	d.box(c + Vector3(-7.8, 0.7, -6.3), c + Vector3(7.8, 10.0, 6.3), wall, true)
	for y in [3.6, 6.8]:
		d.box(c + Vector3(-7.85, y, -6.35), c + Vector3(7.85, y + 0.25, 6.35), wall.darkened(0.2))
	_hip_roof(d, c, 8.5, 7.0, 10.0, 3.0, Color(0.2, 0.45, 0.3))
	for y in [1.5, 4.6, 7.8]:
		_windows(glow, c, 7.82, 6.32, y, 1.7, 3.0)
	var t := c + Vector3(8.2, 0, 6.0)
	PersonModel.limb(d, t, t + Vector3(0, 12.0, 0), Vector2(2.4, 2.4), Vector2(2.4, 2.4), wall.lightened(0.05), true)
	PersonModel.limb(d, t + Vector3(0, 12.0, 0), t + Vector3(0, 15.5, 0), Vector2(2.8, 2.8), Vector2(0.05, 0.05), Color(0.2, 0.45, 0.3), true)
	for y in [2.0, 5.2, 8.4]:
		glow.box(t + Vector3(-0.5, y, 2.38), t + Vector3(0.5, y + 1.6, 2.42), Color(0.95, 0.84, 0.55))
	d.box(c + Vector3(-1, 0.7, 6.3), c + Vector3(1, 3.4, 6.34), Color(0.3, 0.18, 0.1))
	d.box(c + Vector3(-2.5, 0, 6.3), c + Vector3(2.5, 0.7, 8.5), Color(0.6, 0.58, 0.55), true)


## Шале: каменный цоколь, обшитый деревом первый этаж, крутая двускатная
## крыша до земли почти, треугольное окно во весь фронтон.
static func _chalet(d: MeshBuilder, glow: MeshBuilder, c: Vector3, wall: Color) -> void:
	var stone := Color(0.55, 0.53, 0.5)
	var wood := Color(0.5, 0.33, 0.2)
	d.box(c + Vector3(-8, 0, -6), c + Vector3(8, 1.2, 6), stone, true)
	d.box(c + Vector3(-7.8, 1.2, -5.8), c + Vector3(7.8, 4.2, 5.8), wood, true)
	for y in range(0, 10):
		d.box(c + Vector3(-7.85, 1.3 + y * 0.3, -5.85), c + Vector3(7.85, 1.33 + y * 0.3, 5.85), wood.darkened(0.2))
	var roof := Color(0.25, 0.2, 0.18)
	var top := 10.0
	d.quad(c + Vector3(-8.6, 3.6, 6.6), c + Vector3(-8.6, 3.6, -6.6), c + Vector3(0, top, -6.6), c + Vector3(0, top, 6.6), roof, true)
	d.quad(c + Vector3(8.6, 3.6, -6.6), c + Vector3(8.6, 3.6, 6.6), c + Vector3(0, top, 6.6), c + Vector3(0, top, -6.6), roof.darkened(0.06), true)
	for s in [-1.0, 1.0]:
		d.tri(c + Vector3(-7.8, 4.2, s * 5.8), c + Vector3(7.8, 4.2, s * 5.8), c + Vector3(0, top - 0.4, s * 5.8), wall, true)
	# Фронтон к бульвару — стеклянный
	glow.tri(c + Vector3(-5.5, 4.4, 5.84), c + Vector3(5.5, 4.4, 5.84), c + Vector3(0, top - 1.6, 5.84), Color(0.8, 0.88, 0.92), true)
	_windows(glow, c, 7.82, 5.82, 1.9, 1.6, 3.2)
	# Терраса на столбах
	d.box(c + Vector3(-6, 1.2, 5.8), c + Vector3(6, 1.35, 9.0), wood.lightened(0.1), true)
	for x in [-5.7, 0.0, 5.7]:
		d.box(c + Vector3(x - 0.12, 0, 8.7), c + Vector3(x + 0.12, 1.2, 8.95), wood)


## Дорогая машина у гаража: модель из VehicleModels (без физики — коробка-
## препятствие), цвет и вид — по номеру участка.
static func _car(d: MeshBuilder, p: Vector3, yaw: float, i: int) -> void:
	var saved := d.xf
	d.xf = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var paint: Color = [Color(0.04, 0.04, 0.05), Color(0.9, 0.9, 0.88), Color(0.12, 0.2, 0.38), Color(0.55, 0.06, 0.06)][i % 4]
	var wheels: Array
	var r := 0.33
	match i % 3:
		0:
			VehicleModels.volga(d, paint, d)
			wheels = [Vector3(-0.8, 0.33, -1.42), Vector3(0.8, 0.33, -1.42), Vector3(-0.8, 0.33, 1.42), Vector3(0.8, 0.33, 1.42)]
		1:
			VehicleModels.niva(d, paint, d)
			wheels = [Vector3(-0.76, 0.33, -1.1), Vector3(0.76, 0.33, -1.1), Vector3(-0.76, 0.33, 1.1), Vector3(0.76, 0.33, 1.1)]
		_:
			VehicleModels.zhiguli(d, paint, false, d, true)
			r = 0.29
			wheels = [Vector3(-0.68, 0.3, -1.22), Vector3(0.68, 0.3, -1.22), Vector3(-0.68, 0.3, 1.2), Vector3(0.68, 0.3, 1.2)]
	var body := d.xf
	for w in wheels:
		d.xf = body * Transform3D(Basis.IDENTITY, w)
		VehicleModels.car_wheel(d, r, 0.2, Color(0.75, 0.76, 0.78))
	d.xf = body
	d.add_collider(Vector3(-0.95, 0, -2.4), Vector3(0.95, 1.5, 2.4))
	d.xf = saved
