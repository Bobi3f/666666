class_name Football
extends Node3D
## Футбол на школьной спортплощадке: ты против двоих ребят — нападающего и
## вратаря. Три минуты или до трёх голов.
##
## Мяч — настоящий (RigidBody3D): катится, отскакивает от штанг. Подбежал —
## ведёшь его перед собой, «E» у мяча — удар туда, куда смотришь. Ты
## забиваешь в дальние ворота (+X), ребята — в ближние (−X). Вылетел мяч с
## поля — розыгрыш с центра.
##
## Всё — в мировых координатах поля field (School задаёт его по своему двору).
## Урок физкультуры — тот же матч, оценка по счёту (signal finished).

const Villagers := preload("res://scripts/world/villagers.gd")

signal finished(mine: int, theirs: int, pe: bool)

const MATCH_TIME := 180.0
const WIN_GOALS := 3
const GOAL_HALF := 1.45
const GOAL_H := 1.5
const BALL_R := 0.22
const KICK := 11.0
const KID_SPEED := 4.0

## Поле в мире (X — вдоль, ворота на концах; Z — поперёк).
var field := Rect2()
var state := "idle"
var mine := 0
var theirs := 0
var time_left := 0.0
var pe := false
var ball: RigidBody3D
var _ball_zone: InteractZone
var _start_zone: InteractZone
var _striker: Node3D
var _keeper: Node3D
var _coach: Node3D
var _kick_cool := 0.0
var _pause := 0.0
var _t := 0.0
## Кто может начать матч сейчас: () -> String (пусто — можно) — школа
## закрывает поле на ночь и во время уроков других классов.
var can_play: Callable


func setup(f: Rect2) -> void:
	field = f
	_make_ball()
	_striker = _kid(Color(0.85, 0.2, 0.15))
	_keeper = _kid(Color(0.2, 0.25, 0.3))
	_coach = _kid(Color(0.15, 0.3, 0.75), 1.0)
	_coach.name = "Coach"
	_place_idle()
	_start_zone = InteractZone.create("", Vector3(2.4, 2.2, 2.4))
	_start_zone.name = "FootballStart"
	_start_zone.prompt_fn = _start_prompt
	_start_zone.activated.connect(func() -> void: start(false))
	add_child(_start_zone)
	_start_zone.global_position = Vector3(field.get_center().x, 0, field.end.y + 2.0)


func _make_ball() -> void:
	ball = RigidBody3D.new()
	ball.name = "Ball"
	ball.mass = 0.45
	ball.linear_damp = 0.55
	ball.angular_damp = 0.8
	ball.continuous_cd = true
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.45
	mat.friction = 0.6
	ball.physics_material_override = mat
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = BALL_R
	cs.shape = sh
	ball.add_child(cs)
	# Мяч: белый с чёрными «заплатками»
	var b := MeshBuilder.new()
	b.ground_shade = false
	var sm := SphereMesh.new()
	sm.radius = BALL_R
	sm.height = BALL_R * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.96, 0.96, 0.94)
	sm.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	ball.add_child(mi)
	for d in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var c: Vector3 = d * (BALL_R - 0.03)
		b.box(c - Vector3(0.06, 0.06, 0.06), c + Vector3(0.06, 0.06, 0.06), Color(0.08, 0.08, 0.08))
	ball.add_child(b.build_mesh())
	add_child(ball)
	ball.global_position = _center() + Vector3(0, BALL_R + 0.05, 0)
	# Удар — «E» у мяча (на телефоне — кнопка E): зона едет вместе с мячом
	_ball_zone = InteractZone.create("", Vector3(1.8, 1.6, 1.8))
	_ball_zone.name = "Kick"
	_ball_zone.prompt_fn = func() -> String: return "E — удар!" if state == "play" else ""
	_ball_zone.activated.connect(kick)
	add_child(_ball_zone)


## Мальчишка (или физрук): человечек с шагающими ногами.
func _kid(shirt: Color, s := 0.82) -> Node3D:
	var pb := MeshBuilder.new()
	pb.ground_shade = false
	Villagers.person_model(pb, shirt, Color(0.3, 0.25, 0.2), false, false)
	var mi := Villagers.walking_mesh(pb)
	mi.scale = Vector3.ONE * s
	var n := Node3D.new()
	n.add_child(mi)
	add_child(n)
	return n


func _center() -> Vector3:
	var c := field.get_center()
	return Vector3(c.x, 0.05, c.y)


## Где стоят все, пока матча нет: ребята у своих ворот, физрук у бровки.
func _place_idle() -> void:
	var c := field.get_center()
	_striker.global_position = Vector3(c.x + 2.5, 0.05, c.y)
	_keeper.global_position = Vector3(field.end.x - 0.7, 0.05, c.y)
	_coach.global_position = Vector3(c.x - 3.0, 0.05, field.end.y + 1.2)
	_coach.rotation.y = 0.0


func _start_prompt() -> String:
	if state == "play" or state == "goal":
		return ""
	var why: String = can_play.call() if can_play.is_valid() else ""
	if why != "":
		return why
	return "E — футбол с ребятами: 3 минуты или до %d голов" % WIN_GOALS


## Начать матч (pe — урок физкультуры).
func start(as_pe: bool) -> bool:
	if state == "play" or state == "goal":
		return false
	if not as_pe and can_play.is_valid() and can_play.call() != "":
		return false
	pe = as_pe
	mine = 0
	theirs = 0
	time_left = MATCH_TIME
	state = "play"
	_kickoff()
	SoundLibrary.play("whistle", -2.0, 1.1)
	GameManager.notify("%s: «Начали! Ты бьёшь в дальние ворота. У мяча — E, удар»" % ("Физрук" if pe else "Ребята"))
	return true


func _kickoff() -> void:
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.global_position = _center() + Vector3(0, BALL_R + 0.1, 0)
	_place_idle()


## Удар игрока: туда, куда он смотрит, если мяч рядом.
func kick() -> void:
	var p := GameManager.player as Node3D
	if state != "play" or p == null:
		return
	if _flat(p.global_position - ball.global_position).length() > 1.4:
		return
	var dir := -p.global_transform.basis.z
	dir.y = 0.0
	ball.linear_velocity = dir.normalized() * KICK + Vector3(0, 2.2, 0)
	SoundLibrary.play_at("jump", ball.global_position, 2.0, 1.6)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _process(delta: float) -> void:
	_t += delta
	# Зона удара — там, где мяч (не вращаясь вместе с ним)
	_ball_zone.global_position = ball.global_position - Vector3(0, BALL_R, 0)
	for k in [_striker, _keeper]:
		var mi := k.get_child(0) as MeshInstance3D
		Villagers.set_walk(mi, _t * 9.0, 1.0 if k.get_meta("moving", false) else 0.0)
	if state == "play" or state == "goal":
		var lt := "Физкультура" if pe else "Футбол"
		GameManager.challenge_line = "%s: ты %d : %d ребята · %d:%02d — у мяча E: удар" % [lt, mine, theirs, int(time_left) / 60, int(time_left) % 60]
	# Физрук следит за мячом
	var to := ball.global_position - _coach.global_position
	_coach.rotation.y = lerp_angle(_coach.rotation.y, atan2(-to.x, -to.z), minf(delta * 3.0, 1.0))


func _physics_process(delta: float) -> void:
	if state == "goal":
		_pause -= delta
		if _pause <= 0.0:
			if mine >= WIN_GOALS or theirs >= WIN_GOALS:
				_finish()
			else:
				state = "play"
				_kickoff()
		return
	if state != "play":
		return
	time_left -= delta
	if time_left <= 0.0:
		_finish()
		return
	_dribble()
	_kick_cool = maxf(_kick_cool - delta, 0.0)
	_striker_ai(delta)
	_keeper_ai(delta)
	_check_ball()


## Бежишь на мяч — он катится перед тобой.
func _dribble() -> void:
	var p := GameManager.player as CharacterBody3D
	if p == null or GameManager.vehicle != null:
		return
	var d := _flat(ball.global_position - p.global_position)
	var v := _flat(p.velocity)
	if d.length() < 0.75 and v.length() > 1.0 and v.dot(d) > 0.0:
		var push := v.normalized() * maxf(v.length() * 1.2, 2.0)
		ball.linear_velocity = Vector3(push.x, ball.linear_velocity.y, push.z)


## Нападающий ребят: бежит к мячу и бьёт в ворота игрока (−X).
func _striker_ai(delta: float) -> void:
	var bp := ball.global_position
	var me := _striker.global_position
	# Заходит к мячу со стороны своих ворот, чтобы бить в сторону игрока
	var aim := Vector3(bp.x + 0.5, 0.05, bp.z)
	_run(_striker, aim, KID_SPEED, delta)
	if _flat(bp - me).length() < 0.8 and _kick_cool <= 0.0:
		_kick_cool = 1.1
		var goal := Vector3(field.position.x, 0, field.get_center().y + randf_range(-1.2, 1.2))
		var dir := _flat(goal - bp).normalized()
		ball.linear_velocity = dir * randf_range(6.0, 8.5) + Vector3(0, 1.2, 0)
		SoundLibrary.play_at("jump", bp, 0.0, 1.5)


## Вратарь ребят: ходит по линии ворот за мячом, близкий — выбивает.
func _keeper_ai(delta: float) -> void:
	var bp := ball.global_position
	var cz := field.get_center().y
	var aim := Vector3(field.end.x - 0.7, 0.05, clampf(bp.z, cz - GOAL_HALF + 0.3, cz + GOAL_HALF - 0.3))
	_run(_keeper, aim, 2.6, delta)
	if _flat(bp - _keeper.global_position).length() < 0.9 and bp.y < 1.6:
		var dir := Vector3(-1.0, 0, randf_range(-0.6, 0.6)).normalized()
		ball.linear_velocity = dir * 9.0 + Vector3(0, 3.0, 0)
		SoundLibrary.play_at("jump", bp, 0.0, 1.4)


func _run(kid: Node3D, to: Vector3, speed: float, delta: float) -> void:
	var d := _flat(to - kid.global_position)
	var moving := d.length() > 0.2
	kid.set_meta("moving", moving)
	if not moving:
		return
	kid.global_position += d.normalized() * minf(speed * delta, d.length())
	kid.rotation.y = lerp_angle(kid.rotation.y, atan2(-d.x, -d.z), minf(delta * 10.0, 1.0))


## Гол, аут.
func _check_ball() -> void:
	var bp := ball.global_position
	var cz := field.get_center().y
	var in_goal := absf(bp.z - cz) < GOAL_HALF and bp.y < GOAL_H
	if in_goal and bp.x > field.end.x - 0.1:
		_goal(true)
	elif in_goal and bp.x < field.position.x + 0.1:
		_goal(false)
	elif not field.grow(1.5).has_point(Vector2(bp.x, bp.z)) or bp.y < -2.0:
		ball.linear_velocity = Vector3.ZERO
		_kickoff()
		GameManager.notify("Аут! Мяч — с центра")


func _goal(by_me: bool) -> void:
	if by_me:
		mine += 1
	else:
		theirs += 1
	state = "goal"
	_pause = 2.5
	SoundLibrary.play("whistle", -2.0, 1.0)
	if by_me:
		SoundLibrary.play("quest", -6.0, 1.4)
	GameManager.vibrate(150)
	GameManager.notify("%s %d : %d" % ["ГОЛ! Ты забил!" if by_me else "Гол в твои ворота…", mine, theirs])


func _finish() -> void:
	state = "idle"
	GameManager.challenge_line = ""
	SoundLibrary.play("whistle", -2.0, 0.9)
	_kickoff()
	TimeManager.advance(20.0)
	NeedsManager.energy = maxf(NeedsManager.energy - 8.0, 0.0)
	NeedsManager.water = maxf(NeedsManager.water - 10.0, 0.0)
	QuestManager.event("football")
	if mine > theirs:
		QuestManager.event("football_win")
	if not pe:
		var res := "Победа" if mine > theirs else ("Ничья" if mine == theirs else "Проиграл")
		GameManager.notify("Футбол окончен: %s, %d : %d. Ребята: «Приходи ещё!»" % [res, mine, theirs])
	finished.emit(mine, theirs, pe)
