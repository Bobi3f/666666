class_name Chase
extends Node3D
## Погони.
##
## За игроком: уехал от проверки на посту ГАИ или пронёсся мимо поста быстрее
## ста — с поста выезжают милицейские «Жигули» с мигалкой и сиреной. Догнали
## и ты остановился — штраф FINE_CAUGHT. Оторвался (далеко и надолго) —
## повезло, на сегодня отстали.
##
## Со стороны: время от времени на трассе милиция гонится за лихачом —
## мчатся по разделительной, потом нарушитель прижимается к обочине, стоят,
## и оба уезжают. Это только зрелище, мешать игроку им не дают.

const FINE_CAUGHT := 800
## Скорость милиции в погоне, м/с (около 125 км/ч): на «Жигулях» по трассе
## уйти можно, на мопеде — нет.
const TOP := 35.0
const ACCEL := 7.0
## Оторвался: дальше этого, столько секунд подряд.
const LOST_DIST := 230.0
const LOST_TIME := 8.0
## Поймали: ближе этого и стоишь столько секунд.
const CATCH_DIST := 11.0
const CATCH_TIME := 1.5
## Зрелище на трассе: не чаще раза в столько секунд.
const SHOW_EVERY := 240.0
## Трасса вдоль X, полосы — по разные стороны от Z = 0 (как у попуток).
const ROAD_X := Region.HALF - 10.0
const LANE_Z := 2.0

## Погоня за игроком: ""(нет), "chase", "caught", "lost"
var state := ""
var reason := ""
var car: CharacterBody3D
var _mats: Array = []
var _siren: AudioStreamPlayer3D
var _t := 0.0
var _speed := 0.0
var _lost_t := 0.0
var _catch_t := 0.0
var _stuck_t := 0.0
var _end_t := 0.0
var _done_day := -1

## Зрелище: [нарушитель, милиция] и что с ними
var show_state := ""
var show_cars: Array = []
var _show_mats: Array = []
var _show_dir := 1
var _show_x := 0.0
var _show_t := 0.0
var _show_cool := 90.0
var _show_siren: AudioStreamPlayer3D


func _process(delta: float) -> void:
	_t += delta
	if car:
		Police.blink(_mats, _t)
	if show_cars.size() == 2:
		Police.blink(_show_mats, _t)


func _physics_process(delta: float) -> void:
	_update_show(delta)
	if car == null:
		return
	match state:
		"chase":
			_pursue(delta)
		_:
			# Погоня кончилась — тормозим и через несколько секунд уезжаем
			_speed = move_toward(_speed, 0.0, 10.0 * delta)
			_drive(delta, car.global_position - car.global_transform.basis.z)
			_end_t -= delta
			if _end_t <= 0.0:
				_remove_car()


# --- Погоня за игроком --------------------------------------------------------

## Начать погоню из точки at (пост ГАИ). Раз в день — второй раз не гонятся.
func start(at: Vector3, why: String) -> bool:
	if state == "chase" or _done_day == TimeManager.day:
		return false
	var target := _target()
	if target == null:
		return false
	reason = why
	state = "chase"
	_lost_t = 0.0
	_catch_t = 0.0
	_stuck_t = 0.0
	_speed = 0.0
	car = _make_car(at, target.global_position, true)
	_mats = car.get_meta("mats")
	_siren = car.get_node("Siren")
	_siren.play()
	GameManager.vibrate(200)
	GameManager.notify("ПОГОНЯ! %s — за тобой милиция. Остановись — или попробуй оторваться" % why)
	QuestManager.event("chase")
	return true


## Кого догоняем: машину игрока или его самого.
func _target() -> Node3D:
	if GameManager.vehicle:
		return GameManager.vehicle as Node3D
	return GameManager.player as Node3D


func _pursue(delta: float) -> void:
	var target := _target()
	if target == null:
		_end("lost")
		return
	var to := target.global_position - car.global_position
	var dist := Vector2(to.x, to.z).length()
	var v := GameManager.vehicle as Vehicle
	var their := absf(v.speed) if v else 0.0
	# Далеко — жмём на всю, близко — держимся вплотную, на скорости игрока
	var want := TOP if dist > 25.0 else clampf(their + (dist - 7.0) * 0.8, 0.0, TOP)
	_speed = move_toward(_speed, want, (ACCEL if want > _speed else 12.0) * delta)
	_drive(delta, _aim(target.global_position))
	GameManager.challenge_line = "ПОГОНЯ: милиция в %d м — остановись или оторвись (дальше %d м)" % [int(dist), int(LOST_DIST)]
	# Поймали: рядом и стоишь (или вышел из машины)
	if dist < CATCH_DIST and (v == null or their < 1.5):
		_catch_t += delta
		if _catch_t > CATCH_TIME:
			_end("caught")
			return
	else:
		_catch_t = 0.0
	if dist > LOST_DIST:
		_lost_t += delta
		if _lost_t > LOST_TIME:
			_end("lost")
			return
	else:
		_lost_t = 0.0
	# Застрял (забор, дом) рядом с игроком — «срезал дворами»: появляется
	# позади него. Далеко застрял — значит, игрок отрывается
	if dist < 150.0 and _speed > 8.0 and car.get_real_velocity().length() < 2.0:
		_stuck_t += delta
		if _stuck_t > 2.5:
			_stuck_t = 0.0
			var back := target.global_transform.basis.z.normalized() * 45.0
			car.global_position = target.global_position + Vector3(back.x, 1.0, back.z)
	else:
		_stuck_t = 0.0


## Куда рулить: игрок на трассе, а милиция рядом с ней — сначала на полосу
## и по ней, а не напрямик через обочину и кусты.
func _aim(target: Vector3) -> Vector3:
	var p := car.global_position
	var dx := target.x - p.x
	if absf(target.z) < 8.0 and absf(p.z) < 40.0 and absf(dx) > 30.0:
		var lane := LANE_Z * signf(dx)
		return Vector3(p.x + signf(dx) * 25.0, 0, lane)
	return target


## Едет к точке to: поворачивает не резче настоящей машины, держится земли.
func _drive(delta: float, to: Vector3) -> void:
	var d := to - car.global_position
	var want_yaw := atan2(-d.x, -d.z)
	var turn := 2.2 if _speed < 15.0 else 1.4
	car.rotation.y = rotate_toward(car.rotation.y, want_yaw, turn * delta)
	var fwd := -car.global_transform.basis.z
	car.velocity.x = fwd.x * _speed
	car.velocity.z = fwd.z * _speed
	car.velocity.y = 0.0 if car.is_on_floor() else car.velocity.y - 20.0 * delta
	car.move_and_slide()


func _end(how: String) -> void:
	state = how
	_done_day = TimeManager.day
	_end_t = 8.0
	GameManager.challenge_line = ""
	if _siren:
		_siren.stop()
	if how == "caught":
		QuestManager.event("chase_caught")
		var gai = get_parent().get_node_or_null("GaiPost")
		var text := "Догнали! Лейтенант: «%s — штраф %d грн»" % [reason, FINE_CAUGHT]
		if gai:
			gai._fine(FINE_CAUGHT, text)
		else:
			GameManager.notify(text)
	else:
		QuestManager.event("chase_escape")
		GameManager.notify("Оторвался от милиции! Сегодня больше не гоняются — но лучше не попадайся")


func _remove_car() -> void:
	if car:
		car.queue_free()
	car = null
	state = ""


## Милицейские «Жигули» с мигалкой, телом для столкновений и сиреной.
func _make_car(at: Vector3, look: Vector3, siren: bool) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "PoliceCar"
	# Капсула вдоль машины: круглое «днище» переезжает бордюры и ступеньки
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.75
	shape.height = 4.1
	cs.shape = shape
	cs.rotation.x = PI / 2.0
	cs.position.y = 0.75
	body.add_child(cs)
	body.floor_snap_length = 0.6
	body.floor_max_angle = deg_to_rad(40.0)
	add_child(body)
	body.global_position = at + Vector3(0, 0.1, 0)
	var d := look - at
	body.rotation.y = atan2(-d.x, -d.z)
	var mats := Police.car(body, Vector3.ZERO, 0.0)
	body.set_meta("mats", mats)
	if siren:
		var snd := AudioStreamPlayer3D.new()
		snd.name = "Siren"
		snd.stream = SoundLibrary.stream("siren")
		snd.unit_size = 12.0
		snd.max_distance = 260.0
		snd.volume_db = -4.0
		body.add_child(snd)
	return body


# --- Погоня со стороны на трассе ----------------------------------------------

## Запустить зрелище: лихач и милиция мчатся по трассе мимо камеры.
func start_show() -> bool:
	if show_state != "":
		return false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var c := cam.global_position
	_show_dir = 1 if randf() < 0.5 else -1
	# Появляются за 220 м до камеры и проносятся мимо
	_show_x = clampf(c.x - _show_dir * 220.0, -ROAD_X + 20.0, ROAD_X - 20.0)
	var b := MeshBuilder.new()
	b.ground_shade = false
	VehicleModels.npc(b, "car", Color(0.85, 0.75, 0.2))
	var bad := AnimatableBody3D.new()
	bad.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.7, 1.4, 4.2)
	cs.shape = shape
	cs.position.y = 1.0
	bad.add_child(cs)
	bad.add_child(b.build_mesh())
	bad.name = "Violator"
	add_child(bad)
	var cop := AnimatableBody3D.new()
	cop.sync_to_physics = false
	var cs2 := CollisionShape3D.new()
	cs2.shape = shape
	cs2.position.y = 1.0
	cop.add_child(cs2)
	cop.name = "ShowPolice"
	add_child(cop)
	_show_mats = Police.car(cop, Vector3.ZERO, 0.0)
	_show_siren = AudioStreamPlayer3D.new()
	_show_siren.stream = SoundLibrary.stream("siren")
	_show_siren.unit_size = 10.0
	_show_siren.max_distance = 220.0
	_show_siren.volume_db = -6.0
	cop.add_child(_show_siren)
	_show_siren.play()
	show_cars = [bad, cop]
	show_state = "run"
	_show_t = 0.0
	return true


## Лихач впереди, милиция догоняет; через ~20 с — к обочине, стоят, уезжают.
func _update_show(delta: float) -> void:
	if show_state == "":
		_show_cool -= delta
		if _show_cool <= 0.0:
			_show_cool = SHOW_EVERY * randf_range(0.8, 1.3)
			var cam := get_viewport().get_camera_3d()
			# Только если игрок у трассы — иначе смотреть некому
			if cam and absf(cam.global_position.z) < 120.0 and absf(cam.global_position.x) < ROAD_X - 60.0:
				start_show()
		return
	_show_t += delta
	var bad: Node3D = show_cars[0]
	var cop: Node3D = show_cars[1]
	var gap := 0.0
	var lane := 0.0
	match show_state:
		"run":
			# По разделительной: между встречными полосами попутки не мешают
			_show_x += _show_dir * 33.0 * delta
			gap = lerpf(40.0, 12.0, clampf(_show_t / 18.0, 0.0, 1.0))
			if _show_t > 20.0:
				show_state = "pull"
				_show_t = 0.0
		"pull":
			# К обочине, плавно тормозя
			var k := clampf(_show_t / 4.0, 0.0, 1.0)
			_show_x += _show_dir * lerpf(33.0, 0.0, k) * delta
			gap = 9.0
			lane = k
			if _show_t > 4.0:
				show_state = "stop"
				_show_t = 0.0
				_show_siren.stop()
		"stop":
			gap = 9.0
			lane = 1.0
			if _show_t > 14.0:
				show_state = "leave"
				_show_t = 0.0
		"leave":
			_show_x += _show_dir * minf(_show_t * 4.0, 20.0) * delta
			gap = 9.0 + _show_t * 3.0
			lane = 1.0
			if _show_t > 25.0 or absf(_show_x) > ROAD_X:
				_end_show()
				return
	# Обочина своего направления: за правой полосой
	var z := _show_dir * (LANE_Z + 2.6) * lane
	var yaw := -PI / 2.0 if _show_dir > 0 else PI / 2.0
	bad.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(_show_x, 0.05, z))
	cop.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(_show_x - _show_dir * gap, 0.05, z))


func _end_show() -> void:
	for c in show_cars:
		(c as Node).queue_free()
	show_cars = []
	show_state = ""
