class_name KamenkaNorth
extends RefCounted
## Каменка-Северная: новая часть села за лесной дорогой, как в настоящих
## сёлах — от лесной дороги на север идёт Центральная улица с домами по
## обе стороны; у неё магазин «24 часа», трёхэтажка и грузовой двор; в конце
## — улица-кольцо (тупик) вокруг сквера с качелями, дома вокруг кольца.
## Дома — как в сёлах района (Region._house), улицы — гравий (Roads.FIELD).

## Вся часть села: здесь лес не растёт.
const AREA := Rect2(-100, -262, 95, 178)
## Центральная улица (ось) и кольцо вокруг сквера.
const STREET_X := -62.0
const RING := Rect2(-80, -236, 36, 30)
const SHOP24 := Vector3(-48, 0, -147)
const FLATS := Vector3(-44, 0, -176)
const DEPOT := Rect2(-32, -128, 26, 34)


## Дома: [где, куда смотрит]. Фасад — к улице, огород — за домом.
static func houses() -> Array:
	var out := []
	for z in [-100.0, -122.0, -144.0, -166.0, -188.0]:
		out.append([Vector2(-75, z), PI / 2.0])
	for z in [-100.0, -122.0]:
		out.append([Vector2(-49, z), -PI / 2.0])
	for x in [-73.0, -51.0]:
		out.append([Vector2(x, -246), 0.0])
	out.append([Vector2(-90, -221), PI / 2.0])
	out.append([Vector2(-34, -221), -PI / 2.0])
	return out


## Всё сразу: дома, магазин, трёхэтажка, грузовой двор, сквер, фонари.
static func build(r: Region, glow: MeshBuilder, veg: Vegetation) -> void:
	var d: MeshBuilder = r._d
	var i := 0
	for h in houses():
		var p: Vector2 = h[0]
		var yaw: float = h[1]
		r._house(Vector3(p.x, 0, p.y), yaw, 500 + i * 3, glow)
		_block(veg, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0, p.y)), Rect2(-10.5, -14.5, 21, 24))
		i += 1
	_shop24(r, d, glow, veg)
	_flats(d, glow, veg)
	_depot(r, d, veg)
	_square(r, d, veg)
	# Фонари вдоль Центральной улицы и вокруг кольца
	var lamps: Array[Vector3] = []
	var z := -95.0
	while z > -205.0:
		lamps.append(Vector3(STREET_X + 3.8, 0, z))
		z -= 24.0
	for p in [Vector3(-82, 0, -221), Vector3(-42, 0, -221), Vector3(-62, 0, -238)]:
		lamps.append(p)
	for lp in lamps:
		d.box(lp + Vector3(-0.08, 0, -0.08), lp + Vector3(0.08, 5.0, 0.08), Color(0.4, 0.4, 0.42), true)
		d.box(lp + Vector3(-0.05, 4.9, -0.05), lp + Vector3(0.05, 5.0, 0.05), Color(0.4, 0.4, 0.42))
		glow.box(lp + Vector3(-0.18, 4.75, -0.18), lp + Vector3(0.18, 4.9, 0.18), Color(1.0, 0.85, 0.55))
	# Указатель на въезде с лесной дороги
	r._village_sign(Vector3(STREET_X - 4.5, 0, -92), PI / 2.0, "ул. Центральная")


## Прямоугольник rect дома (в его координатах) — без травы и леса.
static func _block(veg: Vegetation, xf: Transform3D, rect: Rect2) -> void:
	var mn := Vector2(INF, INF)
	var mx := -mn
	for c in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
		var w := xf * Vector3(c.x, 0, c.y)
		mn = Vector2(minf(mn.x, w.x), minf(mn.y, w.z))
		mx = Vector2(maxf(mx.x, w.x), maxf(mx.y, w.z))
	veg.block(mn.x, mn.y, mx.x, mx.y)


## Магазин «24 часа»: стеклянная витрина, вывеска, крыльцо к улице (на запад).
## Внутри — то же меню, что в сельмаге, но круглые сутки.
static func _shop24(r: Region, d: MeshBuilder, glow: MeshBuilder, veg: Vegetation) -> void:
	var xf := Transform3D(Basis(Vector3.UP, -PI / 2.0), SHOP24)
	d.xf = xf
	glow.xf = xf
	d.box(Vector3(-4, 0, -3), Vector3(4, 3.2, 3), Color(0.92, 0.9, 0.86), true)
	d.box(Vector3(-4.2, 3.2, -3.2), Vector3(4.2, 3.4, 3.2), Color(0.3, 0.3, 0.32))
	d.box(Vector3(-4.05, 2.4, 3.0), Vector3(4.05, 3.15, 3.08), Color(0.15, 0.35, 0.7))
	for x in [-2.6, 2.4]:
		glow.box(Vector3(x - 1.2, 0.5, 3.0), Vector3(x + 1.2, 2.2, 3.05), Color(0.95, 0.92, 0.75))
	d.box(Vector3(-0.6, 0, 3.0), Vector3(0.6, 2.2, 3.06), Color(0.55, 0.7, 0.75))
	d.box(Vector3(-1.2, 0, 3.0), Vector3(1.2, 0.15, 4.2), Color(0.6, 0.6, 0.58), true)
	d.box(Vector3(-1.4, 2.25, 3.0), Vector3(1.4, 2.35, 4.4), Color(0.3, 0.3, 0.32))
	d.xf = Transform3D.IDENTITY
	glow.xf = Transform3D.IDENTITY
	var l := Label3D.new()
	l.text = "МАГАЗИН 24 ЧАСА"
	l.font_size = 96
	l.pixel_size = 0.0045
	l.outline_size = 0
	l.modulate = Color(1, 0.95, 0.4)
	l.position = xf * Vector3(0, 2.78, 3.1)
	l.rotation.y = -PI / 2.0
	r.add_child(l)
	var zone := InteractZone.create("E — магазин «24 часа»: хлеб, бургер, вода, ремнабор", Vector3(3.0, 2.2, 2.4))
	zone.name = "Shop24Zone"
	zone.position = xf * Vector3(0, 0, 4.4)
	zone.activated.connect(func() -> void: r._world.open_shop(true))
	r.add_child(zone)
	veg.block(SHOP24.x - 5, SHOP24.z - 5, SHOP24.x + 5, SHOP24.z + 5)


## Трёхэтажка: панельный дом с подъездами к улице, окна этажами (вечером
## горят), балконы, плоская крыша с антеннами.
static func _flats(d: MeshBuilder, glow: MeshBuilder, veg: Vegetation) -> void:
	var c := FLATS
	var hx := 5.0
	var hz := 11.0
	var h := 9.3
	var wall := Color(0.82, 0.8, 0.74)
	d.box(c + Vector3(-hx, 0, -hz), c + Vector3(hx, h, hz), wall, true)
	d.box(c + Vector3(-hx - 0.2, h, -hz - 0.2), c + Vector3(hx + 0.2, h + 0.35, hz + 0.2), Color(0.45, 0.45, 0.47))
	# Швы между панелями
	for y in [3.1, 6.2]:
		d.box(c + Vector3(-hx - 0.02, y, -hz - 0.02), c + Vector3(hx + 0.02, y + 0.06, hz + 0.02), wall.darkened(0.15))
	for f in 3:
		var y := 0.9 + f * 3.1
		var z := -hz + 1.4
		while z < hz - 1.0:
			# Окна на улицу (запад) и во двор (восток)
			for sx in [-1.0, 1.0]:
				var x: float = c.x + sx * (hx + 0.02)
				d.box(Vector3(x - 0.03, y - 0.08, c.z + z - 0.08), Vector3(x + 0.03, y + 1.5, c.z + z + 1.28), Color(0.92, 0.92, 0.9))
				glow.box(Vector3(x - 0.04, y, c.z + z), Vector3(x + 0.04, y + 1.4, c.z + z + 1.2), Color(0.95, 0.82, 0.5) if int(z + f) % 3 != 0 else Color(0.35, 0.42, 0.5))
			# Балконы на улицу со второго этажа
			if f > 0 and int(z) % 6 == 0:
				d.box(c + Vector3(-hx - 1.1, y - 0.6, z - 0.3), c + Vector3(-hx, y - 0.45, z + 1.6), wall.darkened(0.1))
				d.box(c + Vector3(-hx - 1.1, y - 0.45, z - 0.3), c + Vector3(-hx - 1.0, y + 0.5, z + 1.6), Color(0.55, 0.35, 0.3))
			z += 2.6
	# Подъезды: двери с козырьками, лавочки
	for z in [-5.5, 5.5]:
		var e := c + Vector3(-hx, 0, z)
		d.box(e + Vector3(-0.06, 0, -0.7), e + Vector3(0.0, 2.2, 0.7), Color(0.35, 0.25, 0.2))
		d.box(e + Vector3(-1.4, 2.4, -1.1), e + Vector3(0.0, 2.55, 1.1), Color(0.4, 0.4, 0.42))
		d.box(e + Vector3(-1.4, 0, -1.1), e + Vector3(0.0, 0.2, 1.1), Color(0.6, 0.6, 0.58), true)
		d.box(e + Vector3(-2.6, 0.42, 1.4), e + Vector3(-2.2, 0.48, 3.2), Color(0.5, 0.36, 0.22), true)
	# Антенны на крыше
	for z in [-7.0, 0.0, 7.0]:
		d.box(c + Vector3(-0.04, h + 0.35, z - 0.04), c + Vector3(0.04, h + 2.2, z + 0.04), Color(0.5, 0.5, 0.52))
		d.box(c + Vector3(-0.6, h + 1.8, z - 0.02), c + Vector3(0.6, h + 1.84, z + 0.02), Color(0.5, 0.5, 0.52))
	veg.block(c.x - hx - 3.5, c.z - hz - 1, c.x + hx + 1, c.z + hz + 1)


## Грузовой двор: забор с воротами к лесной дороге, склад с рампой,
## два ГАЗ-53, поддоны и ящики, вывеска.
static func _depot(r: Region, d: MeshBuilder, veg: Vegetation) -> void:
	var rc := DEPOT
	var fence := Color(0.55, 0.57, 0.58)
	var a := rc.position
	var e := rc.end
	r._fence(d, Vector2(a.x, a.y), Vector2(e.x, a.y), fence)
	r._fence(d, Vector2(a.x, a.y), Vector2(a.x, e.y), fence)
	r._fence(d, Vector2(e.x, a.y), Vector2(e.x, e.y), fence)
	r._fence(d, Vector2(a.x, e.y), Vector2(a.x + 9, e.y), fence)
	r._fence(d, Vector2(a.x + 16, e.y), Vector2(e.x, e.y), fence)
	d.box(Vector3(a.x, 0, a.y), Vector3(e.x, 0.04, e.y), Color(0.45, 0.44, 0.42))
	# Склад с рампой
	var w := Vector3(a.x + 13, 0, a.y + 6)
	d.box(w + Vector3(-9, 0, -4), w + Vector3(9, 5.0, 4), Color(0.62, 0.6, 0.55), true)
	d.box(w + Vector3(-9.3, 5.0, -4.3), w + Vector3(9.3, 5.4, 4.3), Color(0.35, 0.4, 0.38))
	d.box(w + Vector3(-8, 0, 4), w + Vector3(8, 1.1, 5.6), Color(0.5, 0.5, 0.48), true)
	for x in [-5.0, 0.0, 5.0]:
		d.box(w + Vector3(x - 1.6, 1.1, 4.0), w + Vector3(x + 1.6, 4.0, 4.06), Color(0.35, 0.38, 0.4))
	# Два грузовика у рампы
	for k in 2:
		d.xf = Transform3D(Basis(Vector3.UP, 0.0), Vector3(a.x + 7 + k * 10, 0, a.y + 17.5))
		VehicleModels.gaz53(d, [Color(0.3, 0.45, 0.35), Color(0.35, 0.4, 0.6)][k])
		for wz in [-2.2, 1.9]:
			for wx in [-0.95, 0.95]:
				d.box(Vector3(wx - 0.15, 0, wz - 0.45), Vector3(wx + 0.15, 0.9, wz + 0.45), Color(0.07, 0.07, 0.08))
		d.add_collider(Vector3(-1.15, 0, -3.3), Vector3(1.15, 2.3, 3.3))
		d.xf = Transform3D.IDENTITY
	# Поддоны и ящики
	for k in 6:
		var p := Vector3(e.x - 3.5, 0, a.y + 14 + k * 2.4)
		d.box(p + Vector3(-0.6, 0, -0.5), p + Vector3(0.6, 0.15, 0.5), Color(0.6, 0.48, 0.3))
		if k % 2 == 0:
			d.box(p + Vector3(-0.5, 0.15, -0.45), p + Vector3(0.5, 1.0, 0.45), Color(0.55, 0.42, 0.26), true)
	var l := Label3D.new()
	l.text = "ГРУЗОВОЙ ДВОР"
	l.font_size = 96
	l.pixel_size = 0.006
	l.outline_size = 10
	l.position = Vector3(a.x + 12.5, 2.6, e.y + 0.1)
	r.add_child(l)
	veg.block(a.x - 1, a.y - 1, e.x + 1, e.y + 1)


## Сквер в кольце: трава, качели, песочница, лавочки, берёзы.
static func _square(r: Region, d: MeshBuilder, veg: Vegetation) -> void:
	var c := RING.get_center()
	var cv := Vector3(c.x, 0, c.y)
	# Качели: рама и сиденье
	for s in [-1.0, 1.0]:
		VehicleModels.tube(d, cv + Vector3(-3 + s * 1.0, 0, -1.4), cv + Vector3(-3 + s * 0.6, 2.4, 0.0), 0.04, Color(0.25, 0.4, 0.7))
		VehicleModels.tube(d, cv + Vector3(-3 + s * 1.0, 0, 1.4), cv + Vector3(-3 + s * 0.6, 2.4, 0.0), 0.04, Color(0.25, 0.4, 0.7))
	VehicleModels.tube(d, cv + Vector3(-3.7, 2.4, 0), cv + Vector3(-2.3, 2.4, 0), 0.04, Color(0.25, 0.4, 0.7))
	d.box(cv + Vector3(-3.3, 0.5, -0.2), cv + Vector3(-2.7, 0.56, 0.2), Color(0.8, 0.3, 0.2))
	# Песочница
	d.box(cv + Vector3(2, 0, -1.5), cv + Vector3(5, 0.3, 1.5), Color(0.5, 0.36, 0.22), true)
	d.box(cv + Vector3(2.15, 0.25, -1.35), cv + Vector3(4.85, 0.28, 1.35), Color(0.88, 0.8, 0.55))
	# Лавочки по краям
	for p in [cv + Vector3(0, 0, -6), cv + Vector3(0, 0, 6)]:
		d.box(p + Vector3(-1, 0.42, -0.2), p + Vector3(1, 0.48, 0.2), Color(0.5, 0.36, 0.22), true)
	# Берёзы по углам сквера
	for p in [cv + Vector3(-8, 0, -6), cv + Vector3(8, 0, -6), cv + Vector3(-8, 0, 6), cv + Vector3(8, 0, 6)]:
		r._world._tree(d, p, 0.0, Vegetation.TreeKind.BIRCH)
	veg.block(c.x - 10, c.y - 8, c.x + 10, c.y + 8)
