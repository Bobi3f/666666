class_name Farm
extends Node3D
## Своя ферма у Каменки — за трассой, напротив села. Участок за забором с
## воротами, коровник (заходишь — стойла, двенадцать коров, кормушки, свет),
## кирпичный гараж и полукруглый ангар (в оба можно заехать), площадка для
## техники с трактором и грузовиком.
##
## Продаётся у ворот (Daily, дело «farm»): купил — каждое утро доход, а раз в день
## в коровнике можно подоить коров — молоко сразу берут.
## Всё неподвижное — один меш и одно тело; свет внутри — только вблизи.

## Участок в мире: x, z, ширина, длина. Ворота — к трассе (−Z), посередине.
const AREA := Rect2(-12, 24, 60, 44)
const GATE_X := 18.0
const GATE_HALF := 3.0
## Здания (x, z, ширина, длина)
const BARN := Rect2(-6, 50, 30, 14)
const GARAGE := Rect2(26, 27, 10, 8)
const HANGAR := Rect2(30, 40, 16, 24)
const PAD := Rect2(-10, 27, 22, 15)
const MILK_PAY := 150
const MILK_MIN := 45.0
const Villagers := preload("res://scripts/world/villagers.gd")

var milk_day := -1
var _sign: Label3D
## Лампы и здание, где каждая светит: горит, только пока игрок внутри
var _lights: Array[OmniLight3D] = []
var _light_rooms: Array[Rect2] = []


## Занято ли место фермой — для деревьев и травы.
static func occupied(x: float, z: float) -> bool:
	return AREA.grow(4.0).has_point(Vector2(x, z)) or (absf(x - GATE_X) < 5.0 and z > 4.0 and z < AREA.position.y)


func _ready() -> void:
	add_to_group("persist")
	var b := MeshBuilder.new()
	_ground(b)
	_fence(b)
	_pad(b)
	_garage(b)
	_hangar(b)
	_barn(b)
	var mesh := b.build_mesh()
	mesh.name = "FarmMesh"
	mesh.visibility_range_end = 320.0
	add_child(mesh)
	add_child(b.build_body())
	_cows()
	_machines()
	_zones()
	Daily.changed.connect(_update)
	_update()


func _process(_delta: float) -> void:
	# Лампа горит, только пока игрок в её здании: на телефоне каждый свет
	# утяжеляет всё, на что падает
	var p := GameManager.player as Node3D
	if p == null:
		return
	var at := Vector2(p.global_position.x, p.global_position.z)
	for i in _lights.size():
		_lights[i].visible = _light_rooms[i].grow(1.5).has_point(at)


# --- Земля, забор, площадка ---------------------------------------------------

func _ground(b: MeshBuilder) -> void:
	var r := AREA
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0.03, r.end.y), Color(0.45, 0.39, 0.3))
	# Грунтовка от трассы к воротам и колея по двору
	b.box(Vector3(GATE_X - 2.6, 0, 5.5), Vector3(GATE_X + 2.6, 0.035, r.position.y + 1.0), Color(0.48, 0.41, 0.31))
	for x in [GATE_X - 1.3, GATE_X + 1.0]:
		b.box(Vector3(x, 0.035, 5.5), Vector3(x + 0.4, 0.04, r.position.y + 12.0), Color(0.38, 0.32, 0.24))


func _fence(b: MeshBuilder) -> void:
	var r := AREA
	var wood := Color(0.5, 0.4, 0.28)
	var runs := [
		[Vector2(r.position.x, r.position.y), Vector2(GATE_X - GATE_HALF, r.position.y)],
		[Vector2(GATE_X + GATE_HALF, r.position.y), Vector2(r.end.x, r.position.y)],
		[Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y)],
		[Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y)],
		[Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y)],
	]
	for run in runs:
		var a: Vector2 = run[0]
		var c: Vector2 = run[1]
		var mn := Vector3(minf(a.x, c.x) - 0.05, 0, minf(a.y, c.y) - 0.05)
		var mx := Vector3(maxf(a.x, c.x) + 0.05, 0, maxf(a.y, c.y) + 0.05)
		# Три жерди, столбы через 2,5 м
		for y in [0.4, 0.9, 1.4]:
			b.box(mn + Vector3(0, y, 0), mx + Vector3(0, y + 0.08, 0), wood)
		b.add_collider(mn, mx + Vector3(0, 1.5, 0))
		var len := maxf(mx.x - mn.x, mx.z - mn.z)
		var along_x := mx.x - mn.x > mx.z - mn.z
		var t := 0.0
		while t <= len + 0.01:
			var p := mn + (Vector3(t, 0, 0.05) if along_x else Vector3(0.05, 0, t))
			b.box(p + Vector3(-0.09, 0, -0.09), p + Vector3(0.09, 1.65, 0.09), wood.darkened(0.25))
			t += 2.5
	# Ворота: столбы и перекладина с вывеской
	for s in [-1.0, 1.0]:
		var gx: float = GATE_X + s * GATE_HALF
		b.box(Vector3(gx - 0.15, 0, r.position.y - 0.15), Vector3(gx + 0.15, 4.2, r.position.y + 0.15), wood.darkened(0.35), true)
	b.box(Vector3(GATE_X - GATE_HALF - 0.2, 3.6, r.position.y - 0.12), Vector3(GATE_X + GATE_HALF + 0.2, 4.4, r.position.y + 0.12), Color(0.85, 0.82, 0.7))
	var l := _label("ФЕРМА «КАМЕНКА»", Vector3(GATE_X, 4.0, r.position.y - 0.14), PI, 0.0042, Color(0.15, 0.3, 0.15))
	l.visibility_range_end = 200.0


func _pad(b: MeshBuilder) -> void:
	var r := PAD
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0.06, r.end.y), Color(0.55, 0.55, 0.53))
	# Места под технику: белые линии
	var x := r.position.x + 0.5
	while x <= r.end.x:
		b.box(Vector3(x, 0.06, r.position.y + 1.0), Vector3(x + 0.12, 0.065, r.end.y - 1.0), Color(0.9, 0.9, 0.86))
		x += 5.25


# --- Гараж и ангар --------------------------------------------------------------

## Кирпичный гараж: ворота к двору (−X) открыты, внутри верстак, полка, покрышки.
func _garage(b: MeshBuilder) -> void:
	var r := GARAGE
	var brick := Color(0.62, 0.32, 0.24)
	var h := 3.2
	var t := 0.25
	var g0 := r.get_center().y - 1.7
	var g1 := r.get_center().y + 1.7
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0.05, r.end.y), Color(0.5, 0.5, 0.48))
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, h, r.position.y + t), brick, true)
	b.box(Vector3(r.position.x, 0, r.end.y - t), Vector3(r.end.x, h, r.end.y), brick, true)
	b.box(Vector3(r.end.x - t, 0, r.position.y), Vector3(r.end.x, h, r.end.y), brick, true)
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.position.x + t, h, g0), brick, true)
	b.box(Vector3(r.position.x, 0, g1), Vector3(r.position.x + t, h, r.end.y), brick, true)
	b.box(Vector3(r.position.x, 2.7, g0), Vector3(r.position.x + t, h, g1), brick)
	b.box(Vector3(r.position.x - 0.2, h, r.position.y - 0.2), Vector3(r.end.x + 0.2, h + 0.2, r.end.y + 0.2), Color(0.3, 0.3, 0.32))
	# Створки распахнуты к стене
	for z in [g0 - 0.06, g1]:
		b.box(Vector3(r.position.x - 1.6, 0.05, z), Vector3(r.position.x - 0.05, 2.6, z + 0.06), Color(0.3, 0.42, 0.32))
	# Верстак, полка, покрышки
	b.box(Vector3(r.end.x - 0.9, 0, r.position.y + 1.0), Vector3(r.end.x - t, 0.9, r.position.y + 3.5), Color(0.45, 0.32, 0.2), true)
	b.box(Vector3(r.end.x - 0.5, 1.5, r.end.y - 3.5), Vector3(r.end.x - t, 1.55, r.end.y - 0.5), Color(0.45, 0.32, 0.2))
	for i in 4:
		b.box(Vector3(r.end.x - 1.2, i * 0.24, r.end.y - 1.2), Vector3(r.end.x - 0.4, i * 0.24 + 0.22, r.end.y - 0.4), Color(0.08, 0.08, 0.09))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(r.get_center().x, 2.8, r.get_center().y)
	lamp.omni_range = 7.0
	lamp.light_energy = 0.9
	lamp.light_color = Color(1.0, 0.9, 0.7)
	add_child(lamp)
	_lights.append(lamp)
	_light_rooms.append(GARAGE)


## Полукруглый ангар из профлиста: открыт к воротам (−Z), сзади глухой торец.
func _hangar(b: MeshBuilder) -> void:
	var r := HANGAR
	var cx := r.get_center().x
	var rad := r.size.x * 0.5
	var metal := Color(0.66, 0.68, 0.7)
	var n := 12
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0.05, r.end.y), Color(0.52, 0.52, 0.5))
	for i in n:
		var a0 := PI * i / n
		var a1 := PI * (i + 1) / n
		var p0 := Vector3(cx + cos(a0) * rad, sin(a0) * rad * 0.75, 0)
		var p1 := Vector3(cx + cos(a1) * rad, sin(a1) * rad * 0.75, 0)
		var col := metal if i % 2 == 0 else metal.darkened(0.06)
		# Снаружи и изнутри — один лист в две стороны
		b.quad(p0 + Vector3(0, 0, r.position.y), p1 + Vector3(0, 0, r.position.y), p1 + Vector3(0, 0, r.end.y), p0 + Vector3(0, 0, r.end.y), col, true)
		# Глухой задний торец — веером
		b.tri(Vector3(cx, 0, r.end.y), p0 + Vector3(0, 0, r.end.y), p1 + Vector3(0, 0, r.end.y), metal.darkened(0.12), true)
	# Стены для столкновений: бока и торец
	b.add_collider(Vector3(r.position.x - 0.1, 0, r.position.y), Vector3(r.position.x + 1.2, 3.5, r.end.y))
	b.add_collider(Vector3(r.end.x - 1.2, 0, r.position.y), Vector3(r.end.x + 0.1, 3.5, r.end.y))
	b.add_collider(Vector3(r.position.x, 0, r.end.y - 0.2), Vector3(r.end.x, rad * 0.75, r.end.y + 0.1))
	# Сено в тюках у задней стены
	for i in 6:
		for j in 2:
			var p := Vector3(r.position.x + 2.5 + i * 1.8, j * 0.9, r.end.y - 2.2)
			b.box(p, p + Vector3(1.6, 0.85, 1.2), Color(0.85, 0.72, 0.38), true)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(cx, rad * 0.6, r.get_center().y)
	lamp.omni_range = 14.0
	lamp.light_energy = 0.8
	lamp.light_color = Color(1.0, 0.92, 0.75)
	add_child(lamp)
	_lights.append(lamp)
	_light_rooms.append(HANGAR)


# --- Коровник ---------------------------------------------------------------------

## Длинный коровник: двери в торцах, проход посередине, стойла по бокам,
## кормушки к проходу, окна под крышей. Внутри светло — две лампы.
func _barn(b: MeshBuilder) -> void:
	var r := BARN
	var wall := Color(0.86, 0.84, 0.78)
	var h := 3.4
	var t := 0.3
	var z0 := r.position.y
	var z1 := r.end.y
	var mid := r.get_center().y
	var d0 := mid - 2.0
	var d1 := mid + 2.0
	b.box(Vector3(r.position.x, 0, z0), Vector3(r.end.x, 0.08, z1), Color(0.48, 0.45, 0.4))
	# Длинные стены с окнами под крышей
	for zs in [[z0, z0 + t], [z1 - t, z1]]:
		b.box(Vector3(r.position.x, 0, zs[0]), Vector3(r.end.x, 2.2, zs[1]), wall, true)
		b.box(Vector3(r.position.x, 2.9, zs[0]), Vector3(r.end.x, h, zs[1]), wall)
		var x := r.position.x
		while x < r.end.x - 0.1:
			b.box(Vector3(x, 2.2, zs[0]), Vector3(x + 1.0, 2.9, zs[1]), wall, true)
			b.box(Vector3(x + 1.0, 2.25, zs[0] - 0.02), Vector3(x + 3.0, 2.85, zs[1] + 0.02), Color(0.35, 0.45, 0.5))
			x += 3.0
	# Торцы с воротами посередине, над воротами — фронтон
	for xs in [[r.position.x, r.position.x + t], [r.end.x - t, r.end.x]]:
		b.box(Vector3(xs[0], 0, z0), Vector3(xs[1], h, d0), wall, true)
		b.box(Vector3(xs[0], 0, d1), Vector3(xs[1], h, z1), wall, true)
		b.box(Vector3(xs[0], 3.0, d0), Vector3(xs[1], h, d1), wall)
		b.tri(Vector3(xs[0] - 0.01, h, z0), Vector3(xs[0] - 0.01, h, z1), Vector3(xs[0] - 0.01, 6.0, mid), wall.darkened(0.05), true)
	# Двускатная крыша из шифера
	var slate := Color(0.55, 0.56, 0.55)
	b.quad(Vector3(r.position.x - 0.4, h - 0.1, z0 - 0.6), Vector3(r.end.x + 0.4, h - 0.1, z0 - 0.6), Vector3(r.end.x + 0.4, 6.05, mid), Vector3(r.position.x - 0.4, 6.05, mid), slate, true)
	b.quad(Vector3(r.end.x + 0.4, h - 0.1, z1 + 0.6), Vector3(r.position.x - 0.4, h - 0.1, z1 + 0.6), Vector3(r.position.x - 0.4, 6.05, mid), Vector3(r.end.x + 0.4, 6.05, mid), slate.darkened(0.08), true)
	# Проход с соломой, кормушки и перегородки стойл по обе стороны
	b.box(Vector3(r.position.x + t, 0.08, d0), Vector3(r.end.x - t, 0.1, d1), Color(0.78, 0.66, 0.38))
	for side in [-1.0, 1.0]:
		var fz := d0 - 0.6 if side < 0.0 else d1
		b.box(Vector3(r.position.x + 1.0, 0, fz), Vector3(r.end.x - 1.0, 0.7, fz + 0.6), Color(0.55, 0.52, 0.46), true)
		b.box(Vector3(r.position.x + 1.0, 0.55, fz + 0.1), Vector3(r.end.x - 1.0, 0.68, fz + 0.5), Color(0.7, 0.6, 0.3))
		var x := r.position.x + 2.0
		while x < r.end.x - 1.0:
			var za := z0 + t if side < 0.0 else d1 + 0.6
			var zb := d0 - 0.6 if side < 0.0 else z1 - t
			b.box(Vector3(x - 0.04, 0.3, za), Vector3(x + 0.04, 1.2, zb), Color(0.6, 0.6, 0.62))
			b.box(Vector3(x - 0.04, 1.15, za), Vector3(x + 0.04, 1.25, zb), Color(0.6, 0.6, 0.62))
			x += 4.5
	# Бидоны у ворот
	for i in 4:
		var p := Vector3(r.position.x + 0.8 + (i % 2) * 0.55, 0.08, d1 + 0.8 + (i / 2) * 0.55)
		b.box(p, p + Vector3(0.4, 0.7, 0.4), Color(0.75, 0.77, 0.8), true)
	for lx in [r.position.x + r.size.x * 0.3, r.position.x + r.size.x * 0.7]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(lx, 3.0, mid)
		lamp.omni_range = 11.0
		lamp.light_energy = 0.85
		lamp.light_color = Color(1.0, 0.9, 0.72)
		add_child(lamp)
		_lights.append(lamp)
		_light_rooms.append(BARN)
	var l := _label("КОРОВНИК", Vector3(r.position.x - 0.05, 3.4, mid), -PI / 2.0, 0.004, Color(0.2, 0.2, 0.2))
	l.visibility_range_end = 120.0


## Двенадцать коров в стойлах мордой к проходу и две — во дворе. Одним мешем.
func _cows() -> void:
	var b := MeshBuilder.new()
	b.ground_shade = false
	var r := BARN
	var mid := r.get_center().y
	var i := 0
	var x := r.position.x + 4.25
	while x < r.end.x - 1.0:
		for side in [-1.0, 1.0]:
			# Корова смотрит в −Z; северный ряд — мордой к проходу (+Z)
			var yaw := PI if side < 0.0 else 0.0
			b.xf = Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.08, mid + side * 4.4))
			AnimalModel.cow(b, i)
			i += 1
		x += 4.5
	for p in [Vector3(4.0, 0, 46.0), Vector3(9.0, 0, 45.0)]:
		b.xf = Transform3D(Basis(Vector3.UP, randf() * TAU), p)
		AnimalModel.cow(b, i)
		i += 1
	b.xf = Transform3D.IDENTITY
	var mi := b.build_mesh()
	mi.name = "FarmCows"
	mi.visibility_range_end = 90.0
	add_child(mi)


## Трактор и грузовик на площадке — техника фермы.
func _machines() -> void:
	var b := MeshBuilder.new()
	b.ground_shade = false
	b.xf = Transform3D(Basis(Vector3.UP, PI), Vector3(PAD.position.x + 3.0, 0.06, PAD.get_center().y))
	VehicleModels.tractor(b, Color(0.2, 0.45, 0.6))
	b.xf = Transform3D(Basis(Vector3.UP, PI), Vector3(PAD.position.x + 8.3, 0.06, PAD.get_center().y))
	VehicleModels.gaz53(b, Color(0.3, 0.45, 0.3))
	b.xf = Transform3D.IDENTITY
	var mi := b.build_mesh()
	mi.name = "FarmMachines"
	mi.visibility_range_end = 150.0
	add_child(mi)
	for p in [PAD.position.x + 3.0, PAD.position.x + 8.3]:
		var col := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(2.3, 2.6, 5.6)
		cs.shape = sh
		cs.position = Vector3(p, 1.3, PAD.get_center().y)
		col.add_child(cs)
		add_child(col)


# --- Покупка и дойка --------------------------------------------------------------

func _zones() -> void:
	var buy := InteractZone.create("", Vector3(5.0, 2.4, 3.0))
	buy.name = "FarmBuyZone"
	buy.position = Vector3(GATE_X, 0, AREA.position.y - 1.5)
	buy.prompt_fn = func() -> String:
		if Daily.owns("farm"):
			return "Твоя ферма: +%d грн каждое утро. Коров доить — в коровнике" % Daily.income("farm")
		return "E — купить ферму за %d грн: коровник на 12 коров, гараж, ангар, трактор и грузовик; +%d грн каждое утро" % [int(Daily.BUSINESSES.farm.price), int(Daily.BUSINESSES.farm.income)]
	buy.activated.connect(func() -> void: Daily.buy("farm"))
	add_child(buy)
	_sign = _label("", Vector3(GATE_X, 2.8, AREA.position.y - 0.3), PI, 0.0055, Color(0.75, 0.15, 0.1))
	_sign.outline_size = 10
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.visibility_range_end = 120.0
	var milk := InteractZone.create("", Vector3(6.0, 2.4, 3.6))
	milk.name = "FarmMilkZone"
	milk.position = Vector3(BARN.get_center().x, 0, BARN.get_center().y)
	milk.prompt_fn = milk_prompt
	milk.activated.connect(milk_cows)
	add_child(milk)


func milk_prompt() -> String:
	if not Daily.owns("farm"):
		return "Коровник фермы. Купишь ферму — коровы твои"
	if milk_day == TimeManager.day:
		return "Коров сегодня уже подоили. Завтра снова"
	return "E — подоить коров: %d мин, молоко сразу заберут, +%d грн" % [int(MILK_MIN), MILK_PAY]


## Подоить коров — раз в день, на своей ферме. true — подоил.
func milk_cows() -> bool:
	if not Daily.owns("farm") or milk_day == TimeManager.day:
		return false
	if NeedsManager.energy < 15.0:
		GameManager.notify("Сил нет доить — выспись")
		return false
	milk_day = TimeManager.day
	TimeManager.work(MILK_MIN, "Дою коров")
	NeedsManager.rest(-8.0)
	GameManager.add_money(MILK_PAY)
	SoundLibrary.play("cash")
	QuestManager.event("milk")
	GameManager.notify("Подоил коров: сорок литров молока забрала молоковозка, +%d грн" % MILK_PAY)
	return true


func _update() -> void:
	if _sign:
		_sign.text = "ТВОЯ ФЕРМА" if Daily.owns("farm") else "ПРОДАЁТСЯ\n%d грн" % int(Daily.BUSINESSES.farm.price)
		_sign.modulate = Color(0.2, 0.55, 0.2) if Daily.owns("farm") else Color(0.75, 0.15, 0.1)


func _label(text: String, p: Vector3, yaw: float, px: float, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = px
	l.outline_size = 0
	l.modulate = col
	l.position = p
	l.rotation.y = yaw
	add_child(l)
	return l


func save_state() -> Dictionary:
	return {"milk_day": milk_day}


func load_state(d: Dictionary) -> void:
	milk_day = int(d.get("milk_day", -1))
