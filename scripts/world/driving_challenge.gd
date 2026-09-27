class_name DrivingChallenge
extends Node3D
## Заезд по контрольным точкам: экзамен в автошколе, спор с Васей.
##
## Сначала заезд «взводят» (arm) — у инструктора или у Васи. Потом игрок
## садится за руль и въезжает в жёлтый круг старта — пошёл отсчёт.
## Следующая точка горит янтарным кольцом, её нужно проехать. Конусы
## сбивать нельзя (сверх max_cones — провал), время ограничено. Если задана
## стоянка (park), в конце нужно встать в разметку ровно и остановиться.
## Итог — в сигнале finished: {"ok": bool, "time": сек, "cones": сбито, "why": причина}.

signal finished(result: Dictionary)

enum State {IDLE, ARMED, RUNNING}

var title := "Заезд"
var start_pos := Vector3.ZERO
var points: Array[Vector3] = []
## Подписи этапов для строки задания: индекс точки → что сейчас делать.
var stage_names := {}
var cone_positions: Array[Vector3] = []
var max_cones := 99
var time_limit := 60.0
## Стоянка в конце: центр, размер по X и Z, машина должна стоять вдоль Z.
var park_center := Vector3.ZERO
var park_size := Vector2.ZERO
var only_car := false
## Насколько близко нужно проехать к точке: на гонке шире, на экзамене — точно.
var point_radius := 3.0

var state := State.IDLE
var t := 0.0
var idx := 0
var hits := 0
var _parked := 0.0
var _ring: MeshInstance3D
var _start_ring: MeshInstance3D
var _cones: Array[Node3D] = []
var _knocked: Array[bool] = []


func _ready() -> void:
	_ring = _make_ring(Color(0.95, 0.7, 0.2), maxf(2.6, point_radius - 0.4))
	_start_ring = _make_ring(Color(1.0, 0.9, 0.2), 3.2)
	for p in cone_positions:
		var cone := _make_cone()
		add_child(cone)
		cone.global_position = p
		_cones.append(cone)
		_knocked.append(false)
	_update_markers()


func _make_ring(col: Color, r: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = r - 0.25
	torus.outer_radius = r
	torus.rings = 32
	m.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.visible = false
	add_child(m)
	return m


func _make_cone() -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.03
	c.bottom_radius = 0.17
	c.height = 0.55
	body.mesh = c
	body.position.y = 0.275
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.4, 0.08)
	body.material_override = mat
	n.add_child(body)
	var stripe := MeshInstance3D.new()
	var s := CylinderMesh.new()
	s.top_radius = 0.085
	s.bottom_radius = 0.11
	s.height = 0.09
	stripe.mesh = s
	stripe.position.y = 0.3
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.92)
	stripe.material_override = white
	n.add_child(stripe)
	return n


func active() -> bool:
	return state != State.IDLE


## Взвести заезд: ждём машину на старте.
func arm() -> void:
	state = State.ARMED
	GameManager.challenge_line = "%s: въезжай на старт — жёлтый круг" % title
	_reset_cones()
	_update_markers()


func cancel() -> void:
	state = State.IDLE
	GameManager.challenge_line = ""
	_update_markers()


func _reset_cones() -> void:
	for i in _cones.size():
		_knocked[i] = false
		_cones[i].rotation = Vector3.ZERO
		_cones[i].global_position = cone_positions[i]


func _update_markers() -> void:
	_start_ring.visible = state == State.ARMED
	_start_ring.global_position = start_pos + Vector3(0, 0.3, 0)
	_start_ring.rotation = Vector3.ZERO
	_ring.visible = state == State.RUNNING and idx < points.size()
	if _ring.visible:
		_ring.global_position = points[idx] + Vector3(0, 0.3, 0)


func _vehicle() -> Vehicle:
	var v := GameManager.vehicle as Vehicle
	if v and only_car and v.spec.two_wheels:
		return null
	return v


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	# Кольца медленно крутятся — их видно издалека
	_ring.rotate_y(delta * 1.5)
	_start_ring.rotate_y(-delta)
	var v := _vehicle()
	if state == State.ARMED:
		GameManager.challenge_line = "%s: въезжай на старт — жёлтый круг%s" % [title, "" if not only_car else " (на Жигулях)"]
		if v and _flat(v.global_position, start_pos) < 3.5:
			state = State.RUNNING
			t = 0.0
			idx = 0
			hits = 0
			_parked = 0.0
			_reset_cones()
			SoundLibrary.play("quest", -6.0, 1.3)
			GameManager.notify("%s: пошёл отсчёт! Лимит %d с" % [title, int(time_limit)])
			_update_markers()
		return
	t += delta
	if v == null:
		_end(false, "вышел из машины")
		return
	if t > time_limit:
		_end(false, "не уложился во время")
		return
	for i in _cones.size():
		# Конус задет, если попал в габарит машины (плюс его основание)
		var local := v.to_local(cone_positions[i])
		var half: Vector3 = (v.spec.shape as Vector3) * 0.5
		if not _knocked[i] and absf(local.x) < half.x + 0.17 and absf(local.z) < half.z + 0.17:
			_knocked[i] = true
			hits += 1
			var away := (cone_positions[i] - v.global_position)
			away.y = 0
			_cones[i].global_position = cone_positions[i] + away.normalized() * 0.6
			_cones[i].rotation = Vector3(PI / 2.2, atan2(away.x, away.z), 0)
			SoundLibrary.play_at("crash", cone_positions[i], -14.0, 1.8)
			if hits > max_cones:
				_end(false, "сбито конусов: %d" % hits)
				return
			GameManager.notify("Сбит конус! (%d из %d можно)" % [hits, max_cones])
	if idx < points.size():
		if _flat(v.global_position, points[idx]) < point_radius:
			idx += 1
			SoundLibrary.play("click", -4.0, 1.5)
			_update_markers()
			if idx >= points.size() and park_size == Vector2.ZERO:
				_end(true, "")
				return
	else:
		# Стоянка: внутри разметки, вдоль неё и стоит 1,5 секунды
		var p := v.global_position - park_center
		var inside := absf(p.x) < park_size.x * 0.5 and absf(p.z) < park_size.y * 0.5
		var along := absf(v.global_transform.basis.z.dot(Vector3.FORWARD)) > 0.94
		if inside and along and v.speed_kmh() < 1.0:
			_parked += delta
			if _parked > 1.5:
				_end(true, "")
				return
		else:
			_parked = 0.0
	GameManager.challenge_line = "%s: %s   %d:%02d из %d:%02d   конусов сбито: %d" % [
		title, _stage_text(), int(t) / 60, int(t) % 60, int(time_limit) / 60, int(time_limit) % 60, hits]


func _stage_text() -> String:
	if idx >= points.size():
		return "встань в разметку ровно и остановись"
	var best := ""
	var best_i := -1
	for k in stage_names:
		if int(k) <= idx and int(k) > best_i:
			best_i = int(k)
			best = stage_names[k]
	return best if best != "" else "проезжай через кольцо"


func _end(ok: bool, why: String) -> void:
	state = State.IDLE
	GameManager.challenge_line = ""
	_update_markers()
	finished.emit({"ok": ok, "time": t, "cones": hits, "why": why})
