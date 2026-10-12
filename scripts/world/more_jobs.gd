class_name MoreJobs
extends RefCounted
## Ещё работы — чтобы было из чего выбрать, а не только сено и склад:
##   * хлебовоз — лотки с хлебозавода у рынка по трём сёлам, на своём транспорте;
##   * дворник — кучи листьев на площади и в парке города, каждая — пара минут
##     метлой (часы идут своим ходом);
##   * садовник в Липках — газоны у богатых домов: далеко, зато платят больше всех;
##   * лесоруб — брёвна с делянки в лесу у дороги в Липки, к штабелю у обочины.
## Всё на общих RouteJob и CarryJob: раздатчик с табличкой «РАБОТА», стрелка,
## строка задания, событие для заданий (bread, sweep, garden_job, logs).

const BAKERY := Vector3(58.0, 0, 150.0)  # в координатах города, у рынка
const SWEEP_GIVER := Vector3(116.0, 0, 26.0)
## Кучи листьев: площадь, сквер у кафе, аллеи парка (координаты города)
const SWEEP_SPOTS := [
	["площадь, у памятника", Vector3(122, 0, 14)], ["площадь, у лавочек", Vector3(130, 0, 27)],
	["тротуар у кафе", Vector3(88, 0, 20)], ["аллея парка", Vector3(4, 0, 158)],
	["парк, у фонтана", Vector3(-6, 0, 170)], ["парк, у входа", Vector3(10, 0, 150)],
]
const LOG_PAY := 60


## Строит работы и добавляет их в мир. rng — общий генератор мира.
static func build(world: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	var jobs := {}
	jobs.bread = _bread(world, rng)
	jobs.sweep = _sweep(world, rng)
	jobs.garden = _garden(world, rng)
	jobs.logs = _logs(world)
	return jobs


## Хлебовоз: три села по очереди, у каждого магазина — два лотка.
static func _bread(world: Node3D, rng: RandomNumberGenerator) -> RouteJob:
	var j := RouteJob.new()
	j.name = "BreadJob"
	j.id = "bread"
	j.title = "Хлебовоз"
	j.describe = "развезти хлеб по трём сёлам"
	j.giver = Town.w(BAKERY)
	j.sign_text = "ХЛЕБОЗАВОД\nРАБОТА"
	j.verb = "Лотки сдал"
	j.cargo = 6
	j.drop_each = 2
	j.open_from = 5.0
	j.open_to = 12.0
	j.stops_fn = func() -> Array:
		var ids: Array = range(Region.VILLAGES.size())
		ids.shuffle()
		var out := []
		for i in ids.slice(0, 3):
			var v: Dictionary = Region.VILLAGES[i]
			# Четвёртое — имя села для подсказки у раздатчика
			out.append(["магазин, %s" % v.name, Region.stop_pos(i), Region.stop_pos(i), v.name])
		return out
	j.pay_fn = func(stops: Array) -> int:
		var dist := 0.0
		var at: Vector3 = j.giver
		for s in stops:
			dist += at.distance_to(s[1])
			at = s[1]
		return int(round((90.0 + dist * 0.12) / 10.0)) * 10
	j.describe_fn = func(stops: Array, pay: int) -> String:
		var names := []
		for s in stops:
			names.append(String(s[3]))
		return "хлеб в %s — %d грн" % [", ".join(names), pay]
	world.add_child(j)
	_stand(world, Town.w(BAKERY) + Vector3(0, 0, -2.2), Color(0.85, 0.75, 0.55))
	return j


## Дворник: пять куч листьев из шести мест, у каждой — несколько минут работы.
static func _sweep(world: Node3D, rng: RandomNumberGenerator) -> RouteJob:
	var j := RouteJob.new()
	j.name = "SweepJob"
	j.id = "sweep"
	j.title = "Дворник"
	j.describe = "подмести площадь и парк (5 куч листьев)"
	j.giver = Town.w(SWEEP_GIVER)
	j.mode = "foot"
	j.radius = 1.8
	j.work_each = 6.0
	j.work_what = "Мету листья"
	j.verb = "Подмёл"
	j.open_from = 6.0
	j.open_to = 18.0
	j.stops_fn = func() -> Array:
		var spots: Array = SWEEP_SPOTS.duplicate()
		spots.shuffle()
		var out := []
		for s in spots.slice(0, 5):
			out.append([s[0], Town.w(s[1])])
		return out
	j.pay_fn = func(stops: Array) -> int: return stops.size() * 30
	j.make_prop = func(p: Vector3) -> Node3D:
		return _leaf_pile(p, rng)
	world.add_child(j)
	return j


## Садовник в Липках: газоны у четырёх домов из восьми.
static func _garden(world: Node3D, rng: RandomNumberGenerator) -> RouteJob:
	var j := RouteJob.new()
	j.name = "GardenJob"
	j.id = "garden_job"
	j.title = "Садовник в Липках"
	j.describe = "подстричь газоны у четырёх домов"
	j.giver = Vector3(EliteDistrict.BOULEVARD.end.x + 3.0, 0, EliteDistrict.BOULEVARD.end.y + 4.0)
	j.mode = "foot"
	j.radius = 2.0
	j.work_each = 15.0
	j.work_what = "Стригу газон"
	j.verb = "Газон подстриг"
	j.open_from = 8.0
	j.open_to = 19.0
	j.stops_fn = func() -> Array:
		var ids: Array = range(8)
		ids.shuffle()
		var out := []
		for i in ids.slice(0, 4):
			out.append(["газон у дома №%d" % (i + 1), garden_spot(i)])
		return out
	j.pay_fn = func(stops: Array) -> int: return stops.size() * 150
	j.make_prop = func(p: Vector3) -> Node3D:
		return _tall_grass(p, rng)
	world.add_child(j)
	return j


## Где у дома i стричь газон: перед забором, сбоку от ворот.
static func garden_spot(i: int) -> Vector3:
	return EliteDistrict.plot_xf(i) * Vector3(-6.0, 0, 1.2)


## Лесоруб: брёвна с делянки на поляне — к штабелю у быстрой дороги в Липки.
static func _logs(world: Node3D) -> CarryJob:
	var gi := Region.FORESTS.size()
	var glade: Vector2 = ForestLife.glades()[gi][0]
	var c := Vector3(glade.x, 0, glade.y)
	# Ближняя к поляне точка быстрой дороги — штабель у обочины
	var best := Vector3.INF
	var road: Array = EliteDistrict.ROAD_FAST
	for i in road.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(glade, road[i], road[i + 1])
		if best == Vector3.INF or glade.distance_to(q) < Vector2(best.x, best.z).distance_to(glade):
			best = Vector3(q.x, 0, q.y)
	var side := (c - best).normalized()
	var drop := best + side * 6.0
	# Делянка — в глубине леса за поляной: брёвна несут метров двадцать
	c = best + side * 28.0
	var j := CarryJob.new()
	j.name = "LogsJob"
	j.title = "Лесоруб"
	j.item_name = "бревно"
	j.pickup = c + Vector3(-3.0, 0, 3.0)
	j.pile_at = c + Vector3(-3.0, 0, 4.0)
	j.drop = drop
	j.stack_at = drop + side * 1.5
	j.stack_yaw = atan2(side.x, side.z)
	j.per_row = 3
	j.total = 6
	j.pay_each = LOG_PAY
	j.energy_each = 3.0
	j.item_size = Vector3(0.35, 0.35, 2.4)
	j.item_color = Color(0.48, 0.36, 0.24)
	j.event_name = "logs"
	j.can_start = func() -> String:
		var h := TimeManager.hour()
		if h < 7.0 or h > 18.0:
			return "В лесу темно — работа на делянке с 7:00 до 18:00"
		if NeedsManager.energy < 30.0:
			return "Брёвна таскать сил нет. Выспись"
		return ""
	world.add_child(j)
	j.setup()
	var zone := InteractZone.create("", Vector3(3.0, 2.2, 3.0))
	zone.position = c + Vector3(-5.0, 0, 3.0)
	zone.prompt_fn = j.start_prompt
	zone.activated.connect(j.start)
	world.add_child(zone)
	var lbl := Label3D.new()
	lbl.text = "ДЕЛЯНКА\nРАБОТА"
	lbl.font_size = 64
	lbl.pixel_size = 0.006
	lbl.outline_size = 12
	lbl.modulate = Color(1.0, 0.8, 0.3)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = zone.position + Vector3(0, 3.0, 0)
	lbl.visibility_range_end = 120.0
	world.add_child(lbl)
	return j


## Лоток с хлебом у ворот хлебозавода — видно, откуда берут работу.
static func _stand(world: Node3D, p: Vector3, col: Color) -> void:
	var b := MeshBuilder.new()
	b.box(p + Vector3(-0.8, 0, -0.4), p + Vector3(0.8, 0.8, 0.4), Color(0.45, 0.33, 0.22), true)
	for k in 4:
		b.box(p + Vector3(-0.7 + k * 0.36, 0.8, -0.3), p + Vector3(-0.42 + k * 0.36, 0.95, 0.3), col)
	var mi := b.build_mesh()
	mi.visibility_range_end = 120.0
	world.add_child(mi)


## Куча опавших листьев — исчезает, когда подметёшь.
static func _leaf_pile(p: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var b := MeshBuilder.new()
	b.ground_shade = false
	var cols := [Color(0.75, 0.55, 0.18), Color(0.62, 0.32, 0.14), Color(0.5, 0.4, 0.2)]
	for k in 14:
		var a := rng.randf() * TAU
		var r := rng.randf() * 0.9
		var q := p + Vector3(cos(a) * r, 0.02 + k * 0.012, sin(a) * r)
		b.box_rot(q, Vector3(0.5, 0.06, 0.35), rng.randf() * TAU, cols[k % cols.size()])
	return b.build_mesh()


## Отросшая трава на газоне — пучки повыше.
static func _tall_grass(p: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var b := MeshBuilder.new()
	b.ground_shade = false
	for k in 18:
		var q := p + Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-0.8, 0.8))
		b.box(q + Vector3(-0.04, 0, -0.04), q + Vector3(0.04, rng.randf_range(0.3, 0.55), 0.04), Color(0.3, 0.55, 0.2))
	return b.build_mesh()
