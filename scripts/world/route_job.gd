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
## необязательные make_prop / passenger / cargo (посылки на транспорте).
##
## Заказ выбирается заранее — подсказка у раздатчика сразу говорит, куда
## и за сколько (describe_fn), а не «что-то куда-то».

signal finished(ok: bool)

## Идёт сейчас какая-то работа «по точкам» — одновременно только одна.
static var current: RouteJob = null

var id := ""
var title := ""
## Описание для подсказки у раздатчика: «развезти 2 посылки по сёлам».
var describe := ""
var giver := Vector3.ZERO
var giver_size := Vector3(2.4, 2.2, 2.4)
## () -> Array: [[имя точки, Vector3, (куда положить посылки)], …]
var stops_fn: Callable
## (точки) -> int: сколько заплатят
var pay_fn: Callable
var mode := "ride"
var radius := 6.0
## Сколько игровых минут занимает каждая точка (заправить машину).
var minutes_each := 0.0
## Работа руками у каждой точки (подмести, подстричь): столько минут игрок
## занят, часы идут своим ходом (TimeManager.work); work_what — что делает.
var work_each := 0.0
var work_what := "Работаю"
var open_from := 7.0
var open_to := 20.0
## Что поставить у точки (машина у колонки): (Vector3) -> Node3D
var make_prop: Callable
## Пассажир: стоит у раздатчика, едет с игроком, выходит в конце.
var passenger := false
var verb := "Готово"
## Табличка над раздатчиком и её размер (у соседних окошек — помельче).
var sign_text := "РАБОТА"
var sign_pixel := 0.006
## На какой высоте над раздатчиком табличка (в помещении — ниже потолка).
var sign_height := 3.0
## (точки, плата) -> String: описание готового заказа в подсказке.
var describe_fn: Callable
## Посылки: сколько коробок везём (видно на мопеде или в машине) и сколько
## оставляем у каждой точки; 0 — оставляем всё на последней.
var cargo := 0
## Только на этой технике (kind машины, "" — на любой своей): рейс — на ПАЗе.
var need_kind := ""
## Как сказать, на чём ехать, если техника своя особая («на ПАЗе …»).
var ride_on := ""
## () -> String: почему сейчас нельзя взять работу ("" — можно).
var blocked_fn: Callable
var drop_each := 0

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
## Следующий заказ — выбран заранее, чтобы показать его в подсказке.
var _offer: Array = []
var _load := 0
var _cargo_mi: MeshInstance3D
var _cargo_shown := -1


func _ready() -> void:
	_zone = InteractZone.create("", giver_size)
	_zone.position = giver
	_zone.prompt_fn = prompt
	_zone.activated.connect(start)
	add_child(_zone)
	_sign = Label3D.new()
	_sign.text = sign_text
	_sign.font_size = 64
	_sign.pixel_size = sign_pixel
	_sign.outline_size = 12
	_sign.modulate = Color(1.0, 0.8, 0.3)
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.position = giver + Vector3(0, sign_height, 0)
	# Крупную табличку на улице видно издали, мелкую в помещении — вблизи
	_sign.visibility_range_end = clampf(64.0 * sign_pixel * 400.0, 70.0, 150.0)
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
	var why := _blocked()
	if not why.is_empty():
		return why
	var lv := (" (%s)" % JobLevels.tag(id)) if JobLevels.JOBS.has(id) else ""
	if describe_fn.is_valid():
		var o := offer()
		if not o.is_empty():
			return "E — %s: %s%s" % [title, describe_fn.call(o, JobLevels.pay(id, int(pay_fn.call(o)))), lv]
	return "E — %s: %s%s" % [title, describe, lv]


## Заказ, который возьмёт игрок, если нажмёт E.
func offer() -> Array:
	if _offer.is_empty():
		_offer = stops_fn.call()
	return _offer


func _blocked() -> String:
	return String(blocked_fn.call()) if blocked_fn.is_valid() else ""


func start() -> void:
	if active or (current != null and current != self) or not is_open() or not _blocked().is_empty():
		return
	stops = offer()
	_offer = []
	if stops.is_empty():
		return
	pay = JobLevels.pay(id, int(pay_fn.call(stops)))
	_load = cargo
	idx = 0
	active = true
	current = self
	SoundLibrary.play("click", -4.0, 1.2)
	var how := "пешком" if mode == "foot" else (ride_on if not ride_on.is_empty() else "на мопеде или машине")
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
	_load = 0
	_show_cargo()
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
	var v := GameManager.vehicle as Vehicle
	if v and not need_kind.is_empty() and v.kind != need_kind:
		return null
	return v


func _process(delta: float) -> void:
	if _drop_t > 0.0:
		_drop_t -= delta
		if _drop_t <= 0.0 and not active:
			_reset_rider()
	_sign.visible = not active and is_open() and (current == null or current == self)
	if not active:
		return
	_line()
	_show_cargo()
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


## Пройти все точки сразу — для тестов и долгой игры.
func complete_all() -> void:
	if not active:
		start()
	while active:
		_reach()


func _reach() -> void:
	# Время шло, пока ехал и носил, — часы не перематываем
	if minutes_each > 0.0:
		NeedsManager.rest(-1.5)
	if work_each > 0.0:
		TimeManager.work(work_each, work_what)
		NeedsManager.rest(-2.0)
	if cargo > 0:
		var n := drop_each if drop_each > 0 and idx < stops.size() - 1 else _load
		# Третий элемент точки — где оставить коробки (у калитки, у окошка)
		_drop_boxes(stops[idx][2] if stops[idx].size() > 2 else stops[idx][1], mini(n, _load))
		_load -= mini(n, _load)
		_show_cargo()
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
	JobLevels.add(id)
	QuestManager.event(id)
	QuestManager.event("job")
	GameManager.notify("%s: работа сделана, +%d грн" % [title, pay])
	finished.emit(true)


# --- Посылки ------------------------------------------------------------------

## Стопка коробок разного размера: n штук, одним мешем.
static func boxes_mesh(n: int) -> MeshInstance3D:
	var b := MeshBuilder.new()
	b.ground_shade = false
	var cols := [Color(0.72, 0.55, 0.34), Color(0.66, 0.5, 0.3), Color(0.78, 0.62, 0.4)]
	# Много коробок — по три в ряд, чтобы стопка не росла столбом
	var cols_n := 3 if n > 4 else 2
	for i in n:
		var w := 0.34 if i % 2 == 0 else 0.28
		var h := 0.22 if i % 3 != 1 else 0.18
		var x := (float(i % cols_n) - (cols_n - 1) * 0.5) * 0.36
		var y := float(i / cols_n) * 0.23
		var c: Color = cols[i % 3]
		b.box(Vector3(x - w * 0.5, y, -0.17), Vector3(x + w * 0.5, y + h, 0.17), c)
		# Бечёвка крест-накрест
		b.box(Vector3(x - 0.012, y, -0.175), Vector3(x + 0.012, y + h + 0.004, 0.175), c.darkened(0.45))
		b.box(Vector3(x - w * 0.5 - 0.004, y, -0.012), Vector3(x + w * 0.5 + 0.004, y + h + 0.004, 0.012), c.darkened(0.45))
	var mi := b.build_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Коробки едут на транспорте игрока: на мопеде — на багажнике, на машине —
## на крыше. Пересел — переезжают следом.
func _show_cargo() -> void:
	var v := GameManager.vehicle as Vehicle if active else null
	var n := _load if v else 0
	if n == _cargo_shown and (_cargo_mi == null or _cargo_mi.get_parent() == v):
		return
	_cargo_shown = n
	if _cargo_mi and is_instance_valid(_cargo_mi):
		_cargo_mi.queue_free()
	_cargo_mi = null
	if n <= 0:
		return
	_cargo_mi = boxes_mesh(n)
	_cargo_mi.name = "Cargo"
	v.add_child(_cargo_mi)
	_cargo_mi.position = cargo_spot(v)


## Где на транспорте стоят коробки (в его координатах).
static func cargo_spot(v: Vehicle) -> Vector3:
	var seat: Vector3 = v.spec.seat
	if v.spec.two_wheels:
		return Vector3(0, seat.y - 0.38, seat.z + 0.5)
	var box := v._paint_mesh.get_aabb()
	return Vector3(0, box.end.y + 0.02, box.get_center().z + 0.6)


## Оставить коробки у точки: лежат у калитки, потом их забирают в дом.
func _drop_boxes(p: Vector3, n: int) -> void:
	if n <= 0:
		return
	var mi := boxes_mesh(n)
	mi.name = "Dropped"
	add_child(mi)
	mi.global_position = p + Vector3(0.0, 0.02, 0.0)
	mi.visibility_range_end = 80.0
	get_tree().create_timer(40.0).timeout.connect(mi.queue_free)
