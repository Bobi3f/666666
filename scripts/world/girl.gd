class_name Girl
extends Node3D
## Оля — девушка из Каменки, с которой можно подружиться.
##
## Живёт через улицу от игрока. Днём то у своей калитки, то в сельмаге,
## по пятницам и субботам вечером — у сельского клуба, ночью спит.
## По E — разговор: поболтать, подарить цветы или конфеты, позвать гулять.
## Позвал — идёт следом, садится к тебе в машину или на мотоцикл (видно на
## пассажирском месте), выходит вместе с тобой. Катание и танцы с ней на
## дискотеке, подарки и разговоры растят симпатию: знакомая → подруга →
## твоя девушка. Девушка печёт пирожки. Поздно вечером её надо проводить
## домой — бросишь, обидится.
## Дальше — кольцо, предложение и свадьба в сельсовете: жена живёт в доме
## игрока, встречает во дворе и кормит обедом.

const Villagers := preload("res://scripts/world/villagers.gd")

const NAME := "Оля"
const HOME := Vector3(-100.0, 0, -35.2)
## Жена — во дворе игрока, у дорожки к крыльцу (будка — правее).
const WIFE_HOME := Vector3(-127.0, 0, -47.5)
const SHOP := Vector3(-52.5, 0, -26.5)
const CLUB := Vector3(-21.5, 0, -10.5)
## Улица, по которой она ходит между местами.
const STREET_Z := -38.6
const FRIEND := 30
const LOVE := 70
## Подарки: id → [что, цена, симпатия]
const GIFTS := {
	"flowers": ["цветы", 60, 8],
	"candy": ["конфеты «Красный мак»", 100, 12],
}
const TALK_GAIN := 4
const RIDE_GAIN := 2  # за каждую минуту катания
const RIDE_MAX := 12  # за день
const DANCE_GAIN := 10
const WALK_HOME_GAIN := 5
const LEFT_ALONE := 6

enum State {LIFE, FOLLOW, RIDE}

var state := State.LIFE
## Симпатия 0..100
var rel := 0
var talk_day := 0
var gift_day := 0
var pie_day := 0
var dance_day := 0
var ride_day := 0
var ride_today := 0
var met := false
var engaged := false
var married := false

var _walk: MeshInstance3D
var _sit: MeshInstance3D
var _zone: InteractZone
var _path: Array[Vector3] = []
var _spot := ""
var _phase := 0.0
var _ride_t := 0.0
var _scared := 0.0
var _vehicle: Vehicle
var _cond := 100.0
var _late_warned := false
var _say_cool := 0.0
var _rng := RandomNumberGenerator.new()
var panel: GirlPanel
var doll: Node3D


func _ready() -> void:
	add_to_group("persist")
	add_to_group("girl")
	_rng.randomize()
	# Сама Оля — отдельный узел: в машине он переезжает в кузов, а этот
	# остаётся на месте (по его пути ищется сохранение)
	doll = Node3D.new()
	doll.name = "Olya"
	add_child(doll)
	var b := MeshBuilder.new()
	b.ground_shade = false
	model(b, false)
	_walk = Villagers.walking_mesh(b)
	doll.add_child(_walk)
	var s := MeshBuilder.new()
	s.ground_shade = false
	model(s, true)
	_sit = s.build_mesh()
	_sit.visible = false
	doll.add_child(_sit)
	_zone = InteractZone.create("", Vector3(1.8, 2.0, 1.8))
	_zone.position.y = 0.0
	_zone.prompt_fn = _prompt
	_zone.activated.connect(open_talk)
	doll.add_child(_zone)
	panel = GirlPanel.new()
	panel.girl = self
	add_child(panel)
	QuestManager.fired.connect(_on_event)
	doll.global_position = home_pos()
	_spot = ""


## Девушка носом в -Z: туфли, гольфы, платье в горошек, кофточка, руки,
## лицо с ресницами и румянцем, длинные волосы с хвостом и бантом.
## Альфа — метки для шага (как у жителей): ноги 0.9/0.8, руки 0.7/0.6.
static func model(b: MeshBuilder, sit: bool) -> void:
	var skin := Color(0.92, 0.74, 0.62)
	var dress := Color(0.85, 0.2, 0.3)
	var dots := Color(0.98, 0.95, 0.9)
	var hair := Color(0.62, 0.42, 0.22)
	var socks := Color(0.97, 0.97, 0.95)
	var shoe := Color(0.45, 0.12, 0.12)
	var base := 0.85
	if sit:
		base = 0.5
		for x in [-0.17, 0.03]:
			b.box(Vector3(x, 0.42, -0.42), Vector3(x + 0.14, 0.54, 0.0), skin)
			b.box(Vector3(x + 0.01, 0.06, -0.47), Vector3(x + 0.13, 0.45, -0.35), socks)
			b.box(Vector3(x, 0.0, -0.54), Vector3(x + 0.14, 0.07, -0.33), shoe)
		# Подол на коленях
		b.box(Vector3(-0.22, 0.48, -0.3), Vector3(0.22, 0.6, 0.12), dress)
	else:
		for x in [-0.15, 0.03]:
			b.alpha = 0.9 if x < 0.0 else 0.8
			b.box(Vector3(x, 0.3, -0.05), Vector3(x + 0.12, 0.6, 0.06), skin)
			b.box(Vector3(x - 0.005, 0.06, -0.055), Vector3(x + 0.125, 0.32, 0.065), socks)
			b.box(Vector3(x - 0.01, 0.0, -0.11), Vector3(x + 0.13, 0.07, 0.07), shoe)
		b.alpha = 1.0
		# Юбка-колокол чуть выше колен
		b.box(Vector3(-0.26, 0.55, -0.17), Vector3(0.26, 0.86, 0.17), dress)
		b.box(Vector3(-0.27, 0.55, -0.18), Vector3(0.27, 0.59, 0.18), dress.darkened(0.2))
	# Лиф платья, пояс, горошек
	b.box(Vector3(-0.2, base, -0.12), Vector3(0.2, base + 0.56, 0.12), dress)
	b.box(Vector3(-0.21, base + 0.02, -0.125), Vector3(0.21, base + 0.07, 0.125), Color(0.2, 0.2, 0.25))
	for p in [Vector2(-0.12, 0.2), Vector2(0.06, 0.32), Vector2(-0.04, 0.44), Vector2(0.1, 0.14), Vector2(-0.14, 0.38)]:
		b.box(Vector3(p.x, base + p.y, -0.125), Vector3(p.x + 0.04, base + p.y + 0.04, -0.12), dots)
	b.box(Vector3(-0.09, base + 0.5, -0.13), Vector3(0.09, base + 0.57, -0.1), dots)
	# Руки в коротких рукавах
	for side in [-1.0, 1.0]:
		var x0 := 0.2 if side > 0.0 else -0.29
		if sit:
			b.box(Vector3(x0, base + 0.36, -0.07), Vector3(x0 + 0.09, base + 0.55, 0.07), dress)
			b.box(Vector3(x0, base + 0.2, -0.3), Vector3(x0 + 0.09, base + 0.36, -0.02), skin)
		else:
			b.alpha = 0.7 if side < 0.0 else 0.6
			b.box(Vector3(x0, base + 0.36, -0.07), Vector3(x0 + 0.09, base + 0.55, 0.07), dress)
			b.box(Vector3(x0 + 0.01, base + 0.0, -0.05), Vector3(x0 + 0.08, base + 0.37, 0.05), skin)
			b.alpha = 1.0
	# Шея и голова
	b.box(Vector3(-0.045, base + 0.56, -0.045), Vector3(0.045, base + 0.63, 0.045), skin)
	var h := base + 0.63
	b.box(Vector3(-0.1, h, -0.11), Vector3(0.1, h + 0.25, 0.1), skin)
	for x in [-0.06, 0.02]:
		b.box(Vector3(x, h + 0.12, -0.112), Vector3(x + 0.04, h + 0.15, -0.108), Color(0.97, 0.97, 0.97))
		b.box(Vector3(x + 0.012, h + 0.122, -0.115), Vector3(x + 0.028, h + 0.148, -0.111), Color(0.2, 0.45, 0.35))
		b.box(Vector3(x - 0.005, h + 0.15, -0.114), Vector3(x + 0.045, h + 0.158, -0.11), Color(0.1, 0.08, 0.08))
		# Румянец
		b.box(Vector3(x - 0.01, h + 0.07, -0.113), Vector3(x + 0.04, h + 0.1, -0.109), Color(0.95, 0.6, 0.58))
	b.box(Vector3(-0.015, h + 0.08, -0.13), Vector3(0.015, h + 0.13, -0.11), skin.darkened(0.04))
	b.box(Vector3(-0.035, h + 0.045, -0.113), Vector3(0.035, h + 0.06, -0.108), Color(0.85, 0.25, 0.3))
	# Волосы: шапка, чёлка, пряди по бокам до плеч, хвост с бантом
	b.box(Vector3(-0.115, h + 0.17, -0.12), Vector3(0.115, h + 0.29, 0.115), hair)
	b.box(Vector3(-0.1, h + 0.19, -0.125), Vector3(0.1, h + 0.25, -0.11), hair)
	b.box(Vector3(-0.125, h - 0.12, -0.08), Vector3(-0.1, h + 0.22, 0.11), hair)
	b.box(Vector3(0.1, h - 0.12, -0.08), Vector3(0.125, h + 0.22, 0.11), hair)
	b.box(Vector3(-0.1, h - 0.05, 0.09), Vector3(0.1, h + 0.27, 0.12), hair)
	b.box(Vector3(-0.05, h - 0.3, 0.11), Vector3(0.05, h + 0.2, 0.17), hair)
	b.box(Vector3(-0.09, h + 0.17, 0.12), Vector3(0.09, h + 0.24, 0.16), Color(0.95, 0.95, 1.0))


## Где она живёт: у себя через улицу, а после свадьбы — у тебя.
func home_pos() -> Vector3:
	return WIFE_HOME if married else HOME


## Рядом ли она с игроком — гуляет с ним или едет в его машине.
func with_player(dist := 25.0) -> bool:
	var p := _player()
	return state != State.LIFE and p != null and doll.global_position.distance_to(p.global_position) < dist


func level() -> String:
	if married:
		return "жена"
	if engaged:
		return "невеста"
	if rel >= LOVE:
		return "твоя девушка"
	if rel >= FRIEND:
		return "подруга"
	return "знакомая"


func _prompt() -> String:
	if state == State.RIDE:
		return ""
	if TimeManager.hour() < 7.0 and state == State.LIFE:
		return ""
	return "E — поговорить с %s" % ("Олей" if met else "девушкой")


func open_talk() -> void:
	if state == State.RIDE:
		return
	met = true
	SoundLibrary.play("click", -4.0)
	panel.open()


## Добавить симпатии (и сказать, если вырос уровень).
func like(n: int) -> void:
	var before := level()
	rel = clampi(rel + n, 0, 100)
	if level() != before and n > 0:
		QuestManager.event("girl_" + ("love" if rel >= LOVE else "friend"))
		GameManager.notify("Оля теперь — %s!" % level())


## Поболтать: раз в день симпатия растёт. Девушка угощает пирожками.
func talk() -> String:
	var d: int = TimeManager.day
	var lines: Array
	if married:
		lines = ["Как хорошо, что мы теперь вместе!", "Я на огороде полила, не переживай.", "Не задерживайся сегодня, ладно?"]
	elif engaged:
		lines = ["Мама уже платье примеряла — говорит, красивое!", "Скорее бы свадьба!", "Когда в сельсовет пойдём?"]
	elif rel >= LOVE:
		lines = ["Я по тебе соскучилась!", "Ты у меня самый лучший.", "Поедем вечером кататься? Только не гони!"]
	elif rel >= FRIEND:
		lines = ["С тобой весело! Покатаешь ещё?", "В пятницу в клубе дискотека — пойдём?", "Мама спрашивала, кто это меня подвозил…"]
	else:
		lines = ["Привет! Я Оля, живу через дорогу.", "Говорят, ты машину купил? Покатаешь?", "Скучно в Каменке… Хоть бы на дискотеку кто позвал."]
	var t: String = lines[_rng.randi() % lines.size()]
	if talk_day != d:
		talk_day = d
		like(TALK_GAIN)
		QuestManager.event("girl_talk")
	if rel >= LOVE and pie_day != d:
		pie_day = d
		NeedsManager.snacks += 2
		NeedsManager.changed.emit()
		t += " Держи пирожки — сама пекла! (+2 еды в запас)"
		if married:
			NeedsManager.eat(50.0)
			t += " И садись обедать — борщ сварила!"
	return t


## Предложение: нужно кольцо и чтобы она была твоей девушкой.
func propose() -> String:
	if engaged or married:
		return "Я уже сказала «да»!"
	if not Progress.has_item("ring"):
		return "Ты что-то хотел сказать?.. (сначала купи кольцо — рынок в городе)"
	if rel < LOVE:
		return "Ой… давай не будем торопиться. Узнаем друг друга получше."
	engaged = true
	like(10)
	SoundLibrary.play("quest")
	QuestManager.event("proposal")
	return "Да! Да, конечно да! Какое кольцо красивое… Пойдём в сельсовет — пусть распишут!"


## Свадьба в сельсовете: она становится женой и переезжает к тебе.
func wed() -> void:
	if married or not engaged:
		return
	married = true
	rel = 100
	SoundLibrary.play("quest")
	QuestManager.event("wedding")
	GameManager.notify("Свадьба! Вся Каменка гуляет, гости надарили денег. Оля теперь твоя жена и живёт у тебя")


## Подарок раз в день. Возвращает, что она сказала.
func gift(id: String) -> String:
	var g: Array = GIFTS[id]
	if gift_day == TimeManager.day:
		return "Ты уже дарил сегодня! Спасибо, не надо больше."
	if not GameManager.spend(g[1]):
		return "Не хватает денег на %s (%d грн)" % [g[0], g[1]]
	gift_day = TimeManager.day
	SoundLibrary.play("cash")
	like(g[2])
	QuestManager.event("girl_gift")
	return "Ой, %s! Мне?! Спасибо!" % g[0]


func invite() -> String:
	var h := TimeManager.hour()
	# Своей девушке мама разрешает гулять подольше — до «Метелицы» успеть
	if h >= (23.0 if rel >= LOVE else 22.0) or h < 7.0:
		return "Поздно уже, мама не пустит. Давай завтра!"
	state = State.FOLLOW
	_path.clear()
	_late_warned = false
	return "Пойдём! Только недалеко… или покатаешь?" if rel < FRIEND else "Пойдём! Куда сегодня?"


## Отпустить домой. near_home — проводил до калитки.
func send_home(near_home := false) -> void:
	if state == State.RIDE:
		_get_out()
	state = State.LIFE
	if near_home:
		like(WALK_HOME_GAIN)
		GameManager.notify("Оля: «Спасибо, что проводил! До завтра!»")
	# Пусть сама дойдёт куда надо по распорядку
	_spot = "?"


func _on_event(n: String, _a: float) -> void:
	# Танцевал на дискотеке, а Оля рядом — танцует с тобой
	if n == "dance" and state == State.FOLLOW:
		var night: int = TimeManager.day - (1 if TimeManager.hour() < 4.0 else 0)
		if dance_day != night:
			dance_day = night
			like(DANCE_GAIN)
			GameManager.notify("Ты танцевал с Олей! Она в восторге")
			QuestManager.event("girl_dance")


func _player() -> Node3D:
	return GameManager.player as Node3D


func _process(delta: float) -> void:
	_say_cool -= delta
	match state:
		State.LIFE:
			_life(delta)
		State.FOLLOW:
			_follow(delta)
		State.RIDE:
			_ride(delta)


## Где ей быть по распорядку.
func _wanted_spot() -> String:
	var h := TimeManager.hour()
	if h < 7.0 or h >= 23.0:
		return "home"
	if h >= 9.0 and h < 12.0:
		return "shop"
	if h >= 20.0 and TimeManager.weekday() in ["пт", "сб"]:
		return "club"
	return "gate"


func _spot_pos(s: String) -> Vector3:
	match s:
		"shop":
			return SHOP
		"club":
			return CLUB
	return home_pos()


func _life(delta: float) -> void:
	var want := _wanted_spot()
	doll.visible = want != "home" or _path.size() > 0
	if want != _spot:
		var target := _spot_pos(want)
		var p := _player()
		# Только появилась или игрок далеко — просто переносим, вблизи идёт
		# по улице (если идти далеко)
		var first := _spot == ""
		_spot = want
		if first or p == null or p.global_position.distance_to(doll.global_position) > 60.0:
			doll.global_position = target
			_path.clear()
		else:
			_path = [target]
			if doll.global_position.distance_to(target) > 6.0:
				_path = [Vector3(doll.global_position.x, 0, STREET_Z), Vector3(target.x, 0, STREET_Z), target]
	if _path.is_empty():
		Villagers.set_walk(_walk, _phase, 0.0)
		# Стоит и смотрит на игрока, если он рядом
		var p := _player()
		if p and p.global_position.distance_to(doll.global_position) < 8.0:
			_face(p.global_position, delta)
		else:
			# Иначе — лицом к улице (у тебя во дворе улица с другой стороны)
			var street := PI if married and _spot != "shop" and _spot != "club" else 0.0
			doll.rotation.y = lerp_angle(doll.rotation.y, street, minf(delta * 2.0, 1.0))
		return
	_step_to(_path[0], 1.3, delta)
	if Vector2(doll.global_position.x - _path[0].x, doll.global_position.z - _path[0].z).length() < 0.3:
		_path.pop_front()


func _step_to(t: Vector3, speed: float, delta: float) -> void:
	var to := Vector3(t.x - doll.global_position.x, 0, t.z - doll.global_position.z)
	var d := to.length()
	if d < 0.01:
		return
	var move := minf(speed * delta, d)
	doll.global_position += to / d * move
	doll.global_position.y = t.y
	_phase += move * 3.2
	Villagers.set_walk(_walk, _phase, 1.0)
	doll.rotation.y = lerp_angle(doll.rotation.y, atan2(-to.x, -to.z), minf(delta * 8.0, 1.0))


func _face(p: Vector3, delta: float) -> void:
	var to := p - doll.global_position
	doll.rotation.y = lerp_angle(doll.rotation.y, atan2(-to.x, -to.z), minf(delta * 4.0, 1.0))


func _follow(delta: float) -> void:
	doll.visible = true
	_check_late(delta)
	if state != State.FOLLOW:
		return
	var v := GameManager.vehicle as Vehicle
	if v and v.driver:
		if v.global_position.distance_to(doll.global_position) < 15.0:
			_board(v)
		elif _say_cool <= 0.0:
			_say_cool = 30.0
			GameManager.notify("Оля: «Эй, меня подожди!» — подъедь к ней поближе")
		return
	var p := _player()
	if p == null:
		return
	var to := p.global_position - doll.global_position
	to.y = 0.0
	var d := to.length()
	if d > 40.0:
		# Отстала далеко — догоняет
		doll.global_position = p.global_position - to.normalized() * 2.0
		doll.global_position.y = p.global_position.y
		return
	if d > 2.2:
		var speed := 1.6 if d < 5.0 else 5.0
		_step_to(p.global_position - to / d * 1.6, speed, delta)
		doll.global_position.y = p.global_position.y
	else:
		Villagers.set_walk(_walk, _phase, 0.0)
		_face(p.global_position, delta)


## Поздно — просит проводить; бросишь до часу ночи — обидится и уйдёт.
func _check_late(_delta: float) -> void:
	var h := TimeManager.hour()
	var p := _player()
	# Довёз или довёл до калитки поздно вечером — спасибо
	if p and (h >= 22.5 or h < 6.0):
		var home_d := Vector2(doll.global_position.x - home_pos().x, doll.global_position.z - home_pos().z).length()
		if (state == State.FOLLOW and home_d < 8.0) or (state == State.RIDE and home_d < 14.0 and _vehicle.speed_kmh() < 3.0):
			send_home(true)
			return
	if (h >= 22.5 or h < 6.0) and not _late_warned:
		_late_warned = true
		GameManager.notify("Оля: «Ой, поздно уже! Проводишь меня домой?»")
	if h >= 1.0 and h < 6.0:
		if state == State.RIDE:
			_get_out()
		state = State.LIFE
		like(-LEFT_ALONE)
		GameManager.notify("Оля обиделась, что её не проводили, и ушла домой сама")
		doll.global_position = home_pos()
		_spot = "home"


## Место пассажира: справа от водителя, на мотоцикле — за ним.
func seat_of(v: Vehicle) -> Vector3:
	var s: Vector3 = v.spec.seat
	if v.spec.two_wheels:
		return Vector3(0, s.y - 1.27, s.z + 0.48)
	return Vector3(-s.x, s.y - 1.32, s.z)


func can_ride(v: Vehicle) -> bool:
	return v.kind != "tractor" and not v.school


func _board(v: Vehicle) -> void:
	if not can_ride(v):
		if _say_cool <= 0.0:
			_say_cool = 30.0
			GameManager.notify("Оля: «В трактор вдвоём не влезть!»")
		return
	state = State.RIDE
	_vehicle = v
	_cond = v.condition
	_ride_t = 0.0
	_scared = 0.0
	_zone.monitoring = false
	_walk.visible = false
	_sit.visible = true
	var body: Node3D = v._body
	doll.reparent(body, false)
	doll.position = seat_of(v)
	doll.rotation = Vector3.ZERO
	GameManager.notify("Оля села %s" % ("сзади" if v.spec.two_wheels else "рядом"))
	QuestManager.event("girl_ride")


func _get_out() -> void:
	var v := _vehicle
	_vehicle = null
	_sit.visible = false
	_walk.visible = true
	_zone.monitoring = true
	var at := doll.global_position
	if v:
		var ex: Vector3 = v.spec.exit
		at = v.global_transform * Vector3(-ex.x, ex.y, ex.z) - Vector3(0, 0.2, 0)
	doll.reparent(self, false)
	doll.global_position = at
	doll.rotation = Vector3.ZERO
	state = State.FOLLOW


func _ride(delta: float) -> void:
	var v := _vehicle
	if v == null or not is_instance_valid(v):
		state = State.FOLLOW
		return
	_check_late(delta)
	if state != State.RIDE:
		return
	# Водитель вышел — выходит и она
	if v.driver == null:
		_get_out()
		return
	var kmh := v.speed_kmh()
	if v.condition < _cond - 4.0:
		like(-3)
		GameManager.notify("Оля: «Ай! Ты что, аккуратнее!»")
	_cond = v.condition
	if kmh > 110.0:
		_scared += delta
		if _scared > 4.0 and _say_cool <= 0.0:
			_say_cool = 25.0
			GameManager.notify("Оля: «Страшно! Потише, пожалуйста!»")
		return
	_scared = 0.0
	if kmh > 15.0:
		_ride_t += delta
		if _ride_t >= 60.0:
			_ride_t = 0.0
			var d: int = TimeManager.day
			if ride_day != d:
				ride_day = d
				ride_today = 0
			if ride_today < RIDE_MAX:
				ride_today += RIDE_GAIN
				like(RIDE_GAIN)
				if _say_cool <= 0.0:
					_say_cool = 40.0
					var lines := ["Как здорово кататься!", "Ветер в лицо — красота!", "А куда мы едем?", "Включи музыку погромче!"]
					GameManager.notify("Оля: «%s»" % lines[_rng.randi() % lines.size()])


func save_state() -> Dictionary:
	return {"rel": rel, "talk": talk_day, "gift": gift_day, "pie": pie_day, "dance": dance_day,
		"ride_day": ride_day, "ride": ride_today, "met": met, "engaged": engaged, "married": married}


func load_state(d: Dictionary) -> void:
	if state == State.RIDE:
		_get_out()
	state = State.LIFE
	_path.clear()
	_spot = ""
	rel = clampi(int(d.get("rel", 0)), 0, 100)
	talk_day = int(d.get("talk", 0))
	gift_day = int(d.get("gift", 0))
	pie_day = int(d.get("pie", 0))
	dance_day = int(d.get("dance", 0))
	ride_day = int(d.get("ride_day", 0))
	ride_today = int(d.get("ride", 0))
	met = bool(d.get("met", false))
	engaged = bool(d.get("engaged", false))
	married = bool(d.get("married", false))
