extends Node3D
## Грибы в лесу: каждое утро вырастают заново в случайных местах (две
## лесные делянки). Летом и весной — дюжина, осенью — вдвое больше, зимой
## нет. Белый — +2 еды, подосиновик и лисички — +1, мухомор — выбросить.

const AREAS := [Rect2(-195, -190, 170, 105), Rect2(-195, 27, 140, 163)]
## [название, цвет шляпки, еды, вес при выборе]
const KINDS := [
	["белый гриб", Color(0.45, 0.28, 0.14), 2, 2],
	["подосиновик", Color(0.8, 0.35, 0.1), 1, 4],
	["лисички", Color(0.95, 0.72, 0.15), 1, 4],
	["мухомор", Color(0.85, 0.1, 0.08), 0, 2],
]
const MAX := 26

var _day := -1
var _picked: Array = []
var _spots: Array = []  # [позиция, вид]
var _nodes: Array[Node3D] = []
var _meshes: Array[Mesh] = []


func _ready() -> void:
	add_to_group("persist")
	for k in KINDS:
		_meshes.append(_mushroom_mesh(k[1], k[0] == "мухомор", k[0] == "лисички"))
	for i in MAX:
		var n := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.visibility_range_end = 45.0
		n.add_child(mi)
		var zone := InteractZone.create("", Vector3(1.6, 1.8, 1.6))
		zone.prompt_fn = func() -> String: return _prompt(i)
		zone.activated.connect(func() -> void: _pick(i))
		n.add_child(zone)
		n.visible = false
		add_child(n)
		_nodes.append(n)
	TimeManager.minute_passed.connect(func(_m: float) -> void: _check_day())
	_check_day()


func _count_today() -> int:
	match WeatherManager.season():
		1:
			return MAX
		2:
			return 0
	return 12


func _check_day() -> void:
	# Новые грибы — с 6 утра
	var day := TimeManager.day if TimeManager.hour() >= 6.0 else TimeManager.day - 1
	if day == _day:
		return
	_day = day
	_picked.clear()
	_grow()


func _grow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _day * 4513 + 7
	_spots.clear()
	var n := _count_today()
	var weights := 0
	for k in KINDS:
		weights += int(k[3])
	var tries := 0
	while _spots.size() < n and tries < 400:
		tries += 1
		var area: Rect2 = AREAS[rng.randi() % AREAS.size()]
		var x := area.position.x + rng.randf() * area.size.x
		var z := area.position.y + rng.randf() * area.size.y
		if not Roads.tree_ok(x, z):
			continue
		var r := rng.randi() % weights
		var kind := 0
		while r >= int(KINDS[kind][3]):
			r -= int(KINDS[kind][3])
			kind += 1
		_spots.append([Vector3(x, 0, z), kind])
	_update_nodes()


func _update_nodes() -> void:
	for i in MAX:
		var n := _nodes[i]
		var on := i < _spots.size() and not _picked.has(i)
		n.visible = on
		(n.get_child(1) as InteractZone).monitoring = on
		if i < _spots.size():
			n.position = _spots[i][0]
			(n.get_child(0) as MeshInstance3D).mesh = _meshes[int(_spots[i][1])]


func _prompt(i: int) -> String:
	if i >= _spots.size() or _picked.has(i):
		return ""
	var k: Array = KINDS[int(_spots[i][1])]
	if k[0] == "мухомор":
		return "Мухомор — не для еды. E — сбить ногой"
	return "E — срезать: %s" % k[0]


func _pick(i: int) -> void:
	if i >= _spots.size() or _picked.has(i):
		return
	_picked.append(i)
	var k: Array = KINDS[int(_spots[i][1])]
	SoundLibrary.play("step_grass", -4.0, 1.4)
	var left := _spots.size() - _picked.size()
	if int(k[2]) > 0:
		NeedsManager.snacks += int(k[2])
		QuestManager.event("mushroom")
		GameManager.notify("Есть %s! +%d еды в запас. В лесу ещё грибов: %d" % [k[0], k[2], left])
	else:
		GameManager.notify("Мухомор полетел в кусты. Грибов ещё: %d" % left)
	_update_nodes()


static func _mushroom_mesh(cap: Color, dots: bool, cluster: bool) -> Mesh:
	var b := MeshBuilder.new()
	b.ground_shade = false
	# Чуть крупнее настоящих — чтобы на телефоне было видно в траве
	b.xf = Transform3D(Basis().scaled(Vector3.ONE * 1.5), Vector3.ZERO)
	var stem := Color(0.93, 0.9, 0.82)
	var offs := [Vector3.ZERO] if not cluster else [Vector3(-0.07, 0, 0.03), Vector3(0.06, 0, -0.04), Vector3(0.02, 0, 0.08)]
	for o in offs:
		var s := 1.0 if not cluster else 0.6
		b.box(o + Vector3(-0.03, 0, -0.03) * s, o + Vector3(0.03 * s, 0.14 * s, 0.03 * s), stem)
		b.box(o + Vector3(-0.09 * s, 0.13 * s, -0.09 * s), o + Vector3(0.09 * s, 0.19 * s, 0.09 * s), cap)
		b.box(o + Vector3(-0.06 * s, 0.19 * s, -0.06 * s), o + Vector3(0.06 * s, 0.22 * s, 0.06 * s), cap.lightened(0.05))
		if dots:
			for d in [Vector3(-0.04, 0.221, 0.02), Vector3(0.03, 0.221, -0.03), Vector3(0.0, 0.221, 0.04)]:
				b.box(o + d + Vector3(-0.012, 0, -0.012), o + d + Vector3(0.012, 0.004, 0.012), Color(0.97, 0.97, 0.95))
	return b.build_array_mesh()


func save_state() -> Dictionary:
	return {"day": _day, "picked": _picked}


func load_state(d: Dictionary) -> void:
	_day = int(d.get("day", -1))
	_picked = (d.get("picked", []) as Array).duplicate()
	for i in _picked.size():
		_picked[i] = int(_picked[i])
	_grow()
