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
