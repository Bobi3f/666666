extends Node3D
## Движение по трассе: легковушки в обе стороны и рейсовый автобус,
## который стоит на остановках у Каменки и в городе.
##
## Машины едут по своей полосе и притормаживают, если впереди кто-то есть:
## другая машина, машина игрока или сам игрок на дороге. Долго стоят —
## сигналят. За краем мира переезжают на другой край.

const CRUISE := 15.0  # м/с, около 55 км/ч
const BUS_CRUISE := 11.0
const LANE_Z := 2.0
const WORLD_X := 196.0
## Остановки автобуса по полосам: -X — северная (Каменка), +X — южная (город)
const STOPS := {-1: -68.5, 1: 32.0}
const STOP_WAIT := 8.0

var _vehicles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 404
	var colors := [Color(0.7, 0.15, 0.12), Color(0.2, 0.35, 0.6), Color(0.9, 0.9, 0.88), Color(0.25, 0.45, 0.3), Color(0.45, 0.45, 0.47), Color(0.85, 0.7, 0.3)]
	var i := 0
	for dir in [1, -1]:
		for k in 3:
			_spawn(dir, -150.0 + k * 130.0 + dir * 20.0, colors[i % colors.size()], false)
			i += 1
	_spawn(-1, 120.0, Color(0.95, 0.75, 0.2), true)


func _spawn(dir: int, x: float, color: Color, bus: bool) -> void:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = true
	var size := Vector3(2.5, 3.0, 10.0) if bus else Vector3(1.7, 1.4, 4.2)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position.y = size.y * 0.5 + 0.3
	body.add_child(cs)
	body.add_child(_build_mesh(size, color, bus))
	var snd := AudioStreamPlayer3D.new()
	snd.stream = SoundLibrary.stream("engine")
	snd.unit_size = 5.0
	snd.max_distance = 70.0
	snd.volume_db = -6.0 if bus else -10.0
	snd.pitch_scale = 0.7 if bus else 1.4
	body.add_child(snd)
	add_child(body)
	body.global_position = Vector3(x, 0.05, dir * LANE_Z)
	# Модель смотрит носом в -Z; разворачиваем по направлению движения
	body.rotation.y = -PI / 2.0 if dir > 0 else PI / 2.0
	snd.play()
	_vehicles.append({"body": body, "dir": dir, "speed": BUS_CRUISE if bus else CRUISE, "bus": bus,
		"wait": 0.0, "stopped": 0.0, "snd": snd, "len": size.z})


func _build_mesh(size: Vector3, color: Color, bus: bool) -> MeshInstance3D:
	var b := MeshBuilder.new()
	b.ground_shade = false
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var dark := Color(0.08, 0.08, 0.09)
	var glass := Color(0.2, 0.25, 0.3)
	if bus:
		b.box(Vector3(-hx, 0.4, -hz), Vector3(hx, 3.2, hz), color)
		b.box(Vector3(-hx - 0.01, 1.6, -hz + 0.8), Vector3(hx + 0.01, 2.6, hz - 0.5), glass)
		b.box(Vector3(-hx + 0.2, 1.3, -hz - 0.01), Vector3(hx - 0.2, 2.8, -hz), glass)
		b.box(Vector3(-hx, 0.4, -hz), Vector3(hx, 1.0, hz), color.darkened(0.3))
	else:
		b.box(Vector3(-hx, 0.35, -hz), Vector3(hx, 0.95, hz), color)
		b.box(Vector3(-hx + 0.1, 0.95, -hz + 1.3), Vector3(hx - 0.1, 1.5, hz - 0.9), glass)
		b.box(Vector3(-hx + 0.08, 1.5, -hz + 1.35), Vector3(hx - 0.08, 1.56, hz - 0.95), color)
		for x in [-hx + 0.15, hx - 0.45]:
			b.box(Vector3(x, 0.55, -hz - 0.02), Vector3(x + 0.3, 0.72, -hz), Color(1.0, 0.95, 0.8))
			b.box(Vector3(x, 0.55, hz), Vector3(x + 0.3, 0.72, hz + 0.02), Color(0.8, 0.1, 0.08))
	for z in [-hz + 1.0, hz - 1.0]:
		for x in [-hx, hx - 0.2]:
			b.box(Vector3(x - 0.02, 0.0, z - 0.35), Vector3(x + 0.22, 0.7, z + 0.35), dark)
	return b.build_mesh()


func _physics_process(delta: float) -> void:
	for v in _vehicles:
		var body: AnimatableBody3D = v.body
		var dir: int = v.dir
		var x := body.global_position.x
		var target: float = BUS_CRUISE if v.bus else CRUISE

		# Автобус: подъезжает к своей остановке и стоит
		if v.bus:
			var stop_x: float = STOPS[dir]
			var to_stop := (stop_x - x) * dir
			if v.wait > 0.0:
				v.wait -= delta
				target = 0.0
			elif to_stop > 0.0 and to_stop < 25.0:
				target = clampf(to_stop * 0.6, 0.0, BUS_CRUISE)
				if to_stop < 1.0:
					v.wait = STOP_WAIT

		# Препятствие впереди в своей полосе
		var gap := _gap_ahead(v)
		var need: float = v.len * 0.5 + 3.0
		if gap < need + 12.0:
			target = minf(target, maxf(0.0, (gap - need) * 1.2))

		var sp: float = v.speed
		var accel := 3.0 if target > sp else 8.0
		sp = move_toward(sp, target, accel * delta)
		v.speed = sp
		x += sp * dir * delta
		if x * dir > WORLD_X:
			x = -WORLD_X * dir
		body.global_position = Vector3(x, 0.05, dir * LANE_Z)
		(v.snd as AudioStreamPlayer3D).pitch_scale = (0.6 if v.bus else 1.0) + sp / CRUISE * 0.8

		# Стоят из-за игрока — сигналят
		if sp < 0.5 and v.wait <= 0.0 and gap < need + 4.0:
			v.stopped += delta
			if v.stopped > 2.5:
				v.stopped = -4.0
				SoundLibrary.play_at("horn", body.global_position)
		elif v.stopped > 0.0:
			v.stopped = 0.0


## Расстояние до ближайшей помехи впереди по полосе.
func _gap_ahead(v: Dictionary) -> float:
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
	for n in [GameManager.player, GameManager.car]:
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
