class_name PostService
extends Node3D
## Почта района: отделения в Каменке (окошко в сельсовете), в городе и в
## четырёх ближних сёлах (синие киоски у сельмагов).
##
## В каждом — два окошка, у каждого свой заказ (RouteJob):
## «по домам» — 3 коробки по адресам этого села, по одной у каждой калитки;
## «в другую почту» — мешок посылок (6 коробок) в отделение другого села
## или города. Коробки видно на мопеде или на крыше машины.

## Почтовый киоск в городе — у главной улицы, между пятиэтажками.
const TOWN_POST := Vector3(91.0, 0, 92.0)
## Из скольких ближних сёл района — свои отделения.
const VILLAGE_POSTS := 4
const HOME_BOXES := 3
const BAG_BOXES := 6

## [{name, where, window, yaw, road, homes: [[имя, на дороге, у калитки]], home_job, bag_job}]
var offices: Array = []
var _world: Node3D
var _rng := RandomNumberGenerator.new()


func build(world: Node3D) -> void:
	_world = world
	_rng.randomize()
	# Почта Каменки — в сельсовете, окошки внутри; к крыльцу подъезжать снаружи
	_add_office("Каменка", "в Каменке", Civic.COUNCIL + Civic.KAMENKA_WINDOW, 0.0, _kamenka_homes(),
		Civic.COUNCIL + Vector3(0, 0, 7.0))
	_add_office("Город", "в городе", Town.w(TOWN_POST), PI / 2.0, _town_homes())
	for i in VILLAGE_POSTS:
		var v: Dictionary = Region.VILLAGES[i]
		var c: Vector2 = v.c
		var e: int = v.entry
		_add_office(v.name, "в селе %s" % v.name, Vector3(c.x + 34.5 * e, 0, c.y - 8.5), 0.0, _village_homes(i))
	for o in offices:
		if o.name != "Каменка":
			_kiosk(o.window, o.yaw)
		_jobs(o)


func _add_office(n: String, where: String, window: Vector3, yaw: float, homes: Array, road := Vector3.INF) -> void:
	var fwd := Basis(Vector3.UP, yaw) * Vector3.BACK
	offices.append({"name": n, "where": where, "window": window, "yaw": yaw,
		"road": window + fwd * 4.0 if road == Vector3.INF else road, "homes": homes})


## Окно «по домам» слева, «в другую почту» справа (если смотреть на окошко).
func _jobs(o: Dictionary) -> void:
	var basis := Basis(Vector3.UP, o.yaw)
	var fwd := basis * Vector3.BACK
	var right := basis * Vector3.RIGHT
	var home := RouteJob.new()
	home.name = "PostHome_" + o.name
	home.id = "parcel"
	home.title = "Почта"
	home.sign_text = "ПО ДОМАМ"
	home.sign_pixel = 0.0035
	home.giver = o.window + fwd * 0.6 - right * 1.0
	home.giver_size = Vector3(1.4, 2.2, 1.8)
	home.verb = "Посылку вручил"
	# Адреса рядом друг с другом — подъехать надо к своему двору
	home.radius = 3.5
	home.cargo = HOME_BOXES
	home.drop_each = 1
	home.open_from = 8.0
	home.open_to = 18.0
	home.stops_fn = func() -> Array: return _home_route(o)
	home.pay_fn = func(stops: Array) -> int:
		return _round10(50.0 + 20.0 * stops.size() + _route_len(o.window, stops) * 0.2)
	home.describe_fn = func(stops: Array, pay: int) -> String:
		return "посылки по домам %s — %d адреса, %d грн" % [o.where, stops.size(), pay]
	if o.name == "Каменка":
		# Окошки в сельсовете — таблички под потолком
		home.sign_height = 2.15
	add_child(home)
	var bag := RouteJob.new()
	bag.name = "PostBag_" + o.name
	bag.id = "parcel"
	bag.title = "Почта"
	bag.sign_text = "В ПОЧТУ"
	bag.sign_pixel = 0.0035
	bag.giver = o.window + fwd * 0.6 + right * 1.0
	bag.giver_size = Vector3(1.4, 2.2, 1.8)
	bag.verb = "Мешок сдал"
	bag.cargo = BAG_BOXES
	bag.open_from = 8.0
	bag.open_to = 18.0
	bag.stops_fn = func() -> Array:
		var others := offices.filter(func(x: Dictionary) -> bool: return x.name != o.name)
		var to: Dictionary = others[_rng.randi() % others.size()]
		return [["почта %s" % to.where, to.road, to.window + (Basis(Vector3.UP, to.yaw) * Vector3.BACK) * 0.8]]
	bag.pay_fn = func(stops: Array) -> int:
		return _round10(60.0 + _route_len(o.window, stops) * 0.3)
	bag.describe_fn = func(stops: Array, pay: int) -> String:
		return "мешок посылок — %s, %d грн" % [stops[0][0], pay]
	if o.name == "Каменка":
		bag.sign_height = 2.15
	add_child(bag)
	o["home_job"] = home
	o["bag_job"] = bag


## Три адреса подряд — по кратчайшему пути от почты.
func _home_route(o: Dictionary) -> Array:
	var pool: Array = o.homes.duplicate()
	pool.shuffle()
	pool = pool.slice(0, mini(HOME_BOXES, pool.size()))
	var out := []
	var at: Vector3 = o.window
	while not pool.is_empty():
		var best := 0
		for i in pool.size():
			if at.distance_to(pool[i][1]) < at.distance_to(pool[best][1]):
				best = i
		out.append(pool[best])
		at = pool[best][1]
		pool.remove_at(best)
	return out


static func _route_len(start: Vector3, stops: Array) -> float:
	var sum := 0.0
	var at := start
	for s in stops:
		sum += at.distance_to(s[1])
		at = s[1]
	return sum


static func _round10(v: float) -> int:
	return int(round(v / 10.0)) * 10


# --- Адреса -------------------------------------------------------------------

## Дворы Каменки (кроме своего): точка на улице и калитка.
func _kamenka_homes() -> Array:
	var out := []
	var n := 1
	for i in _world.VILLAGE_X.size():
		var x: float = _world.VILLAGE_X[i]
		for row in [[_world.ROW_A_Z, 1.0], [_world.ROW_B_Z, -1.0]]:
			var z: float = row[0]
			var s: float = row[1]
			var num := n
			n += 1
			if Vector2(x, z) == _world.PLAYER_HOUSE:
				continue
			var hi := _world.get_node_or_null("House_%d_%d" % [int(x), int(z)]) as HouseInterior
			var eo := hi.entrance_offset if hi else -1.6
			var gate := Vector3(x + eo * s, 0, z + 12.0 * s + 0.6 * s)
			# Точка на своей половине улицы: соседние адреса не засчитываются разом
			out.append(["дом %d в Каменке" % num, Vector3(gate.x, 0, -40.0 - 2.5 * s), gate])
	return out


## Город: пятиэтажки, больница, рынок, вокзал (в мире — со сдвигом города).
func _town_homes() -> Array:
	var out := []
	for h in _town_spots():
		out.append([h[0], Town.w(h[1]), Town.w(h[2])])
	return out


func _town_spots() -> Array:
	return [
		["пятиэтажка на Садовой, 1", Vector3(70.0, 0, 57.0), Vector3(70.0, 0, 54.0)],
		["пятиэтажка на Садовой, 2", Vector3(125.0, 0, 57.0), Vector3(125.0, 0, 54.0)],
		["пятиэтажка на Садовой, 3", Vector3(70.0, 0, 60.0), Vector3(70.0, 0, 63.0)],
		["больница", Civic.HOSPITAL + Vector3(0, 0, 9.0), Civic.HOSPITAL + Vector3(0, 0, 7.0)],
		["рынок", Vector3(90.0, 0, 144.0), Vector3(90.0, 0, 141.0)],
		["вокзал", Vector3(97.0, 0, 180.0), Vector3(97.0, 0, 177.0)],
	]


## Дома села: точка на улице у двора и место у калитки.
func _village_homes(i: int) -> Array:
	var v: Dictionary = Region.VILLAGES[i]
	var c: Vector2 = v.c
	var e: int = v.entry
	var out := []
	var n := 1
	for side in [-1, 1]:
		for hx in Region.HOUSE_X:
			var x: float = c.x + hx * e
			out.append(["дом %d в селе %s" % [n, v.name], Vector3(x, 0, c.y + side * 2.2), Vector3(x, 0, c.y + side * 5.0)])
			n += 1
	return out


# --- Киоск --------------------------------------------------------------------

## Синий почтовый киоск: окошко смотрит на улицу (вперёд от yaw), над ним
## вывеска, сбоку почтовый ящик.
func _kiosk(front: Vector3, yaw: float) -> void:
	var b := MeshBuilder.new()
	b.xf = Transform3D(Basis(Vector3.UP, yaw), front)
	var blue := Color(0.2, 0.38, 0.72)
	var white := Color(0.9, 0.9, 0.86)
	b.box(Vector3(-2.2, 0, -2.4), Vector3(2.2, 0.15, 0.0), Color(0.55, 0.55, 0.53))
	b.box(Vector3(-2.0, 0.15, -2.2), Vector3(2.0, 2.7, -0.2), white, true)
	b.box(Vector3(-2.0, 0.15, -0.22), Vector3(2.0, 0.9, -0.18), blue)
	b.box(Vector3(-2.3, 2.7, -2.5), Vector3(2.3, 2.85, 0.35), blue)
	b.box(Vector3(-2.0, 2.2, -0.2), Vector3(2.0, 2.65, -0.15), blue)
	for s in [-1.0, 1.0]:
		var x: float = s * 1.0
		# Окошко: тёмное стекло, рама, полочка
		b.box(Vector3(x - 0.6, 1.0, -0.21), Vector3(x + 0.6, 1.9, -0.17), Color(0.15, 0.2, 0.25))
		b.box(Vector3(x - 0.66, 0.94, -0.2), Vector3(x + 0.66, 1.0, -0.12), white.darkened(0.2))
		b.box(Vector3(x - 0.02, 1.0, -0.2), Vector3(x + 0.02, 1.9, -0.15), white)
		b.box(Vector3(x - 0.6, 0.9, -0.2), Vector3(x + 0.6, 0.95, 0.15), Color(0.5, 0.38, 0.25))
	# Почтовый ящик сбоку
	b.box(Vector3(2.0, 0.9, -0.9), Vector3(2.25, 1.5, -0.3), blue, true)
	b.box(Vector3(2.25, 1.35, -0.75), Vector3(2.26, 1.38, -0.45), Color(0.1, 0.1, 0.1))
	b.box(Vector3(2.05, 0, -0.65), Vector3(2.15, 0.9, -0.55), Color(0.3, 0.3, 0.32))
	var mi := b.build_mesh()
	add_child(mi)
	add_child(b.build_body())
	var l := Label3D.new()
	l.text = "ПОЧТА"
	l.font_size = 96
	l.pixel_size = 0.005
	l.modulate = Color(1, 1, 1)
	l.outline_size = 0
	l.position = front + Basis(Vector3.UP, yaw) * Vector3(0, 2.42, -0.13)
	l.rotation.y = yaw
	add_child(l)
