extends Node3D
## Жители Каменки, куры во дворах и собаки у будок.
##
## С жителями можно поговорить (E) — каждый раз следующая фраза, в них
## подсказки: где заработать, где заправиться, как добраться до города.
## Один житель ходит по улице туда-обратно. Собаки лают, если подойти
## к чужому двору, куры бродят и кудахчут.

## Дворы как в world.gd: [x, z, поворот, есть ли будка]. Двор игрока (-125, -56)
## перестраивается, поэтому своей собаки у игрока здесь нет.
const DOG_YARDS := [
	[-150.0, -56.0, 0.0], [-75.0, -56.0, 0.0],
	[-125.0, -24.0, PI], [-100.0, -24.0, PI], [-75.0, -24.0, PI],
]
const CHICKEN_YARDS := [[-150.0, -56.0, 0.0], [-125.0, -24.0, PI], [-75.0, -24.0, PI], [-100.0, -24.0, PI]]

const PEOPLE := [
	{"name": "Баба Галя", "pos": Vector3(-102.0, 0, -36.45), "yaw": 0.0, "sit": true,
		"shirt": Color(0.45, 0.25, 0.35), "hat": Color(0.85, 0.3, 0.3),
		"lines": ["Здравствуй, сынок! В сельмаге хлеб дешевле, чем в городском ларьке.",
			"В колхозе «Заря» сено грузят — платят четыреста за смену. Только не в дождь.",
			"Дом бы тебе новый... Прораб у твоей калитки за двенадцать тысяч возьмётся.",
			"Ночью фонари горят, а раньше тут темень была — хоть глаз выколи."]},
	{"name": "Дед Михалыч", "pos": Vector3(-51.5, 0, -19.0), "yaw": PI / 2.0, "sit": false,
		"shirt": Color(0.3, 0.35, 0.3), "hat": Color(0.25, 0.25, 0.28),
		"lines": ["Жигули твои без бензина не поедут. Заправка у трассы, напротив деревни.",
			"В дождь по грунтовке не гоняй — засядешь по самые пороги.",
			"Со склада в городе хлеб к нам возят. Есть машина — бери заказ, пятьсот платят.",
			"Скрежещешь коробкой? Сцепление выжимай, а то на СТО всё и оставишь."]},
	{"name": "Бригадир Петрович", "pos": Vector3(-39.5, 0, -40.5), "yaw": PI, "sit": false,
		"shirt": Color(0.25, 0.3, 0.45), "hat": Color(0.2, 0.2, 0.22),
		"lines": ["Работа есть — с семи до семи. Жми E у ворот сарая.",
			"Вилы в руки — и три часа на сене. Устанешь, зато четыреста в кармане.",
			"Выспись сначала. Сонный на скирде — это не работник."]},
	{"name": "Тётя Люда", "pos": Vector3(-68.0, 0, -8.0), "yaw": PI, "sit": false,
		"shirt": Color(0.55, 0.45, 0.25), "hat": Color(0.9, 0.9, 0.85),
		"lines": ["Автобус в город ходит с шести утра до десяти вечера. Пятнадцать гривен.",
			"В городе у склада остановка — оттуда обратно так же уедешь.",
			"Жду вот, в поликлинику надо..."]},
	{"name": "Механик Васёк", "pos": Vector3(-82.0, 0, 12.3), "yaw": 0.0, "sit": false,
		"shirt": Color(0.2, 0.25, 0.4), "hat": Color(0.8, 0.4, 0.1),
		"lines": ["Загоняй машину в бокс — посмотрю. Двадцать пять гривен за процент износа.",
			"Заглохнет сама на ходу — значит, изношена. Не тяни, приезжай.",
			"Удары, скрежет, глохнешь — всё это машину убивает."]},
]

var _people: Array[Dictionary] = []
var _walker: Node3D
var _walk_dir := 1.0
var _chickens: Array[Dictionary] = []
var _dogs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 55
	for d in PEOPLE:
		var n := _person(d.shirt, d.hat, d.sit)
		n.position = d.pos
		n.rotation.y = d.yaw
		add_child(n)
		_talk_zone(n, d)
	# Почтальонка ходит по улице
	var walker_data := {"name": "Почтальонка Оля", "shirt": Color(0.2, 0.35, 0.65), "hat": Color(0.2, 0.35, 0.65),
		"lines": ["Писем вам нет, только квитанция за свет.", "Вся Каменка на мне — от пруда до трассы, два раза в день.",
			"Говорят, в город на машине быстрее, чем автобусом. Если бензин есть."]}
	_walker = _person(walker_data.shirt, walker_data.hat, false)
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
	for y in DOG_YARDS:
		var xf := Transform3D(Basis(Vector3.UP, y[2]), Vector3(y[0], 0, y[1]))
		var dog := _dog_mesh()
		dog.position = xf * Vector3(4.6, 0, 9.2)
		dog.rotation.y = y[2] + PI
		add_child(dog)
		_dogs.append({"node": dog, "cool": 0.0})


func _talk_zone(n: Node3D, d: Dictionary) -> void:
	var zone := InteractZone.create("E — поговорить: %s" % d.name, Vector3(2.2, 2.0, 2.2))
	zone.position = Vector3(0, 0, -0.9)
	n.add_child(zone)
	var state := {"i": 0}
	zone.activated.connect(func() -> void:
		var lines: Array = d.lines
		GameManager.notify("%s: «%s»" % [d.name, lines[state.i % lines.size()]])
		state.i += 1)


func _process(delta: float) -> void:
	_walk(delta)
	var p := GameManager.player as Node3D
	var ppos := p.global_position if p else Vector3(1e6, 0, 0)
	for c in _chickens:
		_chicken_step(c, delta, ppos)
	for d in _dogs:
		d.cool = maxf(d.cool - delta, 0.0)
		var dog: Node3D = d.node
		if p and p.visible and d.cool <= 0.0 and dog.global_position.distance_to(ppos) < 7.0:
			d.cool = _rng.randf_range(3.0, 6.0)
			SoundLibrary.play_at("bark", dog.global_position, 0.0, _rng.randf_range(0.9, 1.1))


## Почтальонка: вдоль улицы от пруда до съезда и обратно, у игрока — стоит.
func _walk(delta: float) -> void:
	# Уступает дорогу игроку и машине
	var p := GameManager.player as Node3D
	if p and p.visible and p.global_position.distance_to(_walker.position) < 2.5:
		return
	for car in get_tree().get_nodes_in_group("vehicles"):
		if (car as Node3D).global_position.distance_to(_walker.position + Vector3(_walk_dir * 2.0, 0, 0)) < 3.5:
			return
	_walker.position.x += _walk_dir * 1.2 * delta
	if _walker.position.x > -66.0:
		_walk_dir = -1.0
	elif _walker.position.x < -160.0:
		_walk_dir = 1.0
	_walker.rotation.y = -PI / 2.0 if _walk_dir > 0.0 else PI / 2.0
	# Покачивание при ходьбе
	_walker.get_child(0).position.y = absf(sin(Time.get_ticks_msec() * 0.008)) * 0.04


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
func _person(shirt: Color, hat: Color, sit: bool) -> Node3D:
	var root := Node3D.new()
	var b := MeshBuilder.new()
	b.ground_shade = false
	var skin := Color(0.85, 0.68, 0.55)
	var pants := Color(0.2, 0.2, 0.24)
	var base := 0.0
	if sit:
		# Бёдра вперёд по лавке, голени вниз
		b.box(Vector3(-0.2, 0.42, -0.45), Vector3(0.2, 0.58, 0.0), pants)
		b.box(Vector3(-0.2, 0.0, -0.5), Vector3(0.2, 0.45, -0.35), pants)
		base = 0.5
	else:
		b.box(Vector3(-0.2, 0.0, -0.1), Vector3(-0.03, 0.85, 0.1), pants)
		b.box(Vector3(0.03, 0.0, -0.1), Vector3(0.2, 0.85, 0.1), pants)
		base = 0.85
	b.box(Vector3(-0.24, base, -0.13), Vector3(0.24, base + 0.62, 0.13), shirt)
	for x in [-0.33, 0.24]:
		b.box(Vector3(x, base + 0.05, -0.08), Vector3(x + 0.09, base + 0.6, 0.08), shirt)
	b.box(Vector3(-0.11, base + 0.62, -0.11), Vector3(0.11, base + 0.88, 0.11), skin)
	b.box(Vector3(-0.13, base + 0.85, -0.13), Vector3(0.13, base + 0.95, 0.13), hat)
	b.box(Vector3(-0.06, base + 0.74, -0.115), Vector3(-0.03, base + 0.77, -0.11), Color(0.1, 0.1, 0.1))
	b.box(Vector3(0.03, base + 0.74, -0.115), Vector3(0.06, base + 0.77, -0.11), Color(0.1, 0.1, 0.1))
	root.add_child(b.build_mesh())
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
			b.box(Vector3(x, 0.0, z), Vector3(x + 0.06, 0.26, z + 0.07), fur.darkened(0.1))
	b.box(Vector3(-0.02, 0.45, 0.3), Vector3(0.02, 0.5, 0.5), fur)
	root.add_child(b.build_mesh())
	return root
