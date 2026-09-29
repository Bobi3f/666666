extends Node3D
## Своё дело: ларёк у склада и СТО у трассы можно выкупить. Каждое утро
## они приносят доход (считает Daily). У каждого — табличка «ПРОДАЁТСЯ»,
## после покупки — «ТВОЁ».

## [id, где табличка и место покупки, поворот таблички]
const SPOTS := [
	["kiosk", Vector3(27.6, 0, 10.4), -PI / 2.0],
	["sto", Vector3(-92.6, 0, 12.2), PI / 2.0],
]

var _signs := {}


func _ready() -> void:
	for s in SPOTS:
		var id: String = s[0]
		var pos: Vector3 = s[1]
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
			if Daily.buy(id):
				_update())
		add_child(zone)
	Daily.changed.connect(_update)
	_update()
	_build_bank()


## Сберкасса на площади Мира: будка с окошком, вклад под 1% в день.
const BANK := Vector3(137.8, 0, 21.0)


func _build_bank() -> void:
	var c := BANK
	var b := MeshBuilder.new()
	b.box(c + Vector3(-1.2, 0, -1.6), c + Vector3(1.2, 2.6, 1.6), Color(0.85, 0.87, 0.9), true)
	b.box(c + Vector3(-1.21, 2.0, -1.61), c + Vector3(1.21, 2.6, 1.61), Color(0.15, 0.45, 0.3))
	b.box(c + Vector3(-1.4, 2.6, -1.8), c + Vector3(1.4, 2.72, 1.8), Color(0.3, 0.3, 0.32))
	# Окошко и прилавок, дверь
	b.box(c + Vector3(-1.23, 1.0, -0.9), c + Vector3(-1.2, 1.7, 0.2), Color(0.4, 0.5, 0.55))
	b.box(c + Vector3(-1.5, 0.95, -1.0), c + Vector3(-1.2, 1.0, 0.3), Color(0.5, 0.4, 0.3))
	b.box(c + Vector3(-1.23, 0, 0.6), c + Vector3(-1.2, 1.9, 1.3), Color(0.35, 0.25, 0.18))
	add_child(b.build_mesh())
	var l := Label3D.new()
	l.text = "СБЕРКАССА"
	l.font_size = 72
	l.pixel_size = 0.005
	l.outline_size = 8
	l.modulate = Color(1, 1, 1)
	l.position = c + Vector3(-1.23, 2.3, 0)
	l.rotation.y = -PI / 2.0
	add_child(l)
	var put := InteractZone.create("", Vector3(1.8, 2.2, 1.4))
	put.position = c + Vector3(-2.2, 0, -0.6)
	put.prompt_fn = func() -> String:
		if GameManager.money <= 300:
			return "Сберкасса: вклад %d грн, +1%% в день. Положить нечего — 300 грн оставь на жизнь" % Daily.deposit
		return "E — положить на вклад %d грн (+1%% в день; 300 грн оставить на жизнь)" % (GameManager.money - 300)
	put.activated.connect(func() -> void:
		var sum := Daily.put_money()
		if sum > 0:
			SoundLibrary.play("cash")
			GameManager.notify("Положил %d грн. На вкладе: %d грн — каждое утро +1%%" % [sum, Daily.deposit]))
	add_child(put)
	var take := InteractZone.create("", Vector3(1.8, 2.2, 1.2))
	take.position = c + Vector3(-2.2, 0, 0.9)
	take.prompt_fn = func() -> String:
		return "E — снять вклад: %d грн" % Daily.deposit if Daily.deposit > 0 else "Сберкасса: вклада нет"
	take.activated.connect(func() -> void:
		var sum := Daily.take_money()
		if sum > 0:
			SoundLibrary.play("cash")
			GameManager.notify("Снял со вклада %d грн" % sum))
	add_child(take)


func _prompt(id: String) -> String:
	var b: Dictionary = Daily.BUSINESSES[id]
	if Daily.owns(id):
		return "Твоё дело — %s: +%d грн каждое утро" % [b.title, b.income]
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
			else:
				label.text = "ПРОДАЁТСЯ\n%d грн" % int(Daily.BUSINESSES[id].price)
				label.modulate = Color(0.75, 0.15, 0.1)
