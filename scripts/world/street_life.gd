class_name StreetLife
extends Node3D
## Жизнь на улицах: светофор на перекрёстке трассы и городской улицы,
## прохожие в городе и стадо коров, которое утром идёт через деревенскую
## улицу на луг, а вечером — обратно.
##
## Светофор слушается и трафик (traffic.gd тормозит на красный), и игрок:
## проскочил на красный — штраф. Прохожие ходят по тротуарам и площади,
## машину пропускают и ругаются, если подъехать вплотную. Коровы — твёрдые:
## в них можно врезаться, лучше подождать.

## Стоп-линии на трассе: едущие на восток (+X) и на запад (−X).
const STOP_EAST := 89.0
const STOP_WEST := 105.0
const GREEN := 14.0
const YELLOW := 3.0
const RED := 9.0
const FINE := 100
const Villagers := preload("res://scripts/world/villagers.gd")

## Состояние светофора для трассы: "green", "yellow", "red".
static var highway := "green"

var _t := 0.0
var _lamps: Array[Dictionary] = []  # {"red": mat, "yellow": mat, "green": mat, "for_highway": bool}
var _fine_cool := 0.0
var _last_x := 0.0

var _walkers: Array[Dictionary] = []
var _cows: Array[Dictionary] = []
var _cow_path: Array[Vector3] = []
var _cows_going := 0  # +1 — на луг, −1 — домой, 0 — стоят
var _last_hour := -1.0
var _moo_cool := 0.0
var _shout_cool := 0.0


func _ready() -> void:
	highway = "green"
	_build_lights()
	_build_walkers()
	_build_cows()


# --- Светофор -------------------------------------------------------------------

func _lamp_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col.darkened(0.7)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.0
	return m


func _build_lights() -> void:
	# Для трассы — два столба у стоп-линий; для городской улицы — один
	for spec in [[Vector3(STOP_EAST, 0, 7.6), -PI / 2.0, true], [Vector3(STOP_WEST, 0, -7.6), PI / 2.0, true],
			[Vector3(101.6, 0, 9.0), 0.0, false]]:
		var root := Node3D.new()
		add_child(root)
		root.global_position = spec[0]
		root.rotation.y = spec[1]
		var b := MeshBuilder.new()
		b.ground_shade = false
		b.box(Vector3(-0.08, 0, -0.08), Vector3(0.08, 3.2, 0.08), Color(0.3, 0.32, 0.3))
		b.box(Vector3(-0.22, 2.2, -0.12), Vector3(0.22, 3.4, 0.12), Color(0.12, 0.12, 0.13))
		root.add_child(b.build_mesh())
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.18, 3.2, 0.18)
		cs.shape = sh
		cs.position.y = 1.6
		body.add_child(cs)
		root.add_child(body)
		var entry := {"for_highway": spec[2]}
		var colors := {"red": Color(1.0, 0.12, 0.08), "yellow": Color(1.0, 0.75, 0.1), "green": Color(0.2, 1.0, 0.35)}
		var y := 3.2
		for name in ["red", "yellow", "green"]:
			var mat := _lamp_mat(colors[name])
			var m := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.13
			sph.height = 0.26
			m.mesh = sph
			m.material_override = mat
			m.position = Vector3(0, y, 0.12)
			root.add_child(m)
			entry[name] = mat
			y -= 0.38
		_lamps.append(entry)
	_apply_lights()


func _apply_lights() -> void:
	# Городская улица: зелёный, только когда трасса стоит на красном
	var town := "green" if highway == "red" and _t > 1.5 else "red"
	for e in _lamps:
		var state: String = highway if e.for_highway else town
		for name in ["red", "yellow", "green"]:
			(e[name] as StandardMaterial3D).emission_energy_multiplier = 2.5 if name == state else 0.0


func _update_lights(delta: float) -> void:
	_t += delta
	var before := highway
	match highway:
		"green":
			if _t > GREEN:
				highway = "yellow"
		"yellow":
			if _t > YELLOW:
				highway = "red"
		"red":
			if _t > RED:
				highway = "green"
	if highway != before:
		_t = 0.0
	_apply_lights()
	# Игрок проскочил стоп-линию на красный — штраф
	_fine_cool -= delta
	var v := GameManager.vehicle as Vehicle
	if v == null:
		return
	var x := v.global_position.x
	var on_highway := absf(v.global_position.z) < 4.0
	if on_highway and highway == "red" and _fine_cool <= 0.0 and v.speed_kmh() > 8.0:
		var crossed_east := _last_x < STOP_EAST and x >= STOP_EAST
		var crossed_west := _last_x > STOP_WEST and x <= STOP_WEST
		if crossed_east or crossed_west:
			_fine_cool = 20.0
			GameManager.add_money(-FINE)
			SoundLibrary.play("horn", -8.0, 1.3)
			GameManager.notify("Проехал на красный! Штраф %d грн" % FINE)
	_last_x = x


# --- Прохожие --------------------------------------------------------------------

func _build_walkers() -> void:
	var routes := [
		# Вдоль площади по кругу
		[Vector3(104, 0, 12), Vector3(140, 0, 12), Vector3(140, 0, 30), Vector3(104, 0, 30)],
		[Vector3(140, 0, 30), Vector3(104, 0, 30), Vector3(104, 0, 12), Vector3(140, 0, 12)],
		# Тротуар вдоль трассы
		[Vector3(45, 0, 6.3), Vector3(150, 0, 6.3)],
		[Vector3(150, 0, 6.3), Vector3(45, 0, 6.3)],
		# Главная улица, обе стороны
		[Vector3(93.4, 0, 10), Vector3(93.4, 0, 52)],
		[Vector3(101.4, 0, 52), Vector3(101.4, 0, 10)],
		# Поперечная улица
		[Vector3(45, 0, 53.8), Vector3(90, 0, 53.8)],
		[Vector3(185, 0, 62.3), Vector3(105, 0, 62.3)],
		# Вокруг фонтана
		[Vector3(116, 0, 15), Vector3(128, 0, 15), Vector3(128, 0, 27), Vector3(116, 0, 27)],
	]
	var shirts := [Color(0.7, 0.2, 0.2), Color(0.2, 0.4, 0.7), Color(0.85, 0.75, 0.3), Color(0.3, 0.55, 0.35),
		Color(0.6, 0.3, 0.6), Color(0.9, 0.9, 0.85), Color(0.35, 0.3, 0.25), Color(0.8, 0.45, 0.2), Color(0.25, 0.25, 0.3)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in routes.size():
		var n := Node3D.new()
		n.name = "Walker%d" % i
		var b := MeshBuilder.new()
		b.ground_shade = false
		Villagers.person_model(b, shirts[i % shirts.size()], Color(0.2, 0.18, 0.15), false, i % 3 == 1)
		var body := Villagers.walking_mesh(b)
		n.add_child(body)
		add_child(n)
		var pts: Array = routes[i]
		n.global_position = pts[0]
		_walkers.append({"node": n, "body": body, "pts": pts, "i": 1, "speed": rng.randf_range(1.1, 1.5),
			"phase": rng.randf() * TAU, "wait": 0.0})


func _update_walkers(delta: float) -> void:
	var v := GameManager.vehicle as Vehicle
	_shout_cool -= delta
	for w in _walkers:
		var n: Node3D = w.node
		var pts: Array = w.pts
		var target: Vector3 = pts[w.i]
		var to := target - n.global_position
		to.y = 0
		var go := true
		# Машина рядом и едет — остановиться, повернуться к ней
		if v and v.speed_kmh() > 5.0:
			var d := v.global_position.distance_to(n.global_position)
			if d < 5.0:
				go = false
				var tv := v.global_position - n.global_position
				n.rotation.y = lerp_angle(n.rotation.y, atan2(-tv.x, -tv.z), delta * 6.0)
				if d < 1.6:
					# Отпрыгнул в сторону
					var away := n.global_position - v.global_position
					away.y = 0
					n.global_position += away.normalized() * 1.4
				if d < 3.0 and _shout_cool <= 0.0:
					_shout_cool = 15.0
					GameManager.notify(["Прохожий: «Эй, куда прёшь!»", "Прохожая: «Смотри, куда едешь!»", "«Тротуар тебе не дорога!»"][randi() % 3])
		if go:
			if to.length() < 0.3:
				w.i = (int(w.i) + 1) % pts.size()
			else:
				var step: Vector3 = to.normalized() * float(w.speed) * delta
				n.global_position += step
				# Модель смотрит в −Z: разворачиваем носом по ходу
				n.rotation.y = lerp_angle(n.rotation.y, atan2(-to.x, -to.z), delta * 8.0)
				w.phase = float(w.phase) + float(w.speed) * delta * 4.2
		# Шаг: ноги и руки ходят, тело чуть подпрыгивает
		var body: MeshInstance3D = w.body
		body.position.y = absf(sin(float(w.phase))) * 0.03 if go else 0.0
		body.rotation.z = sin(float(w.phase)) * 0.02 if go else 0.0
		Villagers.set_walk(body, float(w.phase), 1.0 if go else 0.0)


# --- Коровы ----------------------------------------------------------------------

func _build_cows() -> void:
	# Со двора пастуха — через просвет между дворами, через улицу — на луг у трассы
	_cow_path = [Vector3(-138.4, 0, -80), Vector3(-138.4, 0, -44), Vector3(-138.4, 0, -36), Vector3(-138.4, 0, -11),
		Vector3(-160, 0, -11)]
	var spots := [0.0, 2.8, 5.6]
	for i in 3:
		var body := AnimatableBody3D.new()
		body.name = "Cow%d" % i
		body.sync_to_physics = false
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.8, 1.3, 2.1)
		cs.shape = sh
		cs.position.y = 0.75
		body.add_child(cs)
		var b := MeshBuilder.new()
		b.ground_shade = false
		var white := Color(0.92, 0.9, 0.86)
		var spot := Color(0.2, 0.17, 0.15) if i != 1 else Color(0.5, 0.3, 0.18)
		b.box(Vector3(-0.38, 0.65, -0.95), Vector3(0.38, 1.35, 0.8), white)
		b.box(Vector3(-0.39, 0.9, -0.5), Vector3(0.39, 1.25, 0.1), spot)
		b.box(Vector3(0.1, 1.0, 0.3), Vector3(0.39, 1.3, 0.7), spot)
		b.box(Vector3(-0.22, 0.95, 0.8), Vector3(0.22, 1.35, 1.3), white)
		b.box(Vector3(-0.18, 0.95, 1.22), Vector3(0.18, 1.12, 1.36), Color(0.85, 0.6, 0.6))
		for hx in [-0.3, 0.2]:
			b.box(Vector3(hx, 1.33, 0.95), Vector3(hx + 0.1, 1.45, 1.02), Color(0.9, 0.88, 0.8))
		for p in [Vector2(-0.3, -0.8), Vector2(0.18, -0.8), Vector2(-0.3, 0.6), Vector2(0.18, 0.6)]:
			# Ноги по диагонали — шагают парами
			b.alpha = 0.9 if (p.x < 0.0) == (p.y > 0.0) else 0.8
			b.box(Vector3(p.x, 0, p.y), Vector3(p.x + 0.12, 0.66, p.y + 0.14), white.darkened(0.1))
		b.alpha = 1.0
		b.box(Vector3(-0.1, 0.55, -0.1), Vector3(0.1, 0.66, 0.2), Color(0.9, 0.7, 0.7))
		b.alpha = 0.5
		b.box(Vector3(-0.03, 0.9, -1.2), Vector3(0.03, 1.3, -0.95), white.darkened(0.2))
		b.alpha = 1.0
		var cow_mesh := Villagers.animal_mesh(b, 0.66, 1.3, -0.95, 2.0)
		# Хвостом от мух машет всегда, чуть-чуть
		(cow_mesh.material_override as ShaderMaterial).set_shader_parameter("wag", 0.35)
		body.add_child(cow_mesh)
		add_child(body)
		_cows.append({"body": body, "offset": spots[i], "s": 0.0, "mesh": cow_mesh, "phase": i * 1.3})
	_place_cows_for_hour(TimeManager.hour())


func _path_length() -> float:
	var l := 0.0
	for k in _cow_path.size() - 1:
		l += _cow_path[k].distance_to(_cow_path[k + 1])
	return l


func _point_on_path(s: float) -> Array:
	s = clampf(s, 0.0, _path_length())
	for k in _cow_path.size() - 1:
		var seg := _cow_path[k].distance_to(_cow_path[k + 1])
		if s <= seg:
			var dir := (_cow_path[k + 1] - _cow_path[k]).normalized()
			return [_cow_path[k] + dir * s, dir]
		s -= seg
	var last := _cow_path.size() - 1
	return [_cow_path[last], (_cow_path[last] - _cow_path[last - 1]).normalized()]


## Днём коровы на лугу, ночью — во дворе; стадо идёт гуськом.
func _place_cows_for_hour(h: float) -> void:
	var at_pasture := h >= 7.5 and h < 19.0
	for c in _cows:
		c.s = _goal(c, 1 if at_pasture else -1)
		_move_cow(c, 0.0, 1 if at_pasture else -1)


## Куда идёт корова: на лугу — в конец пути, дома — в начало; стадо гуськом.
func _goal(c: Dictionary, going: int) -> float:
	return _path_length() - float(c.offset) if going > 0 else 5.6 - float(c.offset)


func _move_cow(c: Dictionary, ds: float, facing: int) -> void:
	c.s = clampf(float(c.s) + ds, 0.0, _path_length())
	var pd: Array = _point_on_path(c.s)
	var body: AnimatableBody3D = c.body
	body.global_position = pd[0]
	var dir: Vector3 = pd[1] * facing
	body.rotation.y = atan2(dir.x, dir.z)


func _update_cows(delta: float) -> void:
	var h := TimeManager.hour()
	if _last_hour >= 0.0:
		if _last_hour < 7.0 and h >= 7.0:
			_cows_going = 1
			GameManager.notify("Пастух гонит коров на луг — на деревенской улице осторожнее")
		elif _last_hour < 19.0 and h >= 19.0:
			_cows_going = -1
		elif absf(h - _last_hour) > 1.0:
			# Перемотка времени (сон, работа) — стадо уже на месте
			_cows_going = 0
			_place_cows_for_hour(h)
	_last_hour = h
	if _cows_going == 0:
		return
	var moving := false
	for c in _cows:
		var goal := _goal(c, _cows_going)
		var left: float = (goal - float(c.s)) * _cows_going
		var walking := left > 0.05
		if walking:
			moving = true
			_move_cow(c, minf(0.9 * delta, left) * _cows_going, _cows_going)
			c.phase = float(c.phase) + 0.9 * delta * 3.0
		Villagers.set_walk(c.mesh, c.phase, 1.0 if walking else 0.0)
	_moo_cool -= delta
	if moving and _moo_cool <= 0.0:
		_moo_cool = randf_range(6.0, 12.0)
		SoundLibrary.play_at("moo", (_cows[0].body as Node3D).global_position, -2.0, randf_range(0.9, 1.1))
	if not moving:
		_cows_going = 0


func cows_positions() -> Array:
	var out := []
	for c in _cows:
		out.append((c.body as Node3D).global_position)
	return out


func _physics_process(delta: float) -> void:
	_update_lights(delta)
	_update_walkers(delta)
	_update_cows(delta)
