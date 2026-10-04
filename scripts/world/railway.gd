class_name Railway
extends Node3D
## Железная дорога через весь район: путь с запада на восток южнее города,
## стальной мост через Быструю, переезды на грунтовках со шлагбаумами и
## мигалками, платформа «Каменка» у вокзала. По линии ходит электричка:
## стоит на станции, уходит к краю района и возвращается.
##
## Перед переездом электричка гудит, шлагбаумы опускаются, машины района
## ждут (RuralLife спрашивает closed_ahead). Поезд твёрдый — под него лучше
## не лезть.

## Ось пути: прямо от западного края до Степного, там обходит поле с юга.
const LINE := [Vector2(-2000, 205), Vector2(1330, 205), Vector2(1460, 245), Vector2(2000, 245)]
## Середина платформы у вокзала (вокзал — town_south.gd, севернее пути).
const STATION := Vector2(97.0 + Town.SHIFT.x, 205.0)
const SPEED := 22.0
const STOP_TIME := 25.0
const END_WAIT := 30.0
const CAR_LEN := 19.0
const CARS := 4
const RAIL_Y := 0.32
## Переезд закрыт, когда поезд ближе этого.
const CLOSE_DIST := 140.0

## Переезды: {"p": Vector2, "arms": [Node3D], "lights": [MeshInstance3D]}
static var crossings: Array = []
static var _closed: Array[Vector2] = []

var train: Array[AnimatableBody3D] = []
## Положение головы поезда на линии (метры от западного конца), куда едет.
var s := 0.0
var dir := 1.0
var v := 0.0
var wait := 0.0
var state := "station"
## Где встанет: у станции или у конца линии (выбирается при отправлении).
var target := -1.0
var _t := 0.0
var _honked: Array = []


## Расстояние от точки до оси пути.
static func dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for i in LINE.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, LINE[i], LINE[i + 1])
		best = minf(best, q.distance_to(p))
	return best


static func length() -> float:
	var total := 0.0
	for i in LINE.size() - 1:
		total += (LINE[i] as Vector2).distance_to(LINE[i + 1])
	return total


## Точка и направление пути на расстоянии t от западного конца.
static func at(t: float) -> Array:
	for i in LINE.size() - 1:
		var a: Vector2 = LINE[i]
		var c: Vector2 = LINE[i + 1]
		var seg := a.distance_to(c)
		if t <= seg or i == LINE.size() - 2:
			var d := (c - a) / seg
			return [a + d * clampf(t, 0.0, seg), d]
		t -= seg
	return [LINE[0], Vector2.RIGHT]


## Метры вдоль пути до ближайшей к p точки.
static func along(p: Vector2) -> float:
	var acc := 0.0
	var best := INF
	var out := 0.0
	for i in LINE.size() - 1:
		var a: Vector2 = LINE[i]
		var c: Vector2 = LINE[i + 1]
		var q := Geometry2D.get_closest_point_to_segment(p, a, c)
		if q.distance_to(p) < best:
			best = q.distance_to(p)
			out = acc + a.distance_to(q)
		acc += a.distance_to(c)
	return out


## Закрыт ли переезд впереди: для машин района, едущих из pos в сторону d.
static func closed_ahead(pos: Vector2, d: Vector2, ahead_m: float) -> bool:
	for c in _closed:
		var rel: Vector2 = c - pos
		var a := rel.dot(d)
		if a > 3.0 and a < ahead_m and absf(rel.cross(d)) < 6.0:
			return true
	return false


## Где путь пересекает грунтовки района.
static func road_crossings() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for sg in Region.segments():
		for i in LINE.size() - 1:
			var hit = Geometry2D.segment_intersects_segment(sg[0], sg[1], LINE[i], LINE[i + 1])
			if hit != null and out.all(func(o: Vector2) -> bool: return o.distance_to(hit) > 5.0):
				out.append(hit)
	return out


## Где путь пересекает реку — там мост.
static func river_crossing() -> Vector2:
	var rv := Region.river()
	for i in LINE.size() - 1:
		for k in rv.size() - 1:
			var hit = Geometry2D.segment_intersects_segment(LINE[i], LINE[i + 1], rv[k], rv[k + 1])
			if hit != null:
				return hit
	return Vector2.INF


# --- Постройка ----------------------------------------------------------------

## b — земля района (видна издали): насыпь; d — рельсы, шпалы, мост, платформа.
func build(b: MeshBuilder, d: MeshBuilder) -> void:
	crossings.clear()
	_closed.clear()
	var cross := road_crossings()
	var bridge := river_crossing()
	var gravel := Color(0.45, 0.42, 0.38)
	var sleeper := Color(0.3, 0.24, 0.2)
	var rail := Color(0.38, 0.36, 0.35)
	for i in LINE.size() - 1:
		var a: Vector2 = LINE[i]
		var c: Vector2 = LINE[i + 1]
		var seg := a.distance_to(c)
		var u := (c - a) / seg
		var yaw := atan2(u.x, u.y)
		# Кусками по 5 м: меш режется на участки, а у переездов и моста
		# насыпи и рельсов нет — там свой настил
		var t := 0.0
		while t < seg:
			var piece := minf(5.0, seg - t)
			var mid := a + u * (t + piece * 0.5)
			var gap := _near(mid, cross, 6.5 + piece * 0.5) or (bridge != Vector2.INF and mid.distance_to(bridge) < 21.0)
			if not gap:
				b.box_rot(Vector3(mid.x, 0.06, mid.y), Vector3(3.8, 0.12, piece), yaw, gravel)
				for side in [-0.76, 0.76]:
					var o: Vector2 = Vector2(u.y, -u.x) * side
					d.box_rot(Vector3(mid.x + o.x, RAIL_Y - 0.07, mid.y + o.y), Vector3(0.08, 0.14, piece), yaw, rail)
			t += piece
		# Шпалы
		t = 0.8
		while t < seg:
			var p := a + u * t
			if not _near(p, cross, 6.5) and (bridge == Vector2.INF or p.distance_to(bridge) > 21.5):
				d.box_rot(Vector3(p.x, 0.17, p.y), Vector3(2.6, 0.1, 0.25), yaw, sleeper)
			t += 1.6
	for p in cross:
		_crossing(d, p)
	if bridge != Vector2.INF:
		_bridge(d, bridge)
	_platform(d)
	_build_train()


func _near(p: Vector2, list: Array[Vector2], r: float) -> bool:
	for q in list:
		if q.distance_to(p) < r:
			return true
	return false


## Переезд: настил вровень с дорогой, знаки «Внимание, поезд»,
## шлагбаумы с обеих сторон и красные мигалки.
func _crossing(d: MeshBuilder, p: Vector2) -> void:
	var u: Vector2 = at(along(p))[1]
	var yaw := atan2(u.x, u.y)
	var n := Vector2(u.y, -u.x)
	d.box_rot(Vector3(p.x, 0.03, p.y), Vector3(4.2, 0.06, 13.0), yaw, Color(0.3, 0.3, 0.31))
	for side in [-0.76, 0.76]:
		var o: Vector2 = n * side
		d.box_rot(Vector3(p.x + o.x, 0.065, p.y + o.y), Vector3(0.08, 0.02, 13.0), yaw, Color(0.55, 0.55, 0.56))
	var arms: Array = []
	var lights: Array = []
	for k in [-1.0, 1.0]:
		# Столб со знаком и мигалкой справа от дороги перед путём
		var post: Vector2 = p + n * (5.0 * k) + u * (4.5 * k)
		d.box(Vector3(post.x - 0.07, 0, post.y - 0.07), Vector3(post.x + 0.07, 3.0, post.y + 0.07), Color(0.9, 0.9, 0.9), true)
		d.xf = Transform3D(Basis(Vector3.UP, atan2(n.x, n.y) + (PI if k > 0.0 else 0.0)), Vector3(post.x, 0, post.y))
		# Андреевский крест: две бело-красные планки накрест
		var base := d.xf
		for ang in [0.7, -0.7]:
			d.xf = base * Transform3D(Basis(Vector3.BACK, ang), Vector3(0, 2.6, 0.1))
			d.box(Vector3(-0.65, -0.08, 0), Vector3(0, 0.08, 0.04), Color(0.95, 0.95, 0.95))
			d.box(Vector3(0, -0.08, 0), Vector3(0.65, 0.08, 0.04), Color(0.9, 0.15, 0.12))
		d.xf = base
		d.box(Vector3(-0.35, 1.6, 0.08), Vector3(0.35, 1.9, 0.12), Color(0.1, 0.1, 0.1))
		d.xf = Transform3D.IDENTITY
		for lx in [-0.2, 0.2]:
			var lamp := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.16, 0.16, 0.06)
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(1.0, 0.15, 0.1)
			bm.material = mat
			lamp.mesh = bm
			lamp.visible = false
			lamp.visibility_range_end = 300.0
			lamp.position = Vector3(post.x, 1.75, post.y) + Basis(Vector3.UP, atan2(n.x, n.y) + (PI if k > 0.0 else 0.0)) * Vector3(lx, 0, 0.14)
			lamp.rotation.y = atan2(n.x, n.y) + (PI if k > 0.0 else 0.0)
			add_child(lamp)
			lights.append(lamp)
		# Шлагбаум: стрела поперёк дороги, поднята вверх
		var arm := Node3D.new()
		arm.position = Vector3(post.x, 1.0, post.y) - Vector3(n.x, 0, n.y) * (0.35 * k)
		arm.rotation.y = atan2(u.y * k, -u.x * k)
		var ab := MeshBuilder.new()
		ab.ground_shade = false
		var x := 0.0
		while x < 6.0:
			ab.box(Vector3(x, -0.06, -0.05), Vector3(x + 0.5, 0.06, 0.05), Color(0.95, 0.95, 0.95) if int(x * 2.0) % 2 == 0 else Color(0.9, 0.15, 0.12))
			x += 0.5
		var am := ab.build_mesh()
		am.visibility_range_end = 400.0
		arm.add_child(am)
		arm.rotation.z = PI / 2.0 * 0.95
		add_child(arm)
		arms.append(arm)
		d.box(Vector3(arm.position.x - 0.2, 0, arm.position.z - 0.2), Vector3(arm.position.x + 0.2, 1.1, arm.position.z + 0.2), Color(0.6, 0.6, 0.6))
	crossings.append({"p": p, "arms": arms, "lights": lights, "along": along(p)})


## Стальной мост с фермами через Быструю.
func _bridge(d: MeshBuilder, c: Vector2) -> void:
	var u: Vector2 = at(along(c))[1]
	var yaw := atan2(u.x, u.y)
	d.xf = Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, 0, c.y))
	var steel := Color(0.3, 0.38, 0.33)
	var half := 22.0
	d.box(Vector3(-2.2, -0.4, -half), Vector3(2.2, 0.15, half), Color(0.42, 0.42, 0.42))
	var t := -half
	while t < half:
		d.box(Vector3(-1.3, 0.15, t), Vector3(1.3, 0.22, t + 0.25), Color(0.3, 0.24, 0.2))
		t += 0.8
	for side in [-0.76, 0.76]:
		d.box(Vector3(side - 0.04, 0.22, -half), Vector3(side + 0.04, RAIL_Y, half), Color(0.38, 0.36, 0.35))
	for sx in [-2.3, 2.3]:
		d.box(Vector3(sx - 0.15, 0.1, -half), Vector3(sx + 0.15, 0.5, half), steel)
		d.box(Vector3(sx - 0.15, 6.0, -half + 3.0), Vector3(sx + 0.15, 6.3, half - 3.0), steel)
		var z := -half + 3.0
		while z <= half - 3.0 + 0.01:
			d.box(Vector3(sx - 0.12, 0.5, z - 0.12), Vector3(sx + 0.12, 6.0, z + 0.12), steel)
			z += 4.75
		# Раскосы
		z = -half + 3.0
		var k := 0
		while z < half - 3.0 - 0.01:
			var a := Vector3(sx, 0.5 if k % 2 == 0 else 6.0, z)
			var e := Vector3(sx, 6.0 if k % 2 == 0 else 0.5, z + 4.75)
			var mid := (a + e) * 0.5
			var saved := d.xf
			d.xf = d.xf * Transform3D(Basis(Vector3.RIGHT, atan2(e.y - a.y, e.z - a.z) * -1.0), mid)
			d.box(Vector3(-0.08, -0.08, -3.8), Vector3(0.08, 0.08, 3.8), steel)
			d.xf = saved
			z += 4.75
			k += 1
		# Наклонные концы ферм
		for e in [-1.0, 1.0]:
			var saved := d.xf
			d.xf = d.xf * Transform3D(Basis(Vector3.RIGHT, e * atan2(5.5, 3.0)), Vector3(sx, 3.25, e * (half - 1.5)))
			d.box(Vector3(-0.14, -0.14, -3.1), Vector3(0.14, 0.14, 3.1), steel)
			d.xf = saved
	var z2 := -half + 3.0
	while z2 <= half - 3.0 + 0.01:
		d.box(Vector3(-2.3, 6.0, z2 - 0.08), Vector3(2.3, 6.15, z2 + 0.08), steel)
		z2 += 9.5
	# Быки в воде
	for z in [-9.0, 9.0]:
		d.box(Vector3(-2.6, -0.5, z - 1.0), Vector3(2.6, 0.1, z + 1.0), Color(0.55, 0.55, 0.53))
	d.xf = Transform3D.IDENTITY


## Платформа «Каменка»: бетон, край с белой полосой, навес, скамейки,
## лестницы с торцов.
func _platform(d: MeshBuilder) -> void:
	var z0 := STATION.y - 7.2
	var z1 := STATION.y - 2.0
	var x0 := STATION.x - 45.0
	var x1 := STATION.x + 45.0
	var concrete := Color(0.62, 0.62, 0.6)
	d.box(Vector3(x0, 0, z0), Vector3(x1, 0.95, z1), concrete, true)
	d.box(Vector3(x0, 0.95, z1 - 0.4), Vector3(x1, 0.97, z1 - 0.1), Color(0.95, 0.95, 0.9))
	# Пандусы с торцов
	for e in [-1.0, 1.0]:
		var xe: float = x1 if e > 0.0 else x0
		d.xf = Transform3D(Basis.IDENTITY, Vector3(xe, 0, 0))
		d.quad(Vector3(0, 0.95, z0), Vector3(0, 0.95, z1), Vector3(e * 8.0, 0.02, z1), Vector3(e * 8.0, 0.02, z0), concrete.darkened(0.08), true)
		d.xf = Transform3D.IDENTITY
	var ramp_w := z1 - z0
	for e in [-1.0, 1.0]:
		var xe: float = x1 if e > 0.0 else x0
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(8.3, 0.2, ramp_w)
		cs.shape = sh
		body.add_child(cs)
		body.position = Vector3(xe + e * 4.0, 0.4, (z0 + z1) * 0.5)
		body.rotation.z = -e * atan2(0.95, 8.0)
		add_child(body)
	# Навес на столбах, скамейки под ним
	for x in [STATION.x - 12.0, STATION.x - 4.0, STATION.x + 4.0, STATION.x + 12.0]:
		d.box(Vector3(x - 0.1, 0.95, z0 + 1.0), Vector3(x + 0.1, 3.9, z0 + 1.2), Color(0.35, 0.45, 0.4))
	d.box(Vector3(STATION.x - 14.0, 3.9, z0 + 0.2), Vector3(STATION.x + 14.0, 4.05, z1 - 0.8), Color(0.35, 0.45, 0.4))
	for x in [STATION.x - 8.0, STATION.x, STATION.x + 8.0]:
		d.box(Vector3(x - 1.2, 1.35, z0 + 0.6), Vector3(x + 1.2, 1.42, z0 + 1.0), Color(0.5, 0.38, 0.25))
	var l := Label3D.new()
	l.text = "КАМЕНКА"
	l.font_size = 120
	l.pixel_size = 0.008
	l.outline_size = 0
	l.modulate = Color(1, 1, 1)
	l.position = Vector3(STATION.x, 3.5, z1 - 0.79)
	add_child(l)
	d.box(Vector3(STATION.x - 2.5, 3.1, z1 - 0.84), Vector3(STATION.x + 2.5, 3.9, z1 - 0.8), Color(0.15, 0.3, 0.6))


# --- Электричка ---------------------------------------------------------------

## Вагон электрички: зелёный кузов с красной полосой, окна, двери, тележки.
## head — головной: скошенная кабина с лобовыми стёклами и фарами на −Z.
func _car_mesh(head: bool) -> MeshInstance3D:
	var b := MeshBuilder.new()
	b.ground_shade = false
	var green := Color(0.25, 0.48, 0.32)
	var red := Color(0.72, 0.18, 0.14)
	var hl := CAR_LEN * 0.5
	var y0 := RAIL_Y + 0.9
	b.box(Vector3(-1.55, y0, -hl), Vector3(1.55, y0 + 3.0, hl), green)
	b.box(Vector3(-1.4, y0 + 3.0, -hl), Vector3(1.4, y0 + 3.35, hl), Color(0.55, 0.55, 0.55))
	b.box(Vector3(-1.57, y0 + 0.35, -hl), Vector3(1.57, y0 + 0.55, hl), red)
	# Окна рядом и две двери с каждой стороны
	for sx in [-1.57, 1.57]:
		var z := -hl + 2.0
		while z < hl - 2.0:
			if absf(absf(z) - hl + 3.5) > 1.2:
				b.box(Vector3(sx - 0.02, y0 + 1.4, z), Vector3(sx + 0.02, y0 + 2.3, z + 1.1), Color(0.18, 0.22, 0.26))
			z += 1.5
		for dz in [-hl + 3.5, hl - 3.5]:
			b.box(Vector3(sx - 0.03, y0 + 0.1, dz - 0.65), Vector3(sx + 0.03, y0 + 2.5, dz + 0.65), Color(0.7, 0.6, 0.2))
	# Тележки с колёсами
	for bz in [-hl + 3.0, hl - 3.0]:
		b.box(Vector3(-1.2, RAIL_Y + 0.15, bz - 1.4), Vector3(1.2, y0, bz + 1.4), Color(0.15, 0.15, 0.15))
		for wz in [-0.9, 0.9]:
			for wx in [-0.8, 0.72]:
				b.box(Vector3(wx, RAIL_Y - 0.02, bz + wz - 0.45), Vector3(wx + 0.08, RAIL_Y + 0.85, bz + wz + 0.45), Color(0.25, 0.22, 0.2))
	if head:
		# Кабина: наклонный лоб, два стекла, красный «нос», фары
		b.box(Vector3(-1.55, y0, -hl - 1.2), Vector3(1.55, y0 + 1.6, -hl), red)
		b.quad(Vector3(-1.55, y0 + 1.6, -hl - 1.2), Vector3(1.55, y0 + 1.6, -hl - 1.2), Vector3(1.55, y0 + 3.0, -hl), Vector3(-1.55, y0 + 3.0, -hl), green.darkened(0.1), true)
		for x in [-1.3, 0.1]:
			b.quad(Vector3(x, y0 + 1.75, -hl - 1.06), Vector3(x + 1.2, y0 + 1.75, -hl - 1.06), Vector3(x + 1.2, y0 + 2.7, -hl - 0.26), Vector3(x, y0 + 2.7, -hl - 0.26), Color(0.15, 0.2, 0.25), true)
		for x in [-1.1, 0.8]:
			b.box(Vector3(x, y0 + 0.9, -hl - 1.24), Vector3(x + 0.3, y0 + 1.15, -hl - 1.2), Color(1.0, 0.95, 0.75))
	var mi := b.build_mesh()
	mi.visibility_range_end = 1400.0
	return mi


func _build_train() -> void:
	for i in CARS:
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(3.1, 3.4, CAR_LEN)
		cs.shape = sh
		cs.position = Vector3(0, RAIL_Y + 0.9 + 1.7, 0)
		body.add_child(cs)
		var head := i == 0 or i == CARS - 1
		var mi := _car_mesh(head)
		if i == CARS - 1:
			mi.rotation.y = PI
		body.add_child(mi)
		body.name = "TrainCar%d" % i
		add_child(body)
		train.append(body)
	s = along(STATION) + (CARS * (CAR_LEN + 1.2)) * 0.5
	dir = 1.0
	state = "station"
	wait = 5.0
	_place()


## Куда поезду остановиться: у станции (голова проходит середину платформы
## на полсостава), либо у конца линии за краем района.
func _stop_s() -> float:
	var half := CARS * (CAR_LEN + 1.2) * 0.5
	var st := along(STATION) + half * dir
	if (st - s) * dir > 1.0:
		return st
	return length() - 20.0 if dir > 0.0 else 20.0


func _place() -> void:
	for i in train.size():
		var t := s - dir * (i * (CAR_LEN + 1.2) + CAR_LEN * 0.5)
		var a := at(clampf(t, 0.0, length()))
		var p: Vector2 = a[0]
		var u: Vector2 = a[1] * dir
		var body := train[i]
		body.global_position = Vector3(p.x, 0, p.y)
		body.rotation.y = atan2(-u.x, -u.y)


func _process(delta: float) -> void:
	_t += delta
	if wait > 0.0:
		wait -= delta
		if wait <= 0.0:
			if state == "end":
				# Разворот: голова — с другого конца состава
				s = s - dir * CARS * (CAR_LEN + 1.2)
				dir = -dir
				train.reverse()
				for i in train.size():
					var mi := train[i].get_child(1) as MeshInstance3D
					mi.rotation.y = PI if i == train.size() - 1 else 0.0
			state = "run"
			wait = 0.0
			target = _stop_s()
	else:
		if target < 0.0:
			target = _stop_s()
		var stop := target
		var left := (stop - s) * dir
		var want := minf(SPEED, sqrt(maxf(left, 0.0) * 2.0 * 0.7))
		v = move_toward(v, want, delta * (0.9 if want > v else 1.6))
		s += minf(v * delta, maxf(left, 0.0)) * dir
		if left - v * delta < 0.3:
			# Встал точно у места остановки
			s = stop
			v = 0.0
			var at_station := absf(stop - along(STATION)) < 200.0
			state = "station" if at_station else "end"
			wait = STOP_TIME if at_station else END_WAIT
			_honked.clear()
			target = -1.0
	_place()
	_update_crossings(delta)


## Шлагбаумы и мигалки: закрыто, пока поезд рядом с переездом.
func _update_crossings(delta: float) -> void:
	_closed.clear()
	var tail := s - dir * CARS * (CAR_LEN + 1.2)
	var lo := minf(s, tail) - CLOSE_DIST
	var hi := maxf(s, tail) + CLOSE_DIST
	for c in crossings:
		var a: float = c.along
		var closed := a > lo and a < hi and (v > 0.1 or state == "run")
		if closed:
			_closed.append(c.p)
			# Гудок один раз на подходе
			if not _honked.has(c.p) and (a - s) * dir > 0.0:
				_honked.append(c.p)
				SoundLibrary.play_at("horn", train[0].global_position, 4.0, 0.55)
		for arm in c.arms:
			var n := arm as Node3D
			n.rotation.z = move_toward(n.rotation.z, 0.0 if closed else PI / 2.0 * 0.95, delta * 1.2)
		var blink := closed and int(_t * 2.0) % 2 == 0
		for k in c.lights.size():
			(c.lights[k] as Node3D).visible = closed and (blink == (k % 2 == 0))
