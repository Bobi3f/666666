extends Node3D
## Жители Каменки, куры во дворах и собаки у будок.
##
## С жителями можно поговорить (E) — каждый раз следующая фраза, в них
## подсказки: где заработать, где заправиться, как добраться до города.
## А когда у игрока что-то меняется (новый дом, права, своя машина, своё
## дело) — сперва скажут про это, у каждого своё.
##
## У каждого распорядок дня: утром в сельмаг, днём по делам, вечером на
## лавочку, ночью спят дома (их не видно). Ходят по улице пешком; если
## игрок далеко — просто оказываются на месте.
## Почтальонка ходит по улице туда-обратно. Собаки лают, если подойти
## к чужому двору, куры бродят и кудахчут.

## Дворы как в world.gd: [x, z, поворот, есть ли будка]. Двор игрока (-125, -56)
## перестраивается, поэтому своей собаки у игрока здесь нет.
const DOG_YARDS := [
	[-150.0, -56.0, 0.0], [-75.0, -56.0, 0.0],
	[-125.0, -24.0, PI], [-100.0, -24.0, PI], [-75.0, -24.0, PI],
]
const CHICKEN_YARDS := [[-150.0, -56.0, 0.0], [-125.0, -24.0, PI], [-75.0, -24.0, PI], [-100.0, -24.0, PI]]

## Середина деревенской улицы: по ней жители ходят от места к месту.
const LANE_Z := -40.0
const WALK_SPEED := 1.3
## Места: где стоять или сидеть и как пройти к улице (через точки via).
## "home" — дома, не видно.
const SPOTS := {
	"bench_galya": {"pos": Vector3(-102.5, 0, -36.45), "yaw": 0.0, "sit": true},
	"bench_mikh": {"pos": Vector3(-101.3, 0, -36.45), "yaw": 0.0, "sit": true},
	"bench_lyuda": {"pos": Vector3(-77.2, 0, -36.45), "yaw": 0.0, "sit": true},
	"shop_galya": {"pos": Vector3(-53.5, 0, -26.3), "yaw": -PI / 2.0, "via": [Vector3(-57.0, 0, -30.0)]},
	"shop_lyuda": {"pos": Vector3(-53.5, 0, -28.0), "yaw": -PI / 2.0, "via": [Vector3(-57.0, 0, -30.0)]},
	"shop_mikh": {"pos": Vector3(-51.5, 0, -19.0), "yaw": PI / 2.0, "via": [Vector3(-55.0, 0, -20.0), Vector3(-57.0, 0, -30.0)]},
	"shop_petr": {"pos": Vector3(-54.0, 0, -31.2), "yaw": -PI / 2.0, "via": [Vector3(-57.0, 0, -31.2)]},
	"pond": {"pos": Vector3(-172.0, 0, -43.0), "yaw": PI / 2.0},
	"kolkhoz": {"pos": Vector3(-39.5, 0, -40.5), "yaw": PI},
	"stop": {"pos": Vector3(-68.0, 0, -8.0), "yaw": PI, "via": [Vector3(-59.0, 0, -8.0), Vector3(-59.0, 0, -30.0)]},
	"sto": {"pos": Vector3(-82.0, 0, 12.3), "yaw": 0.0, "far": true},
}

## Что говорят, когда у игрока что-то поменялось. Свои реплики — в "react"
## у жителя, остальное — общее. Порядок — от самого важного.
const REACT_ORDER := ["sto", "house2", "house1", "biz", "car", "license", "broken", "rich"]
const REACT_COMMON := {
	"house2": "Дом-то какой отгрохал! Кирпич, черепица — хозяин!",
	"house1": "Новый дом у тебя — любо-дорого! Избу не узнать.",
	"biz": "Говорят, ты теперь при своём деле? Уважаю.",
	"car": "Видали тебя на новой машине! Разбогател, гляжу.",
	"license": "Права получил? Молодец, теперь по-людски ездишь.",
	"broken": "Машину-то почини — гремит на всю деревню!",
	"rich": "Денег, говорят, куры не клюют. Не зазнавайся!",
}

const PEOPLE := [
	{"name": "Баба Галя", "pos": Vector3(-102.0, 0, -36.45), "yaw": 0.0, "sit": true, "woman": true,
		"plan": [[0, "home"], [6, "bench_galya"], [9, "shop_galya"], [11, "bench_galya"], [21, "home"]],
		"react": {"house1": "Ой, сынок, дом-то какой! Мать бы порадовалась.",
			"car": "На машине новой? Прокатишь старуху до города?"},
		"shirt": Color(0.45, 0.25, 0.35), "hat": Color(0.85, 0.3, 0.3),
		"lines": ["Здравствуй, сынок! В сельмаге хлеб дешевле, чем в городском ларьке.",
			"В колхозе «Заря» сено грузят — платят четыреста за смену. Только не в дождь.",
			"Дом бы тебе новый... Прораб у твоей калитки за двенадцать тысяч возьмётся.",
			"Ночью фонари горят, а раньше тут темень была — хоть глаз выколи."]},
	{"name": "Дед Михалыч", "pos": Vector3(-51.5, 0, -19.0), "yaw": PI / 2.0, "sit": false,
		"plan": [[0, "home"], [6, "shop_mikh"], [12, "pond"], [16, "bench_mikh"], [21, "home"]],
		"react": {"broken": "Гремит твоя машина, как мой трактор в сорок девятом. К Ваське езжай!",
			"license": "С правами, значит? В наше время права давали тому, кто трактор заведёт."},
		"shirt": Color(0.3, 0.35, 0.3), "hat": Color(0.25, 0.25, 0.28),
		"lines": ["Жигули твои без бензина не поедут. Заправка у трассы, напротив деревни.",
			"В дождь по грунтовке не гоняй — засядешь по самые пороги.",
			"Со склада в городе хлеб к нам возят. Есть машина — бери заказ, пятьсот платят.",
			"Скрежещешь коробкой? Сцепление выжимай, а то на СТО всё и оставишь."]},
	{"name": "Бригадир Петрович", "pos": Vector3(-39.5, 0, -40.5), "yaw": PI, "sit": false,
		"plan": [[0, "home"], [6, "kolkhoz"], [19, "shop_petr"], [22, "home"]],
		"react": {"biz": "Своё дело открыл? Только колхоз не забывай!",
			"house2": "Кирпичный дом! Небось и колхозная премия там кирпичиком легла."},
		"shirt": Color(0.25, 0.3, 0.45), "hat": Color(0.2, 0.2, 0.22),
		"lines": ["Работа есть — с семи до семи. Жми E у ворот сарая.",
			"Вилы в руки — и три часа на сене. Устанешь, зато четыреста в кармане.",
			"Выспись сначала. Сонный на скирде — это не работник."]},
	{"name": "Тётя Люда", "pos": Vector3(-68.0, 0, -8.0), "yaw": PI, "sit": false, "woman": true,
		"plan": [[0, "home"], [7, "stop"], [12, "shop_lyuda"], [15, "bench_lyuda"], [21, "home"]],
		"react": {"car": "Может, и меня в поликлинику свозишь на своей новой?"},
		"shirt": Color(0.55, 0.45, 0.25), "hat": Color(0.9, 0.9, 0.85),
		"lines": ["Автобус в город ходит с шести утра до десяти вечера. Пятнадцать гривен.",
			"В городе у склада остановка — оттуда обратно так же уедешь.",
			"Жду вот, в поликлинику надо..."]},
	{"name": "Механик Васёк", "pos": Vector3(-82.0, 0, 12.3), "yaw": 0.0, "sit": false,
		"plan": [[0, "home"], [8, "sto"], [20, "home"]],
		"react": {"sto": "Так ты теперь хозяин СТО? Ну, начальник, работаем!",
			"car": "Новую взял? Пригоняй, посмотрим, что у неё под капотом.",
			"broken": "Приезжай, подлатаю. По старой дружбе — без очереди."},
		"shirt": Color(0.2, 0.25, 0.4), "hat": Color(0.8, 0.4, 0.1),
		"lines": ["Загоняй машину в бокс — посмотрю. Двадцать пять гривен за процент износа.",
			"Заглохнет сама на ходу — значит, изношена. Не тяни, приезжай.",
			"Удары, скрежет, глохнешь — всё это машину убивает."]},
]

var _people: Array[Dictionary] = []
var _walker: Node3D
var _walk_dir := 1.0
var _walker_phase := 0.0
var _chickens: Array[Dictionary] = []
var _dogs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
## Калитки, куда носить письма почтальонки: [зона, надпись «ПИСЬМО»]
var _letter_gates: Array = []


func _ready() -> void:
	_rng.seed = 55
	for d in PEOPLE:
		var n := _person(d.shirt, d.hat, false, d.get("woman", false))
		# Второй вид — сидя на лавочке
		var sit_b := MeshBuilder.new()
		sit_b.ground_shade = false
		person_model(sit_b, d.shirt, d.hat, true, d.get("woman", false))
		var sit_mesh := sit_b.build_mesh()
		sit_mesh.visible = false
		n.add_child(sit_mesh)
		n.position = d.pos
		n.rotation.y = d.yaw
		add_child(n)
		var st := {"node": n, "stand": n.get_child(0), "sit": sit_mesh, "data": d, "slot": "", "path": [], "said": {}}
		_people.append(st)
		_talk_zone(n, d, st)
		_place(st, _slot_for(d), true)
	# Почтальонка ходит по улице
	var walker_data := {"name": "Почтальонка Оля", "shirt": Color(0.2, 0.35, 0.65), "hat": Color(0.2, 0.35, 0.65),
		"lines": ["Писем вам нет, только квитанция за свет.", "Вся Каменка на мне — от пруда до трассы, два раза в день.",
			"Говорят, в город на машине быстрее, чем автобусом. Если бензин есть."]}
	_walker = _person(walker_data.shirt, walker_data.hat, false, true)
	_walker.position = Vector3(-150.0, 0, -37.9)
	add_child(_walker)
	_talk_zone(_walker, walker_data)
	for y in CHICKEN_YARDS:
		var xf := Transform3D(Basis(Vector3.UP, y[2]), Vector3(y[0], 0, y[1]))
		for i in 3:
			var c := _chicken_mesh()
			var home := xf
			c.position = home * Vector3(_rng.randf_range(-9.0, -3.5), 0, _rng.randf_range(6.0, 11.0))
			add_child(c)
			_chickens.append({"node": c, "xf": home, "target": c.position, "wait": _rng.randf_range(0.0, 3.0)})
	# Калитки для писем: у двух дворов первого ряда и одного — второго
	for g in [Vector3(-151.6, 0, -43.2), Vector3(-98.4, 0, -36.8), Vector3(-76.6, 0, -43.2)]:
		var i := _letter_gates.size()
		var z := InteractZone.create("", Vector3(2.4, 2.0, 1.8))
		z.position = g
		z.prompt_fn = func() -> String: return "E — опустить письмо в ящик" if _letter_pending(i) else ""
		z.activated.connect(_deliver_letter.bind(i))
		add_child(z)
		var mark := Label3D.new()
		mark.text = "ПИСЬМО"
		mark.font_size = 128
		mark.pixel_size = 0.006
		mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mark.modulate = Color(1.0, 0.9, 0.4)
		mark.outline_size = 12
		mark.position = g + Vector3(0, 2.4, 0)
		add_child(mark)
		# Почтовый ящик на заборе
		var box := MeshBuilder.new()
		box.box(g + Vector3(-0.2, 1.0, -0.12), g + Vector3(0.2, 1.35, 0.12), Color(0.2, 0.35, 0.65))
		box.box(g + Vector3(-0.03, 0, -0.03), g + Vector3(0.03, 1.0, 0.03), Color(0.35, 0.3, 0.25))
		add_child(box.build_mesh())
		_letter_gates.append([z, mark])
	for y in DOG_YARDS:
		var xf := Transform3D(Basis(Vector3.UP, y[2]), Vector3(y[0], 0, y[1]))
		var dog := _dog_mesh()
		dog.position = xf * Vector3(4.6, 0, 9.2)
		dog.rotation.y = y[2] + PI
		add_child(dog)
		_dogs.append({"node": dog, "cool": 0.0})


func _talk_zone(n: Node3D, d: Dictionary, st := {}) -> void:
	var zone := InteractZone.create("E — поговорить: %s" % d.name, Vector3(2.2, 2.0, 2.2))
	zone.position = Vector3(0, 0, -0.9)
	n.add_child(zone)
	var state := {"i": 0}
	zone.activated.connect(func() -> void:
		# Первый разговор за день — с приветствием по времени суток
		var hi := ""
		if int(state.get("day", 0)) != TimeManager.day:
			state["day"] = TimeManager.day
			hi = _greeting() + " "
		# Сначала — задания: предложить, принять вещь, поблагодарить
		var quest_line := QuestManager.talk(d.name)
		if quest_line != "":
			GameManager.notify("%s: «%s%s»" % [d.name, hi, quest_line])
			return
		# Потом — про то, что у игрока поменялось
		var news := _news(d, st)
		if news != "":
			GameManager.notify("%s: «%s%s»" % [d.name, hi, news])
			return
		var lines: Array = d.lines
		GameManager.notify("%s: «%s%s»" % [d.name, hi, lines[state.i % lines.size()]])
		state.i += 1)
	zone.prompt_fn = func() -> String:
		if _has_quest_for(d.name):
			return "E — поговорить: %s  (!)" % d.name
		return "E — поговорить: %s" % d.name


static func _greeting() -> String:
	var h := TimeManager.hour()
	if h >= 5.0 and h < 11.0:
		return "Доброе утро!"
	if h >= 11.0 and h < 17.0:
		return "Добрый день!"
	if h >= 17.0 and h < 22.0:
		return "Добрый вечер!"
	return "Не спится? Ночь на дворе."


## Есть ли у жителя что сказать по заданию: новая просьба или ждёт отчёта.
func _has_quest_for(npc: String) -> bool:
	for id in QuestManager.QUESTS:
		var def: Dictionary = QuestManager.QUESTS[id]
		if def.get("giver", "") != npc:
			continue
		var q: Dictionary = QuestManager.quests[id]
		if q.state == 0:
			return true
		if q.state == 1:
			var step: Dictionary = def.steps[q.step]
			if step.get("talk", false):
				return true
	return false


## Что сказать про перемены у игрока, "" — нечего. Каждое — один раз.
func _news(d: Dictionary, st: Dictionary) -> String:
	if st.is_empty():
		return ""
	var react: Dictionary = d.get("react", {})
	for key in REACT_ORDER:
		if st.said.has(key) or not _news_true(key):
			continue
		if key == "sto" and not react.has(key):
			continue
		st.said[key] = true
		return react.get(key, REACT_COMMON.get(key, ""))
	return ""


func _news_true(key: String) -> bool:
	match key:
		"sto":
			return Daily.owns("sto")
		"house2":
			return Progress.house_level >= 2
		"house1":
			return Progress.house_level >= 1
		"biz":
			return not Daily.owned.is_empty()
		"car":
			return not Progress.owned_cars.is_empty()
		"license":
			return Progress.license
		"broken":
			var car := GameManager.car as Vehicle
			return car != null and car.condition < 40.0
		"rich":
			return GameManager.money >= 20000
	return false


# --- Распорядок дня -----------------------------------------------------------

func _slot_for(d: Dictionary) -> String:
	var h := TimeManager.hour()
	var slot := "home"
	for p in d.plan:
		if h >= float(p[0]):
			slot = p[1]
	return slot


## Поставить жителя на место сразу (instant) или проложить путь по улице.
func _place(st: Dictionary, slot: String, instant: bool) -> void:
	var n: Node3D = st.node
	var from: String = st.slot
	st.slot = slot
	st.path = []
	if slot == "home":
		n.visible = not instant and n.visible
		return
	var spot: Dictionary = SPOTS[slot]
	var far := bool(spot.get("far", false)) or from == "" or from == "home" or bool(SPOTS.get(from, {}).get("far", false))
	if instant or far:
		_set_at(st, spot)
		return
	# Путь: от места к улице, по улице, от улицы к месту
	var path: Array = []
	var from_via: Array = SPOTS[from].get("via", [])
	for v in from_via:
		path.append(v)
	var a: Vector3 = path.back() if not path.is_empty() else n.position
	path.append(Vector3(a.x, 0, LANE_Z))
	var to_via: Array = spot.get("via", []).duplicate()
	to_via.reverse()
	var b: Vector3 = to_via[0] if not to_via.is_empty() else spot.pos
	path.append(Vector3(b.x, 0, LANE_Z))
	path.append_array(to_via)
	path.append(spot.pos)
	st.path = path
	_pose(st, false)


func _set_at(st: Dictionary, spot: Dictionary) -> void:
	var n: Node3D = st.node
	n.visible = true
	n.position = spot.pos
	n.rotation.y = spot.yaw
	_pose(st, bool(spot.get("sit", false)))


func _pose(st: Dictionary, sit: bool) -> void:
	(st.stand as Node3D).visible = not sit
	(st.stand as Node3D).position.y = 0.0
	set_walk(st.stand, 0.0, 0.0)
	(st.sit as Node3D).visible = sit


func _update_people(delta: float, ppos: Vector3) -> void:
	for st in _people:
		var n: Node3D = st.node
		var want := _slot_for(st.data)
		if want != st.slot:
			# Игрок далеко — не тратим время на прогулку
			var near := ppos.distance_to(n.position) < 45.0
			if want != "home":
				near = near or ppos.distance_to(SPOTS[want].pos) < 45.0
			_place(st, want, not near)
		if st.slot == "home" and n.visible and ppos.distance_to(n.position) > 30.0:
			n.visible = false
		var path: Array = st.path
		if path.is_empty():
			continue
		# Уступает дорогу игроку
		if ppos.distance_to(n.position) < 1.6:
			continue
		var to: Vector3 = path[0] - n.position
		to.y = 0.0
		var step := WALK_SPEED * delta
		if to.length() <= step:
			n.position = path[0]
			path.pop_front()
			if path.is_empty():
				_set_at(st, SPOTS[st.slot])
			continue
		n.position += to.normalized() * step
		n.rotation.y = atan2(-to.x, -to.z)
		st["phase"] = float(st.get("phase", 0.0)) + step * 4.2
		(st.stand as Node3D).position.y = absf(sin(float(st.phase))) * 0.03
		set_walk(st.stand, st.phase, 1.0)


func _process(delta: float) -> void:
	_walk(delta)
	_update_letters()
	var p := GameManager.player as Node3D
	var ppos := p.global_position if p else Vector3(1e6, 0, 0)
	_update_people(delta, ppos)
	for c in _chickens:
		_chicken_step(c, delta, ppos)
	for d in _dogs:
		d.cool = maxf(d.cool - delta, 0.0)
		var dog: Node3D = d.node
		# Хвостом виляет, когда рядом человек
		var near := p != null and p.visible and dog.global_position.distance_to(ppos) < 9.0
		var mat := (dog.get_child(0) as MeshInstance3D).material_override as ShaderMaterial
		var w := move_toward(float(d.get("wag", 0.0)), 0.6 if near else 0.12, delta)
		d["wag"] = w
		mat.set_shader_parameter("wag", w)
		if p and p.visible and d.cool <= 0.0 and dog.global_position.distance_to(ppos) < 7.0:
			d.cool = _rng.randf_range(3.0, 6.0)
			SoundLibrary.play_at("bark", dog.global_position, 0.0, _rng.randf_range(0.9, 1.1))


## Почтальонка: вдоль улицы от пруда до съезда и обратно, у игрока — стоит.
func _walk(delta: float) -> void:
	# Уступает дорогу игроку и машине
	var p := GameManager.player as Node3D
	var mesh := _walker.get_child(0) as MeshInstance3D
	if p and p.visible and p.global_position.distance_to(_walker.position) < 2.5:
		set_walk(mesh, 0.0, 0.0)
		mesh.position.y = 0.0
		return
	for car in get_tree().get_nodes_in_group("vehicles"):
		if (car as Node3D).global_position.distance_to(_walker.position + Vector3(_walk_dir * 2.0, 0, 0)) < 3.5:
			set_walk(mesh, 0.0, 0.0)
			return
	_walker.position.x += _walk_dir * 1.2 * delta
	if _walker.position.x > -66.0:
		_walk_dir = -1.0
	elif _walker.position.x < -160.0:
		_walk_dir = 1.0
	_walker.rotation.y = -PI / 2.0 if _walk_dir > 0.0 else PI / 2.0
	# Шаг: ноги и руки, чуть покачивается
	_walker_phase += 1.2 * delta * 4.2
	mesh.position.y = absf(sin(_walker_phase)) * 0.03
	set_walk(mesh, _walker_phase, 1.0)


func _chicken_step(c: Dictionary, delta: float, ppos: Vector3) -> void:
	var node: Node3D = c.node
	if c.wait > 0.0:
		c.wait -= delta
		# Клюёт
		node.get_child(0).rotation.x = -0.5 if fmod(c.wait, 0.6) < 0.3 else 0.0
		return
	var to: Vector3 = c.target - node.position
	if to.length() < 0.1:
		c.wait = _rng.randf_range(1.0, 4.0)
		var home: Transform3D = c.xf
		c.target = home * Vector3(_rng.randf_range(-9.0, -3.5), 0, _rng.randf_range(6.0, 11.0))
		if ppos.distance_to(node.position) < 10.0 and _rng.randf() < 0.3:
			SoundLibrary.play_at("chicken", node.position, -6.0, _rng.randf_range(0.9, 1.2))
		return
	node.get_child(0).rotation.x = 0.0
	node.position += to.normalized() * minf(0.9 * delta, to.length())
	node.rotation.y = atan2(-to.x, -to.z)


# --- Внешний вид ------------------------------------------------------------

## Человек из коробок, носом в -Z. Сидящий — ниже и с согнутыми ногами.
func _person(shirt: Color, hat: Color, sit: bool, woman := false) -> Node3D:
	var root := Node3D.new()
	var b := MeshBuilder.new()
	b.ground_shade = false
	person_model(b, shirt, hat, sit, woman)
	root.add_child(b.build_mesh() if sit else walking_mesh(b))
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 1.4 if sit else 1.8
	cs.shape = shape
	cs.position.y = shape.height * 0.5
	body.add_child(cs)
	root.add_child(body)
	return root


## Человек носом в -Z: ботинки, брюки или юбка с фартуком, ремень, рубаха
## с воротником и пуговицами, рукава и кисти, шея, лицо (глаза, брови, нос,
## рот), уши, волосы; у женщин — косынка, у мужчин — кепка с козырьком.
## Сидящий — бёдра вперёд по лавке, руки на коленях.
static func person_model(b: MeshBuilder, shirt: Color, hat: Color, sit: bool, woman: bool) -> void:
	var skin := Color(0.86, 0.68, 0.56)
	var pants := Color(0.2, 0.2, 0.24)
	var shoe := Color(0.12, 0.1, 0.09)
	var hair := Color(0.35, 0.3, 0.26) if not woman else Color(0.55, 0.5, 0.45)
	var base := 0.85
	if sit:
		base = 0.5
		for x in [-0.19, 0.03]:
			b.box(Vector3(x, 0.42, -0.45), Vector3(x + 0.16, 0.58, 0.0), pants if not woman else shirt.darkened(0.25))
			b.box(Vector3(x + 0.01, 0.06, -0.5), Vector3(x + 0.15, 0.45, -0.36), pants if not woman else Color(0.75, 0.7, 0.62))
			b.box(Vector3(x, 0.0, -0.58), Vector3(x + 0.16, 0.08, -0.34), shoe)
	elif woman:
		# Юбка колоколом, фартук, ноги в чулках
		b.box(Vector3(-0.26, 0.35, -0.16), Vector3(0.26, 0.88, 0.16), shirt.darkened(0.25))
		b.box(Vector3(-0.2, 0.4, -0.17), Vector3(0.2, 0.85, -0.16), Color(0.92, 0.9, 0.84))
		for x in [-0.15, 0.04]:
			b.alpha = 0.9 if x < 0.0 else 0.8
			b.box(Vector3(x, 0.06, -0.05), Vector3(x + 0.11, 0.36, 0.06), Color(0.75, 0.7, 0.62))
			b.box(Vector3(x - 0.01, 0.0, -0.1), Vector3(x + 0.12, 0.07, 0.07), shoe)
		b.alpha = 1.0
	else:
		for x in [-0.19, 0.03]:
			b.alpha = 0.9 if x < 0.0 else 0.8
			b.box(Vector3(x, 0.07, -0.09), Vector3(x + 0.16, 0.85, 0.09), pants)
			b.box(Vector3(x - 0.005, 0.0, -0.15), Vector3(x + 0.165, 0.08, 0.1), shoe)
		b.alpha = 1.0
		b.box(Vector3(-0.23, base - 0.04, -0.13), Vector3(0.23, base + 0.02, 0.13), Color(0.25, 0.18, 0.12))
		b.box(Vector3(-0.03, base - 0.035, -0.135), Vector3(0.03, base + 0.015, -0.13), Color(0.75, 0.7, 0.5))
	# Туловище, воротник, пуговицы
	b.box(Vector3(-0.23, base, -0.13), Vector3(0.23, base + 0.6, 0.13), shirt)
	b.box(Vector3(-0.1, base + 0.55, -0.14), Vector3(0.1, base + 0.62, -0.1), shirt.lightened(0.2))
	if not woman:
		for i in 4:
			b.box(Vector3(-0.012, base + 0.12 + i * 0.12, -0.135), Vector3(0.012, base + 0.14 + i * 0.12, -0.13), Color(0.85, 0.85, 0.8))
	# Руки: плечо, рукав, кисть
	for side in [-1.0, 1.0]:
		var x0 := 0.23 if side > 0.0 else -0.33
		if sit:
			b.box(Vector3(x0, base + 0.3, -0.08), Vector3(x0 + 0.1, base + 0.58, 0.08), shirt)
			b.box(Vector3(x0, base + 0.22, -0.32), Vector3(x0 + 0.1, base + 0.32, -0.02), shirt)
			b.box(Vector3(x0 + 0.01, base + 0.2, -0.42), Vector3(x0 + 0.09, base + 0.3, -0.32), skin)
		else:
			b.alpha = 0.7 if side < 0.0 else 0.6
			b.box(Vector3(x0, base + 0.08, -0.07), Vector3(x0 + 0.1, base + 0.58, 0.07), shirt)
			b.box(Vector3(x0 + 0.005, base - 0.02, -0.06), Vector3(x0 + 0.095, base + 0.1, 0.06), skin)
			b.alpha = 1.0
	# Шея и голова
	b.box(Vector3(-0.05, base + 0.6, -0.05), Vector3(0.05, base + 0.66, 0.05), skin)
	var h := base + 0.66
	b.box(Vector3(-0.11, h, -0.12), Vector3(0.11, h + 0.26, 0.1), skin)
	for x in [-0.125, 0.11]:
		b.box(Vector3(x, h + 0.09, -0.02), Vector3(x + 0.015, h + 0.15, 0.03), skin.darkened(0.08))
	for x in [-0.065, 0.025]:
		b.box(Vector3(x, h + 0.13, -0.122), Vector3(x + 0.04, h + 0.155, -0.118), Color(0.95, 0.95, 0.95))
		b.box(Vector3(x + 0.012, h + 0.133, -0.125), Vector3(x + 0.028, h + 0.152, -0.121), Color(0.15, 0.2, 0.3))
		b.box(Vector3(x - 0.005, h + 0.17, -0.123), Vector3(x + 0.045, h + 0.18, -0.118), hair.darkened(0.3))
	b.box(Vector3(-0.018, h + 0.08, -0.15), Vector3(0.018, h + 0.14, -0.12), skin.darkened(0.05))
	b.box(Vector3(-0.04, h + 0.045, -0.122), Vector3(0.04, h + 0.058, -0.118), Color(0.6, 0.3, 0.28))
	if woman:
		# Косынка, завязанная под подбородком
		b.box(Vector3(-0.13, h + 0.12, -0.1), Vector3(0.13, h + 0.3, 0.12), hat)
		b.box(Vector3(-0.125, h + 0.02, -0.08), Vector3(-0.11, h + 0.2, 0.08), hat)
		b.box(Vector3(0.11, h + 0.02, -0.08), Vector3(0.125, h + 0.2, 0.08), hat)
		b.box(Vector3(-0.1, h + 0.25, -0.125), Vector3(0.1, h + 0.29, -0.1), hair)
	else:
		# Волосы из-под кепки, кепка с козырьком
		b.box(Vector3(-0.115, h + 0.14, 0.02), Vector3(0.115, h + 0.24, 0.105), hair)
		b.box(Vector3(-0.125, h + 0.22, -0.12), Vector3(0.125, h + 0.3, 0.11), hat)
		b.box(Vector3(-0.1, h + 0.22, -0.2), Vector3(0.1, h + 0.24, -0.12), hat.darkened(0.2))


# --- Ходьба: ноги и руки качает шейдер ---------------------------------------

const WALK_SHADER := """
shader_type spatial;

uniform float phase = 0.0;
uniform float amount = 0.0;

// Поворот точки p вокруг оси X, проходящей на высоте pivot_y
vec3 swing(vec3 p, float pivot_y, float a) {
	float dy = p.y - pivot_y;
	float c = cos(a);
	float s = sin(a);
	return vec3(p.x, pivot_y + dy * c - p.z * s, dy * s + p.z * c);
}

void vertex() {
	float tag = COLOR.a;
	float a = sin(phase) * 0.5 * amount;
	if (tag < 0.95 && tag > 0.85) {
		VERTEX = swing(VERTEX, 0.85, a);
	} else if (tag < 0.85 && tag > 0.75) {
		VERTEX = swing(VERTEX, 0.85, -a);
	} else if (tag < 0.75 && tag > 0.65) {
		VERTEX = swing(VERTEX, 1.4, -a * 0.8);
	} else if (tag < 0.65 && tag > 0.55) {
		VERTEX = swing(VERTEX, 1.4, a * 0.8);
	}
}

void fragment() {
	ALBEDO = COLOR.rgb * 1.05;
	ROUGHNESS = 0.9;
}
"""

static var _walk_shader: Shader

## Четвероногие: ноги по диагонали (0.9 и 0.8 в альфе), хвост (0.5) виляет
## вокруг вертикали у корня. hip — высота «плеч», откуда качаются ноги.
const ANIMAL_SHADER := """
shader_type spatial;

uniform float phase = 0.0;
uniform float amount = 0.0;
uniform float hip = 0.6;
uniform vec2 tail_root = vec2(0.5, -1.0);
uniform float wag = 0.0;
uniform float wag_speed = 3.0;

void vertex() {
	float tag = COLOR.a;
	float a = sin(phase) * 0.45 * amount;
	if (tag < 0.95 && tag > 0.85) {
		float dy = VERTEX.y - hip;
		VERTEX = vec3(VERTEX.x, hip + dy * cos(a), VERTEX.z + dy * sin(a));
	} else if (tag < 0.85 && tag > 0.75) {
		float dy = VERTEX.y - hip;
		VERTEX = vec3(VERTEX.x, hip + dy * cos(-a), VERTEX.z + dy * sin(-a));
	} else if (tag < 0.55 && tag > 0.45) {
		float w = sin(TIME * wag_speed) * wag;
		float dx = VERTEX.x;
		float dz = VERTEX.z - tail_root.y;
		VERTEX.x = dx * cos(w) - dz * sin(w);
		VERTEX.z = tail_root.y + dx * sin(w) + dz * cos(w);
	}
}

void fragment() {
	ALBEDO = COLOR.rgb * 1.05;
	ROUGHNESS = 0.9;
}
"""

static var _animal_shader: Shader


static func animal_mesh(b: MeshBuilder, hip: float, tail_y: float, tail_z: float, wag_speed := 3.0) -> MeshInstance3D:
	if _animal_shader == null:
		_animal_shader = Shader.new()
		_animal_shader.code = ANIMAL_SHADER
	var mi := b.build_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = _animal_shader
	mat.set_shader_parameter("hip", hip)
	mat.set_shader_parameter("tail_root", Vector2(tail_y, tail_z))
	mat.set_shader_parameter("wag_speed", wag_speed)
	mi.material_override = mat
	return mi


## Меш человека с шейдером ходьбы — у каждого свой материал, свой шаг.
static func walking_mesh(b: MeshBuilder) -> MeshInstance3D:
	if _walk_shader == null:
		_walk_shader = Shader.new()
		_walk_shader.code = WALK_SHADER
	var mi := b.build_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = _walk_shader
	mi.material_override = mat
	return mi


## Шаг: фаза растёт с пройденным путём, amount 0 — стоит, 1 — идёт.
static func set_walk(mi: MeshInstance3D, phase: float, amount: float) -> void:
	var mat := mi.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("phase", phase)
		mat.set_shader_parameter("amount", amount)


func _chicken_mesh() -> Node3D:
	var root := Node3D.new()
	var b := MeshBuilder.new()
	b.ground_shade = false
	var white := Color(0.95, 0.93, 0.88)
	b.box(Vector3(-0.1, 0.15, -0.14), Vector3(0.1, 0.33, 0.14), white)
	b.box(Vector3(-0.05, 0.3, -0.2), Vector3(0.05, 0.42, -0.1), white)
	b.box(Vector3(-0.02, 0.42, -0.18), Vector3(0.02, 0.47, -0.1), Color(0.85, 0.1, 0.1))
	b.box(Vector3(-0.015, 0.34, -0.25), Vector3(0.015, 0.37, -0.2), Color(0.95, 0.7, 0.2))
	b.box(Vector3(-0.07, 0.25, 0.1), Vector3(0.07, 0.4, 0.18), white.darkened(0.1))
	for x in [-0.05, 0.03]:
		b.box(Vector3(x, 0.0, -0.01), Vector3(x + 0.02, 0.15, 0.01), Color(0.95, 0.7, 0.2))
	var mesh := b.build_mesh()
	root.add_child(mesh)
	return root


func _dog_mesh() -> Node3D:
	var root := Node3D.new()
	var b := MeshBuilder.new()
	b.ground_shade = false
	var fur := Color(0.45, 0.32, 0.2)
	b.box(Vector3(-0.15, 0.25, -0.35), Vector3(0.15, 0.5, 0.3), fur)
	b.box(Vector3(-0.12, 0.45, -0.55), Vector3(0.12, 0.7, -0.3), fur)
	b.box(Vector3(-0.07, 0.48, -0.68), Vector3(0.07, 0.6, -0.55), fur.darkened(0.2))
	b.box(Vector3(-0.12, 0.7, -0.45), Vector3(-0.06, 0.8, -0.38), fur.darkened(0.3))
	b.box(Vector3(0.06, 0.7, -0.45), Vector3(0.12, 0.8, -0.38), fur.darkened(0.3))
	for x in [-0.13, 0.07]:
		for z in [-0.3, 0.2]:
			# По диагонали: левая передняя с правой задней
			b.alpha = 0.9 if (x < 0.0) == (z < 0.0) else 0.8
			b.box(Vector3(x, 0.0, z), Vector3(x + 0.06, 0.26, z + 0.07), fur.darkened(0.1))
	b.alpha = 0.5
	b.box(Vector3(-0.02, 0.45, 0.3), Vector3(0.02, 0.5, 0.5), fur)
	b.alpha = 1.0
	root.add_child(animal_mesh(b, 0.26, 0.47, 0.3, 11.0))
	return root


# --- Письма почтальонки ------------------------------------------------------

func _letter_pending(i: int) -> bool:
	return int(QuestManager.items.get("letters", 0)) > 0 and not QuestManager.items.has("gate_%d" % i)


func _update_letters() -> void:
	for i in _letter_gates.size():
		var pending := _letter_pending(i)
		(_letter_gates[i][1] as Label3D).visible = pending


func _deliver_letter(i: int) -> void:
	if not _letter_pending(i):
		return
	QuestManager.items["gate_%d" % i] = 1
	QuestManager.items["letters"] = int(QuestManager.items["letters"]) - 1
	if QuestManager.items["letters"] <= 0:
		QuestManager.items.erase("letters")
		for k in 3:
			QuestManager.items.erase("gate_%d" % k)
	SoundLibrary.play("click")
	GameManager.notify("Письмо в ящике")
	QuestManager.event("letter")
