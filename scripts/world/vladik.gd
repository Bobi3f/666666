class_name Vladik
extends Node3D
## Дядя Владик — механик из Каменки. Гараж на западной окраине у трассы
## (VladikGarage), внешность — VladikModel, товары и реплики — VladikData,
## окно разговора — VladikPanel.
##
## В гараже он не стоит столбом: работает у верстака, крутит мотор на
## подставке, осматривает мопед, роется на полках и носит ящик к верстаку,
## сидит на табурете с чаем, выходит к воротам поглядеть на трассу. Игрок
## подошёл — бросает дело и поворачивается к нему; ушёл — возвращается к
## работе. С 20:00 до 8:00 гараж закрыт.
##
## Доверие (rep, vladik_reputation) растёт за задания, ремонт и честную
## торговлю и открывает уровни (VladikData.LEVELS). Первая встреча
## начинает задание «Оживить Карпаты».

enum State { IDLE, WALK, RUN, TALK, LOOK_AROUND, REPAIR, USE_TOOL, INSPECT_VEHICLE,
	PICK_UP_OBJECT, PUT_DOWN_OBJECT, SIT, STAND, WORK_AT_BENCH }

const HOURS := [8.0, 20.0]
const WALK_SPEED := 1.25
const RUN_SPEED := 3.2
## Ближе — бросает работу и смотрит на игрока; дальше — снова за дело.
const NOTICE := 3.6
const FORGET := 6.5
## Дальше — не считаем ничего (дёшево для слабого ПК).
const SLEEP_DIST := 70.0
## Сколько раз в день Владик готов просто поболтать.
const CHATS_PER_DAY := 3
## Доверие за честную торговлю и ремонт — не больше стольких очков в день.
const TRADE_REP_DAY := 5

## Распорядок: [дело, где, сколько секунд].
const ROUTINE := [
	[State.WORK_AT_BENCH, "bench", 14.0],
	[State.REPAIR, "engine", 12.0],
	[State.PICK_UP_OBJECT, "shelf", 1.4],
	[State.USE_TOOL, "tool", 9.0],
	[State.INSPECT_VEHICLE, "inspect", 10.0],
	[State.SIT, "chair", 16.0],
	[State.LOOK_AROUND, "door", 7.0],
]

var rep := 0
var met := false
var chats := 0
var chat_day := 0
var trade_rep := 0
var trade_day := 0
var talk_i := 0

var state := State.IDLE
var outfit := "summer"
var panel: VladikPanel

var _body: Node3D
var _poses := {}
var _pose := ""
var _arm: Node3D
var _arm_axis := Vector3.RIGHT
var _routine_i := 0
var _timer := 0.0
var _target := Vector3.ZERO
var _target_yaw := 0.0
var _after_walk := State.IDLE
var _carrying := false
var _t := 0.0
var _check := 0.0
var _zone: InteractZone
var _moped_zone: InteractZone
var _wreck_zone: InteractZone
var _junk_zone: InteractZone
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("persist")
	add_to_group("vladik")
	_rng.randomize()
	global_transform = VladikGarage.xf()
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_build_poses()
	_zone = InteractZone.create("", Vector3(2.4, 2.0, 2.4))
	_zone.name = "TalkZone"
	_zone.prompt_fn = _prompt
	_zone.activated.connect(open_talk)
	_body.add_child(_zone)
	_moped_zone = InteractZone.create("", Vector3(2.6, 2.0, 3.0))
	_moped_zone.name = "MopedZone"
	_moped_zone.position = VladikGarage.MOPED_SPOT
	_moped_zone.prompt_fn = _moped_prompt
	_moped_zone.activated.connect(work_on_moped)
	add_child(_moped_zone)
	_wreck_zone = InteractZone.create("", Vector3(3.2, 2.0, 5.0))
	_wreck_zone.name = "WreckZone"
	_wreck_zone.position = VladikGarage.WRECK
	_wreck_zone.prompt_fn = _wreck_prompt
	_wreck_zone.activated.connect(dismantle)
	add_child(_wreck_zone)
	panel = VladikPanel.new()
	panel.vladik = self
	add_child(panel)
	QuestManager.completed.connect(_on_quest_done)
	_set_state(State.IDLE)
	_body.position = VladikGarage.SPOTS.bench[0]
	_next_activity()
	# Куча лома на свалке — для заданий «найди колесо / двигатель»
	_add_junk_zone.call_deferred()


func _add_junk_zone() -> void:
	_junk_zone = InteractZone.create("", Vector3(4.0, 2.0, 4.0))
	_junk_zone.name = "VladikJunkPile"
	_junk_zone.prompt_fn = _junk_prompt
	_junk_zone.activated.connect(search_junk)
	get_parent().add_child(_junk_zone)
	_junk_zone.global_position = Landmarks.junk_center() + Vector3(6.0, 0, -6.0)


# --- Модель и позы ----------------------------------------------------------

## Все позы — отдельные меши (видна одна): сменить модель — переписать
## только VladikModel.
func _build_poses() -> void:
	for n in _poses.values():
		n.queue_free()
	_poses.clear()
	for p in VladikModel.POSES:
		var b := MeshBuilder.new()
		b.ground_shade = false
		VladikModel.build(b, p, outfit)
		var mi := b.build_mesh()
		mi.name = "Pose_" + p
		mi.visible = false
		mi.visibility_range_end = 90.0
		if p in ["stand", "talk", "work", "carry"] and outfit == "summer":
			_back_print(mi, p)
		_body.add_child(mi)
		_poses[p] = mi
	if _arm:
		_arm.queue_free()
	_arm = Node3D.new()
	_arm.name = "ToolArm"
	_body.add_child(_arm)
	var pose := _pose
	_pose = ""
	_show_pose(pose if pose != "" else "stand")


## Надпись на спине футболки — как на фото.
func _back_print(mi: MeshInstance3D, pose: String) -> void:
	var l := Label3D.new()
	l.text = "Los Angeles"
	l.font_size = 40
	l.pixel_size = 0.005
	l.outline_size = 0
	l.modulate = Color(0.95, 0.94, 0.9)
	l.double_sided = false
	l.visibility_range_end = 25.0
	var xf := VladikModel._torso_xf(pose)
	l.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.36, 0.222))
	mi.add_child(l)


func _show_pose(p: String) -> void:
	if p == _pose:
		return
	_pose = p
	for k in _poses:
		_poses[k].visible = k == p
	for c in _arm.get_children():
		c.queue_free()
	var pts := VladikModel.tool_arm_points(p)
	_arm.visible = not pts.is_empty()
	if pts.is_empty():
		return
	var b := MeshBuilder.new()
	b.ground_shade = false
	var hand: Vector3 = pts.hand - pts.elbow
	VladikModel.tool_arm(b, hand, outfit)
	_arm.add_child(b.build_mesh())
	_arm.position = pts.elbow
	_arm.basis = Basis.IDENTITY
	_arm_axis = hand.normalized().cross(Vector3.UP).normalized()


func pose() -> String:
	return _pose


func _wanted_outfit() -> String:
	var s := WeatherManager.season()
	return "work" if s == 1 or s == 2 else "summer"


# --- Распорядок ----------------------------------------------------------------

func _set_state(s: State) -> void:
	state = s
	_t = 0.0
	match s:
		State.WALK, State.RUN, State.IDLE, State.LOOK_AROUND:
			_show_pose("carry" if _carrying else "stand")
		State.TALK:
			_show_pose("talk")
		State.REPAIR, State.USE_TOOL, State.WORK_AT_BENCH:
			_show_pose("work")
		State.INSPECT_VEHICLE, State.PICK_UP_OBJECT, State.PUT_DOWN_OBJECT, State.STAND:
			_show_pose("crouch")
		State.SIT:
			_show_pose("sit")


## Следующее дело по распорядку: идти туда, потом заниматься.
func _next_activity() -> void:
	var a: Array = ROUTINE[_routine_i % ROUTINE.size()]
	_routine_i += 1
	# Осматривать мопед — только если там что-то стоит; иначе дальше
	if a[0] == State.INSPECT_VEHICLE and not _moped_in_garage():
		a = ROUTINE[_routine_i % ROUTINE.size()]
		_routine_i += 1
	_go(a[1], a[0], a[2])


func _go(spot: String, then: State, secs: float) -> void:
	var sp: Array = VladikGarage.SPOTS[spot]
	_target = sp[0]
	_target_yaw = sp[1]
	_after_walk = then
	_timer = secs
	var far := _body.position.distance_to(_target) > 5.0
	_set_state(State.RUN if far and WeatherManager.wet() else State.WALK)


func _process(delta: float) -> void:
	var h := TimeManager.hour()
	var open := h >= HOURS[0] and h < HOURS[1]
	visible = open
	_zone.monitoring = open
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_slow_checks()
	if not open:
		return
	var player := _player_pos()
	if player.distance_to(global_position) > SLEEP_DIST:
		return
	_t += delta
	var near := Vector2(player.x - _body.global_position.x, player.z - _body.global_position.z).length()
	# Игрок рядом (или окно разговора) — бросает дело и смотрит на него
	if state != State.TALK and state != State.SIT and state != State.STAND and (near < NOTICE or (panel and panel.visible)):
		_set_state(State.TALK)
	if state == State.SIT and near < NOTICE:
		_set_state(State.STAND)
		_timer = 0.5
	match state:
		State.TALK:
			_face_point(player, delta)
			if near > FORGET and not (panel and panel.visible):
				_next_activity()
		State.WALK, State.RUN:
			_walk(delta, WALK_SPEED if state == State.WALK else RUN_SPEED)
		State.STAND:
			_timer -= delta
			if _timer <= 0.0:
				_set_state(State.TALK if near < NOTICE else State.IDLE)
				_timer = 1.0
		State.PICK_UP_OBJECT:
			_timer -= delta
			if _timer <= 0.0:
				_carrying = true
				_go("bench", State.PUT_DOWN_OBJECT, 1.2)
		State.PUT_DOWN_OBJECT:
			_timer -= delta
			if _timer <= 0.0:
				_carrying = false
				_set_state(State.WORK_AT_BENCH)
				_timer = 8.0
		_:
			_animate_work(delta)
			_timer -= delta
			if _timer <= 0.0:
				_next_activity()


func _walk(delta: float, speed: float) -> void:
	var to := _target - _body.position
	to.y = 0.0
	var mat := _poses[_pose].material_override as ShaderMaterial
	if to.length() < 0.06:
		_body.position = _target
		_body.rotation.y = _target_yaw
		if mat:
			mat.set_shader_parameter("amount", 0.0)
		_set_state(_after_walk)
		return
	_body.position += to.normalized() * minf(speed * delta, to.length())
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-to.x, -to.z), minf(delta * 8.0, 1.0))
	if mat:
		mat.set_shader_parameter("phase", _t * speed * 4.2)
		mat.set_shader_parameter("amount", 0.7 if speed > 2.0 else 0.45)


## Работа руками: ключ, напильник, тряпка; у двери — оглядывается.
func _animate_work(_delta: float) -> void:
	if _arm.visible:
		var hz := 2.6
		var amp := 0.3
		match state:
			State.USE_TOOL:
				hz = 5.0
				amp = 0.22
			State.WORK_AT_BENCH:
				hz = 1.6
				amp = 0.4
			State.INSPECT_VEHICLE:
				hz = 1.2
				amp = 0.18
		_arm.basis = Basis(_arm_axis, sin(_t * TAU * hz * 0.5) * amp)
	if state == State.LOOK_AROUND or state == State.SIT:
		var mat := _poses[_pose].material_override as ShaderMaterial
		# Ближе к игроку голову поворачивает PeopleLook
		if mat and _player_pos().distance_to(_body.global_position) > 8.0:
			mat.set_shader_parameter("look", sin(_t * 0.7) * 0.8)


func _face_point(p: Vector3, delta: float) -> void:
	var d := p - _body.global_position
	var yaw_w := atan2(-d.x, -d.z)
	var yaw_l := yaw_w - rotation.y
	_body.rotation.y = lerp_angle(_body.rotation.y, yaw_l, minf(delta * 5.0, 1.0))


func _player_pos() -> Vector3:
	var p := GameManager.player as Node3D
	if GameManager.vehicle:
		p = GameManager.vehicle as Node3D
	return p.global_position if p else Vector3(1e6, 0, 1e6)


## Раз в полсекунды: одежда по сезону, мопед и мотоцикл в гараже, мотор завёлся.
func _slow_checks() -> void:
	if _wanted_outfit() != outfit:
		outfit = _wanted_outfit()
		_build_poses()
	if _quest_step("vl_karpaty") == 0 and _moped_in_garage():
		QuestManager.event("vl_moped_here")
	if _quest_step("vl_karpaty") == 7:
		var m := GameManager.moped as Vehicle
		if m and m.engine_on and VladikGarage.inside(m.global_position, 6.0):
			QuestManager.event("vl_started")
	if _quest_step("vl_bike") == 0 and _bike_in_garage() != null:
		QuestManager.event("vl_bike_here")


func _quest_step(id: String) -> int:
	var q: Dictionary = QuestManager.quests.get(id, {})
	return int(q.step) if q.get("state", 0) == 1 else -1


func _moped_in_garage() -> bool:
	var m := GameManager.moped as Node3D
	return m != null and VladikGarage.inside(m.global_position, 1.0)


func _bike_in_garage() -> Vehicle:
	for v in get_tree().get_nodes_in_group("vehicles"):
		var car := v as Vehicle
		if car and car.kind in ["moto", "izh"] and car.owned() and VladikGarage.inside(car.global_position, 3.0):
			return car
	return null


# --- Доверие --------------------------------------------------------------------

func level() -> int:
	var l := 0
	for t in VladikData.LEVELS:
		if rep >= t:
			l += 1
	return l


## Прибавить доверия; новый уровень — Владик говорит, что открылось.
func add_rep(n: int) -> void:
	var before := level()
	rep = clampi(rep + n, 0, 100)
	var after := level()
	# Полное доверие — для главы «Правая рука Владика»
	if after > before and after >= VladikData.LEVELS.size():
		QuestManager.event("vladik_top")
	if after > before:
		SoundLibrary.play("quest", -4.0)
		GameManager.notify("Дядя Владик доверяет больше: уровень %d — %s. «%s»" % [after, VladikData.LEVEL_TEXT[after - 1], VladikData.LEVEL_UP[after - 1]])


## Доверие за торговлю и ремонт — понемногу и не больше TRADE_REP_DAY в день.
func _trade_rep(n: int) -> void:
	if trade_day != TimeManager.day:
		trade_day = TimeManager.day
		trade_rep = 0
	var give := mini(n, TRADE_REP_DAY - trade_rep)
	if give > 0:
		trade_rep += give
		add_rep(give)


func first_done() -> bool:
	return int(QuestManager.quests.get(VladikData.FIRST_QUEST, {}).get("state", 0)) == 2


# --- Разговор -------------------------------------------------------------------

func _prompt() -> String:
	var mark := " (!)" if QuestManager.has_line_for(VladikData.NAME) or not met else ""
	return "E — поговорить с Дядей Владиком%s" % mark


func open_talk() -> void:
	SoundLibrary.play("click", -4.0)
	panel.open()


## Первая встреча: что сказали (по репликам) и начатое задание.
func first_meeting() -> Array:
	met = true
	var lines: Array = VladikData.MEET_WITH_MOPED if _moped_in_garage() or _moped_near(25.0) else VladikData.MEET_NO_MOPED
	QuestManager.start(VladikData.FIRST_QUEST)
	if _moped_in_garage():
		QuestManager.event("vl_moped_here")
	return lines


func _moped_near(d: float) -> bool:
	var m := GameManager.moped as Node3D
	return m != null and m.global_position.distance_to(global_position) < d


## «Поговорить»: сперва — по заданию (вернулся, привёз), потом совет,
## шутка или история. Болтать больше трёх раз в день не даёт — работа.
func chat() -> String:
	var q := QuestManager.talk(VladikData.NAME)
	if q != "":
		return q
	if chat_day != TimeManager.day:
		chat_day = TimeManager.day
		chats = 0
	chats += 1
	if chats > CHATS_PER_DAY:
		return VladikData.BUSY[_rng.randi() % VladikData.BUSY.size()]
	var t: String = VladikData.TALK[talk_i % VladikData.TALK.size()]
	talk_i += 1
	return t


## Выполнено задание Владика: доверие, а за ремонт — сама техника.
func _on_quest_done(id: String) -> void:
	if id == VladikData.FIRST_QUEST:
		var m := GameManager.moped as Vehicle
		if m:
			_renew_all(m)
		add_rep(VladikData.FIRST_REP)
	elif VladikData.JOBS.has(id):
		add_rep(int(VladikData.JOBS[id][1]))
		if id == "vl_bike":
			var bike := _bike_in_garage()
			if bike:
				_renew_all(bike)
		elif id == "vl_restore":
			if not Progress.owned_cars.has("car:vladik"):
				Progress.owned_cars.append("car:vladik")


func _renew_all(v: Vehicle) -> void:
	for n in Vehicle.WEAR:
		v.renew_part(n)
	v.repair()


## «Получить работу»: следующее задание по уровню, или что сейчас делаешь.
func offer_job() -> String:
	if not first_done():
		return "Сначала свой мопед на ноги поставь. Потом поговорим о работе."
	for id in VladikData.JOBS:
		if int(QuestManager.quests[id].state) == 1:
			return "Ты сперва с «%s» разберись: %s" % [QuestManager.QUESTS[id].title, QuestManager.step_text(id).to_lower()]
	for id in VladikData.JOBS:
		var need: int = VladikData.JOBS[id][0]
		if int(QuestManager.quests[id].state) == 0 and level() >= need:
			QuestManager.start(id)
			return "%s (Новое задание: «%s» — J)" % [QuestManager.QUESTS[id].offer, QuestManager.QUESTS[id].title]
	for id in VladikData.JOBS:
		if int(QuestManager.quests[id].state) == 0:
			return "Работа есть, да рано тебе. Подтяни доверие — уровень %d." % int(VladikData.JOBS[id][0])
	return "Всё, что было, переделали. Заходи — новое появится, свистну."


# --- Мопед в гараже (задание «Оживить Карпаты») ------------------------------

const MOPED_STEPS := {
	1: ["E — осмотреть двигатель с Владиком", "vl_inspect",
		"Так… Свеча в нагаре, масло в баке — одно название, цепь висит. И бензокран, гляди, засран. Купи у меня свечу и масло — дальше сам."],
	4: ["E — проверить и подтянуть цепь", "vl_chain", "Палец — провис. Подтянули. Смажь потом, не жмись."],
	5: ["E — продуть бензокран и фильтр", "vl_fuel", "Вот она, грязь. Продули — бензин пошёл как надо."],
	6: ["E — поставить свечу и залить масло", "vl_repair", "Свеча на место, масло в бак один к пятидесяти. Ну, заводи — проверим."],
}


func _moped_prompt() -> String:
	var s := _quest_step("vl_karpaty")
	if not MOPED_STEPS.has(s) or not _moped_in_garage() or not visible:
		return ""
	return MOPED_STEPS[s][0]


## Шаг ремонта «Карпат» у мопеда: Владик подходит и помогает.
func work_on_moped() -> void:
	var s := _quest_step("vl_karpaty")
	if not MOPED_STEPS.has(s) or not _moped_in_garage():
		return
	if s == 6:
		if not (QuestManager._has("plug", 1) and QuestManager._has("oil2t", 1)):
			GameManager.notify("Дядя Владик: «Свечу и масло сперва купи — у меня, «Купить запчасти»»")
			return
		QuestManager._take("plug", 1)
		QuestManager._take("oil2t", 1)
	SoundLibrary.play("hammer", -6.0)
	TimeManager.work(15.0, "Чиним «Карпаты» с Владиком")
	_body.position = VladikGarage.SPOTS.inspect[0]
	_body.rotation.y = VladikGarage.SPOTS.inspect[1]
	_set_state(State.INSPECT_VEHICLE)
	_timer = 6.0
	GameManager.notify("Дядя Владик: «%s»" % MOPED_STEPS[s][2])
	QuestManager.event(MOPED_STEPS[s][1])


# --- Разборка «копейки» и куча лома на свалке -------------------------------------

func _wreck_prompt() -> String:
	if _quest_step("vl_dismantle") != 0 or not visible:
		return ""
	var n := int(QuestManager.quests.vl_dismantle.n)
	return "E — разбирать «копейку» (заход %d из 3, 40 мин)" % (n + 1)


func dismantle() -> void:
	if _quest_step("vl_dismantle") != 0:
		return
	TimeManager.work(40.0, "Разбираю «копейку»")
	SoundLibrary.play("hammer")
	var got: String = VladikData.DISMANTLE_LOOT[_rng.randi() % VladikData.DISMANTLE_LOOT.size()]
	QuestManager.give_item(got)
	GameManager.notify("Открутил и снял: %s. Лежит в запасе — Владик купит" % String(VladikData.BUYS[got][0]).to_lower())
	QuestManager.event("vl_dismantle")


func _junk_prompt() -> String:
	if _quest_step("vl_junk") == 0:
		return "E — порыться в куче лома (колесо для Владика)"
	if _quest_step("vl_engine") == 0 or _quest_step("vl_restore") == 0:
		return "E — порыться в куче лома (двигатель для Владика)"
	return ""


func search_junk() -> void:
	TimeManager.work(30.0, "Роюсь в куче лома")
	SoundLibrary.play("hammer", -4.0)
	if _quest_step("vl_junk") == 0:
		GameManager.notify("Под ржавым капотом — колесо. Старое, но целое")
		QuestManager.event("vl_junk_found")
	elif _quest_step("vl_engine") == 0 or _quest_step("vl_restore") == 0:
		GameManager.notify("Из-под кузова «Столичника» торчит мотор. Тяжёлый, но живой — грузи")
		QuestManager.event("vl_engine_found")


# --- Торговля и ремонт ------------------------------------------------------------

## Цена расходника id в состоянии q.
static func good_price(id: String, q: String) -> int:
	return maxi(int(round(float(VladikData.GOODS[id][1]) * float(VladikData.QUALITY[q][1]) / 5.0)) * 5, 5)


## Купить расходник в запас. Свеча и масло — для «Оживить Карпаты».
func buy_good(id: String, q := "new") -> bool:
	if not VladikData.GOODS.has(id) or level() < int(VladikData.GOODS[id][2]):
		return false
	var price := good_price(id, q)
	if not GameManager.spend(price):
		return false
	# В задании годится любая — Владик предупредит, если старая
	QuestManager.give_item(id)
	match id:
		"plug":
			QuestManager.event("vl_buy_plug")
		"oil2t":
			QuestManager.event("vl_buy_oil")
	GameManager.notify("Купил у Владика: %s (%s) — %d грн" % [String(VladikData.GOODS[id][0]).to_lower(), VladikData.QUALITY[q][0], price])
	return true


## Можно ли Владику ремонтировать технику v на этом уровне.
func can_repair(v: Vehicle) -> bool:
	if v == null or not v.owned():
		return false
	return level() >= (2 if v.spec.two_wheels else 4)


static func repair_price(v: Vehicle, n: String, q: String) -> int:
	return maxi(int(round(v.part_price(n) * VladikData.REPAIR_K * float(VladikData.QUALITY[q][1]) / 10.0)) * 10, 10)


## Поставить на v узел n в состоянии q (новый, б/у, старый).
func repair_part(v: Vehicle, n: String, q: String) -> bool:
	if not can_repair(v) or not Vehicle.WEAR.has(n):
		return false
	var hp: float = VladikData.QUALITY[q][2]
	if v.part_health(n) >= hp:
		return false
	var price := repair_price(v, n, q)
	if not GameManager.spend(price):
		return false
	SoundLibrary.play("hammer")
	TimeManager.advance(40.0)
	if hp >= 100.0:
		v.renew_part(n)
	else:
		v.health[n] = hp
		v._warned_parts.erase(n)
	QuestManager.event("part_renewed")
	_trade_rep(1)
	GameManager.notify("Владик поставил на «%s»: %s, %s (−%d грн)" % [v.spec.title, String(Vehicle.WEAR[n][0]).to_lower(), VladikData.QUALITY[q][0], price])
	return true


## Редкая деталь на технику v (свой уровень и «для кого»).
func buy_rare(id: String, v: Vehicle) -> bool:
	if not VladikData.RARE.has(id) or v == null or not v.owned():
		return false
	var r: Array = VladikData.RARE[id]
	if level() < int(r[2]) or (r[3] == "moto") != bool(v.spec.two_wheels) or v.has_part(r[4]):
		return false
	if not GameManager.spend(int(r[1])):
		return false
	SoundLibrary.play("hammer")
	TimeManager.advance(30.0)
	v.fit_part(r[4])
	QuestManager.event("tuning")
	GameManager.notify("Владик поставил на «%s»: %s (−%d грн)" % [v.spec.title, String(r[0]).to_lower(), int(r[1])])
	return true


## Что из запаса игрока Владик купит: [id, сколько].
func sellable() -> Array:
	var out := []
	for id in VladikData.BUYS:
		var n := int(QuestManager.items.get(id, 0))
		if n > 0:
			out.append([id, n])
	return out


## Продать одну вещь id. Свечу и масло во время «Оживить Карпаты» не берёт.
func sell_item(id: String) -> bool:
	if not VladikData.BUYS.has(id) or int(QuestManager.items.get(id, 0)) <= 0:
		return false
	if id in ["plug", "oil2t"] and _quest_step(VladikData.FIRST_QUEST) >= 0:
		GameManager.notify("Дядя Владик: «Ты чего? Это ж для твоих «Карпат». Оставь»")
		return false
	QuestManager._take(id, 1)
	var price := int(VladikData.BUYS[id][1])
	GameManager.add_money(price)
	SoundLibrary.play("cash")
	_trade_rep(1)
	GameManager.notify("Продал Владику: %s — +%d грн" % [String(VladikData.BUYS[id][0]).to_lower(), price])
	QuestManager.changed.emit()
	return true


## Цена, за которую Владик купит технику: больше, чем на свалке, и растёт с доверием.
func vehicle_price(v: Vehicle) -> int:
	var base := JunkPanel.sell_price(v) / JunkPanel.SELL_K * VladikData.BUY_VEHICLE_K
	return int(round(base * (1.0 + 0.02 * (level() - 1)) / 10.0)) * 10


func sell_vehicle(v: Vehicle) -> bool:
	if not JunkPanel.can_sell(v) or not first_done():
		return false
	var money := vehicle_price(v)
	v.sell_back()
	GameManager.add_money(money)
	SoundLibrary.play("cash")
	QuestManager.event("vehicle_sold")
	_trade_rep(3)
	GameManager.notify("Дядя Владик купил «%s» за %d грн" % [v.spec.title, money])
	return true


## Своя техника у гаража и во дворе — её можно чинить и продавать.
func nearby_vehicles() -> Array:
	var out := []
	for v in get_tree().get_nodes_in_group("vehicles"):
		var car := v as Vehicle
		if car and car.owned() and car.global_position.distance_to(VladikGarage.w(Vector3(0, 0, 2.0))) < 14.0:
			out.append(car)
	return out


## Позвать на своё СТО — с пятого уровня, если СТО куплено.
func can_hire() -> bool:
	return level() >= 5 and Daily.owns("sto") and not Daily.hired.has("vladik")


func hire() -> bool:
	if not can_hire():
		return false
	Daily.hire("vladik")
	return true


# --- Сохранение -------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"rep": rep, "met": met, "chats": chats, "chat_day": chat_day, "trade_rep": trade_rep,
		"trade_day": trade_day, "talk_i": talk_i}


func load_state(d: Dictionary) -> void:
	rep = clampi(int(d.get("rep", 0)), 0, 100)
	met = bool(d.get("met", false))
	chats = int(d.get("chats", 0))
	chat_day = int(d.get("chat_day", 0))
	trade_rep = int(d.get("trade_rep", 0))
	trade_day = int(d.get("trade_day", 0))
	talk_i = int(d.get("talk_i", 0))
