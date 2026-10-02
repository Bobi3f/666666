class_name RouteJob
extends Node3D
## Работа «по точкам» — одна на всё: посылки, попутчик, заправщик.
## Берётся у раздатчика (зона E, над ней табличка «РАБОТА»), дальше — к
## точкам по очереди: над текущей светится столб, стрелка-навигатор ведёт
## туда (GameManager.nav_target), в строке задания — что делать и плата.
## Последняя точка — деньги и событие для заданий и поручений.
##
## Что за работа — задаётся данными: title, describe, giver, stops_fn,
## pay_fn, mode (ride — на любом своём транспорте, foot — пешком) и
## необязательные make_prop / passenger.

signal finished(ok: bool)

## Идёт сейчас какая-то работа «по точкам» — одновременно только одна.
static var current: RouteJob = null

var id := ""
var title := ""
## Описание для подсказки у раздатчика: «развезти 2 посылки по сёлам».
var describe := ""
var giver := Vector3.ZERO
var giver_size := Vector3(2.4, 2.2, 2.4)
## () -> Array: [[имя точки, Vector3], …]
var stops_fn: Callable
## (точки) -> int: сколько заплатят
var pay_fn: Callable
var mode := "ride"
var radius := 6.0
## Сколько игровых минут занимает каждая точка (заправить машину).
var minutes_each := 0.0
var open_from := 7.0
var open_to := 20.0
## Что поставить у точки (машина у колонки): (Vector3) -> Node3D
var make_prop: Callable
## Пассажир: стоит у раздатчика, едет с игроком, выходит в конце.
var passenger := false
var verb := "Готово"

var active := false
var stops: Array = []
var idx := 0
var pay := 0
var _beacon: Node3D
var _prop: Node3D
var _rider: MeshInstance3D
## Тот же попутчик сидя — едет на мопеде позади игрока.
var _rider_sit: MeshInstance3D
var _zone: InteractZone
var _sign: Label3D
var _drop_t := 0.0


func _ready() -> void:
	_zone = InteractZone.create("", giver_size)
	_zone.position = giver
	_zone.prompt_fn = prompt
	_zone.activated.connect(start)
	add_child(_zone)
	_sign = Label3D.new()
	_sign.text = "РАБОТА"
	_sign.font_size = 64
	_sign.pixel_size = 0.006
	_sign.outline_size = 12
	_sign.modulate = Color(1.0, 0.8, 0.3)
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.position = giver + Vector3(0, 3.0, 0)
	_sign.visibility_range_end = 70.0
	add_child(_sign)
	_beacon = _make_beacon()
	_beacon.visible = false
	add_child(_beacon)
	if passenger:
		var pb := MeshBuilder.new()
		pb.ground_shade = false
		preload("res://scripts/world/villagers.gd").person_model(pb, Color(0.35, 0.4, 0.55), Color(0.3, 0.25, 0.2), false, false)
		_rider = pb.build_mesh()
		_rider.visibility_range_end = 120.0
		add_child(_rider)
		var sb := MeshBuilder.new()
		sb.ground_shade = false
		preload("res://scripts/world/villagers.gd").person_model(sb, Color(0.35, 0.4, 0.55), Color(0.3, 0.25, 0.2), true, false)
		_rider_sit = sb.build_mesh()
		_rider_sit.visible = false
		add_child(_rider_sit)
		_reset_rider()


## Столб света над точкой: виден издалека, светится сам.
func _make_beacon() -> Node3D:
	var n := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.75, 0.25, 0.35)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.9
	cyl.height = 14.0
	cyl.radial_segments = 8
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.position.y = 7.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	return n


func is_open() -> bool:
	var h := TimeManager.hour()
	return h >= open_from and h < open_to


func prompt() -> String:
	if active:
		return "%s: %s (%d из %d)" % [title, stops[idx][0], idx + 1, stops.size()]
	if current != null and current != self:
		return "%s: сначала закончи «%s»" % [title, current.title]
	if not is_open():
		return "%s: работа с %d:00 до %d:00" % [title, int(open_from), int(open_to)]
	return "E — %s: %s" % [title, describe]


func start() -> void:
	if active or (current != null and current != self) or not is_open():
		return
	stops = stops_fn.call()
	if stops.is_empty():
		return
	pay = int(pay_fn.call(stops))
	idx = 0
	active = true
	current = self
	SoundLibrary.play("click", -4.0, 1.2)
	var how := "пешком" if mode == "foot" else "на мопеде или машине"
	GameManager.notify("%s: сначала — %s (%s), плата %d грн. Стрелка покажет дорогу" % [title, stops[0][0], how, pay])
	_show_stop()


func cancel() -> void:
	if not active:
		return
	active = false
	if current == self:
		current = null
	_beacon.visible = false
	GameManager.nav_target = Vector3.INF
	GameManager.nav_label = ""
	GameManager.challenge_line = ""
	_clear_prop()
	if passenger:
		_reset_rider()


## Строка в трекере задания: куда сейчас и сколько заплатят.
func _line() -> void:
	GameManager.challenge_line = "%s: %s — %d из %d, %d грн" % [title, stops[idx][0], idx + 1, stops.size(), pay]


func _show_stop() -> void:
	_line()
	var p: Vector3 = stops[idx][1]
	_beacon.global_position = p
	_beacon.visible = true
	GameManager.nav_target = p
	GameManager.nav_label = stops[idx][0]
	_clear_prop()
	if make_prop.is_valid():
		_prop = make_prop.call(p)
		if _prop:
			add_child(_prop)


func _clear_prop() -> void:
	if _prop and is_instance_valid(_prop):
		_prop.queue_free()
	_prop = null


func _reset_rider() -> void:
	if _rider_sit.get_parent() != self:
		_rider_sit.reparent(self)
	_rider_sit.visible = false
	_rider.global_position = giver + Vector3(0.6, 0, 0)
	_rider.rotation = Vector3(0, PI * 0.5, 0)
	_rider.visible = true


## Кто должен доехать: машина/мопед игрока или он сам пешком.
func _mover() -> Node3D:
	if mode == "foot":
		return GameManager.player as Node3D if GameManager.vehicle == null else null
	return GameManager.vehicle as Node3D


func _process(delta: float) -> void:
	if _drop_t > 0.0:
		_drop_t -= delta
		if _drop_t <= 0.0 and not active:
			_reset_rider()
	_sign.visible = not active and is_open() and (current == null or current == self)
	if not active:
		return
	_line()
	var m := _mover()
	# Пассажир едет с игроком: на мопеде — сзади на сиденье, в машине не виден
	if passenger and GameManager.vehicle:
		var v := GameManager.vehicle as Vehicle
		_rider.visible = false
		if _rider_sit.get_parent() != v:
			_rider_sit.reparent(v)
			_rider_sit.position = Vector3(0, float((v.spec.seat as Vector3).y) - 0.95, float((v.spec.seat as Vector3).z) + 0.45)
			_rider_sit.rotation = Vector3.ZERO
		_rider_sit.visible = v.spec.two_wheels
	if m == null:
		return
	var p: Vector3 = stops[idx][1]
	var d := Vector2(m.global_position.x - p.x, m.global_position.z - p.z).length()
	var slow := true
	if m is Vehicle:
		slow = (m as Vehicle).speed_kmh() < 6.0
	if d < radius and slow:
		_reach()


func _reach() -> void:
	if minutes_each > 0.0:
		TimeManager.advance(minutes_each)
		NeedsManager.rest(-1.5)
	idx += 1
	SoundLibrary.play("click", -4.0, 1.4)
	if idx < stops.size():
		GameManager.notify("%s. Дальше — %s (%d из %d)" % [verb, stops[idx][0], idx + 1, stops.size()])
		_show_stop()
		return
	var last_pos: Vector3 = stops[stops.size() - 1][1]
	cancel()
	if passenger:
		# Попутчик выходит и стоит у дороги, потом возвращается к раздатчику
		_rider_sit.reparent(self)
		_rider_sit.visible = false
		_rider.global_position = last_pos + Vector3(1.5, 0, 0)
		_rider.rotation = Vector3.ZERO
		_rider.visible = true
		_drop_t = 6.0
	GameManager.add_money(pay)
	SoundLibrary.play("cash")
	QuestManager.event(id)
	QuestManager.event("job")
	GameManager.notify("%s: работа сделана, +%d грн" % [title, pay])
	finished.emit(true)
