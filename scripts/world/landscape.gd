class_name Landscape
extends RefCounted
## Пейзаж района между сёлами: пологие холмы, лоскуты полей с разными
## посевами, лесополосы вдоль грунтовок, пруды с камышом. Чтобы район не
## выглядел пустым столом.
##
## Где что лежит — считается один раз (plan) по сетке с разбросом и
## проверками: не на дорогах, не в реке, не в сёлах, лесах и Каменке.
## По этим же данным лес не растёт на холмах и полях, а карта их рисует.

## [центр, радиус, высота]
static var hills: Array = []
## [прямоугольник, посев]
static var fields: Array = []
## [центр, радиус]
static var ponds: Array = []
static var _planned := false

## Посевы: цвет земли, цвет рядов, высота рядов (0 — просто полосы)
const CROPS := {
	"wheat": [Color(0.78, 0.68, 0.33), Color(0.7, 0.6, 0.28), 0.0],
	"sunflower": [Color(0.3, 0.4, 0.18), Color(0.2, 0.36, 0.14), 1.3],
	"rapeseed": [Color(0.86, 0.8, 0.22), Color(0.78, 0.72, 0.2), 0.0],
	"corn": [Color(0.36, 0.3, 0.2), Color(0.28, 0.5, 0.2), 1.6],
	"fallow": [Color(0.42, 0.32, 0.22), Color(0.34, 0.26, 0.17), 0.0],
	"hay": [Color(0.55, 0.6, 0.32), Color(0.5, 0.55, 0.3), 0.0],
	"potato": [Color(0.4, 0.31, 0.2), Color(0.3, 0.45, 0.2), 0.35],
}
const CROP_NAMES := ["wheat", "sunflower", "rapeseed", "corn", "fallow", "hay", "potato"]


## Занято ли место под лесом: на холмах, полях и в прудах деревьев нет.
static func occupied(x: float, z: float) -> bool:
	plan()
	if Landmarks.occupied(x, z) or Farm.occupied(x, z):
		return true
	var p := Vector2(x, z)
	for h in hills:
		if (h[0] as Vector2).distance_to(p) < float(h[1]) * 0.95:
			return true
	for f in fields:
		if (f[0] as Rect2).grow(2.0).has_point(p):
			return true
	for pd in ponds:
		if (pd[0] as Vector2).distance_to(p) < float(pd[1]) + 4.0:
			return true
	return false


## Свободно ли место под новый холм/поле/пруд: круг с центром c радиусом r.
static func _free(c: Vector2, r: float, road_gap: float) -> bool:
	var h := Region.HALF - r - 20.0
	if absf(c.x) > h or absf(c.y) > h:
		return false
	if absf(c.x) < 230.0 + r and absf(c.y) < 230.0 + r:
		return false
	if Town.wr(Rect2(-70, -20, 380, 290)).grow(r).has_point(c):
		return false  # город
	if Region.road_dist(c.x, c.y) < r + road_gap or Region.river_dist(c.x, c.y) < r + 25.0:
		return false
	if absf(c.y) < r + 15.0:
		return false  # трасса
	if Railway.dist(c.x, c.y) < r + 15.0:
		return false
	for v in Region.VILLAGES:
		if (v.c as Vector2).distance_to(c) < r + 110.0:
			return false
	for f in Region.FORESTS + Region.FAR_FORESTS:
		if (f as Rect2).grow(r * 0.8).has_point(c):
			return false
	for f in Region.FIELDS:
		if (f[0] as Rect2).grow(r).has_point(c):
			return false
	if (Region.LAKE).distance_to(c) < r + 60.0:
		return false
	for s in Landmarks.sites():
		if (s[0] as Vector2).distance_to(c) < r + float(s[1]) + 20.0:
			return false
	for o in hills:
		if (o[0] as Vector2).distance_to(c) < r + float(o[1]) + 30.0:
			return false
	for o in fields:
		if (o[0] as Rect2).grow(r + 12.0).has_point(c):
			return false
	for o in ponds:
		if (o[0] as Vector2).distance_to(c) < r + float(o[1]) + 30.0:
			return false
	return true


static func plan() -> void:
	if _planned:
		return
	_planned = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	# Холмы — крупной сеткой с разбросом
	var step := 330.0
	var x := -Region.HALF + 200.0
	while x < Region.HALF - 150.0:
		var z := -Region.HALF + 200.0
		while z < Region.HALF - 150.0:
			var c := Vector2(x + rng.randf_range(-110, 110), z + rng.randf_range(-110, 110))
			var r := rng.randf_range(70.0, 140.0)
			if rng.randf() < 0.7 and _free(c, r, 25.0):
				hills.append([c, r, rng.randf_range(12.0, 30.0)])
			z += step
		x += step
	# Поля — мельче, у дорог и сёл: лоскуты разных посевов
	for v in Region.VILLAGES:
		var vc: Vector2 = v.c
		for k in 14:
			var a := rng.randf() * TAU
			var d := rng.randf_range(150.0, 420.0)
			var c := vc + Vector2(cos(a), sin(a)) * d
			var w := rng.randf_range(70.0, 150.0)
			var l := rng.randf_range(50.0, 110.0)
			var rr := Vector2(w, l).length() * 0.5
			if _free(c, rr, 8.0):
				fields.append([Rect2(c.x - w * 0.5, c.y - l * 0.5, w, l), CROP_NAMES[rng.randi() % CROP_NAMES.size()]])
	# Вдоль трассы — поля на отдалении
	x = -Region.HALF + 300.0
	while x < Region.HALF - 300.0:
		for side in [-1.0, 1.0]:
			var w := rng.randf_range(90.0, 180.0)
			var l := rng.randf_range(60.0, 110.0)
			var c := Vector2(x + rng.randf_range(-60, 60), side * (l * 0.5 + rng.randf_range(25.0, 60.0)))
			if _free(c, Vector2(w, l).length() * 0.5, 8.0):
				fields.append([Rect2(c.x - w * 0.5, c.y - l * 0.5, w, l), CROP_NAMES[rng.randi() % CROP_NAMES.size()]])
		x += 230.0
	# Пруды у сёл
	for v in Region.VILLAGES:
		var vc: Vector2 = v.c
		for k in 3:
			var a := rng.randf() * TAU
			var c := vc + Vector2(cos(a), sin(a)) * rng.randf_range(120.0, 200.0)
			var r := rng.randf_range(9.0, 16.0)
			if _free(c, r, 12.0):
				ponds.append([c, r])
				break


## Высота холма в точке (для деревьев на опушке и проверок): 0 — ровно.
static func height_at(x: float, z: float) -> float:
	plan()
	var p := Vector2(x, z)
	var best := 0.0
	for h in hills:
		var d := (h[0] as Vector2).distance_to(p)
		var r: float = h[1]
		if d < r:
			best = maxf(best, float(h[2]) * (0.5 + 0.5 * cos(PI * d / r)))
	return best


# --- Постройка ----------------------------------------------------------------

## Строит пейзаж: b — меш земли района, d — меш мелочи (камыш, рулоны),
## water — вода, parent — куда положить коллизии холмов.
static func build(b: MeshBuilder, d: MeshBuilder, water: MeshBuilder, parent: Node3D, place_tree: Callable) -> void:
	plan()
	var body := StaticBody3D.new()
	body.name = "HillsCollision"
	for h in hills:
		_hill(b, body, h[0], h[1], h[2])
	parent.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	for f in fields:
		_field(b, d, f[0], f[1], rng)
	for pd in ponds:
		_pond(b, d, water, pd[0], pd[1], rng)
	_shelterbelts(place_tree, rng)


## Пологий холм: кольца от края к вершине, профиль — половина косинуса.
## Край чуть ниже земли — не мерцает на стыке.
static func _hill(b: MeshBuilder, body: StaticBody3D, c: Vector2, r: float, h: float) -> void:
	var rings := 7
	var segs := 18
	var faces := PackedVector3Array()
	var noise := FastNoiseLite.new()
	noise.seed = int(c.x * 7.0 + c.y)
	noise.frequency = 0.02
	var pt := func(ring: int, seg: int) -> Vector3:
		var k := float(ring) / rings
		var a := TAU * float(seg % segs) / segs
		var rr := r * (1.0 - k) * (1.0 + noise.get_noise_1d(float(seg % segs) * 5.0) * 0.12)
		var y := h * (0.5 + 0.5 * cos(PI * (1.0 - k))) - 0.06
		return Vector3(c.x + cos(a) * rr, y, c.y + sin(a) * rr)
	var grass := Color(0.32, 0.47, 0.21)
	var dry := Color(0.5, 0.52, 0.28)
	for ring in rings:
		for seg in segs:
			var p00: Vector3 = pt.call(ring, seg)
			var p01: Vector3 = pt.call(ring, seg + 1)
			var p10: Vector3 = pt.call(ring + 1, seg)
			var p11: Vector3 = pt.call(ring + 1, seg + 1)
			var cols: Array[Color] = []
			for p in [p00, p10, p11, p01]:
				var k := clampf((p as Vector3).y / h, 0.0, 1.0)
				cols.append(grass.lerp(dry, k * 0.6 + noise.get_noise_2d((p as Vector3).x, (p as Vector3).z) * 0.15))
			# Лицом вверх: обход против часовой, если смотреть сверху
			b.quad_vc([p00, p10, p11, p01], cols)
			faces.append_array([p00, p10, p11, p00, p11, p01])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)


## Поле: земля, ряды посева (у подсолнуха и кукурузы — высокие), на
## скошенном лугу — рулоны сена.
static func _field(b: MeshBuilder, d: MeshBuilder, r: Rect2, crop: String, rng: RandomNumberGenerator) -> void:
	var spec: Array = CROPS[crop]
	var base: Color = spec[0]
	var row: Color = spec[1]
	var tall: float = spec[2]
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0.03, r.end.y), base)
	# Ряды — вдоль длинной стороны
	var along_x := r.size.x >= r.size.y
	var n := int((r.size.y if along_x else r.size.x) / 1.6)
	for i in n:
		var t := 0.8 + i * 1.6
		var mn: Vector3
		var mx: Vector3
		var hgt := 0.05 if tall <= 0.0 else tall * rng.randf_range(0.85, 1.05)
		if along_x:
			mn = Vector3(r.position.x + 1.0, 0.03, r.position.y + t - 0.3)
			mx = Vector3(r.end.x - 1.0, hgt, r.position.y + t + 0.3)
		else:
			mn = Vector3(r.position.x + t - 0.3, 0.03, r.position.y + 1.0)
			mx = Vector3(r.position.x + t + 0.3, hgt, r.end.y - 1.0)
		if tall > 0.0:
			d.box(mn, mx, row)
			# Подсолнух: жёлтые шляпки поверх ряда
			if crop == "sunflower":
				d.box(Vector3(mn.x, mx.y - 0.05, mn.z), Vector3(mx.x, mx.y + 0.12, mx.z), Color(0.95, 0.78, 0.15))
		else:
			b.box(mn, mx, row)
	if crop == "hay":
		for k in 10:
			var p := Vector3(rng.randf_range(r.position.x + 4, r.end.x - 4), 0, rng.randf_range(r.position.y + 4, r.end.y - 4))
			_roll(d, p, rng.randf() * PI)


## Рулон сена: восьмигранник на боку.
static func _roll(d: MeshBuilder, p: Vector3, yaw: float) -> void:
	var saved := d.xf
	d.xf = Transform3D(Basis(Vector3.UP, yaw), p)
	var r := 0.75
	var w := 0.65
	var hay := Color(0.78, 0.68, 0.38)
	for i in 8:
		var a0 := TAU * i / 8.0
		var a1 := TAU * (i + 1) / 8.0
		var p0 := Vector3(0, r + sin(a0) * r, cos(a0) * r)
		var p1 := Vector3(0, r + sin(a1) * r, cos(a1) * r)
		d.quad(p0 + Vector3(-w, 0, 0), p1 + Vector3(-w, 0, 0), p1 + Vector3(w, 0, 0), p0 + Vector3(w, 0, 0), hay.darkened(0.05 * (i % 2)), true)
		d.tri(Vector3(-w, r, 0), p1 + Vector3(-w, 0, 0), p0 + Vector3(-w, 0, 0), hay.darkened(0.15), true)
		d.tri(Vector3(w, r, 0), p0 + Vector3(w, 0, 0), p1 + Vector3(w, 0, 0), hay.darkened(0.15), true)
	d.xf = saved


## Пруд: вода, илистый берег, камыш.
static func _pond(b: MeshBuilder, d: MeshBuilder, water: MeshBuilder, c2: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var c := Vector3(c2.x, 0, c2.y)
	var segs := 16
	var pts: Array[Vector3] = []
	for i in segs:
		var a := TAU * i / segs
		var k := 1.0 + sin(a * 3.0 + c2.x) * 0.12
		pts.append(Vector3(cos(a) * r * k * 1.25, 0, sin(a) * r * k))
	for i in segs:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[(i + 1) % segs]
		b.tri(c + Vector3(0, 0.02, 0), c + p1 * 1.15 + Vector3(0, 0.02, 0), c + p0 * 1.15 + Vector3(0, 0.02, 0), Color(0.36, 0.3, 0.2))
		water.tri(c + Vector3(0, 0.035, 0), c + p1 + Vector3(0, 0.035, 0), c + p0 + Vector3(0, 0.035, 0), Color(0.2, 0.32, 0.36))
	for i in 30:
		var p: Vector3 = pts[rng.randi() % segs] * rng.randf_range(0.97, 1.12)
		var hh := rng.randf_range(0.8, 1.6)
		d.box(c + p + Vector3(-0.03, 0, -0.03), c + p + Vector3(0.03, hh, 0.03), Color(0.35, 0.45, 0.2))


## Лесополосы: ряды берёз и тополей вдоль грунтовок, с разрывами у
## развилок и мостов. place_tree(позиция, поворот, вид).
static func _shelterbelts(place_tree: Callable, rng: RandomNumberGenerator) -> void:
	for r in Region.ROADS:
		var pts: Array = r
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var c: Vector2 = pts[i + 1]
			var len := a.distance_to(c)
			if len < 80.0:
				continue
			var dir := (c - a) / len
			var side := Vector2(-dir.y, dir.x) * (1.0 if (i + pts.size()) % 2 == 0 else -1.0)
			# Посадки разные: где берёзы, где тополя, где сосны с елями —
			# по участкам дороги; под деревьями кое-где кусты
			var mix := (i * 7 + pts.size() * 3) % 3
			# Полоса с одной стороны, а через каждые 400 м — и с другой
			var t := 30.0
			while t < len - 30.0:
				# Разрывы в полосе — как настоящие, через каждые 120–200 м
				if fmod(t, 260.0) > 245.0:
					t += 5.0
					continue
				var sd := side if fmod(t, 800.0) < 400.0 else -side
				var p := a + dir * t + sd * rng.randf_range(12.0, 14.0)
				if Region.tree_ok(p.x, p.y) and height_at(p.x, p.y) < 0.1:
					var roll := rng.randf()
					var kind: int
					match mix:
						0:
							kind = Vegetation.TreeKind.BIRCH if roll < 0.75 else Vegetation.TreeKind.SPRUCE
						1:
							kind = Vegetation.TreeKind.POPLAR if roll < 0.8 else Vegetation.TreeKind.BIRCH
						_:
							kind = Vegetation.TreeKind.SPRUCE if roll < 0.7 else Vegetation.TreeKind.BIRCH
					if roll > 0.93:
						kind = Vegetation.TreeKind.BUSH
					place_tree.call(Vector3(p.x, 0, p.y), rng.randf() * TAU, kind)
				t += rng.randf_range(4.0, 5.5)
