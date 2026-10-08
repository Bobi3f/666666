class_name CollegeLife
extends Node3D
## Ученики бурсы (ПТУ №17). В будни к 8:00 сходятся к училищу: кто пешком
## по тротуару с обоих концов улицы, двое на мотоциклах («Влтава» и
## «Иртыш»), двое на своих машинах. Мотоциклы и машины встают во дворе,
## хозяева идут в двери. В 8:00 и 15:00 звенит звонок; после уроков ученики
## выходят: пешие расходятся по улице, остальные садятся, заводятся и
## уезжают к трассе. Ночью и в выходные двор пуст.
##
## Всё считается по часам игры, а не шагами: где ученик в 7:43 — известно
## сразу, поэтому после сна или перемотки времени все на своих местах.
## Координаты — города (узел стоит внутри TownEast).

const Villagers := preload("res://scripts/world/villagers.gd")
## Двери бурсы: сюда входят и отсюда выходят.
const DOOR := Vector3(251.0, 0, 120.0)
## Скорости — метров за игровую минуту (при обычном ходе времени — в секунду).
const WALK := 1.3
const DRIVE := 7.0
const YARD := 2.5
const BACK := 1.2
## Звонок: начало и конец занятий (минуты суток).
const START := 8 * 60
const END := 15 * 60
## Улица у бурсы: полоса к бурсе (от трассы на север), обратная полоса и
## тротуар; FAR_Z — у трассы, оттуда приезжают и туда уезжают.
const LANE_IN := 263.5
const LANE_OUT := 266.5
const SIDEWALK := 260.9
const FAR_Z := 8.0
## Дальше этого от дверей двор не считаем и не рисуем.
const RANGE := 260.0

## Ученики: [чем добирается, приходит, уходит (мин суток), рубашка, девушка,
## откуда идёт (z тротуара) или [модель, цвет, место во дворе]].
const STUDENTS := [
	["walk", 6 * 60 + 52, 15 * 60 + 3, Color(0.2, 0.3, 0.6), false, 30.0],
	["walk", 7 * 60 + 2, 15 * 60 + 1, Color(0.75, 0.3, 0.35), true, 192.0],
	["walk", 7 * 60 + 9, 15 * 60 + 12, Color(0.3, 0.5, 0.3), false, 30.0],
	["walk", 7 * 60 + 15, 15 * 60 + 18, Color(0.9, 0.85, 0.75), true, 192.0],
	["walk", 7 * 60 + 21, 15 * 60 + 27, Color(0.45, 0.42, 0.4), false, 30.0],
	["walk", 7 * 60 + 26, 15 * 60 + 36, Color(0.6, 0.45, 0.7), false, 192.0],
	["moto", 7 * 60 + 38, 15 * 60 + 8, Color(0.2, 0.2, 0.22), false, ["moto", Color(0.75, 0.1, 0.1), Vector3(253.2, 0, 131.2)]],
	["moto", 7 * 60 + 44, 15 * 60 + 21, Color(0.35, 0.4, 0.55), false, ["izh", Color(0.2, 0.35, 0.7), Vector3(253.2, 0, 133.0)]],
	["car", 7 * 60 + 31, 15 * 60 + 14, Color(0.85, 0.85, 0.82), false, ["car", Color(0.9, 0.9, 0.88), Vector3(255.0, 0, 108.4)]],
	["car", 7 * 60 + 47, 15 * 60 + 32, Color(0.55, 0.25, 0.2), true, ["moskvich", Color(0.3, 0.55, 0.6), Vector3(255.0, 0, 111.7)]],
]
## Рукоятки руля и седло мотоциклов — как у своих (vehicle.gd).
const BIKES := {
	"moto": {"seat": Vector3(0, 1.45, 0.25), "grip": Vector3(0.36, 1.22, -0.46), "r": 0.31,
		"wheels": [Vector3(0, 0.31, -0.8), Vector3(0, 0.31, 0.62)], "sound": "engine_moto"},
	"izh": {"seat": Vector3(0, 1.52, 0.3), "grip": Vector3(0.41, 1.31, -0.37), "r": 0.32,
		"wheels": [Vector3(0, 0.32, -0.76), Vector3(0, 0.32, 0.64)], "sound": "engine_izh"},
}

## Каждый ученик: человек, транспорт и два пути — утром и после уроков.
var students: Array[Dictionary] = []
## Стоят у входа весь учебный день (town_east.gd → группа college_idle).
var _idle: Array[Node] = []
var _bell_day := [-1, -1]
var _last_t := -1.0


func _ready() -> void:
	add_to_group("college_life")
	for i in STUDENTS.size():
		students.append(_make(i, STUDENTS[i]))


## Ученик целиком: человечек, мотоцикл или машина, пути туда и обратно.
func _make(i: int, d: Array) -> Dictionary:
	var pb := MeshBuilder.new()
	pb.ground_shade = false
	Villagers.person_model(pb, d[3], Color(0.22, 0.18, 0.14), false, d[4])
	var man := Villagers.walking_mesh(pb)
	man.name = "Student%d" % i
	man.visibility_range_end = 120.0
	man.visible = false
	add_child(man)
	var s := {"kind": d[0], "man": man, "arrive": float(d[1]), "leave": float(d[2])}
	# Чуть разные места у дверей — не входят друг в друга
	var door := DOOR + Vector3(0, 0, (i % 3 - 1) * 0.5)
	if d[0] == "walk":
		var far := Vector3(SIDEWALK, 0, float(d[5]))
		var gate := Vector3(SIDEWALK, 0, 120.8 + (i % 3 - 1) * 0.6)
		s["in"] = _legs(s.arrive, [[false, [far, gate, Vector3(257.5, 0, gate.z), door], WALK]])
		s["out"] = _legs(s.leave, [[false, [door, Vector3(257.5, 0, gate.z), gate, far], WALK]])
		return s
	var v: Array = d[5]
	var spot: Vector3 = v[2]
	var moto: bool = d[0] == "moto"
	var veh := _bike(v[0], v[1], d[3]) if moto else _car(v[0], v[1], i)
	veh.visible = false
	add_child(veh)
	s["veh"] = veh
	s["spot"] = spot
	# Слезает сбоку от мотоцикла, из машины — с водительской стороны
	var side := spot + (Vector3(0.6, 0, -0.9) if moto else Vector3(0.4, 0, -1.3))
	var turn := Vector3(LANE_IN, 0, spot.z - 9.0)
	var exit := Vector3(LANE_OUT, 0, spot.z - 8.0)
	s["in"] = _legs(s.arrive, [
		[true, [Vector3(LANE_IN, 0, FAR_Z), turn], DRIVE],
		[true, [turn, Vector3(260.5, 0, spot.z), spot], YARD],
		[false, [side, Vector3(254.0, 0, door.z + 1.2), door], WALK]])
	s["out"] = _legs(s.leave, [
		[false, [door, Vector3(254.0, 0, door.z + 1.2), side], WALK],
		[true, [spot, Vector3(259.0, 0, spot.z)], BACK, true],
		[true, [Vector3(259.0, 0, spot.z), exit], YARD],
		[true, [exit, Vector3(LANE_OUT, 0, FAR_Z)], DRIVE]])
	return s


## Пути по отрезкам: [на транспорте?, точки, скорость, задним ходом?]. Время
## каждого отрезка — по длине и скорости, отрезки идут друг за другом с t0.
func _legs(t0: float, parts: Array) -> Array:
	var out := []
	var t := t0
	for p in parts:
		var pts: Array = p[1]
		var length := 0.0
		for k in pts.size() - 1:
			length += (pts[k] as Vector3).distance_to(pts[k + 1])
		var dur := length / float(p[2])
		out.append({"veh": p[0], "pts": pts, "len": length, "t0": t, "t1": t + dur, "back": p.size() > 3 and p[3]})
		t += dur
	return out


## Мотоцикл с седоком в шлеме: седок виден, только пока едет.
func _bike(model: String, paint: Color, shirt: Color) -> Node3D:
	var spec: Dictionary = BIKES[model]
	var root := Node3D.new()
	var b := MeshBuilder.new()
	b.ground_shade = false
	if model == "izh":
		VehicleModels.izh(b, paint)
	else:
		VehicleModels.java(b, paint)
	for w in spec.wheels:
		b.xf = Transform3D(Basis.IDENTITY, w)
		VehicleModels.moto_wheel(b, spec.r)
	b.xf = Transform3D.IDENTITY
	var body := b.build_mesh()
	body.material_override = MeshBuilder.vehicle_material()
	body.visibility_range_end = 150.0
	root.add_child(body)
	var seat: Vector3 = spec.seat
	var at := Vector3(seat.x, seat.y - 1.0, seat.z + 0.1)
	var hands := []
	for sx in [-1.0, 1.0]:
		hands.append((spec.grip as Vector3) * Vector3(sx, 1, 1) - at)
	var rb := MeshBuilder.new()
	rb.ground_shade = false
	PersonModel.person(rb, shirt, Color(0.2, 0.18, 0.15), true, false, hands)
	var rider := rb.build_mesh()
	# Шлем в цвет мотоцикла, поверх кепки
	var top := rider.mesh.get_aabb().end.y
	var hb := MeshBuilder.new()
	hb.ground_shade = false
	PersonModel.ball(hb, Vector3(0, top - 0.12, 0.01), Vector3(0.14, 0.15, 0.155), paint.darkened(0.2), 6, 14, true)
	var helmet := hb.build_mesh()
	helmet.material_override = MeshBuilder.vehicle_material()
	rider.add_child(helmet)
	rider.name = "Rider"
	rider.position = at
	rider.visibility_range_end = 150.0
	root.add_child(rider)
	root.set_meta("rider", rider)
	root.set_meta("sound", _engine(root, spec.sound, 1.0))
	return root


## Машина ученика — как попутки на трассе: кузов, номера, коробка, чтобы
## игрок в неё не проезжал насквозь.
func _car(model: String, paint: Color, i: int) -> Node3D:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	var size: Vector3 = VehicleModels.NPC_SIZE.get(model, VehicleModels.NPC_SIZE.car)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position.y = size.y * 0.5 + 0.3
	body.add_child(cs)
	var b := MeshBuilder.new()
	b.ground_shade = false
	VehicleModels.npc(b, model, paint)
	var mi := b.build_mesh()
	mi.material_override = MeshBuilder.vehicle_material()
	mi.visibility_range_end = 160.0
	body.add_child(mi)
	Plates.attach(body, mi.get_aabb(), Plates.number(i * 7919 + 1717), false, b.get_meta("plates", []))
	body.set_meta("shape", cs)
	body.set_meta("sound", _engine(body, "engine", 1.2))
	return body


func _engine(parent: Node3D, sound: String, pitch: float) -> AudioStreamPlayer3D:
	var snd := AudioStreamPlayer3D.new()
	snd.stream = SoundLibrary.stream(sound)
	snd.unit_size = 4.0
	snd.max_distance = 70.0
	snd.volume_db = -8.0
	snd.pitch_scale = pitch
	parent.add_child(snd)
	return snd


## Учебный день: будни.
static func school_day() -> bool:
	return not TimeManager.weekday() in ["сб", "вс"]


## Сразу всех на места по часам (для снимков и после перемотки).
func settle() -> void:
	_last_t = -1.0
	_update(0.0)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var near := cam != null and cam.global_position.distance_to(to_global(DOOR)) < RANGE
	visible = near
	if near:
		_update(delta)
	_ring()


## Звонок на первый урок и с последнего — слышно во дворе.
func _ring() -> void:
	if not school_day():
		return
	var t := TimeManager.hour() * 60.0
	for k in 2:
		var at: int = [START, END][k]
		if t >= at and t < at + 2.0 and _bell_day[k] != TimeManager.day:
			_bell_day[k] = TimeManager.day
			SoundLibrary.play_at("bell", to_global(DOOR + Vector3(0, 3.0, 0)), 4.0)


func _update(delta: float) -> void:
	var t := TimeManager.hour() * 60.0
	var day := school_day()
	# Время прыгнуло (сон, перемотка) — без плавного поворота
	var snap := _last_t < 0.0 or absf(t - _last_t) > 3.0
	_last_t = t
	for s in students:
		_place(s, t, day, delta, snap)
	if _idle.is_empty():
		_idle = get_tree().get_nodes_in_group("college_idle")
	var hang := day and t >= 7 * 60 + 30 and t < 16 * 60 + 30
	for n in _idle:
		(n as Node3D).visible = hang


## Где ученик в минуту t: дома (не видно), в пути, на уроках.
func _place(s: Dictionary, t: float, day: bool, delta: float, snap: bool) -> void:
	var man: MeshInstance3D = s.man
	var veh: Node3D = s.get("veh")
	var legs: Array = []
	if day and t >= s.arrive and t < s["in"][-1].t1:
		legs = s["in"]
	elif day and t >= s.leave and t < s["out"][-1].t1:
		legs = s["out"]
	var in_class: bool = day and t >= s["in"][-1].t1 and t < s.leave
	man.visible = false
	var moving_veh := false
	for k in legs.size():
		var leg: Dictionary = legs[k]
		if t < leg.t0:
			break
		if t >= leg.t1 and k < legs.size() - 1:
			continue
		var f := clampf((t - leg.t0) / maxf(leg.t1 - leg.t0, 0.001), 0.0, 1.0)
		var at := _along(leg.pts, f * leg.len)
		var dir: Vector3 = at[1]
		if leg.veh:
			moving_veh = true
			_set_pose(veh, at[0], -dir if leg.back else dir, delta, snap)
		else:
			man.visible = true
			_set_pose(man, at[0], dir, delta, snap)
			Villagers.set_walk(man, f * leg.len * 3.2, 1.0)
		break
	if veh:
		veh.visible = in_class or not legs.is_empty()
		# Не едет — стоит во дворе носом к училищу
		if veh.visible and not moving_veh:
			_set_pose(veh, s.spot, Vector3(-1, 0, 0), delta, true)
		if veh.has_meta("rider"):
			(veh.get_meta("rider") as Node3D).visible = moving_veh
		if veh.has_meta("shape"):
			(veh.get_meta("shape") as CollisionShape3D).disabled = not veh.visible
		var snd: AudioStreamPlayer3D = veh.get_meta("sound")
		if moving_veh and not snd.playing:
			snd.play()
		elif not moving_veh and snd.playing:
			snd.stop()


## Поставить на место носом по направлению dir (модели смотрят в −Z);
## поворачивает плавно, кроме прыжка времени.
func _set_pose(n: Node3D, p: Vector3, dir: Vector3, delta: float, snap: bool) -> void:
	n.position = Vector3(p.x, 0.05, p.z)
	if dir.length_squared() < 0.0001:
		return
	var yaw := atan2(-dir.x, -dir.z)
	n.rotation.y = yaw if snap else lerp_angle(n.rotation.y, yaw, minf(delta * 6.0, 1.0))


## Точка на ломаной pts в d метрах от начала и направление отрезка там.
static func _along(pts: Array, d: float) -> Array:
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var c: Vector3 = pts[k + 1]
		var l := a.distance_to(c)
		if d <= l or k == pts.size() - 2:
			return [a.lerp(c, clampf(d / maxf(l, 0.001), 0.0, 1.0)), (c - a).normalized()]
		d -= l
	return [pts[-1], Vector3.ZERO]
