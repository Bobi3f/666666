class_name Landmarks
extends Node3D
## Своё лицо у каждого села и места, куда хочется съездить: водонапорная
## башня, мельница, церковь, пилорама, развалины завода, пасека, ферма,
## пионерлагерь, свалка старых машин, элеватор, рыбацкие мостки, пожарная
## вышка, тригопункт на самом высоком холме.
##
## Место — за огородами села, с той стороны, где нет поля (sites).
## Высокое (башни, труба, элеватор, церковь) — в меше земли, видно издали;
## мелочь — в меше сёл с дальностью видимости.

## [вид, название, село, радиус]
const KINDS := [
	["ruin_farm", "Заброшенная ферма", 0, 28.0],
	["water_tower", "Водонапорная башня", 1, 14.0],
	["windmill", "Ветряная мельница", 2, 14.0],
	["church", "Церковь", 3, 22.0],
	["sawmill", "Пилорама", 4, 26.0],
	["factory", "Развалины кирпичного завода", 5, 34.0],
	["apiary", "Пасека деда Степана", 6, 22.0],
	["dairy", "Молочная ферма", 7, 40.0],
	["camp", "Пионерлагерь «Звёздочка»", 8, 48.0],
	["junkyard", "Свалка старых машин", 9, 34.0],
	["elevator", "Элеватор", 10, 26.0],
	["pier", "Рыбацкие мостки", 11, 10.0],
]

static var _sites: Array = []

## Свалка: забор (x, z от центра), полуширина ворот, вагончик сторожа, часы.
const JUNK_YARD := Rect2(-26, -15, 52, 35)
const JUNK_GATE := 3.5
const JUNK_HUT := Vector3(-19.0, 0, 15.5)
const JUNK_OPEN := 7
const JUNK_CLOSE := 20
const Villagers := preload("res://scripts/world/villagers.gd")
var junk_panel: JunkPanel

var _world: Node3D
var _blades: Node3D


## Места достопримечательностей: [центр, радиус, вид, название].
static func sites() -> Array:
	if not _sites.is_empty():
		return _sites
	for k in KINDS:
		var v: Dictionary = Region.VILLAGES[k[2]]
		var c: Vector2 = v.c
		var r: float = k[3]
		var pos: Vector2
		if k[0] == "pier":
			# Мостки — на реке напротив села
			var best := Vector2.ZERO
			var bd := INF
			for q in Region.river():
				var dq := q.distance_to(c)
				if dq < bd:
					bd = dq
					best = q
			pos = best + (c - best).normalized() * (Region.RIVER_HALF + 3.0)
		else:
			# За огородами, с той стороны, где нет поля
			var field: Rect2 = Region.FIELDS[k[2]][0]
			var side := -signf(field.get_center().y - c.y)
			pos = c + Vector2(0, side * (70.0 + r))
			for tries in 4:
				if Region.road_dist(pos.x, pos.y) > r + 8.0:
					break
				pos += Vector2(0, side * 30.0)
		_sites.append([pos, r, k[0], k[1]])
	# Пожарная вышка — посреди большого леса на северо-западе
	_sites.append([Vector2(-1650, -1700), 10.0, "fire_tower", "Пожарная вышка"])
	return _sites


static func occupied(x: float, z: float) -> bool:
	for s in sites():
		if (s[0] as Vector2).distance_to(Vector2(x, z)) < float(s[1]):
			return true
	return false


func build(world: Node3D, b: MeshBuilder, d: MeshBuilder) -> void:
	_world = world
	for s in sites():
		var c := Vector3((s[0] as Vector2).x, 0, (s[0] as Vector2).y)
		match s[2]:
			"ruin_farm": _ruin_farm(d, c)
			"water_tower": _water_tower(b, c)
			"windmill": _windmill(b, d, c)
			"church": _church(b, d, c)
			"sawmill": _sawmill(d, c)
			"factory": _factory(b, d, c)
			"apiary": _apiary(d, c)
			"dairy": _dairy(d, c)
			"camp": _camp(d, c)
			"junkyard": _junkyard(d, c)
			"elevator": _elevator(b, c)
			"pier": _pier(d, c, s[0])
			"fire_tower": _fire_tower(b, c)
		if s[2] != "pier" and s[2] != "fire_tower":
			_board(d, c + Vector3(0, 0, float(s[1]) * 0.8), s[3])
	_trig_point(b)


## Табличка с названием места.
func _board(d: MeshBuilder, p: Vector3, title: String) -> void:
	d.box(p + Vector3(-1.0, 0, -0.04), p + Vector3(-0.92, 1.9, 0.04), Color(0.35, 0.3, 0.25))
	d.box(p + Vector3(0.92, 0, -0.04), p + Vector3(1.0, 1.9, 0.04), Color(0.35, 0.3, 0.25))
	d.box(p + Vector3(-1.1, 1.3, -0.03), p + Vector3(1.1, 1.95, 0.03), Color(0.9, 0.88, 0.8))
	for side in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = title
		l.font_size = 64
		l.pixel_size = 0.0028
		l.outline_size = 0
		l.modulate = Color(0.12, 0.12, 0.14)
		l.width = 2.1 / 0.0028
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = p + Vector3(0, 1.62, 0.04 * side)
		l.rotation.y = 0.0 if side > 0.0 else PI
		add_child(l)


## Восьмигранная «труба» от y0 до y1 с радиусами r0 → r1.
func _prism(b: MeshBuilder, c: Vector3, r0: float, r1: float, y0: float, y1: float, col: Color, sides := 8) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p00 := c + Vector3(cos(a0) * r0, y0, sin(a0) * r0)
		var p01 := c + Vector3(cos(a1) * r0, y0, sin(a1) * r0)
		var p10 := c + Vector3(cos(a0) * r1, y1, sin(a0) * r1)
		var p11 := c + Vector3(cos(a1) * r1, y1, sin(a1) * r1)
		b.quad(p00, p10, p11, p01, col.darkened(0.08 * (i % 2)), true)


## Крыша-конус над призмой.
func _cone(b: MeshBuilder, c: Vector3, r: float, y0: float, h: float, col: Color, sides := 8) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		b.tri(c + Vector3(cos(a0) * r, y0, sin(a0) * r), c + Vector3(0, y0 + h, 0), c + Vector3(cos(a1) * r, y0, sin(a1) * r), col, true)


## Двускатный сарай: стены, крыша вдоль X.
func _barn(b: MeshBuilder, c: Vector3, size: Vector3, wall: Color, roof: Color, collide := true) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	b.box(c + Vector3(-hx, 0, -hz), c + Vector3(hx, size.y, hz), wall, collide)
	var ridge := size.y + size.z * 0.35
	b.quad(c + Vector3(-hx - 0.3, size.y, hz + 0.4), c + Vector3(hx + 0.3, size.y, hz + 0.4), c + Vector3(hx + 0.3, ridge, 0), c + Vector3(-hx - 0.3, ridge, 0), roof, true)
	b.quad(c + Vector3(hx + 0.3, size.y, -hz - 0.4), c + Vector3(-hx - 0.3, size.y, -hz - 0.4), c + Vector3(-hx - 0.3, ridge, 0), c + Vector3(hx + 0.3, ridge, 0), roof.darkened(0.08), true)
	for sx in [-hx, hx]:
		b.tri(c + Vector3(sx, size.y, hz), c + Vector3(sx, size.y, -hz), c + Vector3(sx, ridge, 0), wall.darkened(0.06), true)


# --- Сёла ---------------------------------------------------------------------

func _ruin_farm(d: MeshBuilder, c: Vector3) -> void:
	var brick := Color(0.62, 0.5, 0.42)
	# Коровник без крыши: стены с проломами, стропила
	for z in [-6.0, 6.0]:
		var x := -18.0
		while x < 18.0:
			var h := 3.2 if int(x + z) % 7 != 0 else 1.2
			d.box(c + Vector3(x, 0, z - 0.25), c + Vector3(x + 3.8, h, z + 0.25), brick.darkened(randf() * 0.1), true)
			x += 4.0
	for x in [-18.0, 18.0]:
		d.box(c + Vector3(x - 0.25, 0, -6), c + Vector3(x + 0.25, 3.2, 6), brick, true)
	for i in 6:
		var x := -15.0 + i * 6.0
		d.box_rot(c + Vector3(x, 3.6, 0), Vector3(0.18, 0.18, 12.5), 0.0, Color(0.35, 0.28, 0.2))
	# Разбитая силосная башня
	_prism(d, c + Vector3(24, 0, 0), 2.6, 2.6, 0.0, 9.0, Color(0.7, 0.68, 0.64))
	d.add_collider(c + Vector3(21.5, 0, -2.5), c + Vector3(26.5, 9, 2.5))
	# Бурьян и ржавая телега
	for i in 30:
		var p := c + Vector3(randf_range(-20, 28), 0, randf_range(-9, 9))
		d.box(p + Vector3(-0.04, 0, -0.04), p + Vector3(0.04, randf_range(0.6, 1.3), 0.04), Color(0.4, 0.45, 0.22))


func _water_tower(b: MeshBuilder, c: Vector3) -> void:
	# Башня Рожновского: кирпичный ствол, металлический бак, конус крыши
	_prism(b, c, 2.2, 1.8, 0.0, 16.0, Color(0.62, 0.34, 0.26))
	b.add_collider(c + Vector3(-2, 0, -2), c + Vector3(2, 16, 2))
	_prism(b, c, 3.4, 3.4, 16.0, 21.0, Color(0.45, 0.5, 0.52))
	_prism(b, c, 1.8, 3.4, 15.2, 16.0, Color(0.4, 0.44, 0.46))
	_cone(b, c, 3.6, 21.0, 2.2, Color(0.35, 0.38, 0.4))
	b.box(c + Vector3(-0.6, 0, 2.0), c + Vector3(0.6, 2.2, 2.3), Color(0.3, 0.22, 0.16))


func _windmill(b: MeshBuilder, d: MeshBuilder, c: Vector3) -> void:
	# Деревянная мельница-«шатровка»: сужающаяся башня, крыша, крылья вертятся
	_prism(b, c, 3.2, 2.2, 0.0, 9.0, Color(0.5, 0.38, 0.26), 8)
	b.add_collider(c + Vector3(-2.8, 0, -2.8), c + Vector3(2.8, 9, 2.8))
	_cone(b, c, 2.8, 9.0, 3.0, Color(0.42, 0.32, 0.24), 8)
	d.box(c + Vector3(-0.6, 0, 3.0), c + Vector3(0.6, 2.2, 3.3), Color(0.3, 0.22, 0.16))
	_blades = Node3D.new()
	_blades.position = c + Vector3(0, 9.2, 2.9)
	var bb := MeshBuilder.new()
	for k in 4:
		var a := TAU * k / 4.0
		bb.xf = Transform3D(Basis(Vector3.FORWARD, a), Vector3.ZERO)
		bb.box(Vector3(-0.12, 0, -0.08), Vector3(0.12, 7.0, 0.08), Color(0.4, 0.3, 0.2))
		bb.box(Vector3(0.12, 1.2, -0.03), Vector3(1.2, 7.0, 0.0), Color(0.75, 0.7, 0.6))
	_blades.add_child(bb.build_mesh())
	add_child(_blades)


func _church(b: MeshBuilder, d: MeshBuilder, c: Vector3) -> void:
	var white := Color(0.94, 0.93, 0.9)
	var gold := Color(0.9, 0.72, 0.25)
	var green := Color(0.25, 0.5, 0.4)
	# Храм: неф, апсида, колокольня с луковкой и крестом
	_barn(b, c, Vector3(10.0, 7.0, 8.0), white, green)
	_prism(b, c + Vector3(-7.5, 0, 0), 3.2, 3.2, 0.0, 6.0, white)
	b.add_collider(c + Vector3(-10.5, 0, -3), c + Vector3(-4.5, 6, 3))
	_prism(b, c + Vector3(0, 0, 0), 1.6, 1.6, 9.8, 12.5, white)
	_prism(b, c + Vector3(0, 0, 0), 2.0, 2.4, 12.5, 14.0, gold)
	_prism(b, c + Vector3(0, 0, 0), 2.4, 0.3, 14.0, 17.0, gold)
	# Колокольня у входа
	b.box(c + Vector3(6.0, 0, -2.2), c + Vector3(10.4, 13.0, 2.2), white, true)
	b.box(c + Vector3(5.9, 9.0, -1.2), c + Vector3(10.5, 11.5, 1.2), Color(0.25, 0.25, 0.28))
	_cone(b, c + Vector3(8.2, 0, 0), 2.6, 13.0, 3.0, green)
	_prism(b, c + Vector3(8.2, 0, 0), 0.7, 0.2, 16.0, 18.0, gold)
	for p in [c + Vector3(0, 17.0, 0), c + Vector3(8.2, 18.0, 0)]:
		b.box(p + Vector3(-0.06, 0, -0.06), p + Vector3(0.06, 1.8, 0.06), gold)
		b.box(p + Vector3(-0.5, 1.2, -0.06), p + Vector3(0.5, 1.32, 0.06), gold)
	# Двери, окна, ограда
	d.box(c + Vector3(10.4, 0, -0.8), c + Vector3(10.45, 2.8, 0.8), Color(0.35, 0.22, 0.14))
	for z in [-4.02, 4.0]:
		for x in [-3.0, 0.0, 3.0]:
			d.box(c + Vector3(x - 0.5, 2.5, z), c + Vector3(x + 0.5, 4.8, z + 0.02), Color(0.3, 0.38, 0.48))
	for i in 24:
		var a := TAU * i / 24.0
		var p := c + Vector3(cos(a) * 17.0, 0, sin(a) * 13.0)
		d.box(p + Vector3(-0.15, 0, -0.15), p + Vector3(0.15, 1.2, 0.15), white)


func _sawmill(d: MeshBuilder, c: Vector3) -> void:
	var wood := Color(0.55, 0.42, 0.28)
	# Навес на столбах, пильная рама, штабеля брёвен и досок, опилки
	for x in [-8.0, 0.0, 8.0]:
		for z in [-4.0, 4.0]:
			d.box(c + Vector3(x - 0.15, 0, z - 0.15), c + Vector3(x + 0.15, 4.0, z + 0.15), Color(0.35, 0.28, 0.2), true)
	d.box(c + Vector3(-8.8, 4.0, -5.0), c + Vector3(8.8, 4.25, 5.0), Color(0.4, 0.42, 0.44))
	d.box(c + Vector3(-2, 0, -1), c + Vector3(2, 1.4, 1), Color(0.3, 0.32, 0.34), true)
	for k in 3:
		var p := c + Vector3(-18.0 + k * 5.0, 0, 10.0)
		for row in 4:
			for i in 5 - row:
				var bp := p + Vector3(0, 0.3 + row * 0.55, -1.2 + i * 0.6 + row * 0.3)
				_log(d, bp, 7.0)
		d.add_collider(p + Vector3(-3.5, 0, -1.6), p + Vector3(3.5, 2.2, 1.8))
	for k in 6:
		d.box(c + Vector3(10.0, k * 0.08, -6.0 + k * 0.05), c + Vector3(16.0, k * 0.08 + 0.08, -1.0 - k * 0.05), wood.lightened(0.15))
	for i in 5:
		var s := 3.0 - i * 0.55
		d.box_rot(c + Vector3(12, 0.2 + i * 0.35, 6), Vector3(s, 0.4, s), i * 0.5, Color(0.8, 0.7, 0.5))


## Бревно вдоль X: восьмигранник.
func _log(d: MeshBuilder, p: Vector3, len: float) -> void:
	var r := 0.27
	for i in 8:
		var a0 := TAU * i / 8.0
		var a1 := TAU * (i + 1) / 8.0
		var p0 := p + Vector3(0, sin(a0) * r, cos(a0) * r)
		var p1 := p + Vector3(0, sin(a1) * r, cos(a1) * r)
		d.quad(p0 + Vector3(-len * 0.5, 0, 0), p1 + Vector3(-len * 0.5, 0, 0), p1 + Vector3(len * 0.5, 0, 0), p0 + Vector3(len * 0.5, 0, 0), Color(0.45, 0.33, 0.22), true)
	d.box(p + Vector3(len * 0.5, -r, -r), p + Vector3(len * 0.5 + 0.02, r, r), Color(0.8, 0.68, 0.48))


func _factory(b: MeshBuilder, d: MeshBuilder, c: Vector3) -> void:
	var brick := Color(0.6, 0.28, 0.2)
	# Труба — видно издалека
	_prism(b, c + Vector3(14, 0, -8), 2.4, 1.3, 0.0, 32.0, brick)
	b.add_collider(c + Vector3(12, 0, -10), c + Vector3(16, 32, -6))
	for k in 3:
		_prism(b, c + Vector3(14, 0, -8), 1.45 - k * 0.02, 1.45 - k * 0.02, 20.0 + k * 4.0, 20.4 + k * 4.0, Color(0.3, 0.3, 0.3))
	# Цех: стены с пустыми окнами, обрушенная крыша, груды кирпича
	var hx := 16.0
	for z in [-7.0, 7.0]:
		var x := -hx
		while x < hx:
			var top := 7.0 - absf(sin(x * 0.7)) * 3.5
			d.box(c + Vector3(x, 0, z - 0.3), c + Vector3(x + 1.6, top, z + 0.3), brick.darkened(0.05 + randf() * 0.1), true)
			d.box(c + Vector3(x + 1.6, 0, z - 0.3), c + Vector3(x + 2.0, 1.2, z + 0.3), brick, true)
			x += 2.0
	d.box(c + Vector3(-hx - 0.3, 0, -7), c + Vector3(-hx + 0.3, 6.5, 7), brick, true)
	for i in 8:
		var p := c + Vector3(randf_range(-14, 14), 0, randf_range(-5, 5))
		for k in 3:
			var s := 2.2 - k * 0.6
			d.box_rot(p + Vector3(0, 0.25 + k * 0.4, 0), Vector3(s, 0.5, s * 0.8), randf() * TAU, brick.darkened(0.15))
	_board(d, c + Vector3(-hx - 4, 0, 8), "Кирпичный завод «Красный Яр» · 1958")


func _apiary(d: MeshBuilder, c: Vector3) -> void:
	var colors := [Color(0.3, 0.5, 0.75), Color(0.85, 0.75, 0.3), Color(0.35, 0.6, 0.35), Color(0.85, 0.85, 0.82)]
	for row in 3:
		for i in 7:
			var p := c + Vector3(-9.0 + i * 3.0, 0, -6.0 + row * 4.0)
			d.box(p + Vector3(-0.35, 0, -0.35), p + Vector3(0.35, 0.3, 0.35), Color(0.35, 0.3, 0.25))
			d.box(p + Vector3(-0.4, 0.3, -0.4), p + Vector3(0.4, 1.0, 0.4), colors[(i + row) % colors.size()], true)
			d.box(p + Vector3(-0.48, 1.0, -0.48), p + Vector3(0.48, 1.1, 0.48), Color(0.4, 0.42, 0.44))
	_barn(d, c + Vector3(12, 0, 0), Vector3(4.0, 2.4, 3.2), Color(0.55, 0.42, 0.3), Color(0.4, 0.42, 0.44))


func _dairy(d: MeshBuilder, c: Vector3) -> void:
	# Два длинных коровника, силосная башня, коровы на выгуле
	_barn(d, c + Vector3(0, 0, -8), Vector3(36.0, 3.6, 10.0), Color(0.85, 0.83, 0.78), Color(0.45, 0.47, 0.5))
	_barn(d, c + Vector3(0, 0, 8), Vector3(36.0, 3.6, 10.0), Color(0.85, 0.83, 0.78), Color(0.45, 0.47, 0.5))
	for z in [-2.98, 2.98]:
		var x := -16.0
		while x < 16.0:
			d.box(c + Vector3(x, 1.8, z), c + Vector3(x + 1.2, 2.6, z + 0.02 * signf(z)), Color(0.35, 0.42, 0.5))
			x += 3.0
	_prism(d, c + Vector3(22, 0, 0), 3.0, 3.0, 0.0, 12.0, Color(0.75, 0.75, 0.72))
	_cone(d, c + Vector3(22, 0, 0), 3.2, 12.0, 2.0, Color(0.45, 0.47, 0.5))
	d.add_collider(c + Vector3(19, 0, -3), c + Vector3(25, 12, 3))
	# Выгон с жердяной изгородью и коровами
	var pen := c + Vector3(0, 0, 24)
	for i in 30:
		var a := TAU * i / 30.0
		var p := pen + Vector3(cos(a) * 18.0, 0, sin(a) * 9.0)
		d.box(p + Vector3(-0.08, 0, -0.08), p + Vector3(0.08, 1.2, 0.08), Color(0.4, 0.32, 0.22))
	for i in 9:
		_cow(d, pen + Vector3(randf_range(-14, 14), 0, randf_range(-6, 6)), randf() * TAU)


## Корова: пятнистое туловище, голова, ноги.
func _cow(d: MeshBuilder, p: Vector3, yaw: float) -> void:
	var saved := d.xf
	d.xf = Transform3D(Basis(Vector3.UP, yaw), p)
	var white := Color(0.92, 0.9, 0.86)
	var black := Color(0.12, 0.1, 0.1)
	d.box(Vector3(-0.45, 0.7, -0.9), Vector3(0.45, 1.4, 0.9), white)
	d.box(Vector3(-0.46, 0.9, -0.3), Vector3(0.46, 1.3, 0.3), black)
	d.box(Vector3(-0.25, 1.0, -1.35), Vector3(0.25, 1.45, -0.85), black)
	for x in [-0.3, 0.2]:
		for z in [-0.7, 0.6]:
			d.box(Vector3(x, 0, z), Vector3(x + 0.12, 0.7, z + 0.12), white.darkened(0.2))
	d.xf = saved


func _camp(d: MeshBuilder, c: Vector3) -> void:
	var wood := Color(0.5, 0.42, 0.32)
	# Ворота с аркой и вывеской
	var g := c + Vector3(0, 0, 40)
	for x in [-3.0, 3.0]:
		d.box(g + Vector3(x - 0.2, 0, -0.2), g + Vector3(x + 0.2, 4.5, 0.2), Color(0.8, 0.8, 0.78), true)
	d.box(g + Vector3(-3.4, 4.2, -0.15), g + Vector3(3.4, 5.0, 0.15), Color(0.8, 0.2, 0.18))
	var l := Label3D.new()
	l.text = "ПИОНЕРЛАГЕРЬ «ЗВЁЗДОЧКА»"
	l.font_size = 64
	l.pixel_size = 0.004
	l.outline_size = 0
	l.position = g + Vector3(0, 4.6, 0.17)
	add_child(l)
	# Корпуса с заколоченными окнами
	for k in 3:
		var p := c + Vector3(-20.0 + k * 20.0, 0, -8.0)
		_barn(d, p, Vector3(14.0, 3.2, 7.0), wood, Color(0.42, 0.44, 0.46))
		var x := -5.5
		while x < 6.0:
			d.box(p + Vector3(x - 0.6, 1.2, 3.5), p + Vector3(x + 0.6, 2.4, 3.55), Color(0.35, 0.28, 0.2))
			d.box(p + Vector3(x - 0.7, 1.7, 3.56), p + Vector3(x + 0.7, 1.85, 3.6), Color(0.45, 0.36, 0.26))
			x += 2.5
	# Линейка: флагшток и памятник пионеру-горнисту
	d.box(c + Vector3(-0.08, 0, 14.92), c + Vector3(0.08, 8.0, 15.08), Color(0.7, 0.7, 0.72), true)
	var s := c + Vector3(8, 0, 15)
	d.box(s + Vector3(-0.8, 0, -0.8), s + Vector3(0.8, 1.4, 0.8), Color(0.75, 0.75, 0.72), true)
	d.box(s + Vector3(-0.3, 1.4, -0.2), s + Vector3(0.3, 2.3, 0.2), Color(0.85, 0.85, 0.82))
	d.box(s + Vector3(-0.2, 2.3, -0.2), s + Vector3(0.2, 2.65, 0.2), Color(0.85, 0.85, 0.82))
	d.box(s + Vector3(0.25, 2.3, -0.5), s + Vector3(0.35, 2.4, 0.0), Color(0.85, 0.85, 0.82))
	# Ржавые качели
	var sw := c + Vector3(-12, 0, 18)
	for x in [-1.5, 1.5]:
		d.box(sw + Vector3(x - 0.06, 0, -0.06), sw + Vector3(x + 0.06, 2.6, 0.06), Color(0.5, 0.3, 0.2))
	d.box(sw + Vector3(-1.6, 2.6, -0.06), sw + Vector3(1.6, 2.7, 0.06), Color(0.5, 0.3, 0.2))
	d.box(sw + Vector3(-0.4, 0.6, -0.2), sw + Vector3(0.4, 0.66, 0.2), Color(0.45, 0.35, 0.25))


func _junkyard(d: MeshBuilder, c: Vector3) -> void:
	var rust := [Color(0.5, 0.28, 0.16), Color(0.4, 0.3, 0.22), Color(0.55, 0.35, 0.2), Color(0.35, 0.33, 0.3)]
	for i in 9:
		var p := c + Vector3(-18.0 + (i % 5) * 8.5, 0, -8.0 + (i / 5) * 12.0)
		var b := MeshBuilder.new()
		b.ground_shade = false
		VehicleModels.zhiguli(b, rust[i % rust.size()], false)
		var mi := b.build_mesh()
		mi.position = p + Vector3(0, 0.05 if i % 3 != 0 else -0.25, 0)
		mi.rotation = Vector3(0.0 if i % 4 != 1 else 0.3, randf() * TAU, 0.0 if i % 3 != 2 else 0.12)
		add_child(mi)
		d.add_collider(p + Vector3(-1.0, 0, -1.0), p + Vector3(1.0, 1.3, 1.0))
	# Остов автобуса и горы покрышек
	var bb := MeshBuilder.new()
	bb.ground_shade = false
	VehicleModels.bus(bb, Color(0.55, 0.45, 0.25), Vector3(2.5, 3.0, 9.0))
	var bus := bb.build_mesh()
	bus.position = c + Vector3(20, -0.3, 10)
	bus.rotation = Vector3(0, 0.6, 0.05)
	add_child(bus)
	d.add_collider(c + Vector3(17, 0, 6), c + Vector3(23, 3, 14))
	# Покрышки — у задней стенки, перед воротами свободно для своей машины
	for k in 4:
		var p := c + Vector3(-12.0 + k * 7.0, 0, -12.5)
		for j in 6:
			d.box(p + Vector3(-0.38, j * 0.24, -0.38), p + Vector3(0.38, j * 0.24 + 0.22, 0.38), Color(0.08, 0.08, 0.09))
	_junk_fence(d, c)
	_junk_hut(d, c)


## Территория свалки: забор из ржавого профлиста по кругу, ворота к табличке.
func _junk_fence(d: MeshBuilder, c: Vector3) -> void:
	var r := JUNK_YARD
	# Внутри — утоптанная земля в масляных пятнах
	d.box(c + Vector3(r.position.x, 0.0, r.position.y), c + Vector3(r.end.x, 0.03, r.end.y + 4.0), Color(0.4, 0.35, 0.28))
	for i in 6:
		var o := c + Vector3(-14.0 + i * 5.5, 0.03, 9.0 + float(i % 3) * 3.0)
		d.box(o + Vector3(-1.0, 0, -0.7), o + Vector3(1.0, 0.035, 0.7), Color(0.18, 0.16, 0.14))
	var sheet := [Color(0.45, 0.44, 0.42), Color(0.36, 0.27, 0.22), Color(0.38, 0.4, 0.38)]
	var k := 0
	# Вдоль x — задняя стенка и передняя с проёмом ворот посередине
	for z in [r.position.y, r.end.y]:
		var x := r.position.x
		while x < r.end.x - 0.01:
			var x1 := minf(x + 2.0, r.end.x)
			if not (z == r.end.y and x1 > -JUNK_GATE and x < JUNK_GATE):
				d.box(c + Vector3(x, 0, z - 0.05), c + Vector3(x1, 2.2 - 0.1 * (k % 2), z + 0.05), sheet[k % 3], true)
			x = x1
			k += 1
	for x in [r.position.x, r.end.x]:
		var z := r.position.y
		while z < r.end.y - 0.01:
			var z1 := minf(z + 2.0, r.end.y)
			d.box(c + Vector3(x - 0.05, 0, z), c + Vector3(x + 0.05, 2.2 - 0.1 * (k % 2), z1), sheet[k % 3], true)
			z = z1
			k += 1
	# Столбы ворот и распахнутые створки
	for s in [-1.0, 1.0]:
		var gx: float = s * JUNK_GATE
		d.box(c + Vector3(gx - 0.12, 0, r.end.y - 0.12), c + Vector3(gx + 0.12, 2.6, r.end.y + 0.12), Color(0.3, 0.3, 0.32), true)
		var lx0 := gx + minf(s * 0.1, s * 0.16)
		d.box(c + Vector3(lx0, 0.1, r.end.y + 0.1), c + Vector3(lx0 + 0.06, 2.1, r.end.y + 3.0), Color(0.42, 0.3, 0.2), true)


## Вагончик сторожа с вывеской и дядя Гриша у двери: E — продать технику на
## лом или купить б/у запчасти (JunkPanel).
func _junk_hut(d: MeshBuilder, c: Vector3) -> void:
	var h := c + JUNK_HUT
	d.box(h + Vector3(-2.6, 0.3, -1.2), h + Vector3(2.6, 2.7, 1.2), Color(0.32, 0.42, 0.5), true)
	d.box(h + Vector3(-2.75, 2.7, -1.35), h + Vector3(2.75, 2.85, 1.35), Color(0.3, 0.3, 0.3))
	for x in [-2.2, 2.0]:
		d.box(h + Vector3(x, 0, -1.0), h + Vector3(x + 0.2, 0.3, 1.0), Color(0.2, 0.2, 0.2))
	d.box(h + Vector3(0.6, 0.35, 1.2), h + Vector3(1.5, 2.3, 1.23), Color(0.45, 0.32, 0.2))
	d.box(h + Vector3(-1.9, 1.3, 1.2), h + Vector3(-0.4, 2.2, 1.23), Color(0.6, 0.75, 0.85))
	d.box(h + Vector3(0.4, 0.0, 1.2), h + Vector3(1.7, 0.32, 1.9), Color(0.5, 0.5, 0.48))
	# Вывеска над вагончиком
	d.box(h + Vector3(-2.4, 2.9, 0.9), h + Vector3(2.4, 3.75, 0.98), Color(0.95, 0.85, 0.25))
	for x in [-2.0, 2.0]:
		d.box(h + Vector3(x - 0.04, 2.85, 0.9), h + Vector3(x + 0.04, 2.95, 0.98), Color(0.3, 0.3, 0.3))
	var l := Label3D.new()
	l.text = "ПРИЁМ ЛОМА\nЗАПЧАСТИ Б/У"
	l.font_size = 96
	l.pixel_size = 0.0034
	l.outline_size = 0
	l.modulate = Color(0.12, 0.1, 0.08)
	l.position = h + Vector3(0, 3.32, 0.99)
	add_child(l)
	# Сторож
	var pb := MeshBuilder.new()
	pb.ground_shade = false
	Villagers.person_model(pb, Color(0.3, 0.35, 0.25), Color(0.2, 0.2, 0.22), false, false)
	var who := pb.build_mesh()
	who.position = h + Vector3(2.4, 0, 2.2)
	add_child(who)
	var zone := InteractZone.create("", Vector3(3.0, 2.2, 3.0))
	zone.name = "JunkZone"
	zone.position = h + Vector3(2.4, 0, 2.6)
	zone.prompt_fn = junk_prompt
	zone.activated.connect(open_junk)
	add_child(zone)


func junk_prompt() -> String:
	var hr := TimeManager.hour()
	if hr < JUNK_OPEN or hr >= JUNK_CLOSE:
		return "Дядя Гриша: «Закрыто! Приходи с %d утра до %d вечера»" % [JUNK_OPEN, JUNK_CLOSE]
	return "E — дядя Гриша: продать машину или мотоцикл, б/у запчасти"


## Своя техника за воротами свалки.
func junk_vehicles() -> Array:
	var at := junk_center() + Vector3(0, 0, JUNK_YARD.get_center().y)
	var out := []
	for v in get_tree().get_nodes_in_group("vehicles"):
		var car := v as Vehicle
		if car and car.owned() and not car.school and car.global_position.distance_to(at) < 30.0:
			out.append(car)
	return out


func open_junk() -> void:
	var hr := TimeManager.hour()
	if hr < JUNK_OPEN or hr >= JUNK_CLOSE:
		return
	if junk_panel == null:
		junk_panel = JunkPanel.new()
		add_child(junk_panel)
	SoundLibrary.play("click", -4.0)
	junk_panel.open("junk", junk_vehicles())


## Центр свалки в мире.
static func junk_center() -> Vector3:
	for st in sites():
		if st[2] == "junkyard":
			return Vector3((st[0] as Vector2).x, 0, (st[0] as Vector2).y)
	return Vector3.ZERO


func _elevator(b: MeshBuilder, c: Vector3) -> void:
	var conc := Color(0.78, 0.77, 0.73)
	# Шесть силосов в два ряда и башня с галереей
	for row in 2:
		for i in 3:
			var p := c + Vector3(-7.0 + i * 5.2, 0, -2.6 + row * 5.2)
			_prism(b, p, 2.5, 2.5, 0.0, 22.0, conc)
	b.add_collider(c + Vector3(-10, 0, -5.5), c + Vector3(6, 22, 5.5))
	b.box(c + Vector3(7.0, 0, -3.0), c + Vector3(13.0, 30.0, 3.0), conc.darkened(0.05), true)
	b.box(c + Vector3(-10.0, 22.0, -1.5), c + Vector3(7.0, 24.0, 1.5), conc.darkened(0.15))
	b.box(c + Vector3(6.9, 26.0, -3.1), c + Vector3(13.1, 27.5, 3.1), Color(0.8, 0.2, 0.18))
	var l := Label3D.new()
	l.text = "ЭЛЕВАТОР"
	l.font_size = 96
	l.pixel_size = 0.01
	l.outline_size = 0
	l.position = c + Vector3(10.0, 26.75, 3.15)
	add_child(l)


## Мостки на реке: с них ловится рыба, как на пруду.
func _pier(d: MeshBuilder, c: Vector3, bank: Vector2) -> void:
	var dir2 := Vector2.ZERO
	var bd := INF
	for q in Region.river():
		var dq := q.distance_to(bank)
		if dq < bd:
			bd = dq
			dir2 = (q - bank).normalized()
	var yaw := atan2(dir2.x, dir2.y)
	var saved := d.xf
	d.xf = Transform3D(Basis(Vector3.UP, yaw), c)
	d.box(Vector3(-0.7, 0.3, -1.0), Vector3(0.7, 0.4, 6.0), Color(0.5, 0.4, 0.28), true)
	for z in [0.0, 2.5, 5.0]:
		for x in [-0.6, 0.5]:
			d.box(Vector3(x, -0.4, z), Vector3(x + 0.12, 0.3, z + 0.12), Color(0.3, 0.24, 0.16))
	d.xf = saved
	var fwd := Vector3(dir2.x, 0, dir2.y)
	# Рыбачат с начала мостков, до береговой стенки; поплавок — в реке
	var spot := c + fwd * 1.2 + Vector3(0, 0.4, 0)
	var zone := InteractZone.create("", Vector3(2.4, 2.0, 2.4))
	zone.position = spot
	zone.prompt_fn = func() -> String:
		var f: FishingGame = _world._fishing
		if f.active() and f.spot.distance_to(spot) < 3.0:
			return "КЛЮЁТ! E — подсекай!" if f.state == FishingGame.State.BITE else "Поплавок на воде — жди, пока нырнёт"
		return "E — порыбачить на Быстрой"
	zone.activated.connect(func() -> void: _world.fish_at(spot, spot + fwd * 7.0 + Vector3(0, -0.34, 0)))
	add_child(zone)


func _fire_tower(b: MeshBuilder, c: Vector3) -> void:
	var steel := Color(0.55, 0.3, 0.2)
	# Четыре ноги, раскосы, будка наверху
	for x in [-1.6, 1.6]:
		for z in [-1.6, 1.6]:
			b.box(c + Vector3(x - 0.12, 0, z - 0.12), c + Vector3(x + 0.12, 24.0, z + 0.12), steel)
	b.add_collider(c + Vector3(-2.2, 0, -2.2), c + Vector3(2.2, 3, 2.2))
	for k in 6:
		var y := 3.0 + k * 3.5
		var w := 1.72
		b.box(c + Vector3(-w, y, -w), c + Vector3(w, y + 0.12, -w + 0.12), steel)
		b.box(c + Vector3(-w, y, w - 0.12), c + Vector3(w, y + 0.12, w), steel)
	b.box(c + Vector3(-1.3, 24.0, -1.3), c + Vector3(1.3, 26.4, 1.3), Color(0.55, 0.45, 0.35))
	b.box(c + Vector3(-1.5, 26.4, -1.5), c + Vector3(1.5, 26.6, 1.5), Color(0.3, 0.3, 0.32))


## Тригопункт — деревянная пирамида на самом высоком холме.
func _trig_point(b: MeshBuilder) -> void:
	var top: Array = []
	for h in Landscape.hills:
		if top.is_empty() or float(h[2]) > float(top[2]):
			top = h
	if top.is_empty():
		return
	var c2: Vector2 = top[0]
	var c := Vector3(c2.x, float(top[2]) - 0.2, c2.y)
	var wood := Color(0.45, 0.36, 0.26)
	for x in [-1.2, 1.2]:
		for z in [-1.2, 1.2]:
			b.box_rot((c + Vector3(x, 0, z) + c + Vector3(0, 5.0, 0)) * 0.5, Vector3(0.14, 5.3, 0.14), 0.0, wood)
	b.box(c + Vector3(-0.3, 4.6, -0.3), c + Vector3(0.3, 5.4, 0.3), Color(0.9, 0.88, 0.8))
	b.box(c + Vector3(-0.05, 5.4, -0.05), c + Vector3(0.05, 6.5, 0.05), wood)


func _process(delta: float) -> void:
	if _blades:
		_blades.rotate_z(delta * 0.6)
