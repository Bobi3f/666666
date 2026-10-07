class_name Princess
extends Node3D
## Принцесса — девушка игрока: розовое платье, золотая корона на голове.
## Днём (8:00–21:00) гуляет по улице Каменки у его дома с двумя собачками —
## белой болонкой Снежкой и рыжим спаниелем Рыжиком — и полосатым котом
## Барсиком: питомцы бегут следом. E рядом — её окошко (PrincessPanel):
## позвать гулять (идёт рядом со всей свитой) или отпустить, купить брелочек.
##
## Настроение (mood 0–100): добрая (от 50) — ласковая, скидка на брелоки,
## гуляет охотно, над головой «добрая». Злая — каждый день без встречи она
## обижается сильнее: грубит, брелоки дороже, гулять не идёт. Помириться —
## купить брелочек, гулять с ней, приходить почаще.

const Villagers := preload("res://scripts/world/villagers.gd")
## Прогулка: точки по улице Каменки (туда-обратно), стоянки у точек.
const ROUTE := [Vector3(-152, 0, -41.5), Vector3(-118, 0, -41.5), Vector3(-96, 0, -41.5), Vector3(-72, 0, -41.5), Vector3(-96, 0, -41.5), Vector3(-130, 0, -41.5)]
const SPEED := 1.1
const SCALE := 1.0
## Что говорит, когда зовёшь гулять и когда отпускаешь.
const LINES := [
	"Привет, мой рыцарь! Корону не трогай — она для настоящей принцессы.",
	"Пойдём погуляем? Снежка с Рыжиком уже хвостами виляют.",
	"Ты сегодня опять на работе пропадал? Я соскучилась!",
	"Барсик опять спал на твоём мопеде. Он тебя тоже любит.",
	"Купишь мне розовую «Волгу»? Будем возить собачек на речку.",
	"Снежка, дай лапу! Видишь — она тебя уже слушается.",
	"С тобой хоть на край района. Только не по грязи — у меня туфли.",
]
const BYE := [
	"Всё, мы домой — собачек кормить. Заходи вечером!",
	"Спасибо за прогулку, милый. Не скучай!",
	"Барсик устал, пора домой. Целую!",
]
const ANGRY := [
	"Явился! Где ты пропадал? Я тебя ждала-ждала!",
	"Не подходи. Корону не трогай. И собачек не трогай!",
	"Гулять? С тобой? Сначала заслужи. Брелочек хотя бы купи.",
	"Барсик, фас! Ну ладно, Барсик не умеет. Но я злая!",
]
## Брелочки: id, название, цена в гривнах.
const KEYCHAINS := [
	["crown", "брелок-коронка", 120], ["snezhka", "собачка Снежка", 90], ["barsik", "кот Барсик", 90],
	["heart", "сердечко", 60], ["star", "звёздочка", 70], ["volga", "розовая «Волга»", 200],
]
## Гуляет рядом с игроком (позвал), иначе — своя прогулка по улице.
var following := false
var hug_day := -1
var mood := 70.0
var seen_day := 1
var keychains: Array = []
var _mood_label: Label3D

var girl: MeshInstance3D
var pets: Array[Node3D] = []
var _target := 0
var _wait := 2.0
var _phase := 0.0
var _line := 0
var _zone: InteractZone
## Где каждый питомец относительно девочки (слева, справа, позади).
const PET_OFFSETS := [Vector3(-0.9, 0, 0.9), Vector3(0.9, 0, 1.1), Vector3(0.2, 0, 1.8)]


func _ready() -> void:
	name = "Princess"
	add_to_group("persist")
	var b := MeshBuilder.new()
	b.ground_shade = false
	PersonModel.girl(b, false, Color(0.95, 0.5, 0.72), Color(0.88, 0.68, 0.28))
	girl = Villagers.walking_mesh(b)
	girl.scale = Vector3.ONE * SCALE
	girl.position = ROUTE[0]
	add_child(girl)
	var top := girl.mesh.get_aabb().end.y
	var crown := _crown()
	crown.position = Vector3(0, top - 0.05, 0)
	girl.add_child(crown)
	_mood_label = Label3D.new()
	_mood_label.font_size = 48
	_mood_label.pixel_size = 0.005
	_mood_label.outline_size = 10
	_mood_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mood_label.position = Vector3(0, top + 0.3, 0)
	_mood_label.visibility_range_end = 25.0
	girl.add_child(_mood_label)
	_show_mood()
	var furs := [Color(0.96, 0.95, 0.92), Color(0.78, 0.45, 0.2)]
	for i in 2:
		var db := MeshBuilder.new()
		db.ground_shade = false
		AnimalModel.dog(db, furs[i])
		var dog := Villagers.animal_mesh(db, 0.38, 0.47, 0.32, 11.0)
		dog.scale = Vector3.ONE * (0.75 if i == 0 else 0.95)
		pets.append(dog)
	var cb := MeshBuilder.new()
	cb.ground_shade = false
	cat_model(cb, Color(0.55, 0.52, 0.48))
	pets.append(Villagers.animal_mesh(cb, 0.2, 0.26, 0.2, 2.5))
	for i in pets.size():
		var p: Node3D = pets[i]
		p.position = ROUTE[0] + PET_OFFSETS[i]
		add_child(p)
	_zone = InteractZone.create("", Vector3(2.6, 2.0, 2.6))
	_zone.prompt_fn = func() -> String:
		return "E — Принцесса (%s): поговорить, гулять, брелочки" % ("добрая" if kind() else "злая")
	_zone.activated.connect(talk)
	girl.add_child(_zone)
	_zone.scale = Vector3.ONE / SCALE


## Золотая корона: обруч, пять зубцов с шариками, камешки — красные и синие.
func _crown() -> MeshInstance3D:
	var b := MeshBuilder.new()
	b.ground_shade = false
	var gold := Color(1.0, 0.8, 0.2)
	var r := 0.085
	for k in 10:
		var a := TAU * k / 10.0
		var c := Vector3(cos(a) * r, 0.025, sin(a) * r)
		b.box_rot(c, Vector3(0.06, 0.05, 0.015), -a + PI / 2.0, gold)
	for k in 5:
		var a := TAU * k / 5.0
		var c := Vector3(cos(a) * r, 0.05, sin(a) * r)
		PersonModel.limb(b, c, c + Vector3(0, 0.07, 0), Vector2(0.018, 0.018), Vector2(0.004, 0.004), gold)
		PersonModel.ball(b, c + Vector3(0, 0.075, 0), Vector3(0.012, 0.012, 0.012), gold, 2, 6)
		var gem := Vector3(cos(a + 0.6) * (r + 0.008), 0.025, sin(a + 0.6) * (r + 0.008))
		PersonModel.ball(b, gem, Vector3(0.013, 0.013, 0.008), Color(0.9, 0.1, 0.2) if k % 2 == 0 else Color(0.15, 0.35, 0.95), 2, 6)
	return b.build_mesh()


## Кот: тонкое туловище, круглая голова с острыми ушами, длинный хвост
## трубой; полосы потемнее. Смотрит в −Z, как собаки.
static func cat_model(b: MeshBuilder, fur: Color) -> void:
	var dark := fur.darkened(0.35)
	PersonModel.limb(b, Vector3(0, 0.24, 0.17), Vector3(0, 0.25, -0.15), Vector2(0.075, 0.075), Vector2(0.08, 0.085), fur, true)
	for k in 3:
		var z := 0.1 - k * 0.11
		b.box(Vector3(-0.07, 0.3, z - 0.015), Vector3(0.07, 0.33, z + 0.015), dark)
	var h := Vector3(0, 0.36, -0.22)
	PersonModel.ball(b, h, Vector3(0.075, 0.07, 0.07), fur, 4, 8)
	for s in [-1.0, 1.0]:
		PersonModel.limb(b, h + Vector3(s * 0.045, 0.05, 0.0), h + Vector3(s * 0.05, 0.11, 0.01), Vector2(0.025, 0.012), Vector2(0.004, 0.004), fur, true)
		b.box(h + Vector3(s * 0.03 - 0.012, 0.01, -0.07), h + Vector3(s * 0.03 + 0.012, 0.03, -0.066), Color(0.55, 0.8, 0.3))
	PersonModel.ball(b, h + Vector3(0, -0.015, -0.07), Vector3(0.012, 0.01, 0.008), Color(0.85, 0.5, 0.55), 2, 6)
	for p in [Vector2(-0.045, -0.13), Vector2(0.045, -0.13), Vector2(-0.045, 0.14), Vector2(0.045, 0.14)]:
		b.alpha = 0.9 if (p.x < 0.0) == (p.y < 0.0) else 0.8
		PersonModel.limb(b, Vector3(p.x, 0.22, p.y), Vector3(p.x, 0.02, p.y), Vector2(0.022, 0.024), Vector2(0.018, 0.018), fur)
	b.alpha = 0.5
	PersonModel.limb(b, Vector3(0, 0.26, 0.2), Vector3(0, 0.5, 0.3), Vector2(0.018, 0.018), Vector2(0.012, 0.012), fur)
	b.alpha = 1.0


## E: повернуться к игроку и открыть окошко Принцессы.
func talk() -> void:
	var pl := GameManager.player as Node3D
	if pl:
		var to := pl.global_position - girl.global_position
		girl.rotation.y = atan2(-to.x, -to.z)
	catch_up()
	var panel := get_tree().get_first_node_in_group("princess_panel") as PrincessPanel
	if panel:
		panel.open(self)
	else:
		walk()


func kind() -> bool:
	return mood >= 50.0


## Сколько дней не виделись — на столько и обиделась (−15 за день).
func catch_up() -> void:
	var missed := TimeManager.day - seen_day - 1
	if missed > 0:
		set_mood(mood - 15.0 * missed)
	seen_day = TimeManager.day


func set_mood(v: float) -> void:
	mood = clampf(v, 0.0, 100.0)
	_show_mood()


func _show_mood() -> void:
	if _mood_label == null:
		return
	_mood_label.text = "добрая" if kind() else "злая!"
	_mood_label.modulate = Color(1.0, 0.55, 0.75) if kind() else Color(0.95, 0.2, 0.15)


## Что она говорит сейчас — по настроению.
func say() -> String:
	_line += 1
	return (LINES if kind() else ANGRY)[_line % (LINES if kind() else ANGRY).size()]


## Цена брелока i: доброй — скидка, злой — дороже.
func price(i: int) -> int:
	var base: int = KEYCHAINS[i][2]
	return int(round(base * (0.8 if kind() else 1.5)))


## Купить брелок i: в коллекцию, Принцесса добреет. true — купил.
func buy(i: int) -> bool:
	var id: String = KEYCHAINS[i][0]
	if keychains.has(id) or not GameManager.spend(price(i)):
		return false
	keychains.append(id)
	set_mood(mood + 20.0)
	SoundLibrary.play("cash", -4.0)
	QuestManager.event("keychain")
	GameManager.notify("Купил у Принцессы брелок: %s. В коллекции %d из %d" % [KEYCHAINS[i][1], keychains.size(), KEYCHAINS.size()])
	return true


## Позвать гулять / отпустить. Злая гулять не идёт. Что ответила.
func walk() -> String:
	if not following and not kind():
		set_mood(mood + 2.0)
		var no := "Не пойду! Сначала помирись со мной."
		GameManager.notify("Принцесса: «%s»" % no)
		return no
	following = not following
	var said := ""
	if following:
		set_mood(mood + 5.0)
		said = LINES[_line % LINES.size()]
		GameManager.notify("Принцесса: «%s»" % said)
		# Обняла — раз в день прибавляет сил
		if hug_day != TimeManager.day:
			hug_day = TimeManager.day
			NeedsManager.rest(10.0)
			GameManager.notify("Принцесса обняла тебя — сил прибавилось")
	else:
		said = BYE[_line % BYE.size()]
		GameManager.notify("Принцесса: «%s»" % said)
		_target = _nearest_route()
	_line += 1
	_wait = 1.0
	SoundLibrary.play("bark", -6.0, 1.3)
	QuestManager.event("princess")
	return said


func _nearest_route() -> int:
	var best := 0
	for i in ROUTE.size():
		if girl.position.distance_to(ROUTE[i]) < girl.position.distance_to(ROUTE[best]):
			best = i
	return best


static func out_now() -> bool:
	var h := TimeManager.hour()
	return h >= 8.0 and h < 21.0


func _process(delta: float) -> void:
	var out := out_now()
	visible = out
	_zone.process_mode = Node.PROCESS_MODE_INHERIT if out else Node.PROCESS_MODE_DISABLED
	if not out:
		following = false
		return
	var pl := GameManager.player as Node3D
	# Далеко от игрока — не считаем шаги и лапы
	if pl and pl.global_position.distance_to(girl.global_position) > 120.0:
		return
	var moving := false
	if following and pl:
		# Рядом с игроком, чуть сбоку и позади; уехал далеко — идёт домой
		var goal := pl.global_position + Basis(Vector3.UP, pl.rotation.y) * Vector3(1.0, 0, 1.2)
		goal.y = girl.position.y
		var to := goal - girl.position
		to.y = 0.0
		if pl.global_position.distance_to(girl.global_position) > 60.0:
			following = false
			_target = _nearest_route()
			GameManager.notify("Принцесса не угналась за тобой и пошла домой")
		elif to.length() > 0.6:
			var step := minf(SPEED * (3.5 if to.length() > 4.0 else 1.3) * delta, to.length())
			girl.position += to.normalized() * step
			girl.rotation.y = atan2(-to.x, -to.z)
			moving = true
			_phase += step * 4.2 / SCALE
	elif _wait > 0.0:
		_wait -= delta
	else:
		var goal: Vector3 = ROUTE[_target]
		var to := goal - girl.position
		to.y = 0.0
		var step := SPEED * delta
		if to.length() <= step:
			girl.position = goal
			_target = (_target + 1) % ROUTE.size()
			_wait = randf_range(3.0, 7.0)
		else:
			girl.position += to.normalized() * step
			girl.rotation.y = atan2(-to.x, -to.z)
			moving = true
			_phase += step * 4.2 / SCALE
	Villagers.set_walk(girl, _phase, 1.0 if moving else 0.0)
	# Питомцы бегут к своим местам возле девочки, с отставанием
	var rot := Basis(Vector3.UP, girl.rotation.y)
	for i in pets.size():
		var p: Node3D = pets[i]
		var want: Vector3 = girl.position + rot * PET_OFFSETS[i]
		var to := want - p.position
		to.y = 0.0
		var d := to.length()
		if d > 0.15:
			var sp := minf(d * 2.2, 3.5) * delta
			p.position += to.normalized() * minf(sp, d)
			p.rotation.y = atan2(-to.x, -to.z)
		elif moving:
			p.rotation.y = girl.rotation.y


func save_state() -> Dictionary:
	return {"line": _line, "hug": hug_day, "mood": mood, "seen": seen_day, "keys": keychains}


func load_state(d: Dictionary) -> void:
	_line = int(d.get("line", 0))
	hug_day = int(d.get("hug", -1))
	mood = float(d.get("mood", 70.0))
	seen_day = int(d.get("seen", TimeManager.day))
	var k: Variant = d.get("keys", [])
	keychains = (k as Array).duplicate() if k is Array else []
	_show_mood()
