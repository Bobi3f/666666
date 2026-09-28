extends Node3D
## Воскресная ярмарка на площади Мира: каждый седьмой день с 8:00 до 16:00.
##
## Три прилавка: рыбу принимают вдвое дороже сельмага, пирожки дешевле,
## чем в магазине, и лотерея — пять билетов в день, выигрыш до 2 000 грн.
## В другие дни прилавков нет.

const OPEN_H := 8.0
const CLOSE_H := 16.0
const FISH_PRICE := 120
const PIES_PRICE := 90
const PIES := 3
const TICKET := 50
const TICKETS_PER_DAY := 5

## [id, вывеска, центр прилавка, цвет навеса]
const STALLS := [
	["fish", "РЫБА", Vector3(106.8, 0, 16.5), Color(0.2, 0.45, 0.75)],
	["pies", "ПИРОЖКИ", Vector3(106.8, 0, 21.0), Color(0.85, 0.35, 0.2)],
	["lottery", "ЛОТЕРЕЯ", Vector3(106.8, 0, 25.5), Color(0.55, 0.3, 0.7)],
]

var _stalls: Node3D
var _tickets_day := 0
var _tickets := 0
var _announced_day := 0
var _rng := RandomNumberGenerator.new()
var _was_open := true


static func is_fair_day(day: int) -> bool:
	return day % 7 == 0


static func is_open() -> bool:
	var h := TimeManager.hour()
	return is_fair_day(TimeManager.day) and h >= OPEN_H and h < CLOSE_H


func _ready() -> void:
	_rng.randomize()
	_stalls = Node3D.new()
	add_child(_stalls)
	var b := MeshBuilder.new()
	var people := MeshBuilder.new()
	people.ground_shade = false
	for s in STALLS:
		var p: Vector3 = s[2]
		var awning: Color = s[3]
		var wood := Color(0.55, 0.4, 0.25)
		# Прилавок лицом к площади (+X), столбы и полосатый навес
		b.box(p + Vector3(0.6, 0, -1.4), p + Vector3(1.2, 0.95, 1.4), wood, true)
		b.box(p + Vector3(0.55, 0.95, -1.5), p + Vector3(1.3, 1.02, 1.5), wood.lightened(0.15))
		for z in [-1.45, 1.35]:
			for x in [-0.9, 1.2]:
				b.box(p + Vector3(x, 0, z), p + Vector3(x + 0.1, 2.3, z + 0.1), wood.darkened(0.3))
		for k in 6:
			var c := awning if k % 2 == 0 else Color(0.95, 0.93, 0.88)
			b.box(p + Vector3(-1.0, 2.3, -1.55 + k * 0.52), p + Vector3(1.6, 2.4, -1.03 + k * 0.52), c)
		_goods(b, s[0], p)
		# Продавец за прилавком
		people.xf = Transform3D(Basis(Vector3.UP, -PI / 2.0), p + Vector3(-0.2, 0, 0))
		preload("res://scripts/world/villagers.gd").person_model(people, awning.darkened(0.2), Color(0.9, 0.9, 0.85), false, s[0] != "lottery")
		var sign := Label3D.new()
		sign.text = s[1]
		sign.font_size = 72
		sign.pixel_size = 0.006
		sign.outline_size = 10
		sign.modulate = Color(1.0, 0.95, 0.8)
		sign.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), p + Vector3(1.62, 2.1, 0))
		_stalls.add_child(sign)
		var id: String = s[0]
		var zone := InteractZone.create("", Vector3(2.0, 2.2, 3.0))
		zone.position = p + Vector3(2.2, 0, 0)
		zone.prompt_fn = func() -> String: return _prompt(id)
		zone.activated.connect(func() -> void: _use(id))
		_stalls.add_child(zone)
	# Флажки гирляндой над прилавками
	for k in 24:
		var z := 14.5 + k * 0.55
		var col: Color = [Color(0.9, 0.2, 0.2), Color(0.95, 0.8, 0.2), Color(0.2, 0.5, 0.85)][k % 3]
		b.tri(Vector3(105.9, 2.9, z), Vector3(105.9, 2.9, z + 0.4), Vector3(105.9, 2.5, z + 0.2), col)
	b.box(Vector3(105.87, 2.9, 14.4), Vector3(105.93, 2.93, 27.8), Color(0.3, 0.3, 0.3))
	_stalls.add_child(b.build_mesh())
	_stalls.add_child(people.build_mesh())
	_update()


func _goods(b: MeshBuilder, id: String, p: Vector3) -> void:
	match id:
		"fish":
			for k in 5:
				b.box(p + Vector3(0.7, 1.02, -1.2 + k * 0.5), p + Vector3(1.15, 1.1, -0.95 + k * 0.5), Color(0.6, 0.65, 0.7))
		"pies":
			for k in 8:
				b.box(p + Vector3(0.7 + (k % 2) * 0.22, 1.02, -1.2 + (k / 2) * 0.6), p + Vector3(0.88 + (k % 2) * 0.22, 1.1, -1.0 + (k / 2) * 0.6), Color(0.85, 0.6, 0.3))
		"lottery":
			b.box(p + Vector3(0.7, 1.02, -0.4), p + Vector3(1.1, 1.5, 0.4), Color(0.9, 0.85, 0.3))
			b.box(p + Vector3(0.69, 1.3, -0.3), p + Vector3(0.7, 1.45, 0.3), Color(0.8, 0.1, 0.1))


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	var open := is_open()
	if open != _was_open:
		_was_open = open
		_stalls.visible = open
		for c in _stalls.get_children():
			if c is InteractZone:
				c.set_deferred("monitoring", open)
	# Утром в воскресенье — напоминание
	var day := TimeManager.day
	if is_fair_day(day) and _announced_day != day and TimeManager.hour() >= 7.0 and TimeManager.hour() < CLOSE_H and GameManager.in_game:
		_announced_day = day
		GameManager.notify("Сегодня воскресенье — ярмарка на площади Мира до 16:00: рыба дороже, пирожки, лотерея")


func _prompt(id: String) -> String:
	match id:
		"fish":
			if NeedsManager.fish <= 0:
				return "Ярмарка: рыбу берут по %d грн — поймай на пруду" % FISH_PRICE
			return "E — продать рыбу: %d шт. по %d грн" % [NeedsManager.fish, FISH_PRICE]
		"pies":
			return "E — пирожки с капустой: %d шт. за %d грн" % [PIES, PIES_PRICE]
		"lottery":
			if _tickets_left() <= 0:
				return "Лотерея: билеты на сегодня кончились"
			return "E — лотерейный билет за %d грн (осталось %d)" % [TICKET, _tickets_left()]
	return ""


func _tickets_left() -> int:
	if _tickets_day != TimeManager.day:
		return TICKETS_PER_DAY
	return TICKETS_PER_DAY - _tickets


func _use(id: String) -> void:
	if not is_open():
		return
	match id:
		"fish":
			var n := NeedsManager.fish
			if n <= 0:
				GameManager.notify("Рыбы с собой нет")
				return
			NeedsManager.fish = 0
			GameManager.add_money(n * FISH_PRICE)
			SoundLibrary.play("cash")
			QuestManager.event("fair_sold", n)
			GameManager.notify("Продал %d рыб на ярмарке: +%d грн" % [n, n * FISH_PRICE])
		"pies":
			if not GameManager.spend(PIES_PRICE):
				GameManager.notify("Не хватает денег")
				return
			NeedsManager.snacks += PIES
			SoundLibrary.play("cash")
			GameManager.notify("Горячие пирожки: +%d еды в запас" % PIES)
		"lottery":
			if _tickets_left() <= 0:
				return
			if not GameManager.spend(TICKET):
				GameManager.notify("Не хватает денег")
				return
			if _tickets_day != TimeManager.day:
				_tickets_day = TimeManager.day
				_tickets = 0
			_tickets += 1
			var r := _rng.randf()
			var win := 2000 if r < 0.03 else (500 if r < 0.15 else (100 if r < 0.4 else 0))
			if win > 0:
				GameManager.add_money(win)
				SoundLibrary.play("quest")
				GameManager.notify("Билет выиграл %d грн!" % win)
			else:
				SoundLibrary.play("click")
				GameManager.notify("Без выигрыша. Повезёт в другой раз")
