class_name Roadside
extends Node3D
## Жизнь вдоль дорог района: ЛЭП вдоль трассы и к сёлам, километровые
## столбики, остановки на съездах к сёлам (автобус до Каменки), придорожное
## кафе «Дорожное» у Заозерья, вторая заправка с шиномонтажом на востоке,
## ремонт грунтовки с катком и кучами щебня.

const CAFE := Vector3(-1380.0, 0, -22.0)
const FUEL2 := Vector3(1000.0, 0, 16.0)
const ROADWORK := Vector3(430.0, 0, 80.0)
const CAFE_PRICE := 60

var _world: Node3D


## b — земля района (видна издали): столбы и провода; d — мелочь вблизи.
func build(world: Node3D, b: MeshBuilder, d: MeshBuilder) -> void:
	_world = world
	_power_lines(b)
	_km_posts(b)
	_stops()
	_cafe(d)
	_fuel_station(d)
	_roadwork(d)


## Столб ЛЭП с траверсой и тремя изоляторами; провода — до следующего.
func _pole(b: MeshBuilder, p: Vector3, next: Vector3, yaw: float) -> void:
	var wood := Color(0.35, 0.28, 0.2)
	b.box_rot(p + Vector3(0, 4.5, 0), Vector3(0.26, 9.0, 0.26), yaw, wood, true)
	b.box_rot(p + Vector3(0, 8.38, 0), Vector3(2.4, 0.15, 0.16), yaw, wood)
	var across := Basis(Vector3.UP, yaw) * Vector3(1, 0, 0)
	for k in [-1.0, 0.0, 1.0]:
		var ins: Vector3 = p + across * k + Vector3(0, 8.52, 0)
		b.box(ins - Vector3(0.05, 0.07, 0.05), ins + Vector3(0.05, 0.07, 0.05), Color(0.85, 0.85, 0.8))
		if next != Vector3.INF:
			var a: Vector3 = ins + Vector3(0, 0.05, 0)
			var e: Vector3 = next + across * k + Vector3(0, 8.57, 0)
			var mid := (a + e) * 0.5 - Vector3(0, 0.5, 0)
			var dir := e - a
			b.box_rot(mid, Vector3(0.03, 0.03, dir.length()), atan2(dir.x, dir.z), Color(0.1, 0.1, 0.1))


## Линия столбов по ломаной: шаг ~50 м, в реке и на мостах столбов нет.
func _line(b: MeshBuilder, pts: Array, offset: float, step: float) -> void:
	var poles: Array[Vector3] = []
	var yaws: Array[float] = []
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var c: Vector2 = pts[i + 1]
		var len := a.distance_to(c)
		var dir := (c - a) / len
		var side := Vector2(-dir.y, dir.x) * offset
		var t := 0.0 if i == 0 else step * 0.5
		while t < len:
			var p := a + dir * t + side
			if Region.river_dist(p.x, p.y) > Region.RIVER_HALF + 6.0 and Region.road_dist(p.x, p.y) > Region.ROAD_HALF + 1.0 \
					and Railway.dist(p.x, p.y) > 4.0 \
					and Landscape.height_at(p.x, p.y) < 0.1:
				poles.append(Vector3(p.x, 0, p.y))
				yaws.append(atan2(dir.x, dir.y) + PI * 0.5)
			t += step
	for i in poles.size():
		var next := poles[i + 1] if i + 1 < poles.size() and poles[i].distance_to(poles[i + 1]) < 90.0 else Vector3.INF
		_pole(b, poles[i], next, yaws[i])


func _power_lines(b: MeshBuilder) -> void:
	# Вдоль трассы — с севера, за Каменкой (в Каменке своя линия)
	_line(b, [Vector2(-Region.HALF + 20.0, -9.0), Vector2(-215.0, -9.0)], 0.0, 50.0)
	_line(b, [Vector2(215.0, -9.0), Vector2(Region.HALF - 20.0, -9.0)], 0.0, 50.0)
	# К сёлам — вдоль грунтовок
	for r in Region.ROADS:
		var pts: Array = r
		if (pts[0] as Vector2).distance_to(pts[pts.size() - 1]) > 150.0:
			_line(b, pts, 9.0, 55.0)


## Километровые столбики вдоль трассы: белые с чёрной полосой и цифрой.
func _km_posts(b: MeshBuilder) -> void:
	var x := -Region.HALF + 500.0
	while x < Region.HALF:
		if absf(x) > 220.0:
			var p := Vector3(x, 0, 6.3)
			b.box(p + Vector3(-0.12, 0, -0.12), p + Vector3(0.12, 1.1, 0.12), Color(0.95, 0.95, 0.93))
			b.box(p + Vector3(-0.13, 0.8, -0.13), p + Vector3(0.13, 0.95, 0.13), Color(0.1, 0.1, 0.1))
			var l := Label3D.new()
			l.text = str(int((x + Region.HALF) / 1000.0 * 10.0) / 10.0).replace(".", ",")
			l.font_size = 64
			l.pixel_size = 0.004
			l.outline_size = 0
			l.modulate = Color(0.1, 0.1, 0.1)
			l.position = p + Vector3(0, 0.55, -0.13)
			l.rotation.y = PI
			add_child(l)
		x += 500.0


## Остановки у съездов с трассы к сёлам: отсюда автобус до Каменки.
func _stops() -> void:
	var d := MeshBuilder.new()
	for r in Region.ROADS:
		var start: Vector2 = r[0]
		# Только съезды с трассы (начало дороги у самой трассы)
		if absf(start.y) > 6.0 or absf(start.x) < 230.0:
			continue
		var side := 1.0 if start.y > 0.0 else -1.0
		var p := Vector3(start.x + 14.0, 0, side * 7.8)
		_world._bus_stop(d, p, 0.0 if side < 0.0 else PI, false)
	add_child(d.build_mesh())
	add_child(d.build_body())


## Придорожное кафе у съезда к Заозерью: столики под навесом, фура у входа.
func _cafe(d: MeshBuilder) -> void:
	var c := CAFE
	var wall := Color(0.85, 0.75, 0.55)
	d.box(c + Vector3(-6, 0, -4), c + Vector3(6, 3.2, 4), wall, true)
	d.box(c + Vector3(-6.4, 3.2, -4.4), c + Vector3(6.4, 3.45, 4.4), Color(0.55, 0.25, 0.18))
	d.box(c + Vector3(-5.5, 1.0, 4.0), c + Vector3(-1.5, 2.3, 4.05), Color(0.35, 0.45, 0.5))
	d.box(c + Vector3(1.5, 1.0, 4.0), c + Vector3(5.5, 2.3, 4.05), Color(0.35, 0.45, 0.5))
	d.box(c + Vector3(-0.7, 0, 4.0), c + Vector3(0.7, 2.3, 4.05), Color(0.4, 0.28, 0.2))
	# Навес над террасой и столики со скамейками
	d.box(c + Vector3(-6, 2.7, 4), c + Vector3(6, 2.85, 8), Color(0.75, 0.2, 0.18))
	for x in [-5.9, 5.8]:
		d.box(c + Vector3(x, 0, 7.8), c + Vector3(x + 0.1, 2.7, 7.9), Color(0.3, 0.25, 0.2))
	for x in [-4.0, 0.0, 4.0]:
		var t := c + Vector3(x, 0, 6.0)
		d.box(t + Vector3(-0.6, 0.72, -0.5), t + Vector3(0.6, 0.78, 0.5), Color(0.5, 0.36, 0.22), true)
		d.box(t + Vector3(-0.05, 0, -0.05), t + Vector3(0.05, 0.72, 0.05), Color(0.3, 0.25, 0.2))
		for s in [-1.0, 1.0]:
			d.box(t + Vector3(-0.6, 0.42, s * 0.85 - 0.15), t + Vector3(0.6, 0.47, s * 0.85 + 0.15), Color(0.5, 0.36, 0.22))
	# Мангал с дымком — просто красные угли
	d.box(c + Vector3(6.6, 0, 5.0), c + Vector3(7.8, 0.8, 5.5), Color(0.2, 0.2, 0.2))
	d.box(c + Vector3(6.7, 0.8, 5.05), c + Vector3(7.7, 0.84, 5.45), Color(0.9, 0.3, 0.1))
	d.box(c + Vector3(-13, 0, 8.5), c + Vector3(13, 0.04, 17.5), Color(0.4, 0.4, 0.41))
	var l := Label3D.new()
	l.text = "КАФЕ «ДОРОЖНОЕ»\nшашлык · борщ · чай"
	l.font_size = 96
	l.pixel_size = 0.006
	l.outline_size = 10
	l.modulate = Color(1.0, 0.95, 0.85)
	l.outline_modulate = Color(0.4, 0.15, 0.1)
	l.position = c + Vector3(0, 2.9, 4.1)
	add_child(l)
	# Фура дальнобойщика на стоянке
	var truck := MeshBuilder.new()
	truck.ground_shade = false
	VehicleModels.gaz53(truck, Color(0.6, 0.15, 0.12), null)
	var tm := truck.build_mesh()
	tm.position = c + Vector3(-8.0, 0.05, 13.0)
	tm.rotation.y = PI / 2.0
	add_child(tm)
	var zone := InteractZone.create("", Vector3(3.0, 2.2, 3.0))
	zone.position = c + Vector3(0, 0, 5.8)
	zone.prompt_fn = func() -> String:
		var h := TimeManager.hour()
		if h < 7.0 or h >= 23.0:
			return "Кафе закрыто. Открыто с 7:00 до 23:00"
		return "E — пообедать: шашлык и борщ (%d грн)" % CAFE_PRICE
	zone.activated.connect(func() -> void:
		var h := TimeManager.hour()
		if h < 7.0 or h >= 23.0 or not GameManager.spend(CAFE_PRICE):
			return
		TimeManager.advance(30.0)
		NeedsManager.eat(45.0)
		SoundLibrary.play("click", -4.0)
		QuestManager.event("ate")
		GameManager.notify("Шашлык с лучком и тарелка борща — сытно. Дальнобойщики хвалят"))
	add_child(zone)


## Заправка «на востоке» у трассы и шиномонтаж рядом.
func _fuel_station(d: MeshBuilder) -> void:
	var c := FUEL2
	d.box(c + Vector3(-12, 0, -4), c + Vector3(12, 0.05, 12), Color(0.33, 0.33, 0.34))
	# Навес на столбах, две колонки, будка кассы
	d.box(c + Vector3(-6, 4.2, 0), c + Vector3(6, 4.6, 7), Color(0.9, 0.9, 0.88))
	d.box(c + Vector3(-6.02, 4.2, 6.98), c + Vector3(6.02, 4.6, 7.02), Color(0.15, 0.5, 0.25))
	for x in [-5.0, 4.8]:
		for z in [0.5, 6.3]:
			d.box(c + Vector3(x, 0, z), c + Vector3(x + 0.25, 4.2, z + 0.25), Color(0.8, 0.8, 0.78), true)
	for x in [-2.0, 2.0]:
		d.box(c + Vector3(x - 0.4, 0, 3.0), c + Vector3(x + 0.4, 1.7, 3.8), Color(0.2, 0.55, 0.3), true)
		d.box(c + Vector3(x - 0.3, 1.1, 3.8), c + Vector3(x + 0.3, 1.5, 3.82), Color(0.2, 0.2, 0.22))
	d.box(c + Vector3(7, 0, 8), c + Vector3(11, 2.8, 11.5), Color(0.9, 0.9, 0.88), true)
	d.box(c + Vector3(6.8, 2.8, 7.8), c + Vector3(11.2, 3.0, 11.7), Color(0.15, 0.5, 0.25))
	var l := Label3D.new()
	l.text = "АЗС"
	l.font_size = 96
	l.pixel_size = 0.012
	l.outline_size = 12
	l.modulate = Color(1, 1, 1)
	l.outline_modulate = Color(0.1, 0.4, 0.2)
	l.position = c + Vector3(0, 4.4, -0.05)
	l.rotation.y = PI
	add_child(l)
	var zone := InteractZone.create("", Vector3(8.0, 2.2, 5.0))
	zone.position = c + Vector3(0, 0, 3.4)
	zone.prompt_fn = func() -> String:
		var car: Vehicle = _world._car_near(c + Vector3(0, 0, 3.4), 10.0)
		if car == null:
			return "АЗС: подгони машину к колонкам"
		var need := int(ceilf(car.tank() - car.fuel))
		if need <= 0:
			return "Бак полный (%d л)" % int(car.fuel)
		return "E — заправить %d л за %d грн (в баке %d л)" % [need, need * _world.FUEL_PRICE, int(car.fuel)]
	zone.activated.connect(func() -> void:
		var car: Vehicle = _world._car_near(c + Vector3(0, 0, 3.4), 10.0)
		if car == null:
			return
		var price: int = _world.FUEL_PRICE
		var liters := minf(car.tank() - car.fuel, floorf(GameManager.money / float(price)))
		if liters < 1.0:
			return
		GameManager.spend(int(ceilf(liters)) * price)
		car.refuel(liters)
		QuestManager.event("refuel")
		GameManager.notify("Заправил %d л. В баке %d л" % [int(liters), int(car.fuel)]))
	add_child(zone)
	# Шиномонтаж: будка, стопки покрышек, вывеска
	var t := c + Vector3(-18, 0, 7)
	d.box(t + Vector3(-3, 0, -2.5), t + Vector3(3, 2.8, 2.5), Color(0.55, 0.55, 0.57), true)
	d.box(t + Vector3(-1.5, 0, 2.5), t + Vector3(1.5, 2.4, 2.55), Color(0.2, 0.2, 0.22))
	for k in 4:
		for j in 5:
			var tp := t + Vector3(3.8 + k * 0.9, j * 0.25, 1.5)
			d.box(tp + Vector3(-0.38, 0, -0.38), tp + Vector3(0.38, 0.24, 0.38), Color(0.08, 0.08, 0.09))
	var ls := Label3D.new()
	ls.text = "ШИНОМОНТАЖ"
	ls.font_size = 96
	ls.pixel_size = 0.005
	ls.outline_size = 8
	ls.position = t + Vector3(0, 2.55, 2.6)
	add_child(ls)


## Ремонт грунтовки к Заречью: каток, кучи щебня, конусы, знак.
func _roadwork(d: MeshBuilder) -> void:
	var c := ROADWORK
	# Щебень кучами у обочины
	for k in 3:
		var p := c + Vector3(6.0, 0, -12.0 + k * 8.0)
		for i in 4:
			var w := 2.4 - i * 0.55
			d.box_rot(p + Vector3(0, 0.25 + i * 0.4, 0), Vector3(w, 0.5, w), i * 0.4, Color(0.55, 0.53, 0.5).darkened(i * 0.04), i == 0)
	# Каток: кабина, два вальца
	var r := c + Vector3(-1.3, 0, 4.0)
	d.box(r + Vector3(-0.9, 0.9, -1.2), r + Vector3(0.9, 2.6, 0.6), Color(0.95, 0.75, 0.15), true)
	d.box(r + Vector3(-0.8, 1.9, -1.1), r + Vector3(0.8, 2.5, 0.1), Color(0.4, 0.5, 0.55))
	for z in [-2.2, 1.6]:
		for i in 8:
			var a0 := TAU * i / 8.0
			var a1 := TAU * (i + 1) / 8.0
			var p0 := r + Vector3(0, 0.6 + sin(a0) * 0.6, z + cos(a0) * 0.6)
			var p1 := r + Vector3(0, 0.6 + sin(a1) * 0.6, z + cos(a1) * 0.6)
			d.quad(p0 + Vector3(-1.0, 0, 0), p1 + Vector3(-1.0, 0, 0), p1 + Vector3(1.0, 0, 0), p0 + Vector3(1.0, 0, 0), Color(0.3, 0.3, 0.32), true)
	d.add_collider(r + Vector3(-1.0, 0, -2.8), r + Vector3(1.0, 1.2, 2.2))
	# Конусы и знак «Дорожные работы»
	for k in 5:
		var cp := c + Vector3(0.4, 0, -8.0 + k * 3.5)
		d.box(cp + Vector3(-0.2, 0, -0.2), cp + Vector3(0.2, 0.08, 0.2), Color(0.1, 0.1, 0.1))
		d.box(cp + Vector3(-0.12, 0.08, -0.12), cp + Vector3(0.12, 0.6, 0.12), Color(0.95, 0.45, 0.1))
		d.box(cp + Vector3(-0.125, 0.3, -0.125), cp + Vector3(0.125, 0.38, 0.125), Color(0.95, 0.95, 0.95))
	_world._sign(d, c + Vector3(-4.5, 0, -18.0), PI, "ДОРОЖНЫЕ\nРАБОТЫ", 1.3, true)
