class_name HouseInterior
extends Node3D
## Интерьер дома игрока: кухня с печью и комната, разделённые перегородкой.
##
## Стены — настоящие коробки с толщиной, поэтому изнутри они непрозрачные
## (у тонкой наружной стены изнутри видна изнанка, которую видеокарта
## отбрасывает, и стена кажется прозрачной).
##
## Всё строится в ОДИН меш с пятью поверхностями — по одной на текстуру
## (обои, пол, побелка, дерево, ткань). Это 5 вызовов отрисовки на весь
## интерьер, сколько бы мебели ни было. Текстуры рисуются кодом при старте,
## файлов-картинок не нужно.
##
## Как поставить: добавить Node3D внутрь дома игрока, повесить этот скрипт,
## выставить position на уровень пола, а inner_size — чуть меньше внутреннего
## размера дома. Вход — в стене со стороны +Z.

## Внутренний размер: ширина (X), высота потолка (Y), глубина (Z), метры.
@export var inner_size := Vector3(8.0, 2.6, 6.0)
@export var wall_thickness := 0.12
## Где стоит перегородка между кухней и комнатой: 0 — левый край, 1 — правый.
@export_range(0.25, 0.75) var partition_at := 0.4
@export var door_width := 0.9
@export var door_height := 2.0
## Смещение входной двери по X от центра стены.
@export var entrance_offset := -1.6
@export var build_collision := true
@export var lamp_energy := 1.2

enum { WALLPAPER, FLOOR, PLASTER, WOOD, FABRIC }

const TILE := {
	WALLPAPER: 0.6,
	FLOOR: 1.0,
	PLASTER: 1.0,
	WOOD: 0.8,
	FABRIC: 0.5,
}

var _tools: Array[SurfaceTool] = []
var _body: StaticBody3D


func _ready() -> void:
	build()


func build() -> void:
	for c in get_children():
		c.queue_free()
	_tools.clear()
	for i in 5:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools.append(st)

	if build_collision:
		_body = StaticBody3D.new()
		_body.name = "Collision"
		add_child(_body)

	_build_shell()
	_build_kitchen()
	_build_room()
	_build_lamp()

	var mesh := ArrayMesh.new()
	var mats := _make_materials()
	for i in _tools.size():
		_tools[i].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[i])
	var mi := MeshInstance3D.new()
	mi.name = "InteriorMesh"
	mi.mesh = mesh
	add_child(mi)
	_tools.clear()


# --- Коробка дома ---------------------------------------------------------

func _build_shell() -> void:
	var hx := inner_size.x * 0.5
	var hz := inner_size.z * 0.5
	var h := inner_size.y
	var t := wall_thickness

	# Пол и потолок
	_box(FLOOR, Vector3(-hx - t, -0.06, -hz - t), Vector3(hx + t, 0.0, hz + t), Color.WHITE)
	_collide(Vector3(-hx - t, -0.3, -hz - t), Vector3(hx + t, 0.0, hz + t))
	_box(PLASTER, Vector3(-hx - t, h, -hz - t), Vector3(hx + t, h + 0.06, hz + t), Color(0.97, 0.96, 0.93), false)

	# Наружные стены. Стена ставится снаружи от inner_size, внутрь смотрит обоями.
	var door := [[hx + t + entrance_offset, door_width, door_height]]
	_wall(Vector3(-hx - t, 0, hz + t * 0.5), Vector3(hx + t, 0, hz + t * 0.5), door)
	_wall(Vector3(-hx - t, 0, -hz - t * 0.5), Vector3(hx + t, 0, -hz - t * 0.5), [])
	_wall(Vector3(-hx - t * 0.5, 0, -hz), Vector3(-hx - t * 0.5, 0, hz), [])
	_wall(Vector3(hx + t * 0.5, 0, -hz), Vector3(hx + t * 0.5, 0, hz), [])

	# Перегородка кухня/комната с проходом ближе к задней стене
	var px := _partition_x()
	var pass_z := -hz * 0.45
	_wall(Vector3(px, 0, hz), Vector3(px, 0, -hz), [[hz - pass_z, door_width, door_height]])


func _partition_x() -> float:
	return -inner_size.x * 0.5 + inner_size.x * partition_at


## Стена вдоль оси X или Z от a до b. openings: [[расстояние от a, ширина, высота], ...]
func _wall(a: Vector3, b: Vector3, openings: Array) -> void:
	var h := inner_size.y
	var t := wall_thickness
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var across := Vector3(absf(dir.z), 0, absf(dir.x)) * t * 0.5
	var wood := Color(0.55, 0.36, 0.22)

	openings.sort_custom(func(p, q): return p[0] < q[0])
	var cursor := 0.0
	for o in openings:
		var o0: float = o[0] - o[1] * 0.5
		var o1: float = o[0] + o[1] * 0.5
		_wall_piece(a, dir, across, cursor, o0, 0.0, h)
		_wall_piece(a, dir, across, o0, o1, o[2], h)
		# Наличник: два косяка и перекладина, чуть толще стены
		var jamb := across + across.normalized() * 0.02
		_piece_box(WOOD, a, dir, jamb, o0 - 0.07, o0, 0.0, o[2] + 0.07, wood)
		_piece_box(WOOD, a, dir, jamb, o1, o1 + 0.07, 0.0, o[2] + 0.07, wood)
		_piece_box(WOOD, a, dir, jamb, o0, o1, o[2], o[2] + 0.07, wood)
		cursor = o1
	_wall_piece(a, dir, across, cursor, length, 0.0, h)


func _wall_piece(a: Vector3, dir: Vector3, across: Vector3, s0: float, s1: float, y0: float, y1: float) -> void:
	if s1 - s0 < 0.01 or y1 - y0 < 0.01:
		return
	var box := _piece_box(WALLPAPER, a, dir, across, s0, s1, y0, y1, Color.WHITE)
	_collide(box[0], box[1])
	if y0 < 0.01:
		# Плинтус на уровне пола
		var skirt := across + across.normalized() * 0.015
		_piece_box(WOOD, a, dir, skirt, s0, s1, 0.0, 0.08, Color(0.45, 0.28, 0.16))


func _piece_box(surf: int, a: Vector3, dir: Vector3, across: Vector3, s0: float, s1: float, y0: float, y1: float, color: Color) -> Array:
	var p0 := a + dir * s0
	var p1 := a + dir * s1
	var mn := Vector3(minf(p0.x, p1.x), y0, minf(p0.z, p1.z)) - across
	var mx := Vector3(maxf(p0.x, p1.x), y1, maxf(p0.z, p1.z)) + across
	_box(surf, mn, mx, color)
	return [mn, mx]


# --- Кухня ----------------------------------------------------------------

func _build_kitchen() -> void:
	var x0 := -inner_size.x * 0.5
	var x1 := _partition_x()
	var z0 := -inner_size.z * 0.5
	var white := Color(0.95, 0.94, 0.9)
	var brown := Color(0.5, 0.32, 0.2)
	var dark := Color(0.12, 0.1, 0.09)

	# Русская печь в заднем углу: основание, лежанка, топка, труба в потолок
	var s0 := Vector3(x0, 0, z0)
	_solid(PLASTER, s0, s0 + Vector3(1.6, 1.5, 1.9), white)
	_solid(PLASTER, s0 + Vector3(0, 1.5, 0), s0 + Vector3(0.9, 1.9, 1.9), white)
	_box(PLASTER, s0 + Vector3(0.45, 0.6, 1.9), s0 + Vector3(1.15, 1.05, 1.92), dark)
	_box(WOOD, s0 + Vector3(0.4, 0.55, 1.9), s0 + Vector3(1.2, 0.6, 1.95), Color(0.2, 0.2, 0.2))
	_box(PLASTER, s0 + Vector3(0.2, 1.9, 0.2), s0 + Vector3(0.7, inner_size.y, 0.7), white)

	# Стол у стены и две табуретки
	var tx := x0 + 0.15
	var tz := z0 + 3.0
	_table(Vector3(tx, 0, tz), Vector3(tx + 0.7, 0.75, tz + 1.1), brown)
	_stool(Vector3(tx + 1.0, 0, tz + 0.25), brown)
	_stool(Vector3(tx + 1.0, 0, tz + 0.85), brown)

	# Кухонный шкафчик с полкой над ним у перегородки
	var cx := x1 - wall_thickness * 0.5 - 0.5
	_solid(WOOD, Vector3(cx, 0, z0 + 0.2), Vector3(cx + 0.5, 0.85, z0 + 1.1), brown)
	_box(WOOD, Vector3(cx - 0.02, 0.85, z0 + 0.18), Vector3(cx + 0.52, 0.89, z0 + 1.12), brown.lightened(0.15))
	_box(WOOD, Vector3(cx + 0.2, 1.5, z0 + 0.2), Vector3(cx + 0.5, 1.53, z0 + 1.1), brown)

	# Половик у входа
	_rug(Vector3(entrance_offset - 0.6, 0, inner_size.z * 0.5 - 1.3), Vector3(entrance_offset + 0.6, 0, inner_size.z * 0.5 - 0.3), Color(0.55, 0.25, 0.2))


# --- Комната --------------------------------------------------------------

func _build_room() -> void:
	var x0 := _partition_x() + wall_thickness * 0.5
	var x1 := inner_size.x * 0.5
	var z0 := -inner_size.z * 0.5
	var z1 := inner_size.z * 0.5
	var brown := Color(0.45, 0.28, 0.17)

	# Кровать у правой стены: каркас, матрас, одеяло, подушка
	var b0 := Vector3(x1 - 1.0, 0, z0 + 0.1)
	_solid(WOOD, b0, b0 + Vector3(0.95, 0.4, 2.0), brown)
	_box(WOOD, b0 + Vector3(0, 0, 0), b0 + Vector3(0.95, 0.9, 0.06), brown)
	_box(FABRIC, b0 + Vector3(0.05, 0.4, 0.06), b0 + Vector3(0.9, 0.55, 1.95), Color(0.9, 0.9, 0.85))
	_box(FABRIC, b0 + Vector3(0.03, 0.55, 0.6), b0 + Vector3(0.92, 0.6, 1.97), Color(0.3, 0.4, 0.65))
	_box(FABRIC, b0 + Vector3(0.15, 0.55, 0.12), b0 + Vector3(0.8, 0.68, 0.5), Color.WHITE)

	# Шифоньер в углу у входа
	var w0 := Vector3(x1 - 0.6, 0, z1 - 1.3)
	_solid(WOOD, w0, w0 + Vector3(0.6, 2.0, 1.2), brown.darkened(0.1))
	_box(WOOD, w0 + Vector3(-0.01, 0.1, 0.59), w0 + Vector3(0.0, 1.9, 0.61), Color(0.2, 0.12, 0.07))

	# Стол посередине, два стула
	var c := Vector3((x0 + x1) * 0.5 - 0.3, 0, 0.3)
	_table(c + Vector3(-0.5, 0, -0.4), c + Vector3(0.5, 0.75, 0.4), brown)
	_stool(c + Vector3(-0.8, 0, 0.0), brown)
	_stool(c + Vector3(0.8, 0, 0.0), brown)

	# Ковёр на полу и ковёр на стене над кроватью
	_rug(c + Vector3(-1.3, 0, -1.1), c + Vector3(1.3, 0, 1.1), Color(0.6, 0.15, 0.12))
	_box(FABRIC, Vector3(x1 - 0.015, 0.8, z0 + 0.2), Vector3(x1, 2.0, z0 + 2.0), Color(0.55, 0.12, 0.1))

	# Книжная полка на перегородке
	_box(WOOD, Vector3(x0, 1.4, z1 - 2.2), Vector3(x0 + 0.25, 1.43, z1 - 1.2), brown)
	_box(WOOD, Vector3(x0, 1.75, z1 - 2.2), Vector3(x0 + 0.25, 1.78, z1 - 1.2), brown)


# --- Мебель ---------------------------------------------------------------

func _table(mn: Vector3, mx: Vector3, color: Color) -> void:
	var leg := 0.06
	_box(WOOD, Vector3(mn.x - 0.03, mx.y - 0.04, mn.z - 0.03), Vector3(mx.x + 0.03, mx.y, mx.z + 0.03), color.lightened(0.1))
	for p in [Vector2(mn.x, mn.z), Vector2(mx.x - leg, mn.z), Vector2(mn.x, mx.z - leg), Vector2(mx.x - leg, mx.z - leg)]:
		_box(WOOD, Vector3(p.x, 0, p.y), Vector3(p.x + leg, mx.y - 0.04, p.y + leg), color)
	_collide(Vector3(mn.x, 0, mn.z), mx)


func _stool(pos: Vector3, color: Color) -> void:
	var s := 0.36
	var mn := pos - Vector3(s * 0.5, 0, s * 0.5)
	_box(WOOD, mn + Vector3(0, 0.42, 0), mn + Vector3(s, 0.46, s), color.lightened(0.1))
	for p in [Vector2(0.02, 0.02), Vector2(s - 0.06, 0.02), Vector2(0.02, s - 0.06), Vector2(s - 0.06, s - 0.06)]:
		_box(WOOD, mn + Vector3(p.x, 0, p.y), mn + Vector3(p.x + 0.04, 0.42, p.y + 0.04), color)


func _rug(mn: Vector3, mx: Vector3, color: Color) -> void:
	_box(FABRIC, Vector3(mn.x, 0.0, mn.z), Vector3(mx.x, 0.012, mx.z), color)


func _build_lamp() -> void:
	var h := inner_size.y
	for x in [(-inner_size.x * 0.5 + _partition_x()) * 0.5, (_partition_x() + inner_size.x * 0.5) * 0.5]:
		var p := Vector3(x, h, 0)
		_box(WOOD, p + Vector3(-0.01, -0.45, -0.01), p + Vector3(0.01, 0, 0.01), Color(0.1, 0.1, 0.1))
		_box(FABRIC, p + Vector3(-0.2, -0.6, -0.2), p + Vector3(0.2, -0.45, 0.2), Color(0.95, 0.75, 0.4))
		var light := OmniLight3D.new()
		light.position = p + Vector3(0, -0.7, 0)
		light.light_energy = lamp_energy
		light.light_color = Color(1.0, 0.85, 0.65)
		light.omni_range = maxf(inner_size.x, inner_size.z) * 0.6
		light.shadow_enabled = false
		add_child(light)


# --- Геометрия ------------------------------------------------------------

func _solid(surf: int, mn: Vector3, mx: Vector3, color: Color) -> void:
	_box(surf, mn, mx, color)
	_collide(mn, mx)


func _collide(mn: Vector3, mx: Vector3) -> void:
	if not build_collision:
		return
	var shape := BoxShape3D.new()
	shape.size = mx - mn
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = (mn + mx) * 0.5
	_body.add_child(cs)


# Нормаль, «вправо» и «вверх» для каждой грани, глядя на неё снаружи.
const FACES := [
	[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
	[Vector3.LEFT, Vector3.BACK, Vector3.UP],
	[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
	[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
	[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
	[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
]


## Коробка из шести граней. UV считаются в метрах, поэтому текстура не
## растягивается на длинных стенах, а повторяется.
func _box(surf: int, mn: Vector3, mx: Vector3, color: Color, shade_bottom := true) -> void:
	var st := _tools[surf]
	var c := (mn + mx) * 0.5
	var e := (mx - mn) * 0.5
	var tile: float = TILE[surf]
	for f in FACES:
		var n: Vector3 = f[0]
		var r: Vector3 = f[1]
		var u: Vector3 = f[2]
		var fc := c + n * e
		var rr := r * e
		var uu := u * e
		var pts := [fc - rr - uu, fc + rr - uu, fc + rr + uu, fc - rr + uu]
		# Чуть темнее у пола — предмет «стоит», а не висит
		for i in [0, 2, 1, 0, 3, 2]:
			var p: Vector3 = pts[i]
			var k := 1.0
			if shade_bottom:
				k = lerpf(0.78, 1.0, clampf(p.y / 0.8, 0.0, 1.0))
			st.set_color(Color(color.r * k, color.g * k, color.b * k))
			st.set_normal(n)
			st.set_uv(Vector2(p.dot(r), -p.dot(u)) / tile)
			st.add_vertex(p)


# --- Текстуры -------------------------------------------------------------

func _make_materials() -> Array[StandardMaterial3D]:
	var list: Array[StandardMaterial3D] = []
	var gens := [_tex_wallpaper, _tex_floor, _tex_plaster, _tex_wood, _tex_fabric]
	for g in gens:
		var img: Image = g.call()
		img.generate_mipmaps()
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.9
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		list.append(m)
	return list


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 1977
	return r


## Советские обои: кремовый фон, полосы и мелкий ромбик-цветок.
func _tex_wallpaper() -> Image:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := _rng()
	var base := Color(0.86, 0.8, 0.64)
	var stripe := Color(0.76, 0.68, 0.5)
	var flower := Color(0.55, 0.42, 0.32)
	for y in n:
		for x in n:
			var col := base
			var sx := x % 32
			if sx < 3 or (sx > 13 and sx < 15):
				col = stripe
			var dx := absi((x % 32) - 24)
			var dy := absi((y % 32) - 16)
			if dx + dy < 5 and dx + dy > 1:
				col = flower
			col = col.lerp(Color.WHITE, rng.randf() * 0.04)
			img.set_pixel(x, y, col)
	return img


## Дощатый пол: доски по 16 см с разным тоном, волокна и тёмные швы.
func _tex_floor() -> Image:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := _rng()
	var boards := 6
	var bh := n / boards
	var tones: Array[float] = []
	var offsets: Array[int] = []
	for i in boards:
		tones.append(rng.randf_range(-0.08, 0.08))
		offsets.append(rng.randi_range(0, n))
	for y in n:
		var b := mini(y / bh, boards - 1)
		for x in n:
			var grain := sin((x * 0.05 + y * 0.9 + b * 13.0)) * 0.03 + sin(x * 0.31 + b) * 0.015
			var v := 0.5 + tones[b] + grain + rng.randf() * 0.03
			var col := Color(v * 1.05, v * 0.72, v * 0.45)
			if y % bh == 0 or (x + offsets[b]) % n == 0:
				col = col.darkened(0.55)
			img.set_pixel(x, y, col)
	return img


## Побелка: почти белая, с лёгкими пятнами.
func _tex_plaster() -> Image:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := _rng()
	for y in n:
		for x in n:
			var v := 0.93 + rng.randf() * 0.06 + sin(x * 0.2) * sin(y * 0.17) * 0.02
			img.set_pixel(x, y, Color(v, v, v * 0.98))
	return img


## Дерево для мебели: светлое, с волокнами. Цвет задаётся цветом вершин.
func _tex_wood() -> Image:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := _rng()
	for y in n:
		for x in n:
			var ring := sin(y * 0.35 + sin(x * 0.08) * 2.5) * 0.08
			var v := 0.9 + ring + rng.randf() * 0.04
			img.set_pixel(x, y, Color(v, v * 0.95, v * 0.9))
	return img


## Ткань: мелкое плетение и клетка, цвет задаётся цветом вершин.
func _tex_fabric() -> Image:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := _rng()
	for y in n:
		for x in n:
			var v := 0.85
			if (x + y) % 2 == 0:
				v += 0.06
			if (x / 8 + y / 8) % 2 == 0:
				v -= 0.08
			v += rng.randf() * 0.04
			img.set_pixel(x, y, Color(v, v, v))
	return img
