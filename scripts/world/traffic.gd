extends Node3D
## Движение по трассе: в обе стороны едут «Жигули», «Москвичи»,
## «Запорожцы», «Волги», «Нивы», «буханки», ГАЗоны и КамАЗы. Рейсовые
## автобусы ходят в обе стороны и встают на каждой остановке своей
## стороны: у Каменки, в городе и на съездах к сёлам.
##
## Ночью у всех горят фары, при торможении — стоп-сигналы.
## Машины едут по своей полосе и притормаживают, если впереди кто-то есть:
## другая машина, машина игрока или сам игрок на дороге. Долго стоят —
## сигналят. За краем мира переезжают на другой край.

const CRUISE := 15.0  # м/с, около 55 км/ч
const BUS_CRUISE := 11.0
const LANE_Z := 2.0
const WORLD_X := Region.HALF - 10.0
## Остановки автобуса по полосам: -X — северная сторона (Каменка),
## +X — южная (город, сдвинут на Town.SHIFT); остановки на съездах к сёлам
## добавляются в _ready.
const STOPS := {-1: -68.5, 1: 32.0 + Town.SHIFT.x}
const STOP_WAIT := 8.0
## Дальше этого мотор попутки не слышно — звук выключаем.
const SOUND_RANGE := 80.0
## Какие машины едут по трассе (по кругу).
const KINDS := ["car", "moskvich", "zaz", "volga", "car", "niva", "uaz", "truck", "moskvich", "kamaz", "car", "zaz"]

var stops := {-1: [STOPS[-1]], 1: [STOPS[1]]}

var _vehicles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Машины едут в физике — рисуются между её шагами
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_rng.seed = 404
	var colors := [Color(0.7, 0.15, 0.12), Color(0.2, 0.35, 0.6), Color(0.9, 0.9, 0.88), Color(0.25, 0.45, 0.3), Color(0.45, 0.45, 0.47),
		Color(0.85, 0.7, 0.3), Color(0.55, 0.2, 0.3), Color(0.3, 0.55, 0.6), Color(0.15, 0.15, 0.17)]
	# Остановки на съездах к сёлам — как их ставит roadside.gd
	for r in Region.ROADS:
		var start: Vector2 = r[0]
		if absf(start.y) > 6.0 or absf(start.x) < 230.0:
			continue
		(stops[1 if start.y > 0.0 else -1] as Array).append(start.x + 14.0)
	var i := 0
	for dir in [1, -1]:
		for k in 12:
			var kind: String = KINDS[i % KINDS.size()]
			var col: Color = colors[(i * 5) % colors.size()]
			if kind == "kamaz":
				col = Color(0.9, 0.45, 0.1)
			elif kind == "uaz":
				col = Color(0.4, 0.45, 0.32)
			_spawn(dir, -1850.0 + k * 320.0 + dir * 40.0, col, kind)
			i += 1
	_spawn(-1, 120.0, Color(0.95, 0.75, 0.2), "bus")
	_spawn(1, -900.0, Color(0.9, 0.9, 0.85), "bus")


func _spawn(dir: int, x: float, color: Color, kind: String) -> void:
	var bus := kind == "bus"
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	var size: Vector3 = VehicleModels.NPC_SIZE.get(kind, VehicleModels.NPC_SIZE.car)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position.y = size.y * 0.5 + 0.3
	body.add_child(cs)
	var mesh := _build_mesh(kind, color)
	body.add_child(mesh)
	Plates.attach(body, mesh.get_aabb(), Plates.number(_vehicles.size() * 7919 + 101), false, mesh.get_meta("plates", []))
	var lights := _build_lights(size)
	body.add_child(lights[0])
	var snd := AudioStreamPlayer3D.new()
	snd.stream = SoundLibrary.stream("engine")
	snd.unit_size = 5.0
	snd.max_distance = SOUND_RANGE - 10.0
	snd.volume_db = -6.0 if bus else -10.0
	snd.pitch_scale = 0.7 if bus else 1.4
	body.add_child(snd)
	add_child(body)
	_place(body, x, dir)
	var cruise := BUS_CRUISE if bus else (CRUISE * 0.75 if kind in ["truck", "kamaz", "zaz", "uaz"] else CRUISE)
	_vehicles.append({"body": body, "dir": dir, "speed": cruise, "cruise": cruise, "bus": bus, "kind": kind,
		"wait": 0.0, "left_stop": INF, "at_stop": INF, "stopped": 0.0, "snd": snd, "len": size.z, "head": lights[1], "tail": lights[2]})


## Ставит машину в полосу носом по ходу: модель смотрит в -Z, поэтому
## едущие на восток (+X) повёрнуты на −90°, на запад — на +90°.
func _place(body: Node3D, x: float, dir: int) -> void:
	body.global_transform = Transform3D(Basis(Vector3.UP, -PI / 2.0 if dir > 0 else PI / 2.0), Vector3(x, 0.05, dir * LANE_Z))


func _build_mesh(kind: String, color: Color) -> MeshInstance3D:
	var b := MeshBuilder.new()
	b.ground_shade = false
	VehicleModels.npc(b, kind, color)
	var mi := b.build_mesh()
	mi.set_meta("plates", b.get_meta("plates", []))
	return mi


## Фары и стоп-сигналы: один меш из двух поверхностей (фары, стопы), у
## каждой машины свои материалы — их цвет меняется на ходу.
## Возвращает [узел, фары, стопы].
func _build_lights(size: Vector3) -> Array:
	var head := StandardMaterial3D.new()
	head.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tail := StandardMaterial3D.new()
	tail.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var mesh := ArrayMesh.new()
	for front in [true, false]:
		var b := MeshBuilder.new()
		b.ground_shade = false
		for x in [-hx + 0.3, hx - 0.3]:
			var c := Vector3(x, 0.65, (-hz - 0.03) if front else (hz + 0.03))
			b.box(c - Vector3(0.15, 0.09, 0.02), c + Vector3(0.15, 0.09, 0.02), Color.WHITE)
		var part := b.build_array_mesh()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part.surface_get_arrays(0))
		mesh.surface_set_material(mesh.get_surface_count() - 1, head if front else tail)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "Lights"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return [mi, head, tail]


func _physics_process(delta: float) -> void:
	var h := TimeManager.hour()
	var dark := h < 6.3 or h > 19.7 or WeatherManager.fog > 0.5 or WeatherManager.rain > 0.5
	# Помехи для всех машин — один список на кадр, а не на каждую машину
	var others: Array = [GameManager.player]
	others.append_array(get_tree().get_nodes_in_group("vehicles"))
	var cam3 := get_viewport().get_camera_3d()
	var cam := cam3.global_position if cam3 else Vector3.ZERO
	for v in _vehicles:
		var body: AnimatableBody3D = v.body
		var dir: int = v.dir
		var x := body.global_position.x
		var target: float = v.cruise

		# Автобус: подъезжает к ближайшей остановке впереди, стоит и едет
		# дальше; та, от которой отъехал, до следующего круга не считается
		if v.bus:
			var to_stop := INF
			var stop_x := INF
			for sx in stops[dir]:
				var d: float = (float(sx) - x) * dir
				if d > -0.5 and d < to_stop and absf(float(sx) - float(v.left_stop)) > 0.1:
					to_stop = d
					stop_x = sx
			if v.wait > 0.0:
				v.wait -= delta
				target = 0.0
				if v.wait <= 0.0:
					v.left_stop = v.at_stop
			elif to_stop < 25.0:
				target = clampf(to_stop * 0.6 + 0.6, 0.0, BUS_CRUISE)
				if to_stop < 0.8:
					v.wait = STOP_WAIT
					v.at_stop = stop_x
			if (x - float(v.left_stop)) * dir > 30.0:
				v.left_stop = INF

		# Светофор у поворота в город: на жёлтый и красный — стоп перед линией
		if StreetLife.highway != "green":
			var line: float = StreetLife.STOP_EAST if dir > 0 else StreetLife.STOP_WEST
			var to_line: float = (line - x) * dir - v.len * 0.5
			# На жёлтый — проезжаем, если уже не успеть остановиться
			var can_stop: bool = StreetLife.highway == "red" or to_line > v.speed * v.speed / 12.0
			if to_line > -0.5 and to_line < 40.0 and can_stop:
				# Равномерное торможение (3 м/с²) ровно к линии
				target = minf(target, sqrt(maxf(to_line - 1.0, 0.0) * 6.0))

		# Препятствие впереди в своей полосе
		var gap := _gap_ahead(v, others)
		var need: float = v.len * 0.5 + 3.0
		if gap < need + 12.0:
			target = minf(target, maxf(0.0, (gap - need) * 1.2))

		var sp: float = v.speed
		var accel := 3.0 if target > sp else 8.0
		var slowing := target < sp - 0.5 or sp < 0.3
		# Цвет фар — только когда поменялся: иначе материал обновляется каждый кадр
		var lamps := int(dark) + 2 * int(slowing)
		if lamps != int(v.get("lamps", -1)):
			v.lamps = lamps
			(v.head as StandardMaterial3D).albedo_color = Color(1.0, 0.95, 0.8) if dark else Color(0.75, 0.75, 0.7)
			(v.tail as StandardMaterial3D).albedo_color = Color(1.0, 0.1, 0.05) if slowing else (Color(0.6, 0.06, 0.04) if dark else Color(0.35, 0.05, 0.04))
		sp = move_toward(sp, target, accel * delta)
		v.speed = sp
		x += sp * dir * delta
		if x * dir > WORLD_X:
			x = -WORLD_X * dir
		_place(body, x, dir)
		# Мотор слышно только вблизи: дальние машины молчат и не тратят
		# время на смешивание звука (в браузере его считает тот же процессор)
		var snd := v.snd as AudioStreamPlayer3D
		var hear := absf(x - cam.x) < SOUND_RANGE and absf(dir * LANE_Z - cam.z) < SOUND_RANGE
		if hear != snd.playing:
			if hear:
				snd.play()
			else:
				snd.stop()
		if hear:
			snd.pitch_scale = (0.6 if v.bus or v.kind in ["truck", "kamaz"] else 1.0) + sp / CRUISE * 0.8

		# Стоят из-за игрока — сигналят
		if sp < 0.5 and v.wait <= 0.0 and gap < need + 4.0:
			v.stopped += delta
			if v.stopped > 2.5:
				v.stopped = -4.0
				SoundLibrary.play_at("horn", body.global_position)
		elif v.stopped > 0.0:
			v.stopped = 0.0


## Расстояние до ближайшей помехи впереди по полосе.
func _gap_ahead(v: Dictionary, others: Array) -> float:
	var body: AnimatableBody3D = v.body
	var dir: int = v.dir
	var x := body.global_position.x
	var lane_z := dir * LANE_Z
	var best := INF
	for other in _vehicles:
		if is_same(other, v) or other.dir != dir:
			continue
		var d: float = ((other.body as Node3D).global_position.x - x) * dir - other.len * 0.5
		if d > 0.0:
			best = minf(best, d)
	for n in others:
		var node := n as Node3D
		if node == null or not node.is_inside_tree() or not node.visible:
			continue
		var p := node.global_position
		if absf(p.z - lane_z) < 2.2:
			var d := (p.x - x) * dir - 2.0
			if d > -1.0:
				best = minf(best, maxf(d, 0.0))
	return best


## Для тестов и отладки.
func vehicles() -> Array[Dictionary]:
	return _vehicles
