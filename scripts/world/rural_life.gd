class_name RuralLife
extends Node3D
## Жизнь на просёлках и лугах района: по грунтовкам ездят трактора, «Нивы»,
## «Жигули», грузовики, мотоциклы и телега с лошадью; у сёл пасутся стада
## с пастухом; в пшеничном поле ходит комбайн. В каждом селе по улице
## ходят жители, у магазина на лавочке сидит бабушка.
##
## Все едут по своей стороне дороги, у конца дороги стоят и разворачиваются.
## Перед игроком и его машиной останавливаются и сигналят. Далеко от
## камеры не рисуются (дальность видимости), а считаются почти даром.

const Villagers := preload("res://scripts/world/villagers.gd")
## [вид, скорость м/с, цвет]
const KINDS := [
	["tractor", 3.5, Color(0.2, 0.45, 0.25)],
	["niva", 9.0, Color(0.55, 0.12, 0.1)],
	["car", 10.0, Color(0.2, 0.35, 0.6)],
	["cart", 1.8, Color(0.5, 0.38, 0.25)],
	["moto", 8.0, Color(0.15, 0.15, 0.4)],
	["truck", 7.0, Color(0.35, 0.45, 0.3)],
]
const SEE := 350.0

var movers: Array[Dictionary] = []
var herds: Array[Dictionary] = []
## Жители на улицах сёл: {mesh, c (центр улицы), x (смещение), dir}
var walkers: Array[Dictionary] = []
var _combine: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func _ready() -> void:
	_rng.seed = 2024
	var i := 0
	for r in Region.ROADS:
		var pts: Array = r
		var total := 0.0
		for k in pts.size() - 1:
			total += (pts[k] as Vector2).distance_to(pts[k + 1])
		if total < 150.0:
			continue
		_add_mover(pts, total, KINDS[i % KINDS.size()], _rng.randf() * total)
		i += 1
	for v in Region.VILLAGES.size():
		if v % 2 == 0:
			_add_herd(v)
	_add_combine()
	for v in Region.VILLAGES.size():
		_add_village_people(v)


# --- Машины на просёлках ------------------------------------------------------

func _model(kind: String, color: Color) -> Node3D:
	var root := Node3D.new()
	var b := MeshBuilder.new()
	b.ground_shade = false
	match kind:
		"tractor":
			VehicleModels.tractor(b, color)
		"niva":
			VehicleModels.niva(b, color)
		"truck":
			VehicleModels.gaz53(b, color, null)
		"moto":
			VehicleModels.java(b, color)
			Villagers.person_model(b, Color(0.3, 0.35, 0.3), Color(0.2, 0.2, 0.22), true, false)
		"cart":
			_cart(b)
		_:
			VehicleModels.zhiguli(b, color, false)
	if kind in ["car", "niva"]:
		for p in [Vector3(-0.78, 0.29, -1.3), Vector3(0.78, 0.29, -1.3), Vector3(-0.78, 0.29, 1.3), Vector3(0.78, 0.29, 1.3)]:
			var saved := b.xf
			b.xf = Transform3D(Basis.IDENTITY, p)
			VehicleModels.car_wheel(b, 0.3, 0.2)
			b.xf = saved
	var mi := b.build_mesh()
	mi.visibility_range_end = SEE
	root.add_child(mi)
	if kind == "cart":
		# Лошадь с шагом — отдельным мешем с шейдером животных
		var hb := MeshBuilder.new()
		hb.ground_shade = false
		_horse(hb)
		var horse := Villagers.animal_mesh(hb, 0.9, 1.5, 1.4, 2.0)
		horse.name = "Horse"
		horse.visibility_range_end = SEE
		root.add_child(horse)
	return root


## Телега с возницей: кузов на двух колёсах, оглобли вперёд.
func _cart(b: MeshBuilder) -> void:
	var wood := Color(0.5, 0.38, 0.25)
	b.box(Vector3(-0.8, 0.6, -0.2), Vector3(0.8, 0.7, 2.6), wood)
	for sx in [-0.8, 0.75]:
		b.box(Vector3(sx, 0.7, -0.2), Vector3(sx + 0.05, 1.0, 2.6), wood.darkened(0.15))
		b.box(Vector3(sx * 1.2 - 0.05, 0, 1.0), Vector3(sx * 1.2 + 0.05, 0.9, 1.9), Color(0.3, 0.22, 0.15))
	for sx in [-0.35, 0.3]:
		b.box(Vector3(sx, 0.6, -2.4), Vector3(sx + 0.06, 0.66, -0.2), wood.darkened(0.3))
	b.box(Vector3(-0.6, 0.7, 1.8), Vector3(0.6, 1.1, 2.5), Color(0.8, 0.7, 0.4))
	var saved := b.xf
	b.xf = Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0.4))
	Villagers.person_model(b, Color(0.4, 0.35, 0.3), Color(0.25, 0.22, 0.2), true, false)
	b.xf = saved


## Лошадь: гнедая, ноги по диагонали, хвост.
func _horse(b: MeshBuilder) -> void:
	var bay := Color(0.45, 0.28, 0.16)
	var z0 := -2.6
	b.box(Vector3(-0.3, 0.9, z0 - 0.9), Vector3(0.3, 1.5, z0 + 0.9), bay)
	b.box(Vector3(-0.18, 1.3, z0 - 1.4), Vector3(0.18, 2.0, z0 - 0.85), bay)
	b.box(Vector3(-0.14, 1.75, z0 - 1.8), Vector3(0.14, 2.0, z0 - 1.3), bay.darkened(0.1))
	for p in [Vector2(-0.25, z0 - 0.7), Vector2(0.13, z0 - 0.7), Vector2(-0.25, z0 + 0.6), Vector2(0.13, z0 + 0.6)]:
		b.alpha = 0.9 if (p.x < 0.0) == (p.y > z0) else 0.8
		b.box(Vector3(p.x, 0, p.y), Vector3(p.x + 0.12, 0.92, p.y + 0.14), bay.darkened(0.2))
	b.alpha = 0.5
	b.box(Vector3(-0.05, 0.9, z0 + 0.9), Vector3(0.05, 1.45, z0 + 1.05), Color(0.15, 0.1, 0.08))
	b.alpha = 1.0


func _add_mover(pts: Array, total: float, spec: Array, s: float) -> void:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var kind: String = spec[0]
	shape.size = Vector3(0.8, 1.4, 2.0) if kind == "moto" else (Vector3(2.2, 2.4, 6.5) if kind == "truck" else Vector3(1.7, 1.6, 4.2))
	if kind == "cart":
		shape.size = Vector3(1.6, 1.6, 6.5)
	cs.shape = shape
	cs.position = Vector3(0, shape.size.y * 0.5, -1.0 if kind == "cart" else 0.0)
	body.add_child(cs)
	body.add_child(_model(kind, spec[2]))
	add_child(body)
	movers.append({"body": body, "pts": pts, "total": total, "s": s, "dir": 1 if _rng.randf() < 0.5 else -1,
		"speed": float(spec[1]), "v": float(spec[1]), "kind": kind, "wait": 0.0, "honk": 0.0})


## Точка и направление на дороге на расстоянии s от начала.
func _at(pts: Array, s: float) -> Array:
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var c: Vector2 = pts[k + 1]
		var seg := a.distance_to(c)
		if s <= seg or k == pts.size() - 2:
			var d := (c - a) / seg
			return [a + d * clampf(s, 0.0, seg), d]
		s -= seg
	return [pts[0], Vector2.RIGHT]


func _update_mover(m: Dictionary, delta: float, cam: Vector3) -> void:
	var body: AnimatableBody3D = m.body
	if m.wait > 0.0:
		m.wait -= delta
		if m.wait <= 0.0:
			m.dir = -int(m.dir)
		return
	var at := _at(m.pts, m.s)
	var d: Vector2 = at[1] * float(m.dir)
	# Помеха впереди: игрок пешком или его машина в полосе
	var want: float = m.speed
	var pos2: Vector2 = at[0]
	for n in [GameManager.player, GameManager.vehicle]:
		var node := n as Node3D
		if node == null or not node.visible:
			continue
		var rel := Vector2(node.global_position.x, node.global_position.z) - pos2
		var ahead := rel.dot(d)
		if ahead > 0.0 and ahead < 12.0 and absf(rel.cross(d)) < 3.0:
			want = 0.0
			m.honk = float(m.honk) - delta
			if m.honk <= 0.0 and m.kind != "cart":
				m.honk = 5.0
				SoundLibrary.play_at("horn", body.global_position, -6.0)
	# Шлагбаум на переезде опущен — ждём поезд
	if Railway.closed_ahead(pos2, d, 16.0):
		want = 0.0
	m.v = move_toward(float(m.v), want, delta * (3.0 if want > float(m.v) else 8.0))
	m.s = float(m.s) + float(m.v) * delta * float(m.dir)
	if m.s <= 0.0 or m.s >= float(m.total):
		m.s = clampf(float(m.s), 0.0, float(m.total))
		m.wait = _rng.randf_range(4.0, 12.0)
	# По своей (правой) стороне дороги
	var side := Vector2(-d.y, d.x) * -1.3
	var p := pos2 + side
	var near := cam.distance_to(Vector3(p.x, 0, p.y)) < SEE + 50.0
	if near or body.visible:
		body.global_position = Vector3(p.x, 0.05, p.y)
		body.rotation.y = atan2(-d.x, -d.y)
	body.visible = near
	if near and m.kind == "cart":
		var horse := body.get_child(1).get_node("Horse") as MeshInstance3D
		Villagers.set_walk(horse, _t * 2.2, 1.0 if float(m.v) > 0.2 else 0.0)


# --- Стада --------------------------------------------------------------------

func _add_herd(v: int) -> void:
	var c: Vector2 = Region.VILLAGES[v].c
	var e: int = Region.VILLAGES[v].entry
	var center := Vector2.INF
	for tries in 12:
		var p := c + Vector2(-e * _rng.randf_range(130.0, 220.0), _rng.randf_range(-120.0, 120.0))
		if Region.tree_ok(p.x, p.y) and Region.road_dist(p.x, p.y) > 30.0 and Landscape.height_at(p.x, p.y) < 0.1:
			center = p
			break
	if center == Vector2.INF:
		return
	var cows: Array = []
	for i in 6:
		var b := MeshBuilder.new()
		b.ground_shade = false
		_cow_model(b, i)
		var mi := Villagers.animal_mesh(b, 0.66, 1.3, -0.95, 2.0)
		(mi.material_override as ShaderMaterial).set_shader_parameter("wag", 0.35)
		mi.visibility_range_end = SEE
		add_child(mi)
		var start := center + Vector2(_rng.randf_range(-15, 15), _rng.randf_range(-15, 15))
		mi.position = Vector3(start.x, 0, start.y)
		cows.append({"mesh": mi, "target": start, "wait": _rng.randf_range(0.0, 8.0), "phase": i * 1.1})
	var sb := MeshBuilder.new()
	sb.ground_shade = false
	Villagers.person_model(sb, Color(0.35, 0.3, 0.25), Color(0.3, 0.25, 0.2), false, false)
	sb.box(Vector3(0.3, 0, -0.1), Vector3(0.35, 1.7, -0.05), Color(0.4, 0.3, 0.2))
	var shep := sb.build_mesh()
	shep.position = Vector3(center.x + 18.0, 0, center.y)
	shep.visibility_range_end = SEE
	add_child(shep)
	herds.append({"center": center, "cows": cows, "shepherd": shep})


func _cow_model(b: MeshBuilder, i: int) -> void:
	var white := Color(0.92, 0.9, 0.86)
	var spot: Color = [Color(0.2, 0.17, 0.15), Color(0.5, 0.3, 0.18), Color(0.35, 0.22, 0.15)][i % 3]
	b.box(Vector3(-0.38, 0.65, -0.95), Vector3(0.38, 1.35, 0.8), white)
	b.box(Vector3(-0.39, 0.9, -0.5), Vector3(0.39, 1.25, 0.1), spot)
	b.box(Vector3(-0.22, 0.95, 0.8), Vector3(0.22, 1.35, 1.3), white if i % 2 == 0 else spot)
	for p in [Vector2(-0.3, -0.8), Vector2(0.18, -0.8), Vector2(-0.3, 0.6), Vector2(0.18, 0.6)]:
		b.alpha = 0.9 if (p.x < 0.0) == (p.y > 0.0) else 0.8
		b.box(Vector3(p.x, 0, p.y), Vector3(p.x + 0.12, 0.66, p.y + 0.14), white.darkened(0.1))
	b.alpha = 0.5
	b.box(Vector3(-0.03, 0.9, -1.2), Vector3(0.03, 1.3, -0.95), white.darkened(0.2))
	b.alpha = 1.0


func _update_herd(h: Dictionary, delta: float) -> void:
	var center: Vector2 = h.center
	for c in h.cows:
		var mi: MeshInstance3D = c.mesh
		var pos := Vector2(mi.position.x, mi.position.z)
		if c.wait > 0.0:
			c.wait -= delta
			Villagers.set_walk(mi, 0.0, 0.0)
			if c.wait <= 0.0:
				c.target = center + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-20, 20))
			continue
		var to: Vector2 = c.target - pos
		if to.length() < 0.3:
			c.wait = _rng.randf_range(5.0, 15.0)
			continue
		var step := to.normalized() * minf(0.6 * delta, to.length())
		mi.position += Vector3(step.x, 0, step.y)
		mi.rotation.y = lerp_angle(mi.rotation.y, atan2(to.x, to.y), delta * 2.0)
		Villagers.set_walk(mi, _t * 3.0 + float(c.phase), 1.0)


# --- Жители сёл ---------------------------------------------------------------

const SHIRTS := [Color(0.6, 0.3, 0.25), Color(0.3, 0.4, 0.6), Color(0.45, 0.5, 0.3), Color(0.55, 0.45, 0.6), Color(0.7, 0.6, 0.3)]


## Двое прохожих ходят вдоль улицы туда-обратно, бабушка сидит на лавочке
## у магазина.
func _add_village_people(v: int) -> void:
	var c: Vector2 = Region.VILLAGES[v].c
	var e: int = Region.VILLAGES[v].entry
	for k in 2:
		var b := MeshBuilder.new()
		b.ground_shade = false
		Villagers.person_model(b, SHIRTS[(v + k * 2) % SHIRTS.size()], Color(0.3, 0.25, 0.2).lightened(0.2 * k), false, (v + k) % 2 == 0)
		var mi := Villagers.walking_mesh(b)
		mi.visibility_range_end = SEE * 0.6
		add_child(mi)
		var w := {"mesh": mi, "c": c, "z": c.y + (2.2 if k == 0 else -2.4), "x": _rng.randf_range(-45.0, 45.0),
			"dir": 1.0 if k == 0 else -1.0, "wait": 0.0, "phase": _rng.randf() * TAU}
		walkers.append(w)
		_place_walker(w)
	var shop := Vector2(c.x + 42.0 * e, c.y - 9.0)
	var gb := MeshBuilder.new()
	gb.ground_shade = false
	Villagers.person_model(gb, Color(0.45, 0.25, 0.35), Color(0.85, 0.3, 0.3), true, true)
	var gran := gb.build_mesh()
	gran.position = Vector3(shop.x + 3.5 * e, 0, shop.y + 3.25)
	gran.rotation.y = PI
	gran.visibility_range_end = SEE * 0.6
	add_child(gran)


func _place_walker(w: Dictionary) -> void:
	var mi: MeshInstance3D = w.mesh
	mi.position = Vector3((w.c as Vector2).x + float(w.x), 0, float(w.z))
	mi.rotation.y = -PI / 2.0 if float(w.dir) > 0.0 else PI / 2.0


## Прохожий идёт вдоль улицы, у края села стоит, оглядывается и идёт назад.
func _update_walker(w: Dictionary, delta: float) -> void:
	var mi: MeshInstance3D = w.mesh
	if float(w.wait) > 0.0:
		w.wait = float(w.wait) - delta
		Villagers.set_walk(mi, 0.0, 0.0)
		if float(w.wait) <= 0.0:
			w.dir = -float(w.dir)
			_place_walker(w)
		return
	w.x = float(w.x) + float(w.dir) * 1.2 * delta
	if absf(float(w.x)) > 50.0:
		w.x = clampf(float(w.x), -50.0, 50.0)
		w.wait = _rng.randf_range(3.0, 10.0)
	_place_walker(w)
	Villagers.set_walk(mi, _t * 4.0 + float(w.phase), 1.0)


# --- Комбайн ------------------------------------------------------------------

func _add_combine() -> void:
	var field: Rect2 = Rect2()
	var best := INF
	for f in Landscape.fields:
		if f[1] == "wheat":
			var d := (f[0] as Rect2).get_center().length()
			if d < best:
				best = d
				field = f[0]
	if best == INF:
		return
	var b := MeshBuilder.new()
	b.ground_shade = false
	var red := Color(0.75, 0.15, 0.12)
	b.box(Vector3(-1.4, 0.8, -2.0), Vector3(1.4, 3.2, 3.0), red)
	b.box(Vector3(-0.9, 3.2, -2.0), Vector3(0.9, 4.4, -0.4), Color(0.4, 0.5, 0.55))
	b.box(Vector3(-3.2, 0.3, -3.6), Vector3(3.2, 1.2, -2.2), Color(0.85, 0.7, 0.2))
	b.box(Vector3(1.4, 2.6, 0.0), Vector3(3.6, 2.9, 0.4), red.darkened(0.2))
	for p in [Vector3(-1.5, 0.8, -1.0), Vector3(1.2, 0.8, -1.0)]:
		b.box(p + Vector3(0, -0.8, -0.8), p + Vector3(0.3, 0.8, 0.8), Color(0.1, 0.1, 0.1))
	for p in [Vector3(-1.4, 0.5, 2.2), Vector3(1.2, 0.5, 2.2)]:
		b.box(p + Vector3(0, -0.5, -0.5), p + Vector3(0.25, 0.5, 0.5), Color(0.1, 0.1, 0.1))
	var mi := b.build_mesh()
	mi.visibility_range_end = SEE * 1.5
	add_child(mi)
	_combine = {"mesh": mi, "field": field, "row": 0, "t": 0.0, "dir": 1}


func _update_combine(delta: float) -> void:
	var f: Rect2 = _combine.field
	var mi: MeshInstance3D = _combine.mesh
	var rows := int(f.size.y / 6.0)
	_combine.t = float(_combine.t) + delta * 2.2 * float(_combine.dir)
	if _combine.t > f.size.x - 6.0 or _combine.t < 0.0:
		_combine.dir = -int(_combine.dir)
		_combine.t = clampf(float(_combine.t), 0.0, f.size.x - 6.0)
		_combine.row = (int(_combine.row) + 1) % maxi(rows, 1)
	mi.position = Vector3(f.position.x + 3.0 + float(_combine.t), 0, f.position.y + 3.0 + float(_combine.row) * 6.0)
	mi.rotation.y = -PI / 2.0 if int(_combine.dir) > 0 else PI / 2.0


func _process(delta: float) -> void:
	_t += delta
	var cam3 := get_viewport().get_camera_3d()
	var cam := cam3.global_position if cam3 else Vector3.ZERO
	for m in movers:
		_update_mover(m, delta, cam)
	for h in herds:
		if cam.distance_to(Vector3((h.center as Vector2).x, 0, (h.center as Vector2).y)) < SEE:
			_update_herd(h, delta)
	if not _combine.is_empty():
		_update_combine(delta)
	for w in walkers:
		var c: Vector2 = w.c
		if absf(cam.x - c.x) < SEE * 0.6 and absf(cam.z - c.y) < SEE * 0.6:
			_update_walker(w, delta)
