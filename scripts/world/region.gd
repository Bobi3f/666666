class_name Region
extends Node3D
## Район вокруг Каменки: ещё четыре села с жителями, река Быстрая с мостами,
## грунтовки между сёлами, леса, поля и озеро. Край мира — ±2000 м.
##
## Земля, берега, дороги и деревья — в общем меше мира (world.gd). Дома,
## заборы и камыш — в своём меше кусками по 100 м с дальностью видимости:
## телефон рисует только ближние сёла.
##
## Данные (река, дороги, сёла) — статические: по ним машина узнаёт грунтовку,
## карта рисует район, лес не растёт на дорогах.

const Villagers := preload("res://scripts/world/villagers.gd")
const HALF := 2000.0
## Сёла дальше этого не рисуются (куски меша домов): на телефоне ближе.
static func view_range() -> float:
	return [380.0, 500.0, 700.0][SettingsManager.detail]
const RIVER_HALF := 8.0
## Опорные точки реки с севера на юг; между ними — плавная кривая.
const RIVER := [Vector2(420, -2000), Vector2(350, -1600), Vector2(380, -1200), Vector2(340, -950), Vector2(330, -700), Vector2(300, -550), Vector2(350, -420), Vector2(320, -300),
	Vector2(280, -150), Vector2(310, 0), Vector2(360, 150), Vector2(330, 300), Vector2(290, 450),
	Vector2(320, 700), Vector2(370, 950), Vector2(340, 1200), Vector2(300, 1600), Vector2(360, 2000)]
const ROAD_HALF := 3.0

## Сёла: центр улицы (улица вдоль X, 110 м), с какого конца въезд,
## что говорят жители. Дома по обе стороны улицы.
const VILLAGES := [
	{"name": "Озерцово", "c": Vector2(-460, -300), "entry": 1, "lines": [
		"За селом озеро — караси с ладонь. Мостки есть, бери удочку.",
		"Районный автобус раз в полдня к нам заходит, в Каменку — хоть каждый час.",
		"Раньше тут клуб был, кино крутили. Теперь телевизор у каждого.",
	]},
	{"name": "Первомай", "c": Vector2(475, -350), "entry": -1, "lines": [
		"За рекой живём! Мост деревянный — по нему не гони, доски старые.",
		"Из Первомая до города через Заречье ближе, по восточной грунтовке.",
		"Весной дорогу так развозит, что только на тракторе и проедешь.",
	]},
	{"name": "Тошики", "c": Vector2(-430, 380), "entry": 1, "lines": [
		"Тошики — село маленькое, зато грибов в лесу — хоть косой коси.",
		"В Дубраве на юге кабаны ходят, осторожней там по вечерам.",
		"У нас каждый второй на «Ниве». Дороги такие — иначе никак.",
	]},
	{"name": "Заречье", "c": Vector2(490, 300), "entry": -1, "lines": [
		"Заречье — потому что за Быстрой. Мост на трассе ещё при Союзе строили.",
		"Колхоз наш развалился, теперь кто во что горазд: кто пчёлы, кто картошка.",
		"Внук в городе на СТО работает, говорит — деньги хорошие.",
	]},
	{"name": "Сосновка", "c": Vector2(-850, -750), "entry": 1, "lines": [
		"Сосновка — самый край района. Дальше только лес да болота.",
		"Из Озерцово к нам дорога через бор — в дождь не суйся.",
		"Летом черники столько, что вёдрами носим.",
	]},
	{"name": "Красный Яр", "c": Vector2(850, -800), "entry": -1, "lines": [
		"Красный Яр — за Первомаем, через лес. Глина у нас красная, отсюда и имя.",
		"Раньше кирпичный завод был, теперь развалины одни.",
		"Автобус районный к нам редко, но доходит.",
	]},
	{"name": "Берёзовка", "c": Vector2(-900, 750), "entry": 1, "lines": [
		"Берёзовка — тишина, воздух. Городские на лето дачи снимают.",
		"Из Тошиков к нам одна дорога, зимой её не чистят.",
		"Пасека у деда Степана — мёд лучший в районе.",
	]},
	{"name": "Лужки", "c": Vector2(850, 900), "entry": -1, "lines": [
		"Лужки — луга заливные, весной Быстрая разливается до самого села.",
		"Коров у нас больше, чем людей. Молоко в город возим.",
		"Из Заречья к нам на «Жигулях» доедешь, если сухо.",
	]},
	{"name": "Горки", "c": Vector2(0, -1600), "entry": -1, "lines": [
		"Горки — на самом севере. Дорога от Каменки через поля, мимо леса.",
		"Зимой к нам только трактор пробьётся, а летом — красота.",
		"Тут раньше пионерский лагерь стоял, в лесу ещё корпуса видны.",
	]},
	{"name": "Заозерье", "c": Vector2(-1500, -150), "entry": 1, "lines": [
		"Заозерье — последнее село на западе по трассе. Дальше — соседний район.",
		"Дальнобойщики у нас ночуют, кафе бы открыть — да денег нет.",
		"До Каменки по трассе — минут пятнадцать на «Жигулях».",
	]},
	{"name": "Степное", "c": Vector2(1550, 150), "entry": -1, "lines": [
		"Степное — на востоке, за рекой и лесом. Тут ветер всегда.",
		"Пшеницу сеем, зерно в город возим. Грузовик бы свой...",
		"Автобус районный заходит, но раз в полдня.",
	]},
	{"name": "Малиновка", "c": Vector2(150, 1600), "entry": 1, "lines": [
		"Малиновка — на юге, вдоль Быстрой. Малины в оврагах — море.",
		"К нам дорога от трассы у города, прямо на юг, не заблудишься.",
		"Рыбаки из города к нам на Быструю ездят — клюёт хорошо.",
	]},
]
## Дороги (грунт): ломаные от трассы или полевой дороги к сёлам. Улицы
## сёл добавляются к ним сами.
const ROADS := [
	[Vector2(-380, -4.5), Vector2(-380, -160), Vector2(-398, -262), Vector2(-405, -300)],
	[Vector2(-6.5, -89), Vector2(-6.5, -225), Vector2(150, -300), Vector2(420, -350)],
	[Vector2(-300, 4.5), Vector2(-300, 160), Vector2(-360, 300), Vector2(-375, 380)],
	[Vector2(430, 4.5), Vector2(430, 160), Vector2(435, 300)],
	[Vector2(560, -4.5), Vector2(560, -200), Vector2(530, -350)],
	[Vector2(-518, -300), Vector2(-700, -450), Vector2(-770, -650), Vector2(-795, -750)],
	[Vector2(533, -350), Vector2(700, -500), Vector2(760, -700), Vector2(795, -800)],
	[Vector2(-488, 380), Vector2(-650, 500), Vector2(-800, 650), Vector2(-845, 750)],
	[Vector2(548, 300), Vector2(700, 550), Vector2(770, 800), Vector2(795, 900)],
	[Vector2(-6.5, -225), Vector2(-60, -700), Vector2(-120, -1200), Vector2(-58, -1600)],
	[Vector2(-1380, -4.5), Vector2(-1380, -120), Vector2(-1442, -150)],
	[Vector2(1420, 4.5), Vector2(1420, 120), Vector2(1492, 150)],
	[Vector2(250, 4.5), Vector2(250, 600), Vector2(260, 1200), Vector2(208, 1600)],
]
## Дальние леса — реже: их почти всегда видно только издали.
const FAR_FORESTS := [
	Rect2(-2000, -2000, 700, 600), Rect2(-1000, -2000, 800, 300), Rect2(600, -2000, 900, 500),
	Rect2(1600, -1200, 400, 900), Rect2(-2000, -1100, 450, 700), Rect2(-2000, 300, 500, 900),
	Rect2(-1200, 1400, 900, 600), Rect2(500, 1400, 1000, 600), Rect2(1600, 500, 400, 1000),
]
const FORESTS := [
	Rect2(-700, -700, 260, 300), Rect2(-330, -650, 250, 300), Rect2(520, -680, 180, 260),
	Rect2(-700, 120, 220, 200), Rect2(-200, 450, 350, 250), Rect2(560, 420, 140, 280),
	Rect2(80, -650, 180, 180), Rect2(-260, 205, 200, 160),
	Rect2(-1200, -1200, 400, 350), Rect2(-600, -1200, 500, 300), Rect2(400, -1200, 500, 250),
	Rect2(1000, -600, 200, 500), Rect2(-1200, -300, 250, 500), Rect2(-1200, 950, 500, 250),
	Rect2(-300, 850, 600, 350), Rect2(1000, 300, 200, 500), Rect2(450, 1050, 450, 150),
]
const FIELDS := [
	[Rect2(-520, -270, 100, 40), Color(0.78, 0.68, 0.33)],
	[Rect2(420, -420, 110, 40), Color(0.4, 0.3, 0.2)],
	[Rect2(-490, 412, 110, 43), Color(0.36, 0.55, 0.2)],
	[Rect2(440, 222, 110, 44), Color(0.78, 0.68, 0.33)],
	[Rect2(-910, -718, 110, 40), Color(0.36, 0.55, 0.2)],
	[Rect2(795, -872, 110, 40), Color(0.78, 0.68, 0.33)],
	[Rect2(-960, 782, 110, 40), Color(0.4, 0.3, 0.2)],
	[Rect2(795, 828, 110, 40), Color(0.36, 0.55, 0.2)],
	[Rect2(-55, -1672, 110, 40), Color(0.78, 0.68, 0.33)],
	[Rect2(-1560, -118, 110, 40), Color(0.36, 0.55, 0.2)],
	[Rect2(1495, 182, 110, 40), Color(0.78, 0.68, 0.33)],
	[Rect2(95, 1632, 110, 40), Color(0.4, 0.3, 0.2)],
]
const LAKE := Vector2(-560, -380)
const LAKE_R := Vector2(30, 20)
const BUS_FARE := 25

## Дома по отступу от центра улицы: [x, сторона] (-1 — север, 1 — юг).
const HOUSE_X := [-44.0, -22.0, 0.0, 20.0]
const WALLS := [Color(0.45, 0.6, 0.75), Color(0.55, 0.68, 0.45), Color(0.85, 0.78, 0.55),
	Color(0.82, 0.8, 0.76), Color(0.58, 0.43, 0.3), Color(0.72, 0.55, 0.6)]
const ROOFS := [Color(0.42, 0.44, 0.46), Color(0.55, 0.25, 0.18), Color(0.28, 0.42, 0.3), Color(0.5, 0.5, 0.52)]

static var _river: PackedVector2Array = PackedVector2Array()
static var _segs: Array = []  # [a, b] — все отрезки дорог и улиц

var visited: Array = []
var _world: Node3D
var _d := MeshBuilder.new()
var _rng := RandomNumberGenerator.new()
var _bridges: Array = []  # [точка, направление дороги, полуширина настила]
var _check := 0.0


func _ready() -> void:
	add_to_group("persist")


# --- Данные района (для машины, карты, леса) ---------------------------------

## Река — плавная кривая через опорные точки, шаг около 4 м.
static func river() -> PackedVector2Array:
	if _river.is_empty():
		var n := RIVER.size()
		for i in n - 1:
			var p0: Vector2 = RIVER[maxi(i - 1, 0)]
			var p1: Vector2 = RIVER[i]
			var p2: Vector2 = RIVER[i + 1]
			var p3: Vector2 = RIVER[mini(i + 2, n - 1)]
			var steps := int(p1.distance_to(p2) / 4.0)
			for k in steps:
				var t := float(k) / steps
				_river.append(0.5 * (p1 * 2.0 + (p2 - p0) * t + (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t * t
					+ (p1 * 3.0 - p0 - p2 * 3.0 + p3) * t * t * t))
		_river.append(RIVER[n - 1])
	return _river


## Все дороги района и улицы сёл отрезками [a, b].
static func segments() -> Array:
	if _segs.is_empty():
		for r in ROADS:
			for i in (r as Array).size() - 1:
				_segs.append([r[i], r[i + 1]])
		for v in VILLAGES:
			var c: Vector2 = v.c
			_segs.append([c + Vector2(-58, 0), c + Vector2(58, 0)])
	return _segs


static func _dist_line(pts: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for i in pts.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
	return best


static func road_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for s in segments():
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, s[0], s[1])))
	return best


## На грунтовке района (для покрытия под колёсами).
static func on_road(x: float, z: float) -> bool:
	# Внутри Каменки из дорог района — только съезд на север у полевой дороги
	if absf(x) < 195.0 and absf(z) < 195.0 and (x < -10.0 or x > -3.0):
		return false
	return road_dist(x, z) < ROAD_HALF + 0.2


static func river_dist(x: float, z: float) -> float:
	if x < 250.0 or x > 400.0:
		return INF
	return _dist_line(river(), Vector2(x, z))


## Какое село рядом (до 75 м от центра улицы), иначе пусто.
static func village_at(x: float, z: float) -> String:
	for v in VILLAGES:
		if (v.c as Vector2).distance_to(Vector2(x, z)) < 75.0:
			return v.name
	return ""


## Где можно сажать лес: не на дорогах, не в реке, не в сёлах, полях и озере.
static func tree_ok(x: float, z: float) -> bool:
	if road_dist(x, z) < ROAD_HALF + 3.0 or river_dist(x, z) < RIVER_HALF + 6.0:
		return false
	var p := Vector2(x, z)
	for v in VILLAGES:
		var c: Vector2 = v.c
		if Rect2(c.x - 66, c.y - 38, 132, 76).has_point(p):
			return false
	for f in FIELDS:
		if (f[0] as Rect2).grow(3.0).has_point(p):
			return false
	var l := (p - LAKE) / (LAKE_R * 1.3)
	return l.length() > 1.0


## Точка у остановки села: сюда высаживает районный автобус.
static func stop_pos(i: int) -> Vector3:
	var c: Vector2 = VILLAGES[i].c
	return Vector3(c.x + 40.0 * VILLAGES[i].entry, 0, c.y + 5.0)


## Где стоит сельский магазин (перед дверью, на улице).
static func shop_pos(i: int) -> Vector3:
	var c: Vector2 = VILLAGES[i].c
	return Vector3(c.x + 42.0 * VILLAGES[i].entry, 0, c.y - 2.0)


## Все дома района: [центр, поворот] — для карты.
static func houses() -> Array:
	var out := []
	for v in VILLAGES:
		var c: Vector2 = v.c
		for side in [-1, 1]:
			for hx in HOUSE_X:
				out.append([Vector2(c.x + hx * v.entry, c.y + side * 16.0), 0.0 if side < 0 else PI])
	return out


# --- Постройка ----------------------------------------------------------------

## Строит район: glow — окна (общий меш мира). Земля, дороги и река —
## в своём меше крупными кусками по 500 м: вдаль видно всё, а вызовов
## отрисовки на телефоне мало. Дома, заборы и тени деревьев — в меше с
## дальностью видимости.
func build(world: Node3D, _world_b: MeshBuilder, glow: MeshBuilder, veg: Vegetation) -> void:
	_world = world
	_rng.seed = 7001
	_d.chunk_size = 100.0
	var b := MeshBuilder.new()
	b.chunk_size = 500.0
	_ground(b)
	_highway(b)
	_find_bridges()
	_river_build(b)
	_roads(b, veg)
	_lake(b)
	for f in FIELDS:
		var r: Rect2 = f[0]
		b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0.03, r.end.y), f[1])
		veg.block(r.position.x, r.position.y, r.end.x, r.end.y)
	for i in VILLAGES.size():
		_village(i, b, glow, veg)
	_forests(_d)
	_district_bus()
	var ground := b.build_chunked()
	ground.name = "RegionGround"
	for c in ground.get_children():
		# Дальность задана — общая настройка мелочи (world.gd) её не урежет
		(c as GeometryInstance3D).visibility_range_end = HALF * 4.0
	add_child(ground)
	var ground_body := b.build_body()
	ground_body.name = "RegionGroundCollision"
	add_child(ground_body)
	var mesh := _d.build_chunked()
	mesh.name = "RegionMesh"
	for c in mesh.get_children():
		var gi := c as GeometryInstance3D
		gi.visibility_range_end = view_range()
		gi.visibility_range_end_margin = 20.0
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	add_child(mesh)
	SettingsManager.changed.connect(func() -> void:
		for c in mesh.get_children():
			(c as GeometryInstance3D).visibility_range_end = view_range())
	var body := _d.build_body()
	body.name = "RegionCollision"
	add_child(body)


## Земля вокруг Каменки: сетка 20 м, пятна того же шума, что и в Каменке.
func _ground(b: MeshBuilder) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.02
	var detail := FastNoiseLite.new()
	detail.seed = 8
	detail.frequency = 0.11
	var grass := Color(0.32, 0.47, 0.21)
	var dry := Color(0.47, 0.5, 0.27)
	var damp := Color(0.24, 0.38, 0.17)
	var bare := Color(0.45, 0.4, 0.28)
	var cell := 20.0
	var n := int(HALF * 2.0 / cell)
	var col := func(x: float, z: float) -> Color:
		var c := grass.lerp(dry, clampf(noise.get_noise_2d(x, z) * 0.8 + 0.35, 0.0, 1.0))
		var d := detail.get_noise_2d(x * 0.3, z * 0.3)
		if d > 0.35:
			c = c.lerp(bare, (d - 0.35) * 0.6)
		elif d < -0.3:
			c = c.lerp(damp, (-0.3 - d) * 1.2)
		return c
	for i in n:
		for j in n:
			var x0 := -HALF + i * cell
			var z0 := -HALF + j * cell
			# Каменка со своей землёй — посередине
			if x0 >= -200.0 and x0 < 200.0 and z0 >= -200.0 and z0 < 200.0:
				continue
			var pts := [Vector3(x0, 0, z0 + cell), Vector3(x0 + cell, 0, z0 + cell), Vector3(x0 + cell, 0, z0), Vector3(x0, 0, z0)]
			var cols: Array[Color] = []
			for p in pts:
				cols.append(col.call((p as Vector3).x, (p as Vector3).z))
			b.quad_vc(pts, cols)


## Трасса за пределами Каменки — до края района.
func _highway(b: MeshBuilder) -> void:
	var asphalt := Color(0.24, 0.24, 0.25)
	var dirt := Color(0.46, 0.39, 0.28)
	var white := Color(0.92, 0.92, 0.9)
	for span in [[-HALF, -200.0], [200.0, HALF]]:
		var x0: float = span[0]
		var x1: float = span[1]
		b.box(Vector3(x0, 0, -5.5), Vector3(x1, 0.02, 5.5), dirt)
		b.box(Vector3(x0, 0, -4), Vector3(x1, 0.05, 4), asphalt, true)
		var x := x0 + 2.0
		while x < x1 - 3.0:
			b.box(Vector3(x, 0.05, -0.08), Vector3(x + 3.0, 0.06, 0.08), white)
			x += 6.0
		for zz in [-3.7, 3.55]:
			b.box(Vector3(x0, 0.05, zz), Vector3(x1, 0.06, zz + 0.15), white)
	# Указатели на съездах к сёлам
	_world._sign(b, Vector3(-383.8, 0, -6.2), 0.0, "↑ Озерцово 4 км", 1.7)
	_world._sign(b, Vector3(-303.8, 0, 6.2), PI, "↓ Тошики 5 км", 1.5)
	_world._sign(b, Vector3(426.2, 0, 6.2), PI, "↓ Заречье 4 км", 1.6)
	_world._sign(b, Vector3(556.2, 0, -6.2), 0.0, "↑ Первомай 5 км", 1.7)
	_world._sign(b, Vector3(-10.0, 0, -92.0), 0.0, "↑ Первомай 7 км", 1.7)


## Где дороги (и трасса) пересекают реку — там мосты.
func _find_bridges() -> void:
	var lines: Array = [[Vector2(-HALF, 0), Vector2(HALF, 0), 5.8]]
	for s in segments():
		lines.append([s[0], s[1], ROAD_HALF + 0.6])
	var rv := river()
	for l in lines:
		for i in rv.size() - 1:
			var hit = Geometry2D.segment_intersects_segment(l[0], l[1], rv[i], rv[i + 1])
			# Одна и та же переправа может попасть на стык двух кусков реки
			if hit != null and _bridges.all(func(o: Array) -> bool: return (o[0] as Vector2).distance_to(hit) > 5.0):
				_bridges.append([hit, ((l[1] as Vector2) - (l[0] as Vector2)).normalized(), l[2]])


## Не под мостом ли точка (вода и берега там не строятся).
func _under_bridge(p: Vector2, extra := 0.0) -> bool:
	for br in _bridges:
		var c: Vector2 = br[0]
		var u: Vector2 = br[1]
		var d := p - c
		if absf(d.dot(u)) < 22.0 and absf(d.cross(u)) < float(br[2]) + extra:
			return true
	return false


## Полоса вдоль реки (вода или берег). У моста режем её на куски около
## метра вдоль и поперёк, чтобы вырез точно шёл по краю настила.
func _strip(to: MeshBuilder, a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2, y: float, color: Color) -> void:
	var mid := (a0 + a1 + b0 + b1) * 0.25
	var near := false
	for br in _bridges:
		if (br[0] as Vector2).distance_to(mid) < 45.0:
			near = true
	var k := 4 if near else 1
	var m := maxi(1, int(a0.distance_to(b0))) if near else 1
	for s in k:
		var t0 := float(s) / k
		var t1 := float(s + 1) / k
		for r in m:
			var u0 := float(r) / m
			var u1 := float(r + 1) / m
			var p00 := a0.lerp(a1, t0).lerp(b0.lerp(b1, t0), u0)
			var p01 := a0.lerp(a1, t1).lerp(b0.lerp(b1, t1), u0)
			var p10 := a0.lerp(a1, t0).lerp(b0.lerp(b1, t0), u1)
			var p11 := a0.lerp(a1, t1).lerp(b0.lerp(b1, t1), u1)
			if near and _under_bridge((p00 + p01 + p10 + p11) * 0.25, 0.1):
				continue
			_flat_quad(to, [Vector3(p00.x, y, p00.y), Vector3(p01.x, y, p01.y), Vector3(p11.x, y, p11.y), Vector3(p10.x, y, p10.y)], color)


## Горизонтальный четырёхугольник лицом вверх, в каком бы порядке ни шли точки.
func _flat_quad(to: MeshBuilder, p: Array, color: Color) -> void:
	var n: Vector3 = ((p[1] as Vector3) - p[0]).cross((p[2] as Vector3) - p[0])
	if n.y >= 0.0:
		to.quad(p[0], p[1], p[2], p[3], color)
	else:
		to.quad(p[0], p[3], p[2], p[1], color)


func _river_build(b: MeshBuilder) -> void:
	var rv := river()
	var water := Color(0.2, 0.32, 0.38)
	var bank := Color(0.38, 0.32, 0.22)
	var sand := Color(0.6, 0.55, 0.4)
	var norms: Array[Vector2] = []
	for i in rv.size():
		var d := rv[mini(i + 1, rv.size() - 1)] - rv[maxi(i - 1, 0)]
		norms.append(Vector2(-d.y, d.x).normalized())
	for i in rv.size() - 1:
		var p0 := rv[i]
		var p1 := rv[i + 1]
		var n0 := norms[i]
		var n1 := norms[i + 1]
		# Ширина чуть гуляет
		var w0 := RIVER_HALF + sin(p0.y * 0.013) * 1.5
		var w1 := RIVER_HALF + sin(p1.y * 0.013) * 1.5
		_strip(_world._water_b, p0 + n0 * w0, p1 + n1 * w1, p0 - n0 * w0, p1 - n1 * w1, 0.045, water)
		for s in [-1.0, 1.0]:
			var e0: Vector2 = p0 + n0 * w0 * s
			var e1: Vector2 = p1 + n1 * w1 * s
			_strip(b, e0, e1, e0 + n0 * 3.5 * s, e1 + n1 * 3.5 * s, 0.03, bank if int(p0.y / 60.0) % 3 != 0 else sand)
			# Берег — невидимая стенка: в реку не въехать, только по мосту
			var d: Vector2 = e1 - e0
			var yaw := atan2(d.x, d.y)
			for q in 4:
				var mid: Vector2 = e0.lerp(e1, (q + 0.5) / 4.0) + (n0 + n1) * 0.25 * s
				if _under_bridge(mid, 0.3):
					continue
				b.xf = Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, 0, mid.y))
				b.add_collider(Vector3(-0.2, 0, -d.length() * 0.125 - 0.1), Vector3(0.2, 1.3, d.length() * 0.125 + 0.1))
				b.xf = Transform3D.IDENTITY
			# Камыш
			if _rng.randf() < 0.35 and not _under_bridge(e0, 3.0):
				for k in 4:
					var q: Vector2 = e0 + n0 * s * _rng.randf_range(-0.4, 1.4) + (e1 - e0) * _rng.randf()
					var h := _rng.randf_range(0.8, 1.6)
					_d.box(Vector3(q.x - 0.03, 0, q.y - 0.03), Vector3(q.x + 0.03, h, q.y + 0.03), Color(0.35, 0.45, 0.2))
	for br in _bridges:
		_bridge(b, br)


## Мост: на трассе — бетонный с отбойником, на грунтовке — деревянный.
func _bridge(b: MeshBuilder, br: Array) -> void:
	var c: Vector2 = br[0]
	var u: Vector2 = br[1]
	var half: float = br[2]
	var yaw := atan2(u.x, u.y)
	var highway := absf(c.y) < 1.0 and absf(u.y) < 0.01
	b.xf = Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, 0, c.y))
	var length := 30.0
	if highway:
		var concrete := Color(0.62, 0.62, 0.6)
		for s in [-1.0, 1.0]:
			# Бордюр, отбойник на столбиках, край плиты
			b.box(Vector3(s * half - 0.4, 0, -length * 0.5), Vector3(s * half + 0.4, 0.3, length * 0.5), concrete)
			b.box(Vector3(s * half - 0.08, 0.55, -length * 0.5), Vector3(s * half + 0.08, 0.85, length * 0.5), Color(0.78, 0.78, 0.8), true)
			b.add_collider(Vector3(s * half - 0.1, 0, -length * 0.5), Vector3(s * half + 0.1, 1.0, length * 0.5))
			var z := -length * 0.5
			while z <= length * 0.5:
				b.box(Vector3(s * half - 0.07, 0.3, z - 0.07), Vector3(s * half + 0.07, 0.6, z + 0.07), Color(0.4, 0.4, 0.42))
				z += 2.5
			b.box(Vector3(s * (half + 0.4) - 0.3, -0.6, -length * 0.5), Vector3(s * (half + 0.4) + 0.3, 0.02, length * 0.5), concrete.darkened(0.2))
	else:
		var plank := Color(0.5, 0.38, 0.24)
		b.box(Vector3(-half, 0.04, -length * 0.5), Vector3(half, 0.1, length * 0.5), plank)
		var z := -length * 0.5
		while z < length * 0.5:
			b.box(Vector3(-half, 0.1, z), Vector3(half, 0.12, z + 0.08), plank.darkened(0.25))
			z += 0.6
		for s in [-1.0, 1.0]:
			b.box(Vector3(s * half - 0.08, 0.9, -length * 0.5), Vector3(s * half + 0.08, 1.0, length * 0.5), plank.darkened(0.1), true)
			b.box(Vector3(s * half - 0.06, 0.5, -length * 0.5), Vector3(s * half + 0.06, 0.56, length * 0.5), plank.darkened(0.1))
			z = -length * 0.5
			while z <= length * 0.5:
				b.box(Vector3(s * half - 0.08, 0, z - 0.08), Vector3(s * half + 0.08, 1.05, z + 0.08), plank.darkened(0.3), true)
				z += 3.0
	b.xf = Transform3D.IDENTITY


## Грунтовки: полосы вдоль отрезков, ямы и лужи — как на лесной дороге.
func _roads(b: MeshBuilder, veg: Vegetation) -> void:
	var dirt := Color(0.46, 0.39, 0.28)
	for s in segments():
		var a: Vector2 = s[0]
		var c: Vector2 = s[1]
		var d := c - a
		var mid := (a + c) * 0.5
		b.box_rot(Vector3(mid.x, 0.0175, mid.y), Vector3(ROAD_HALF * 2.0, 0.035, d.length()), atan2(d.x, d.y), dirt)
		# Круглые стыки: повороты и концы без торчащих углов
		# Цвет — как у верха коробки дороги (грань сверху светлее, низ затемнён)
		var top := dirt * (1.06 * lerpf(0.72, 1.0, 0.035 / 1.2))
		top.a = 1.0
		for end in [a, c]:
			var e3 := Vector3(end.x, 0.035, end.y)
			for q in 12:
				var a0 := TAU * q / 12.0
				var a1 := TAU * (q + 1) / 12.0
				b.tri(e3, e3 + Vector3(cos(a1), 0, sin(a1)) * ROAD_HALF, e3 + Vector3(cos(a0), 0, sin(a0)) * ROAD_HALF, top)
		# Колеи
		for off in [-1.0, 1.0]:
			var side: Vector2 = Vector2(d.y, -d.x).normalized() * off
			var m2: Vector2 = mid + side
			b.box_rot(Vector3(m2.x, 0.036, m2.y), Vector3(0.35, 0.004, d.length()), atan2(d.x, d.y), dirt.darkened(0.15))
		# Ямы и места для луж
		for i in int(d.length() / 45.0):
			var p := a.lerp(c, _rng.randf())
			p += Vector2(d.y, -d.x).normalized() * _rng.randf_range(-1.5, 1.5)
			if absf(p.x) < 200.0 and absf(p.y) < 200.0:
				continue
			if _under_bridge(p, 2.0):
				continue
			var hole := Vector3(p.x, 0, p.y)
			b.box_rot(hole + Vector3(0, 0.037, 0), Vector3(_rng.randf_range(0.6, 1.2), 0.005, _rng.randf_range(0.5, 1.0)), _rng.randf() * TAU, Color(0.22, 0.17, 0.12))
			_world._potholes.append(hole)
			var q := a.lerp(c, _rng.randf())
			_world._puddle_spots.append(Vector3(q.x, 0.05, q.y))
		# Трава на дороге в Каменке не растёт (съезд к Первомаю)
		if absf(mid.x) < 200.0 and absf(mid.y) < 200.0:
			veg.block(minf(a.x, c.x) - 3.5, maxf(minf(a.y, c.y), -200.0), maxf(a.x, c.x) + 3.5, minf(maxf(a.y, c.y), 200.0))


## Озеро у Озерцово: вода, илистый берег, камыш, мостки с рыбалкой.
func _lake(b: MeshBuilder) -> void:
	var c := Vector3(LAKE.x, 0, LAKE.y)
	var segs := 28
	var pts: Array[Vector3] = []
	for i in segs:
		var a := TAU * i / segs
		var k := 1.0 + sin(a * 3.0) * 0.1 + _rng.randf_range(-0.04, 0.04)
		pts.append(Vector3(cos(a) * LAKE_R.x * k, 0, sin(a) * LAKE_R.y * k))
	for i in segs:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[(i + 1) % segs]
		b.tri(c + Vector3(0, 0.02, 0), c + p1 * 1.12 + Vector3(0, 0.02, 0), c + p0 * 1.12 + Vector3(0, 0.02, 0), Color(0.36, 0.3, 0.2))
		_world._water_b.tri(c + Vector3(0, 0.035, 0), c + p1 + Vector3(0, 0.035, 0), c + p0 + Vector3(0, 0.035, 0), Color(0.2, 0.32, 0.36))
	for i in 70:
		var p: Vector3 = pts[_rng.randi() % segs] * _rng.randf_range(0.97, 1.12)
		if p.x > LAKE_R.x * 0.8 and absf(p.z) < 3.0:
			continue
		var h := _rng.randf_range(0.8, 1.6)
		_d.box(c + p + Vector3(-0.03, 0, -0.03), c + p + Vector3(0.03, h, 0.03), Color(0.35, 0.45, 0.2))
	# Мостки с восточного берега
	var m := c + Vector3(pts[0].x - 0.5, 0, 0)
	_d.box(m + Vector3(-4.5, 0.3, -0.6), m + Vector3(1.0, 0.38, 0.6), Color(0.5, 0.4, 0.28), true)
	for x in [-4.2, -2.4, -0.6]:
		for z in [-0.55, 0.45]:
			_d.box(m + Vector3(x, -0.3, z), m + Vector3(x + 0.1, 0.3, z + 0.1), Color(0.3, 0.24, 0.16))
	var fishing := InteractZone.create("", Vector3(2.4, 2.0, 1.6))
	fishing.position = m + Vector3(-3.0, 0.38, 0)
	fishing.prompt_fn = func() -> String:
		var f: FishingGame = _world._fishing
		if f.active() and f.spot.distance_to(fishing.position) < 3.0:
			return "КЛЮЁТ! E — подсекай!" if f.state == FishingGame.State.BITE else "Поплавок на воде — жди, пока нырнёт"
		return "E — порыбачить на озере"
	fishing.activated.connect(func() -> void:
		_world.fish_at(fishing.position, m + Vector3(-7.5, 0.06, 0.3)))
	add_child(fishing)


# --- Сёла ---------------------------------------------------------------------

func _village(i: int, b: MeshBuilder, glow: MeshBuilder, veg: Vegetation) -> void:
	var v: Dictionary = VILLAGES[i]
	var c: Vector2 = v.c
	var e: int = v.entry
	veg.areas.append(Rect2(c.x - 75, c.y - 45, 150, 90))
	veg.block(c.x - 61, c.y - 3.5, c.x + 61, c.y + 3.5)
	var k := 0
	for side in [-1, 1]:
		for hx in HOUSE_X:
			var pos := Vector3(c.x + hx * e, 0, c.y + side * 16.0)
			_house(pos, 0.0 if side < 0 else PI, i * 8 + k, glow)
			veg.block(pos.x - 5, pos.z - 4, pos.x + 5, pos.z + 4)
			veg.block(pos.x - 8.5, pos.z + side * 7.5, pos.x + 8.5, pos.z + side * 14.5)
			k += 1
	# Магазин, остановка, указатель, житель
	var shop := Vector3(c.x + 42.0 * e, 0, c.y - 9.0)
	_shop(shop, glow)
	veg.block(shop.x - 4, shop.z - 3.5, shop.x + 4, shop.z + 4.5)
	var stop := stop_pos(i)
	_world._bus_stop(_d, stop, PI, false)
	veg.block(stop.x - 3, stop.z - 1.5, stop.x + 3, stop.z + 1.5)
	_village_sign(Vector3(c.x + 60.0 * e, 0, c.y - 5.0), PI / 2.0 * e, v.name)
	_villager(i, Vector3(c.x + 35.0 * e, 0, c.y - 4.2))
	# Лавочка у магазина, колодец посреди улицы
	_d.box(Vector3(shop.x - 1.0 + 3.5 * e, 0.4, shop.z + 3.0), Vector3(shop.x + 1.0 + 3.5 * e, 0.47, shop.z + 3.4), Color(0.5, 0.38, 0.25), true)
	var well := Vector3(c.x - 11.0 * e, 0, c.y - 5.5)
	_d.box(well + Vector3(-0.7, 0, -0.7), well + Vector3(0.7, 0.8, 0.7), Color(0.45, 0.35, 0.25), true)
	for s in [-0.6, 0.6]:
		_d.box(well + Vector3(s - 0.06, 0.8, -0.06), well + Vector3(s + 0.06, 2.0, 0.06), Color(0.4, 0.3, 0.2))
	_d.xf = Transform3D(Basis.IDENTITY, well)
	_d.quad(Vector3(-0.9, 1.9, 0.8), Vector3(0.9, 1.9, 0.8), Vector3(0.9, 2.3, 0), Vector3(-0.9, 2.3, 0), Color(0.45, 0.25, 0.18), true)
	_d.quad(Vector3(0.9, 1.9, -0.8), Vector3(-0.9, 1.9, -0.8), Vector3(-0.9, 2.3, 0), Vector3(0.9, 2.3, 0), Color(0.45, 0.25, 0.18), true)
	_d.xf = Transform3D.IDENTITY
	# Фонари на улице
	for lx in [-33.0, 10.0]:
		var lp := Vector3(c.x + lx * e, 0, c.y + 4.0)
		_d.box(lp + Vector3(-0.08, 0, -0.08), lp + Vector3(0.08, 5.0, 0.08), Color(0.4, 0.4, 0.42), true)
		_d.box(lp + Vector3(-0.05, 4.9, -0.05), lp + Vector3(0.05, 5.0, -1.2), Color(0.4, 0.4, 0.42))
		glow.box(lp + Vector3(-0.18, 4.7, -1.35), lp + Vector3(0.18, 4.85, -1.0), Color(1.0, 0.85, 0.55))


## Сельский дом снаружи: цоколь, стены, двускатная крыша, окна с ставнями,
## забор с калиткой, огород за домом и яблоня во дворе.
func _house(pos: Vector3, yaw: float, idx: int, glow: MeshBuilder) -> void:
	var wall: Color = WALLS[idx % WALLS.size()]
	var roof: Color = ROOFS[(idx * 7 + 1) % ROOFS.size()]
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	var d := _d
	d.xf = xf
	glow.xf = xf
	d.box(Vector3(-4, 0, -3), Vector3(4, 0.45, 3), Color(0.5, 0.5, 0.48))
	d.box(Vector3(-3.8, 0.45, -2.8), Vector3(3.8, 3.0, 2.8), wall)
	d.add_collider(Vector3(-4, 0, -3), Vector3(4, 3.2, 3))
	var eave := Vector3(4.3, 3.0, 3.4)
	var ridge := 4.7
	d.quad(Vector3(-eave.x, eave.y, eave.z), Vector3(eave.x, eave.y, eave.z), Vector3(eave.x, ridge, 0), Vector3(-eave.x, ridge, 0), roof, true)
	d.quad(Vector3(eave.x, eave.y, -eave.z), Vector3(-eave.x, eave.y, -eave.z), Vector3(-eave.x, ridge, 0), Vector3(eave.x, ridge, 0), roof.darkened(0.1), true)
	for x in [-3.8, 3.8]:
		d.tri(Vector3(x, 3.0, 2.8), Vector3(x, 3.0, -2.8), Vector3(x, ridge - 0.1, 0), wall.darkened(0.08), true)
	# Труба
	d.box(Vector3(1.6, 3.6, -1.2), Vector3(2.2, 5.3, -0.6), Color(0.6, 0.35, 0.28))
	# Окна на улицу и сбоку, у окон — ставни
	var frame := Color(0.92, 0.92, 0.88)
	var shutter: Color = [Color(0.25, 0.45, 0.7), Color(0.3, 0.55, 0.3), Color(0.9, 0.9, 0.85)][idx % 3]
	for x in [-2.3, 2.3]:
		d.box(Vector3(x - 0.6, 1.1, 2.8), Vector3(x + 0.6, 2.4, 2.86), frame)
		glow.box(Vector3(x - 0.48, 1.22, 2.86), Vector3(x + 0.48, 2.28, 2.88), Color(0.95, 0.8, 0.45))
		for s in [-1.0, 1.0]:
			d.box(Vector3(x + s * 0.6 + minf(s, 0.0) * 0.45, 1.1, 2.82), Vector3(x + s * 0.6 + maxf(s, 0.0) * 0.45, 2.4, 2.9), shutter)
	for z in [-1.0, 1.0]:
		d.box(Vector3(3.8, 1.1, z - 0.55), Vector3(3.86, 2.4, z + 0.55), frame)
		glow.box(Vector3(3.86, 1.22, z - 0.45), Vector3(3.88, 2.28, z + 0.45), Color(0.95, 0.8, 0.45))
	# Крыльцо и дверь — сбоку фасада
	d.box(Vector3(-0.6, 0, 2.8), Vector3(0.6, 0.45, 3.8), Color(0.5, 0.4, 0.3), true)
	d.box(Vector3(-0.45, 0.45, 2.8), Vector3(0.45, 2.4, 2.86), Color(0.4, 0.28, 0.2))
	# Забор: спереди с калиткой, по бокам до огорода
	var fence: Color = [Color(0.55, 0.45, 0.32), Color(0.35, 0.5, 0.35), Color(0.45, 0.55, 0.7)][idx % 3]
	for seg in [[Vector2(-10, 9), Vector2(-1.2, 9)], [Vector2(1.2, 9), Vector2(10, 9)], [Vector2(-10, 9), Vector2(-10, -14)], [Vector2(10, 9), Vector2(10, -14)]]:
		_fence(d, seg[0], seg[1], fence)
	# Огород с грядками
	d.box(Vector3(-8.5, 0, -14.5), Vector3(8.5, 0.04, -7.5), Color(0.38, 0.28, 0.18))
	var z := -14.0
	while z < -8.0:
		d.box(Vector3(-8, 0.04, z), Vector3(8, 0.12, z + 0.5), Color(0.33, 0.24, 0.15))
		if (idx + int(z)) % 2 == 0:
			var x := -7.5
			while x < 8.0:
				d.box(Vector3(x - 0.15, 0.12, z + 0.1), Vector3(x + 0.15, 0.4, z + 0.4), Color(0.3, 0.5, 0.2))
				x += 0.8
		z += 1.2
	# Сарайчик и дерево во дворе
	d.box(Vector3(-9.2, 0, -6.5), Vector3(-6.5, 2.2, -3.5), Color(0.45, 0.36, 0.26))
	d.add_collider(Vector3(-9.2, 0, -6.5), Vector3(-6.5, 2.2, -3.5))
	d.box(Vector3(-9.4, 2.2, -6.7), Vector3(-6.3, 2.35, -3.3), Color(0.35, 0.33, 0.32))
	glow.xf = Transform3D.IDENTITY
	_world._tree(d, Vector3(6.8 if idx % 2 == 0 else -6.5, 0, 5.5), _rng.randf() * TAU, Vegetation.TreeKind.APPLE if idx % 3 != 2 else Vegetation.TreeKind.BIRCH)
	d.xf = Transform3D.IDENTITY


## Штакетник от a до b (в координатах дома), с коллизией.
func _fence(d: MeshBuilder, a: Vector2, c: Vector2, color: Color) -> void:
	var dir := (c - a)
	var size_m := dir.length()
	var u := dir / size_m
	var mid := (a + c) * 0.5
	var yaw := atan2(u.x, u.y)
	d.box_rot(Vector3(mid.x, 0.35, mid.y), Vector3(0.05, 0.08, size_m), yaw, color.darkened(0.2))
	d.box_rot(Vector3(mid.x, 0.95, mid.y), Vector3(0.05, 0.08, size_m), yaw, color.darkened(0.2))
	var t := 0.0
	while t <= size_m:
		var p := a + u * t
		d.box_rot(Vector3(p.x, 0.6, p.y), Vector3(0.1, 1.2, 0.1), yaw, color)
		t += 0.35
	var saved := d.xf
	d.xf = d.xf * Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, 0, mid.y))
	d.add_collider(Vector3(-0.08, 0, -size_m * 0.5), Vector3(0.08, 1.2, size_m * 0.5))
	d.xf = saved


## Сельский магазин «Продукты»: хлеб и молоко, как в сельмаге.
func _shop(p: Vector3, glow: MeshBuilder) -> void:
	var d := _d
	d.box(p + Vector3(-3.2, 0, -2.6), p + Vector3(3.2, 3.0, 2.6), Color(0.85, 0.82, 0.76), true)
	d.box(p + Vector3(-3.4, 3.0, -2.8), p + Vector3(3.4, 3.2, 2.8), Color(0.4, 0.4, 0.42))
	d.box(p + Vector3(-3.25, 2.2, 2.6), p + Vector3(3.25, 2.9, 2.66), Color(0.2, 0.4, 0.65))
	d.box(p + Vector3(-0.6, 0, 2.6), p + Vector3(0.6, 2.1, 2.66), Color(0.4, 0.3, 0.22))
	for x in [-2.0, 2.0]:
		glow.box(p + Vector3(x - 0.8, 0.9, 2.6), p + Vector3(x + 0.8, 1.9, 2.67), Color(0.95, 0.85, 0.55))
	d.box(p + Vector3(-0.8, 0, 2.6), p + Vector3(0.8, 0.12, 3.6), Color(0.55, 0.55, 0.53))
	var l := Label3D.new()
	l.text = "ПРОДУКТЫ"
	l.font_size = 96
	l.pixel_size = 0.005
	l.outline_size = 0
	l.modulate = Color(1, 1, 1)
	l.position = p + Vector3(0, 2.55, 2.68)
	add_child(l)
	var zone := InteractZone.create("", Vector3(3.0, 2.2, 2.2))
	zone.position = p + Vector3(0, 0, 3.8)
	zone.prompt_fn = func() -> String:
		var h := TimeManager.hour()
		if h < 8.0 or h >= 21.0:
			return "Магазин закрыт. Работает с 8:00 до 21:00"
		return "E — купить хлеб и молоко (40 грн)"
	zone.activated.connect(func() -> void: _world._buy_village_food())
	add_child(zone)


## Синий указатель с названием села при въезде.
func _village_sign(p: Vector3, yaw: float, title: String) -> void:
	var d := _d
	d.xf = Transform3D(Basis(Vector3.UP, yaw), p)
	for x in [-1.3, 1.2]:
		d.box(Vector3(x, 0, -0.04), Vector3(x + 0.08, 2.4, 0.04), Color(0.45, 0.45, 0.45), true)
	d.box(Vector3(-1.5, 1.6, 0.04), Vector3(1.5, 2.4, 0.08), Color(0.12, 0.3, 0.65))
	d.box(Vector3(-1.5, 1.6, 0.0), Vector3(1.5, 2.4, 0.04), Color(0.6, 0.6, 0.6))
	d.xf = Transform3D.IDENTITY
	var lbl := Label3D.new()
	lbl.text = title
	lbl.font_size = 96
	lbl.pixel_size = 0.005
	lbl.outline_size = 0
	lbl.position = p + Basis(Vector3.UP, yaw) * Vector3(0, 2.0, 0.09)
	lbl.rotation.y = yaw
	add_child(lbl)


## Житель у магазина: стоит, поворачивается к игроку, рассказывает про село.
func _villager(i: int, p: Vector3) -> void:
	var v: Dictionary = VILLAGES[i]
	var b := MeshBuilder.new()
	b.ground_shade = false
	var shirts := [Color(0.6, 0.3, 0.25), Color(0.3, 0.4, 0.6), Color(0.45, 0.5, 0.3), Color(0.55, 0.45, 0.6)]
	Villagers.person_model(b, shirts[i % shirts.size()], Color(0.3, 0.25, 0.2), false, i % 2 == 1)
	var mi := b.build_mesh()
	mi.position = p
	mi.name = "Villager_%d" % i
	add_child(mi)
	var zone := InteractZone.create("E — поговорить", Vector3(2.4, 2.0, 2.4))
	zone.position = p
	var n := [0]
	zone.activated.connect(func() -> void:
		var pl := GameManager.player as Node3D
		if pl:
			var to := pl.global_position - mi.global_position
			mi.rotation.y = atan2(to.x, to.z)
		var lines: Array = v.lines
		GameManager.notify("%s: «%s»" % [Villagers._greeting(), lines[n[0] % lines.size()]])
		n[0] += 1
		QuestManager.event("talk"))
	add_child(zone)


## Леса района: ели и берёзы, по-разному густые.
func _forests(b: MeshBuilder) -> void:
	for area in FORESTS + FAR_FORESTS:
		var r: Rect2 = area
		var count := int(r.get_area() / (280.0 if FORESTS.has(area) else 800.0))
		for i in count:
			var x := r.position.x + _rng.randf() * r.size.x
			var z := r.position.y + _rng.randf() * r.size.y
			if not tree_ok(x, z):
				continue
			var kind := Vegetation.TreeKind.SPRUCE if _rng.randf() < 0.6 else Vegetation.TreeKind.BIRCH
			_world._tree(b, Vector3(x, 0, z), _rng.randf() * TAU, kind)


# --- Районный автобус ----------------------------------------------------------

## Куда идёт районный автобус в этот час: каждый час — в следующее село.
static func bus_target(hour: float) -> int:
	return int(hour) % VILLAGES.size()


## Табличка «Районный» у остановки в Каменке: автобус по сёлам.
func _district_bus() -> void:
	var p: Vector3 = _world.STOP_VILLAGE + Vector3(-5.0, 0, 0.2)
	_d.box(p + Vector3(-0.05, 0, -0.05), p + Vector3(0.05, 2.5, 0.05), Color(0.4, 0.4, 0.4), true)
	_d.box(p + Vector3(-0.55, 1.8, 0.05), p + Vector3(0.55, 2.55, 0.09), Color(0.2, 0.5, 0.3))
	var l := Label3D.new()
	l.text = "РАЙОННЫЙ\nпо сёлам"
	l.font_size = 64
	l.pixel_size = 0.004
	l.outline_size = 0
	l.position = p + Vector3(0, 2.18, 0.1)
	add_child(l)
	var zone := InteractZone.create("", Vector3(2.0, 2.2, 2.2))
	zone.position = p + Vector3(0, 0, 0.8)
	zone.prompt_fn = func() -> String:
		var h := TimeManager.hour()
		if h < 6.0 or h >= 22.0:
			return "Районный автобус ходит с 6:00 до 22:00"
		var t := bus_target(h)
		return "E — районный автобус: сейчас в %s (%d грн). Каждый час — в другое село" % [VILLAGES[t].name, BUS_FARE]
	zone.activated.connect(ride_district)
	add_child(zone)


## Поездка районным автобусом: полчаса в дороге, выходишь у остановки села.
func ride_district() -> void:
	var h := TimeManager.hour()
	if h < 6.0 or h >= 22.0:
		GameManager.notify("Районный автобус ходит с 6:00 до 22:00")
		return
	if not GameManager.spend(BUS_FARE):
		return
	var t := bus_target(h)
	TimeManager.advance(30.0)
	var p := GameManager.player as Node3D
	if p:
		p.global_position = stop_pos(t) + Vector3(0, 0.1, -2.2)
		if p is CharacterBody3D:
			(p as CharacterBody3D).velocity = Vector3.ZERO
		p.rotation.y = 0.0
	QuestManager.event("bus")
	GameManager.notify("Приехал в %s. %s. Назад — с остановки, автобус до Каменки" % [VILLAGES[t].name, TimeManager.clock_text()])


# --- Кто где побывал ------------------------------------------------------------

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	var who := (GameManager.vehicle if GameManager.vehicle else GameManager.player) as Node3D
	if who == null:
		return
	var here := village_at(who.global_position.x, who.global_position.z)
	if here != "" and not visited.has(here):
		visited.append(here)
		QuestManager.event("village_visit")
		GameManager.notify("Село %s. Побывал в %d из %d соседних сёл" % [here, visited.size(), VILLAGES.size()])


func save_state() -> Dictionary:
	return {"visited": visited.duplicate()}


func load_state(d: Dictionary) -> void:
	visited = (d.get("visited", []) as Array).duplicate()
