extends Node3D
const Villagers := preload("res://scripts/world/villagers.gd")
## Своё дело: ларёк у склада и СТО у трассы можно выкупить, автопарк —
## открыть, когда своих машин три. Каждое утро они приносят доход (считает
## Daily). У каждого — табличка «ПРОДАЁТСЯ», после покупки — «ТВОЁ».
## Конкурент Жора — ларёк в Озерцово: перекупить его или разорить акциями.

## [id, где табличка и место покупки, поворот таблички, в городе ли (тогда
## точка — в координатах города)]
const SPOTS := [
	["kiosk", Vector3(27.6, 0, 10.4), -PI / 2.0, true],
	["sto", Vector3(-92.6, 0, 12.2), PI / 2.0, false],
	["fleet", Vector3(271.0, 0, 169.0), -PI / 2.0, true],
]
## Ларёк Жоры — у магазина в Озерцово (село 0).
const RIVAL := Vector3(-409.0, 0, -308.0)

var _signs := {}
var _rival: Node3D
var _rival_label: Label3D
var _rival_zone: InteractZone


func _ready() -> void:
	for s in SPOTS:
		var id: String = s[0]
		var pos: Vector3 = Town.w(s[1]) if s[3] else s[1]
		var b := MeshBuilder.new()
		# Столбик с щитом
		b.box(pos + Vector3(-0.05, 0, -0.05), pos + Vector3(0.05, 1.6, 0.05), Color(0.35, 0.3, 0.25))
		var board := Basis(Vector3.UP, float(s[2]))
		b.xf = Transform3D(board, pos)
		b.box(Vector3(-0.7, 1.5, -0.04), Vector3(0.7, 2.2, 0.04), Color(0.95, 0.93, 0.85))
		b.xf = Transform3D.IDENTITY
		add_child(b.build_mesh())
		var label := Label3D.new()
		label.font_size = 64
		label.pixel_size = 0.005
		label.outline_size = 8
		label.transform = Transform3D(board, pos + board * Vector3(0, 1.85, 0.06))
		add_child(label)
		var label_back := label.duplicate() as Label3D
		label_back.transform = Transform3D(board * Basis(Vector3.UP, PI), pos + board * Vector3(0, 1.85, -0.06))
		add_child(label_back)
		_signs[id] = [label, label_back]
		var zone := InteractZone.create("", Vector3(2.4, 2.2, 2.4))
		zone.position = pos
		zone.prompt_fn = func() -> String: return _prompt(id)
		zone.activated.connect(func() -> void:
			if id == "kiosk" and Daily.owns("kiosk") and Daily.rival == Daily.Rival.ACTIVE:
				Daily.dump()
			elif Daily.buy(id):
				_update())
		add_child(zone)
	_build_rival()
	Daily.changed.connect(_update)
	_update()
	_build_bank()


## Ларёк Жоры у магазина в Озерцово: синяя будка с окошком, вывеска;
## пока конкурент торгует — его можно перекупить.
func _build_rival() -> void:
	_rival = Node3D.new()
	_rival.position = RIVAL
	add_child(_rival)
	var b := MeshBuilder.new()
	b.box(Vector3(-1.8, 0, -1.4), Vector3(1.8, 2.6, 1.4), Color(0.7, 0.55, 0.2), true)
	b.box(Vector3(-2.0, 2.6, -1.6), Vector3(2.0, 2.75, 1.6), Color(0.9, 0.9, 0.9))
	b.box(Vector3(-1.2, 1.0, 1.4), Vector3(1.2, 2.0, 1.42), Color(0.85, 0.9, 0.95))
	b.box(Vector3(-1.3, 0.9, 1.4), Vector3(1.3, 0.97, 1.65), Color(0.7, 0.7, 0.7))
	b.box(Vector3(-1.5, 2.15, 1.42), Vector3(1.5, 2.55, 1.45), Color(0.2, 0.45, 0.25))
	_rival.add_child(b.build_mesh())
	_rival.add_child(b.build_body())
	_rival_label = Label3D.new()
	_rival_label.font_size = 64
	_rival_label.pixel_size = 0.0045
	_rival_label.outline_size = 8
	_rival_label.position = Vector3(0, 2.35, 1.47)
	_rival.add_child(_rival_label)
	_rival_zone = InteractZone.create("", Vector3(3.0, 2.2, 2.0))
	_rival_zone.name = "RivalZone"
	_rival_zone.position = Vector3(0, 0, 2.4)
	_rival_zone.prompt_fn = func() -> String:
		return "Жора: «Ларёк продам за %d — и торгуй сам». E — перекупить (+%d грн в день, и твой ларёк снова с полным доходом)" % [Daily.RIVAL_BUYOUT, int(Daily.BUSINESSES.kiosk2.income)]
	_rival_zone.activated.connect(func() -> void: Daily.buy_rival())
	_rival.add_child(_rival_zone)
	var pb := MeshBuilder.new()
	pb.ground_shade = false
	Villagers.person_model(pb, Color(0.55, 0.15, 0.15), Color(0.15, 0.15, 0.17), false, false)
	var who := pb.build_mesh()
	who.position = Vector3(1.1, 0, 0.6)
	who.rotation.y = PI
	_rival.add_child(who)


## Банк на трассе у восточной улицы (здание — town_east.gd): окошки вклада
## у входа, вклад под 10% годовых. Точка у двери, в координатах города.
const BANK := Vector3(201.0, 0, 10.0)


func _build_bank() -> void:
	var c := Town.w(BANK)
	var put := InteractZone.create("", Vector3(1.8, 2.2, 1.4))
	put.position = c + Vector3(-1.3, 0, 0)
	put.prompt_fn = func() -> String:
		if GameManager.money <= 300:
			return "Банк: вклад %d грн, 10%% годовых. Положить нечего — 300 грн оставь на жизнь" % Daily.deposit
		return "E — положить на вклад %d грн (10%% годовых, проценты каждое утро; 300 грн оставить на жизнь)" % (GameManager.money - 300)
	put.activated.connect(func() -> void:
		var sum := Daily.put_money()
		if sum > 0:
			SoundLibrary.play("cash")
			GameManager.notify("Положил %d грн. На вкладе: %d грн — 10%% годовых, проценты каждое утро" % [sum, Daily.deposit]))
	add_child(put)
	var take := InteractZone.create("", Vector3(1.8, 2.2, 1.4))
	take.position = c + Vector3(1.3, 0, 0)
	take.prompt_fn = func() -> String:
		return "E — снять вклад: %d грн" % Daily.deposit if Daily.deposit > 0 else "Банк: вклада нет"
	take.activated.connect(func() -> void:
		var sum := Daily.take_money()
		if sum > 0:
			SoundLibrary.play("cash")
			GameManager.notify("Снял со вклада %d грн" % sum))
	add_child(take)


func _prompt(id: String) -> String:
	var b: Dictionary = Daily.BUSINESSES[id]
	if id == "kiosk" and Daily.owns(id) and Daily.rival == Daily.Rival.ACTIVE:
		if Daily.dump_days.has(TimeManager.day):
			return "Акция сегодня уже идёт: день %d из %d. Жора теряет покупателей" % [Daily.dump_days.size(), Daily.DUMP_DAYS]
		return "E — акция «дешевле, чем у Жоры»: %d грн, день %d из %d (доход сейчас +%d в день)" % [Daily.DUMP_COST, Daily.dump_days.size() + 1, Daily.DUMP_DAYS, Daily.income(id)]
	if Daily.owns(id):
		if id == "fleet" and Daily.income(id) == 0:
			return "Твой автопарк простаивает: нужно %d своих машины, сейчас %d" % [int(b.cars), Daily.own_cars()]
		return "Твоё дело — %s: +%d грн каждое утро" % [b.title, Daily.income(id)]
	if id == "fleet":
		var n := Daily.own_cars()
		if n < int(b.cars):
			return "Автопарк: нужно %d своих машины (сейчас %d) — потом +%d грн в день" % [int(b.cars), n, b.income]
		return "E — открыть автопарк из своих машин: +%d грн каждое утро" % b.income
	if GameManager.money < int(b.price):
		return "Продаётся %s: %d грн, доход %d грн в день — пока не хватает денег" % [b.title, b.price, b.income]
	return "E — выкупить %s за %d грн: +%d грн каждое утро" % [b.title, b.price, b.income]


func _update() -> void:
	for id in _signs:
		for l in _signs[id]:
			var label := l as Label3D
			if Daily.owns(id):
				label.text = "ТВОЁ"
				label.modulate = Color(0.25, 0.6, 0.25)
			elif id == "fleet":
				label.text = "АВТОПАРК\n3 машины"
				label.modulate = Color(0.15, 0.3, 0.6)
			else:
				label.text = "ПРОДАЁТСЯ\n%d грн" % int(Daily.BUSINESSES[id].price)
				label.modulate = Color(0.75, 0.15, 0.1)
	if _rival:
		_rival.visible = Daily.rival != Daily.Rival.NONE
		_rival_label.text = {Daily.Rival.ACTIVE: "ЛАРЁК ЖОРЫ", Daily.Rival.BOUGHT: "ТВОЙ ЛАРЁК", Daily.Rival.RUINED: "ЗАКРЫТО"}.get(Daily.rival, "")
		_rival_zone.monitoring = Daily.rival == Daily.Rival.ACTIVE
