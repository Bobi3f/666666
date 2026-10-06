class_name Backlot
extends RefCounted
## Задворки у бурсы: за пятиэтажками на ул. Заводской — две девятиэтажки,
## старая кирпичная котельная с высокой трубой и горящими окнами, бетонный
## забор «в ромбик» с граффити, ржавая теплотрасса на опорах с «П»-аркой
## над тропинкой, тусовка у бочки с огнём: старый диван, пластиковые
## стулья, поддоны, покрышки, мешки с мусором, матрас, сгоревшие «Жигули».
## Координаты — городские (как в TownEast), в меше города.

## Всё место: лес и трава здесь не растут.
const AREA := Rect2(291, 62, 52, 132)
const BOILER := Rect2(296, 150, 20, 10)
const CHIMNEY := Vector3(321, 0, 155)
const FIRE := Vector3(306, 0, 132)
const TOWERS := [Rect2(326, 70, 13, 32), Rect2(326, 112, 13, 30)]

const CONCRETE := Color(0.62, 0.64, 0.64)
const RUST := Color(0.42, 0.25, 0.16)
const BRICK := Color(0.5, 0.27, 0.2)


static func build(east: Node3D, b: MeshBuilder, glow: MeshBuilder, veg: Vegetation) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 1987
	veg.block(AREA.position.x, AREA.position.y, AREA.end.x, AREA.end.y)
	# Утоптанная земля и тропинка от улицы мимо пятиэтажек
	b.box(Vector3(AREA.position.x, 0, AREA.position.y), Vector3(AREA.end.x, 0.02, AREA.end.y), Color(0.3, 0.33, 0.22))
	b.box(Vector3(268, 0, 116), Vector3(326, 0.03, 119), Color(0.42, 0.36, 0.27))
	for t in TOWERS:
		_tower(b, glow, t)
	_boiler(b, glow)
	_fence(b, r)
	_pipes(b)
	_hangout(east, b, glow, r)
	_litter(b, r)
	_graffiti(east)


## Девятиэтажка: панели с полосами цвета, окна этажами (вечером многие
## горят), швы панелей, лоджии, подъезды с козырьками, крыша с машинным
## отделением лифта.
static func _tower(b: MeshBuilder, glow: MeshBuilder, t: Rect2) -> void:
	var h := 27.5
	var y0 := 0.0
	var wall := Color(0.78, 0.8, 0.8)
	b.box(Vector3(t.position.x, y0, t.position.y), Vector3(t.end.x, h, t.end.y), wall, true)
	# Цветная полоса снизу и под крышей, как на старых панельках
	b.box(Vector3(t.position.x - 0.03, 0, t.position.y - 0.03), Vector3(t.end.x + 0.03, 2.8, t.end.y + 0.03), Color(0.62, 0.65, 0.35))
	b.box(Vector3(t.position.x - 0.03, h - 1.2, t.position.y - 0.03), Vector3(t.end.x + 0.03, h, t.end.y + 0.03), Color(0.35, 0.5, 0.62))
	for f in 9:
		var y := 3.0 + f * 2.75
		b.box(Vector3(t.position.x - 0.02, y - 0.12, t.position.y - 0.02), Vector3(t.end.x + 0.02, y - 0.06, t.end.y + 0.02), wall.darkened(0.12))
		var z := t.position.y + 1.2
		var k := 0
		while z < t.end.y - 1.5:
			for x in [t.position.x - 0.03, t.end.x + 0.01]:
				var lit := (k * 7 + f * 3) % 5 < 2
				glow.box(Vector3(x, y + 0.5, z), Vector3(x + 0.02, y + 1.9, z + 1.3), Color(0.95, 0.8, 0.45) if lit else Color(0.22, 0.27, 0.32))
			z += 2.3
			k += 1
	# Подъезды к улице (запад): двери и козырьки
	for z in [t.position.y + 7.0, t.end.y - 7.0]:
		b.box(Vector3(t.position.x - 0.05, 0, z - 0.8), Vector3(t.position.x, 2.3, z + 0.8), Color(0.35, 0.28, 0.22))
		b.box(Vector3(t.position.x - 1.6, 2.5, z - 1.4), Vector3(t.position.x, 2.65, z + 1.4), CONCRETE.darkened(0.2))
		glow.box(Vector3(t.position.x - 0.3, 2.3, z - 0.15), Vector3(t.position.x - 0.1, 2.45, z + 0.15), Color(1.0, 0.9, 0.6))
	b.box(Vector3(t.position.x + 3, h, t.position.y + 10), Vector3(t.end.x - 3, h + 2.6, t.position.y + 16), wall.darkened(0.1))


## Котельная: кирпич, большие окна в мелкую клетку (горят), ворота,
## рядом высокая кирпичная труба с поясами.
static func _boiler(b: MeshBuilder, glow: MeshBuilder) -> void:
	var c := BOILER
	b.box(Vector3(c.position.x, 0, c.position.y), Vector3(c.end.x, 5.5, c.end.y), BRICK, true)
	b.box(Vector3(c.position.x - 0.2, 5.5, c.position.y - 0.2), Vector3(c.end.x + 0.2, 5.8, c.end.y + 0.2), BRICK.darkened(0.3))
	for y in [1.4, 2.8, 4.2]:
		b.box(Vector3(c.position.x - 0.02, y, c.position.y - 0.02), Vector3(c.end.x + 0.02, y + 0.05, c.end.y + 0.02), BRICK.darkened(0.2))
	var x := c.position.x + 1.5
	while x < c.end.x - 1.0:
		glow.box(Vector3(x, 1.6, c.position.y - 0.03), Vector3(x + 1.6, 4.3, c.position.y), Color(0.95, 0.78, 0.38))
		for k in 3:
			b.box(Vector3(x + k * 0.55, 1.6, c.position.y - 0.05), Vector3(x + k * 0.55 + 0.05, 4.3, c.position.y - 0.03), BRICK.darkened(0.4))
		x += 3.3
	b.box(Vector3(c.end.x - 0.02, 0, c.position.y + 2.5), Vector3(c.end.x + 0.03, 3.6, c.position.y + 6.5), Color(0.3, 0.32, 0.3))
	# Труба: сужается кверху, пояса, ржавые скобы-лестница
	var ch := CHIMNEY
	PersonModel.limb(b, ch, ch + Vector3(0, 32, 0), Vector2(1.5, 1.5), Vector2(0.9, 0.9), BRICK.darkened(0.08))
	for y in [8.0, 16.0, 24.0, 31.0]:
		var rr := lerpf(1.5, 0.9, y / 32.0) + 0.08
		PersonModel.limb(b, ch + Vector3(0, y, 0), ch + Vector3(0, y + 0.5, 0), Vector2(rr, rr), Vector2(rr, rr), BRICK.darkened(0.3))
	b.box(ch + Vector3(-1.6, 0, -1.6), ch + Vector3(1.6, 1.0, 1.6), CONCRETE.darkened(0.15), true)


## Бетонный забор из плит «в ромбик» вдоль задворок, местами плиты выбиты.
static func _fence(b: MeshBuilder, r: RandomNumberGenerator) -> void:
	var runs := [[Vector2(292, 64), Vector2(292, 114)], [Vector2(292, 121), Vector2(292, 192)], [Vector2(292, 192), Vector2(342, 192)], [Vector2(342, 64), Vector2(342, 192)]]
	for run in runs:
		var a: Vector2 = run[0]
		var c: Vector2 = run[1]
		var dir := (c - a).normalized()
		var n := int(a.distance_to(c) / 3.0)
		for i in n:
			if r.randf() < 0.06:
				continue
			var p0 := a + dir * (i * 3.0)
			var p1 := p0 + dir * 2.95
			var mn := Vector3(minf(p0.x, p1.x) - (0.08 if absf(dir.y) > 0.5 else 0.0), 0, minf(p0.y, p1.y) - (0.08 if absf(dir.x) > 0.5 else 0.0))
			var mx := Vector3(maxf(p0.x, p1.x) + (0.08 if absf(dir.y) > 0.5 else 0.0), 2.4, maxf(p0.y, p1.y) + (0.08 if absf(dir.x) > 0.5 else 0.0))
			b.box(mn, mx, CONCRETE.darkened(r.randf() * 0.12), true)
			# Ромбики рельефа — тёмными точками
			var m := (p0 + p1) * 0.5
			for yy in [0.6, 1.2, 1.8]:
				for s in [-0.75, 0.0, 0.75]:
					var q: Vector2 = m + dir * s
					var nrm := Vector2(-dir.y, dir.x) * 0.1
					b.box_rot(Vector3(q.x + nrm.x, yy, q.y + nrm.y), Vector3(0.28, 0.28, 0.02), atan2(dir.x, dir.y) + PI / 2.0, CONCRETE.darkened(0.22))


## Теплотрасса: две толстые ржавые трубы в обмотке на бетонных опорах от
## котельной к домам, над тропинкой — «П»-аркой.
static func _pipes(b: MeshBuilder) -> void:
	var pts := [Vector3(296, 0, 162), Vector3(294, 0, 162), Vector3(294, 0, 124), Vector3(294, 0, 112), Vector3(294, 0, 70)]
	for k in 2:
		var off := Vector3(-0.45 + k * 0.9, 0, 0)
		var y := 0.9
		var path := [pts[0] + off, pts[1] + off, pts[2] + off, pts[2] + off + Vector3(0, 3.0, 0), pts[3] + off + Vector3(0, 3.0, 0), pts[3] + off, pts[4] + off]
		for i in path.size() - 1:
			var a: Vector3 = path[i] + Vector3(0, y, 0)
			var c: Vector3 = path[i + 1] + Vector3(0, y, 0)
			PersonModel.limb(b, a, c, Vector2(0.34, 0.34), Vector2(0.34, 0.34), RUST if (i + k) % 2 == 0 else Color(0.55, 0.52, 0.48))
			PersonModel.ball(b, a, Vector3(0.36, 0.36, 0.36), RUST.darkened(0.1), 3, 8)
	# Опоры
	var z := 72.0
	while z < 162.0:
		if z < 111.0 or z > 125.0:
			b.box(Vector3(293.2, 0, z - 0.25), Vector3(294.8, 0.55, z + 0.25), CONCRETE.darkened(0.1), true)
		z += 6.0


## Тусовка у бочки: огонь, диван, стулья, стол из поддонов, покрышки,
## матрас, ящики; двое парней на корточках; сгоревшие «Жигули» у забора.
static func _hangout(east: Node3D, b: MeshBuilder, glow: MeshBuilder, r: RandomNumberGenerator) -> void:
	var f := FIRE
	b.box(f + Vector3(-5, 0, -5), f + Vector3(5, 0.03, 5), Color(0.36, 0.3, 0.22))
	PersonModel.limb(b, f, f + Vector3(0, 0.9, 0), Vector2(0.3, 0.3), Vector2(0.3, 0.3), RUST.darkened(0.2), false)
	glow.box(f + Vector3(-0.22, 0.75, -0.22), f + Vector3(0.22, 1.15, 0.22), Color(1.0, 0.55, 0.15))
	glow.box(f + Vector3(-0.12, 1.15, -0.12), f + Vector3(0.12, 1.45, 0.12), Color(1.0, 0.8, 0.3))
	# Диван: сиденье, спинка, подлокотники
	var s := f + Vector3(-2.6, 0, -1.5)
	var sofa := Color(0.3, 0.38, 0.55)
	b.box(s + Vector3(-1.0, 0.2, -0.45), s + Vector3(1.0, 0.55, 0.45), sofa, true)
	b.box(s + Vector3(-1.0, 0.55, -0.45), s + Vector3(1.0, 1.0, -0.2), sofa.darkened(0.15))
	for x in [-1.0, 0.8]:
		b.box(s + Vector3(x, 0.2, -0.45), s + Vector3(x + 0.2, 0.75, 0.45), sofa.darkened(0.1))
	# Пластиковые стулья
	for p in [f + Vector3(1.8, 0, -1.2), f + Vector3(2.0, 0, 1.0)]:
		var w := Color(0.92, 0.92, 0.9)
		b.box(p + Vector3(-0.25, 0.42, -0.25), p + Vector3(0.25, 0.47, 0.25), w)
		b.box(p + Vector3(0.2, 0.47, -0.25), p + Vector3(0.25, 0.9, 0.25), w)
		for q in [Vector3(-0.22, 0, -0.22), Vector3(0.18, 0, -0.22), Vector3(-0.22, 0, 0.18), Vector3(0.18, 0, 0.18)]:
			b.box(p + q, p + q + Vector3(0.04, 0.42, 0.04), w.darkened(0.1))
	# Стол из поддонов, бутылки на нём
	var t := f + Vector3(0.0, 0, 2.2)
	for k in 2:
		b.box(t + Vector3(-0.6, k * 0.15, -0.4), t + Vector3(0.6, k * 0.15 + 0.12, 0.4), Color(0.6, 0.48, 0.3))
	for k in 3:
		PersonModel.limb(b, t + Vector3(-0.3 + k * 0.25, 0.27, 0), t + Vector3(-0.3 + k * 0.25, 0.5, 0), Vector2(0.035, 0.035), Vector2(0.025, 0.025), [Color(0.2, 0.45, 0.25), Color(0.5, 0.35, 0.15), Color(0.2, 0.45, 0.25)][k])
	# Покрышки столбиками и на земле
	for p in [f + Vector3(4.0, 0, -3.0), f + Vector3(4.2, 0, 3.5), Vector3(300, 0, 104)]:
		for k in r.randi_range(1, 3):
			PersonModel.limb(b, p + Vector3(0, k * 0.22, 0), p + Vector3(0, k * 0.22 + 0.2, 0), Vector2(0.36, 0.36), Vector2(0.36, 0.36), Color(0.07, 0.07, 0.08), true)
	# Матрас и ящики у стены котельной
	b.box_rot(Vector3(302, 0.1, 146.5), Vector3(1.9, 0.2, 0.9), 0.3, Color(0.55, 0.52, 0.42))
	for k in 4:
		b.box_rot(Vector3(298 + k * 1.1, 0.3, 147.6 + r.randf() * 0.4), Vector3(0.6, 0.6, 0.5), r.randf() * 0.5, Color(0.55, 0.42, 0.26))
	# Двое на корточках у огня
	for k in 2:
		var pb := MeshBuilder.new()
		pb.ground_shade = false
		PersonModel.person(pb, [Color(0.15, 0.15, 0.17), Color(0.2, 0.25, 0.4)][k], Color(0.1, 0.1, 0.1), true, false)
		var mi := pb.build_mesh()
		mi.position = f + Vector3(-1.2 + k * 2.2, -0.25, -1.3 + k * 2.6)
		mi.rotation.y = atan2(-(f.x - mi.position.x), -(f.z - mi.position.z))
		east.add_child(mi)
	# Сгоревшие «Жигули» без колёс у забора
	b.xf = Transform3D(Basis(Vector3.UP, 0.25), Vector3(336, -0.2, 176))
	VehicleModels.zhiguli(b, Color(0.18, 0.15, 0.13), false)
	b.xf = Transform3D.IDENTITY
	b.add_collider(Vector3(334.8, 0, 173.5), Vector3(337.2, 1.3, 178.5))


## Мусор: пакеты, бумажки, банки, доски — на задворках и вдоль тротуара.
static func _litter(b: MeshBuilder, r: RandomNumberGenerator) -> void:
	var cols := [Color(0.85, 0.85, 0.8), Color(0.2, 0.3, 0.6), Color(0.15, 0.15, 0.15), Color(0.6, 0.5, 0.3), Color(0.7, 0.2, 0.2)]
	for i in 160:
		var p := Vector3(r.randf_range(AREA.position.x + 1, AREA.end.x - 1), 0.03, r.randf_range(AREA.position.y + 1, AREA.end.y - 1))
		b.box_rot(p, Vector3(r.randf_range(0.1, 0.4), 0.02, r.randf_range(0.1, 0.3)), r.randf() * TAU, cols[r.randi() % cols.size()])
	for i in 50:
		var p := Vector3(r.randf_range(268.5, 272.0), 0.13, r.randf_range(90.0, 170.0))
		b.box_rot(p, Vector3(r.randf_range(0.08, 0.25), 0.01, r.randf_range(0.08, 0.2)), r.randf() * TAU, cols[r.randi() % cols.size()])
	# Мешки с мусором кучей
	for i in 7:
		var p := Vector3(r.randf_range(316, 320), 0, r.randf_range(140, 146))
		PersonModel.ball(b, p + Vector3(0, 0.3, 0), Vector3(0.35, 0.32, 0.3), Color(0.12, 0.12, 0.14), 4, 8)


## Граффити на заборе и котельной.
static func _graffiti(east: Node3D) -> void:
	var tags := [["ЦОЙ ЖИВ", Vector3(292.15, 1.2, 140), PI / 2.0, Color(0.95, 0.3, 0.3)],
		["ПТУ-14 ФОРЕВА", Vector3(292.15, 1.4, 172), PI / 2.0, Color(0.4, 0.75, 1.0)],
		["ПРАВДА", Vector3(305, 2.2, 149.95), PI, Color(0.75, 0.45, 0.95)],
		["ЛЮБА + САША", Vector3(310, 1.2, 191.9), PI, Color(1.0, 0.85, 0.3)],
		["СПАРТАК", Vector3(341.85, 1.4, 100), -PI / 2.0, Color(0.95, 0.95, 0.95)]]
	for t in tags:
		var l := Label3D.new()
		l.text = t[0]
		l.font_size = 120
		l.pixel_size = 0.006
		l.outline_size = 0
		l.modulate = t[3]
		l.position = t[1]
		l.rotation.y = t[2]
		l.double_sided = false
		l.visibility_range_end = 70.0
		east.add_child(l)
