class_name ForestLife
extends RefCounted
## Жизнь леса: чтобы, заехав в лес, чувствовалось — выехал из села.
## В каждом ближнем лесу (Region.FORESTS и леса у дорог в Липки) — поляна
## с бревном-скамьёй и кострищем, лесная тропа от опушки к поляне,
## поваленные деревья с корнями, пни, поленница и ковёр опавших листьев.
## На поляне и тропе деревья не растут (occupied — для Region.tree_ok).
##
## Всё — в общий меш района кусками (Region._d): ни одного узла на мелочь.

## Поляны и тропы: заполняются при первом обращении (детерминированно).
static var _glades: Array = []
static var _trails: Array = []


static func forests() -> Array:
	return Region.FORESTS + EliteDistrict.FORESTS


static func _plan() -> void:
	if not _glades.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for f in forests():
		var r: Rect2 = f
		var c := r.get_center() + Vector2(rng.randf_range(-0.2, 0.2) * r.size.x, rng.randf_range(-0.2, 0.2) * r.size.y)
		var rad := clampf(minf(r.size.x, r.size.y) * 0.12, 9.0, 18.0)
		_glades.append([c, rad])
		# Тропа — от ближнего края леса к поляне, с изгибами
		var edge := c
		var dl := c.x - r.position.x
		var dr := r.end.x - c.x
		var dt := c.y - r.position.y
		var db := r.end.y - c.y
		var m := minf(minf(dl, dr), minf(dt, db))
		if m == dl:
			edge = Vector2(r.position.x - 2.0, c.y)
		elif m == dr:
			edge = Vector2(r.end.x + 2.0, c.y)
		elif m == dt:
			edge = Vector2(c.x, r.position.y - 2.0)
		else:
			edge = Vector2(c.x, r.end.y + 2.0)
		var pts: Array = [edge]
		for k in range(1, 4):
			var p := edge.lerp(c, k / 4.0)
			var side := (c - edge).orthogonal().normalized()
			pts.append(p + side * rng.randf_range(-6.0, 6.0))
		pts.append(c)
		_trails.append(pts)


## Поляна или тропа — деревья тут не сажаем.
static func occupied(x: float, z: float) -> bool:
	_plan()
	var p := Vector2(x, z)
	for g in _glades:
		if p.distance_to(g[0]) < float(g[1]):
			return true
	for t in _trails:
		var pts: Array = t
		for i in pts.size() - 1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])) < 2.4:
				return true
	return false


static func glades() -> Array:
	_plan()
	return _glades


static func build(d: MeshBuilder) -> void:
	_plan()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	var earth := Color(0.38, 0.31, 0.22)
	for i in _glades.size():
		var c: Vector2 = _glades[i][0]
		var rad: float = _glades[i][1]
		var r: Rect2 = forests()[i]
		_trail(d, _trails[i], earth)
		_glade(d, Vector3(c.x, 0, c.y), rad, rng)
		# Поваленные деревья, пни и листья — по всему лесу
		for k in 4:
			var p := _spot(r, rng)
			if p != Vector3.INF:
				_fallen(d, p, rng.randf() * TAU, rng.randf() < 0.5, rng)
		for k in 7:
			var p := _spot(r, rng)
			if p != Vector3.INF:
				_stump(d, p, rng)
		for k in 6:
			var p := _spot(r, rng)
			if p != Vector3.INF:
				_leaves(d, p, rng)


## Свободное место в лесу (не на дороге, не у реки, не в селе) или INF.
static func _spot(r: Rect2, rng: RandomNumberGenerator) -> Vector3:
	for tries in 6:
		var x := rng.randf_range(r.position.x + 4.0, r.end.x - 4.0)
		var z := rng.randf_range(r.position.y + 4.0, r.end.y - 4.0)
		if Region.road_dist(x, z) > 6.0 and Region.river_dist(x, z) > 14.0 and absf(z) > 12.0 and not EliteDistrict.occupied(x, z):
			return Vector3(x, 0, z)
	return Vector3.INF


## Тропа: утоптанная земля шириной метр с небольшим.
static func _trail(d: MeshBuilder, pts: Array, col: Color) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var c: Vector2 = pts[i + 1]
		var dir := c - a
		var mid := (a + c) * 0.5
		d.box_rot(Vector3(mid.x, 0.01, mid.y), Vector3(1.3, 0.02, dir.length() + 0.6), atan2(dir.x, dir.y), col)


## Поляна: светлая трава, бревно-скамья, кострище из камней, пара пней.
static func _glade(d: MeshBuilder, c: Vector3, rad: float, rng: RandomNumberGenerator) -> void:
	PersonModel.limb(d, c, c + Vector3(0, 0.02, 0), Vector2(rad, rad), Vector2(rad, rad), Color(0.42, 0.55, 0.26), true)
	# Кострище: кольцо камней, зола, обгоревшие поленья
	PersonModel.limb(d, c, c + Vector3(0, 0.03, 0), Vector2(0.7, 0.7), Vector2(0.7, 0.7), Color(0.16, 0.15, 0.14), true)
	for k in 9:
		var a := TAU * k / 9.0
		PersonModel.ball(d, c + Vector3(cos(a) * 0.85, 0.08, sin(a) * 0.85), Vector3(0.16, 0.1, 0.14), Color(0.5, 0.49, 0.46), 2, 6)
	for k in 3:
		var a := rng.randf() * TAU
		VehicleModels.tube(d, c + Vector3(cos(a) * 0.4, 0.06, sin(a) * 0.4), c + Vector3(-cos(a) * 0.3, 0.12, -sin(a) * 0.3), 0.05, Color(0.12, 0.1, 0.09))
	# Бревно-скамья
	var yaw := rng.randf() * TAU
	var lp := c + Vector3(cos(yaw) * 2.6, 0, sin(yaw) * 2.6)
	var along := Vector3(-sin(yaw), 0, cos(yaw)) * 1.6
	PersonModel.limb(d, lp - along + Vector3(0, 0.22, 0), lp + along + Vector3(0, 0.22, 0), Vector2(0.22, 0.22), Vector2(0.2, 0.2), Color(0.42, 0.32, 0.22), true)
	d.add_collider(lp - Vector3(1.0, 0, 1.0), lp + Vector3(1.0, 0.44, 1.0))
	# Поленница у края поляны
	var wp := c + Vector3(rad - 2.5, 0, 0)
	for row in 3:
		for k in 5:
			var y := 0.12 + row * 0.22
			var x := -0.9 + k * 0.45 + (row % 2) * 0.2
			PersonModel.limb(d, wp + Vector3(x, y, -0.5), wp + Vector3(x, y, 0.5), Vector2(0.11, 0.11), Vector2(0.11, 0.11), Color(0.55, 0.42, 0.28), true)
	d.add_collider(wp - Vector3(1.1, 0, 0.55), wp + Vector3(1.1, 0.7, 0.55))


## Поваленное дерево: ствол на земле, корни вывернуты с комом земли, сучья.
static func _fallen(d: MeshBuilder, p: Vector3, yaw: float, birch: bool, rng: RandomNumberGenerator) -> void:
	var bark := Color(0.88, 0.88, 0.84) if birch else Color(0.38, 0.28, 0.2)
	var dir := Vector3(cos(yaw), 0, sin(yaw))
	var len := rng.randf_range(7.0, 11.0)
	var a := p + Vector3(0, 0.3, 0)
	var c := p + dir * len + Vector3(0, 0.18, 0)
	PersonModel.limb(d, a, c, Vector2(0.3, 0.3), Vector2(0.12, 0.12), bark, true)
	if birch:
		for k in 6:
			var q := a.lerp(c, 0.1 + k * 0.14)
			d.box(q + Vector3(-0.08, 0.2, -0.08), q + Vector3(0.08, 0.31, 0.08), Color(0.12, 0.12, 0.12))
	# Корни и ком земли — вывернуты вверх
	PersonModel.ball(d, p - dir * 0.2 + Vector3(0, 0.7, 0), Vector3(0.9, 0.9, 0.35), Color(0.32, 0.25, 0.18), 3, 8)
	for k in 5:
		var ang := TAU * k / 5.0
		var tip := p - dir * 0.3 + Vector3(cos(ang) * 0.4, 0.7 + sin(ang) * 0.9, sin(ang) * 0.2) + Vector3(-dir.z, 0, dir.x) * cos(ang) * 0.8
		VehicleModels.tube(d, p + Vector3(0, 0.6, 0), tip, 0.04, Color(0.3, 0.22, 0.15))
	# Сучья вдоль ствола
	for k in 4:
		var q := a.lerp(c, 0.3 + k * 0.15)
		var side := Vector3(-dir.z, 0, dir.x) * (1.0 if k % 2 == 0 else -1.0)
		VehicleModels.tube(d, q, q + side * 1.1 + Vector3(0, 0.5, 0) + dir * 0.4, 0.035, bark.darkened(0.15))
	# Препятствие — по стволу: коробка вдоль него (поперёк — с запасом)
	var lo := Vector3(minf(a.x, c.x), 0, minf(a.z, c.z)) - Vector3(0.3, 0, 0.3)
	var hi := Vector3(maxf(a.x, c.x), 0.6, maxf(a.z, c.z)) + Vector3(0.3, 0, 0.3)
	if absf(dir.x) > 0.3 and absf(dir.z) > 0.3:
		# Наискосок коробка вышла бы огромной — тогда только ком с корнями
		lo = p - Vector3(0.9, 0, 0.9)
		hi = p + Vector3(0.9, 1.4, 0.9)
	d.add_collider(lo, hi)


## Пень: низкий срез с годичными кольцами, мох сбоку.
static func _stump(d: MeshBuilder, p: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(0.25, 0.55)
	var r := rng.randf_range(0.22, 0.38)
	PersonModel.limb(d, p, p + Vector3(0, h, 0), Vector2(r * 1.15, r * 1.15), Vector2(r, r), Color(0.36, 0.27, 0.19), true)
	PersonModel.limb(d, p + Vector3(0, h, 0), p + Vector3(0, h + 0.01, 0), Vector2(r * 0.9, r * 0.9), Vector2(r * 0.9, r * 0.9), Color(0.72, 0.6, 0.42), true)
	PersonModel.ball(d, p + Vector3(r * 0.6, h * 0.4, 0), Vector3(0.12, h * 0.4, 0.2), Color(0.3, 0.45, 0.2), 2, 6)


## Ковёр листьев и хвои: пятна жёлтых, рыжих и бурых листьев.
static func _leaves(d: MeshBuilder, p: Vector3, rng: RandomNumberGenerator) -> void:
	var cols := [Color(0.62, 0.48, 0.2), Color(0.55, 0.32, 0.16), Color(0.42, 0.33, 0.2), Color(0.7, 0.58, 0.25)]
	for k in 10:
		var q := p + Vector3(rng.randf_range(-2.5, 2.5), 0.012, rng.randf_range(-2.5, 2.5))
		d.box_rot(q, Vector3(rng.randf_range(0.4, 1.1), 0.01, rng.randf_range(0.3, 0.8)), rng.randf() * TAU, cols[k % cols.size()])
