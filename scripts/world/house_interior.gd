class_name HouseInterior
extends Node3D
## Интерьер дома: кухня и комната, разделённые перегородкой.
## Обстановка зависит от достатка двора — как в деревне из README:
##   POOR   — бревенчатые стены, дощатый потолок, лавка, сундук, голая лампочка;
##   MIDDLE — обои, побелка, русская печь, шифоньер, ковёр на стене;
##   RICH   — бордовые обои, паркет, кухонный гарнитур с плитой и холодильником,
##            стенка с телевизором, диван, двуспальная кровать, люстра.
##
## Стены — настоящие коробки с толщиной, поэтому изнутри они непрозрачные
## (у тонкой наружной стены изнутри видна изнанка, которую видеокарта
## отбрасывает, и стена кажется прозрачной).
##
## Всё строится в ОДИН меш с пятью поверхностями — по одной на текстуру
## (стены, пол, побелка, дерево, ткань). Это 5 вызовов отрисовки на весь
## интерьер, сколько бы мебели ни было. Текстуры рисуются кодом при старте,
## файлов-картинок не нужно.
##
## Как поставить: добавить Node3D внутрь дома, повесить этот скрипт,
## выставить position на уровень пола, а inner_size — чуть меньше внутреннего
## размера дома. Вход — в стене со стороны +Z.

enum Wealth { POOR, MIDDLE, RICH }

@export var wealth := Wealth.MIDDLE
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

enum { WALLS, FLOOR, PLASTER, WOOD, FABRIC }

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
	match wealth:
		Wealth.POOR:
			_kitchen_poor()
			_room_poor()
		Wealth.RICH:
			_kitchen_rich()
			_room_rich()
		_:
			_kitchen_middle()
			_room_middle()
	_build_lamps()

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

	# Пол и потолок. У бедного дома потолок дощатый, у остальных побелка.
	_box(FLOOR, Vector3(-hx - t, -0.06, -hz - t), Vector3(hx + t, 0.0, hz + t), Color.WHITE)
	_collide(Vector3(-hx - t, -0.3, -hz - t), Vector3(hx + t, 0.0, hz + t))
	var ceiling := Vector3(hx + t, h + 0.06, hz + t)
	if wealth == Wealth.POOR:
		_box(WOOD, Vector3(-hx - t, h, -hz - t), ceiling, Color(0.55, 0.42, 0.3), false)
		# Матица — балка поперёк потолка
		_box(WOOD, Vector3(-hx, h - 0.18, -0.1), Vector3(hx, h, 0.1), Color(0.4, 0.3, 0.2))
	else:
		_box(PLASTER, Vector3(-hx - t, h, -hz - t), ceiling, Color(0.97, 0.96, 0.93), false)

	# Наружные стены. Стена ставится снаружи от inner_size, внутрь смотрит отделкой.
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
	var wood := _trim_color()

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
	var box := _piece_box(WALLS, a, dir, across, s0, s1, y0, y1, Color.WHITE)
	_collide(box[0], box[1])
	if y0 < 0.01 and wealth != Wealth.POOR:
		# Плинтус на уровне пола; в срубе его нет
		var skirt := across + across.normalized() * 0.015
		_piece_box(WOOD, a, dir, skirt, s0, s1, 0.0, 0.08, _trim_color().darkened(0.2))


func _piece_box(surf: int, a: Vector3, dir: Vector3, across: Vector3, s0: float, s1: float, y0: float, y1: float, color: Color) -> Array:
	var p0 := a + dir * s0
	var p1 := a + dir * s1
	var mn := Vector3(minf(p0.x, p1.x), y0, minf(p0.z, p1.z)) - across
	var mx := Vector3(maxf(p0.x, p1.x), y1, maxf(p0.z, p1.z)) + across
	_box(surf, mn, mx, color)
	return [mn, mx]


func _trim_color() -> Color:
	match wealth:
		Wealth.POOR:
			return Color(0.42, 0.33, 0.24)
		Wealth.RICH:
			return Color(0.35, 0.18, 0.1)
	return Color(0.55, 0.36, 0.22)


# Границы комнат (внутренние поверхности стен).
func _kitchen_rect() -> Rect2:
	var x0 := -inner_size.x * 0.5
	var x1 := _partition_x() - wall_thickness * 0.5
	return Rect2(x0, -inner_size.z * 0.5, x1 - x0, inner_size.z)


func _room_rect() -> Rect2:
	var x0 := _partition_x() + wall_thickness * 0.5
	return Rect2(x0, -inner_size.z * 0.5, inner_size.x * 0.5 - x0, inner_size.z)


# --- Бедный двор ----------------------------------------------------------

func _kitchen_poor() -> void:
	var k := _kitchen_rect()
	var wood := Color(0.5, 0.38, 0.26)
	_russian_stove(Vector3(k.position.x, 0, k.position.y), Color(0.82, 0.8, 0.74))

	# Стол и лавка вдоль стены
	var tz := k.position.y + 3.0
	_table(Vector3(k.position.x + 0.15, 0, tz), Vector3(k.position.x + 0.85, 0.75, tz + 1.1), wood)
	_bench(Vector3(k.position.x + 1.0, 0, tz - 0.1), Vector3(k.position.x + 1.3, 0.45, tz + 1.2), wood)

	# Полка-воронец над столом и ведро у входа
	_box(WOOD, Vector3(k.position.x, 1.7, tz - 0.2), Vector3(k.position.x + 0.3, 1.74, tz + 1.3), wood)
	var bx := entrance_offset - door_width * 0.5 - 0.35
	var bz := inner_size.z * 0.5 - 0.35
	_box(WOOD, Vector3(bx - 0.14, 0, bz - 0.14), Vector3(bx + 0.14, 0.32, bz + 0.14), Color(0.55, 0.57, 0.6))
	_box(FABRIC, Vector3(bx - 0.12, 0.3, bz - 0.12), Vector3(bx + 0.12, 0.31, bz + 0.12), Color(0.3, 0.4, 0.45))

	_rug(Vector3(entrance_offset - 0.4, 0, inner_size.z * 0.5 - 1.8), Vector3(entrance_offset + 0.4, 0, inner_size.z * 0.5 - 0.2), Color(0.5, 0.45, 0.35))


func _room_poor() -> void:
	var r := _room_rect()
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var wood := Color(0.5, 0.38, 0.26)

	# Железная кровать: тонкие спинки и сетка, серое одеяло
	var b0 := Vector3(x1 - 0.95, 0, z0 + 0.1)
	var iron := Color(0.25, 0.27, 0.3)
	_box(WOOD, b0, b0 + Vector3(0.9, 0.45, 1.95), iron)
	_collide(b0, b0 + Vector3(0.9, 0.45, 1.95))
	_box(WOOD, b0 + Vector3(0, 0, -0.03), b0 + Vector3(0.9, 0.95, 0.0), iron)
	_box(WOOD, b0 + Vector3(0, 0, 1.95), b0 + Vector3(0.9, 0.75, 1.98), iron)
	_box(FABRIC, b0 + Vector3(0.03, 0.45, 0.02), b0 + Vector3(0.87, 0.58, 1.93), Color(0.5, 0.5, 0.48))
	_box(FABRIC, b0 + Vector3(0.15, 0.58, 0.08), b0 + Vector3(0.75, 0.7, 0.45), Color(0.85, 0.83, 0.78))

	# Сундук у стены
	var c0 := Vector3(r.position.x + 0.1, 0, z1 - 1.3)
	_solid(WOOD, c0, c0 + Vector3(0.55, 0.55, 1.0), Color(0.45, 0.25, 0.15))
	_box(WOOD, c0 + Vector3(-0.01, 0.1, 0.1), c0 + Vector3(0.56, 0.14, 0.9), Color(0.2, 0.2, 0.2))
	_box(WOOD, c0 + Vector3(-0.01, 0.42, 0.1), c0 + Vector3(0.56, 0.46, 0.9), Color(0.2, 0.2, 0.2))

	# Простой стол с табуреткой и половик
	var c := Vector3(r.get_center().x - 0.2, 0, 0.5)
	_table(c + Vector3(-0.45, 0, -0.35), c + Vector3(0.45, 0.75, 0.35), wood)
	_stool(c + Vector3(0.75, 0, 0.0), wood)
	_rug(Vector3(r.position.x + 0.8, 0, z0 + 0.5), Vector3(r.position.x + 1.6, 0, z1 - 0.5), Color(0.55, 0.35, 0.3))

	# Иконная полочка в углу
	_box(WOOD, Vector3(x1 - 0.35, 1.8, z1 - 0.35), Vector3(x1, 1.83, z1), wood)
	_box(FABRIC, Vector3(x1 - 0.22, 1.83, z1 - 0.06), Vector3(x1 - 0.06, 2.05, z1 - 0.02), Color(0.8, 0.6, 0.25))


# --- Средний двор ---------------------------------------------------------

func _kitchen_middle() -> void:
	var k := _kitchen_rect()
	var x0 := k.position.x
	var z0 := k.position.y
	var brown := Color(0.5, 0.32, 0.2)

	_russian_stove(Vector3(x0, 0, z0), Color(0.95, 0.94, 0.9))

	# Стол у стены и две табуретки
	var tx := x0 + 0.15
	var tz := z0 + 3.0
	_table(Vector3(tx, 0, tz), Vector3(tx + 0.7, 0.75, tz + 1.1), brown)
	_stool(Vector3(tx + 1.0, 0, tz + 0.25), brown)
	_stool(Vector3(tx + 1.0, 0, tz + 0.85), brown)

	# Кухонный шкафчик с полкой над ним у перегородки
	var cx := k.end.x - 0.5
	_solid(WOOD, Vector3(cx, 0, z0 + 0.2), Vector3(cx + 0.5, 0.85, z0 + 1.1), brown)
	_box(WOOD, Vector3(cx - 0.02, 0.85, z0 + 0.18), Vector3(cx + 0.52, 0.89, z0 + 1.12), brown.lightened(0.15))
	_box(WOOD, Vector3(cx + 0.2, 1.5, z0 + 0.2), Vector3(cx + 0.5, 1.53, z0 + 1.1), brown)

	# Половик у входа
	_rug(Vector3(entrance_offset - 0.6, 0, inner_size.z * 0.5 - 1.3), Vector3(entrance_offset + 0.6, 0, inner_size.z * 0.5 - 0.3), Color(0.55, 0.25, 0.2))


func _room_middle() -> void:
	var r := _room_rect()
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var brown := Color(0.45, 0.28, 0.17)

	# Кровать у правой стены: каркас, матрас, одеяло, подушка
	var b0 := Vector3(x1 - 1.0, 0, z0 + 0.1)
	_solid(WOOD, b0, b0 + Vector3(0.95, 0.4, 2.0), brown)
	_box(WOOD, b0, b0 + Vector3(0.95, 0.9, 0.06), brown)
	_box(FABRIC, b0 + Vector3(0.05, 0.4, 0.06), b0 + Vector3(0.9, 0.55, 1.95), Color(0.9, 0.9, 0.85))
	_box(FABRIC, b0 + Vector3(0.03, 0.55, 0.6), b0 + Vector3(0.92, 0.6, 1.97), Color(0.3, 0.4, 0.65))
	_box(FABRIC, b0 + Vector3(0.15, 0.55, 0.12), b0 + Vector3(0.8, 0.68, 0.5), Color.WHITE)

	# Шифоньер в углу у входа
	var w0 := Vector3(x1 - 0.6, 0, z1 - 1.3)
	_solid(WOOD, w0, w0 + Vector3(0.6, 2.0, 1.2), brown.darkened(0.1))
	_box(WOOD, w0 + Vector3(-0.01, 0.1, 0.59), w0 + Vector3(0.0, 1.9, 0.61), Color(0.2, 0.12, 0.07))

	# Стол посередине, два стула
	var c := Vector3(r.get_center().x - 0.3, 0, 0.3)
	_table(c + Vector3(-0.5, 0, -0.4), c + Vector3(0.5, 0.75, 0.4), brown)
	_stool(c + Vector3(-0.8, 0, 0.0), brown)
	_stool(c + Vector3(0.8, 0, 0.0), brown)

	# Ковёр на полу и ковёр на стене над кроватью
	_rug(c + Vector3(-1.3, 0, -1.1), c + Vector3(1.3, 0, 1.1), Color(0.6, 0.15, 0.12))
	_box(FABRIC, Vector3(x1 - 0.015, 0.8, z0 + 0.2), Vector3(x1, 2.0, z0 + 2.0), Color(0.55, 0.12, 0.1))

	# Книжная полка на перегородке
	_box(WOOD, Vector3(x0, 1.4, z1 - 2.2), Vector3(x0 + 0.25, 1.43, z1 - 1.2), brown)
	_box(WOOD, Vector3(x0, 1.75, z1 - 2.2), Vector3(x0 + 0.25, 1.78, z1 - 1.2), brown)


# --- Зажиточный двор ------------------------------------------------------

func _kitchen_rich() -> void:
	var k := _kitchen_rect()
	var x0 := k.position.x
	var z0 := k.position.y
	var white := Color(0.93, 0.93, 0.9)
	var front := Color(0.85, 0.8, 0.7)
	var dark := Color(0.12, 0.12, 0.12)

	# Холодильник в углу
	_solid(PLASTER, Vector3(x0, 0, z0), Vector3(x0 + 0.6, 1.75, z0 + 0.62), white)
	_box(WOOD, Vector3(x0 + 0.5, 0.9, z0 + 0.62), Vector3(x0 + 0.54, 1.3, z0 + 0.66), Color(0.7, 0.7, 0.72))

	# Гарнитур вдоль задней стены: тумбы, столешница, газовая плита, навесные шкафы
	var gx0 := x0 + 0.65
	var gx1 := k.end.x - 0.1
	_solid(WOOD, Vector3(gx0, 0, z0), Vector3(gx1, 0.86, z0 + 0.6), front)
	_box(WOOD, Vector3(gx0 - 0.02, 0.86, z0), Vector3(gx1 + 0.02, 0.9, z0 + 0.63), Color(0.4, 0.4, 0.42))
	var sx := gx0 + 0.6
	_box(PLASTER, Vector3(sx, 0, z0 + 0.02), Vector3(sx + 0.5, 0.9, z0 + 0.61), white)
	_box(PLASTER, Vector3(sx + 0.03, 0.12, z0 + 0.61), Vector3(sx + 0.47, 0.6, z0 + 0.62), dark)
	for p in [Vector2(0.13, 0.17), Vector2(0.37, 0.17), Vector2(0.13, 0.43), Vector2(0.37, 0.43)]:
		_box(PLASTER, Vector3(sx + p.x - 0.07, 0.9, z0 + p.y - 0.07), Vector3(sx + p.x + 0.07, 0.915, z0 + p.y + 0.07), dark)
	_box(WOOD, Vector3(gx0, 1.45, z0), Vector3(gx1, 2.15, z0 + 0.35), front)
	# Щели между дверцами
	var x := gx0 + 0.5
	while x < gx1 - 0.1:
		_box(WOOD, Vector3(x - 0.005, 0.05, z0 + 0.6), Vector3(x + 0.005, 0.82, z0 + 0.605), dark)
		_box(WOOD, Vector3(x - 0.005, 1.48, z0 + 0.35), Vector3(x + 0.005, 2.12, z0 + 0.355), dark)
		x += 0.5

	# Обеденный стол с четырьмя стульями
	var brown := Color(0.4, 0.22, 0.12)
	var c := Vector3(x0 + 0.95, 0, z0 + 3.7)
	_table(c + Vector3(-0.45, 0, -0.6), c + Vector3(0.45, 0.76, 0.6), brown)
	for p in [Vector3(-0.72, 0, -0.3), Vector3(-0.72, 0, 0.3), Vector3(0.72, 0, -0.3), Vector3(0.72, 0, 0.3)]:
		_chair(c + p, brown, signf(p.x))

	_rug(Vector3(entrance_offset - 0.6, 0, inner_size.z * 0.5 - 1.3), Vector3(entrance_offset + 0.6, 0, inner_size.z * 0.5 - 0.3), Color(0.35, 0.3, 0.45))


func _room_rich() -> void:
	var r := _room_rect()
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var lacquer := Color(0.35, 0.18, 0.1)

	# Стенка вдоль задней стены: два шкафа по краям, посередине тумба,
	# открытая ниша с телевизором и антресоль
	var s0 := Vector3(x0 + 0.1, 0, z0)
	var s1 := Vector3(x0 + 2.8, 2.2, z0 + 0.5)
	var seam := Color(0.15, 0.08, 0.04)
	_solid(WOOD, s0, Vector3(s0.x + 0.9, s1.y, s1.z), lacquer)
	_solid(WOOD, Vector3(s0.x + 1.8, 0, z0), s1, lacquer)
	_solid(WOOD, Vector3(s0.x + 0.9, 0, z0), Vector3(s0.x + 1.8, 0.5, s1.z), lacquer)
	_box(WOOD, Vector3(s0.x + 0.9, 1.6, z0), Vector3(s0.x + 1.8, s1.y, s1.z), lacquer)
	_box(WOOD, Vector3(s0.x + 0.9, 0.5, z0), Vector3(s0.x + 1.8, 1.6, z0 + 0.03), seam)
	# Телевизор на тумбе: корпус и серый экран
	_box(PLASTER, Vector3(s0.x + 1.05, 0.5, z0 + 0.08), Vector3(s0.x + 1.65, 0.98, z0 + 0.48), Color(0.15, 0.15, 0.16))
	_box(PLASTER, Vector3(s0.x + 1.1, 0.56, z0 + 0.48), Vector3(s0.x + 1.5, 0.92, z0 + 0.49), Color(0.3, 0.36, 0.4))
	# Стеклянные дверцы в боковых шкафах и щели между дверцами
	for gx0 in [s0.x + 0.1, s0.x + 1.9]:
		_box(PLASTER, Vector3(gx0, 1.1, z0 + 0.5), Vector3(gx0 + 0.7, 1.9, z0 + 0.505), Color(0.55, 0.65, 0.7))
	for gx in [s0.x + 0.45, s0.x + 2.25]:
		_box(WOOD, Vector3(gx - 0.005, 0.05, z0 + 0.5), Vector3(gx + 0.005, 2.15, z0 + 0.51), seam)

	# Диван напротив телевизора
	var d := Vector3(s0.x + 1.35, 0, z0 + 2.4)
	var fabric := Color(0.35, 0.4, 0.3)
	_solid(FABRIC, d + Vector3(-0.95, 0, -0.45), d + Vector3(0.95, 0.42, 0.45), fabric)
	_box(FABRIC, d + Vector3(-0.95, 0.42, 0.25), d + Vector3(0.95, 0.85, 0.45), fabric)
	_box(FABRIC, d + Vector3(-1.1, 0, -0.45), d + Vector3(-0.95, 0.6, 0.45), fabric.darkened(0.1))
	_box(FABRIC, d + Vector3(0.95, 0, -0.45), d + Vector3(1.1, 0.6, 0.45), fabric.darkened(0.1))

	# Журнальный столик
	var t := d + Vector3(0, 0, -1.1)
	_table(t + Vector3(-0.4, 0, -0.25), t + Vector3(0.4, 0.45, 0.25), lacquer)

	# Двуспальная кровать у правой стены
	var b0 := Vector3(x1 - 1.6, 0, z0 + 0.1)
	_solid(WOOD, b0, b0 + Vector3(1.6, 0.42, 2.0), lacquer)
	_box(WOOD, b0, b0 + Vector3(1.6, 1.1, 0.08), lacquer)
	_box(FABRIC, b0 + Vector3(0.05, 0.42, 0.08), b0 + Vector3(1.55, 0.58, 1.95), Color(0.95, 0.93, 0.88))
	_box(FABRIC, b0 + Vector3(0.03, 0.58, 0.7), b0 + Vector3(1.57, 0.64, 1.97), Color(0.6, 0.3, 0.35))
	_box(FABRIC, b0 + Vector3(0.12, 0.58, 0.14), b0 + Vector3(0.72, 0.72, 0.5), Color.WHITE)
	_box(FABRIC, b0 + Vector3(0.88, 0.58, 0.14), b0 + Vector3(1.48, 0.72, 0.5), Color.WHITE)

	# Шифоньер у входа, большой ковёр, ковёр на стене
	var w0 := Vector3(x1 - 0.6, 0, z1 - 1.5)
	_solid(WOOD, w0, w0 + Vector3(0.6, 2.1, 1.4), lacquer)
	_box(WOOD, w0 + Vector3(-0.01, 0.1, 0.69), w0 + Vector3(0.0, 2.0, 0.71), Color(0.1, 0.05, 0.03))
	_rug(Vector3(x0 + 0.3, 0, z0 + 0.8), Vector3(x0 + 2.6, 0, z0 + 3.1), Color(0.55, 0.1, 0.1))
	_box(FABRIC, Vector3(x1 - 0.015, 0.8, z0 + 0.3), Vector3(x1, 2.1, z0 + 2.2), Color(0.5, 0.1, 0.12))


# --- Мебель ---------------------------------------------------------------

## Русская печь: основание, лежанка, топка с заслонкой, труба в потолок.
func _russian_stove(s0: Vector3, color: Color) -> void:
	var dark := Color(0.12, 0.1, 0.09)
	_solid(PLASTER, s0, s0 + Vector3(1.6, 1.5, 1.9), color)
	_solid(PLASTER, s0 + Vector3(0, 1.5, 0), s0 + Vector3(0.9, 1.9, 1.9), color)
	_box(PLASTER, s0 + Vector3(0.45, 0.6, 1.9), s0 + Vector3(1.15, 1.05, 1.92), dark)
	_box(WOOD, s0 + Vector3(0.4, 0.55, 1.9), s0 + Vector3(1.2, 0.6, 1.95), Color(0.2, 0.2, 0.2))
	_box(PLASTER, s0 + Vector3(0.2, 1.9, 0.2), s0 + Vector3(0.7, inner_size.y, 0.7), color)


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


## Стул со спинкой; side = -1 — спинка слева (по X), +1 — справа.
func _chair(pos: Vector3, color: Color, side: float) -> void:
	_stool(pos, color)
	var bx := pos.x + side * 0.16
	_box(WOOD, Vector3(bx - 0.02, 0.46, pos.z - 0.18), Vector3(bx + 0.02, 0.95, pos.z + 0.18), color)


func _bench(mn: Vector3, mx: Vector3, color: Color) -> void:
	_box(WOOD, Vector3(mn.x, mx.y - 0.05, mn.z), mx, color.lightened(0.1))
	for z in [mn.z + 0.05, mx.z - 0.1]:
		_box(WOOD, Vector3(mn.x + 0.03, 0, z), Vector3(mx.x - 0.03, mx.y - 0.05, z + 0.05), color)
	_collide(mn, mx)


func _rug(mn: Vector3, mx: Vector3, color: Color) -> void:
	_box(FABRIC, Vector3(mn.x, 0.0, mn.z), Vector3(mx.x, 0.012, mx.z), color)


func _build_lamps() -> void:
	var h := inner_size.y
	var k := _kitchen_rect()
	var r := _room_rect()
	for x in [k.get_center().x, r.get_center().x]:
		var p := Vector3(x, h, 0)
		var energy := lamp_energy
		match wealth:
			Wealth.POOR:
				# Голая лампочка на проводе — тусклее
				_box(WOOD, p + Vector3(-0.005, -0.5, -0.005), p + Vector3(0.005, 0, 0.005), Color(0.1, 0.1, 0.1))
				_box(PLASTER, p + Vector3(-0.04, -0.6, -0.04), p + Vector3(0.04, -0.5, 0.04), Color(1.0, 0.95, 0.7))
				energy *= 0.7
			Wealth.RICH:
				# Люстра: штанга, диск и три плафона
				_box(WOOD, p + Vector3(-0.01, -0.35, -0.01), p + Vector3(0.01, 0, 0.01), Color(0.7, 0.6, 0.3))
				_box(WOOD, p + Vector3(-0.3, -0.38, -0.3), p + Vector3(0.3, -0.35, 0.3), Color(0.7, 0.6, 0.3))
				for a in 3:
					var o := Vector3(cos(a * TAU / 3.0), 0, sin(a * TAU / 3.0)) * 0.25
					_box(PLASTER, p + o + Vector3(-0.08, -0.55, -0.08), p + o + Vector3(0.08, -0.38, 0.08), Color(1.0, 0.95, 0.85))
				energy *= 1.3
			_:
				_box(WOOD, p + Vector3(-0.01, -0.45, -0.01), p + Vector3(0.01, 0, 0.01), Color(0.1, 0.1, 0.1))
				_box(FABRIC, p + Vector3(-0.2, -0.6, -0.2), p + Vector3(0.2, -0.45, 0.2), Color(0.95, 0.75, 0.4))
		var light := OmniLight3D.new()
		light.position = p + Vector3(0, -0.7, 0)
		light.light_energy = energy
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


## Сколько метров покрывает одна копия текстуры поверхности.
func _tile(surf: int) -> float:
	match surf:
		WALLS:
			return 0.88 if wealth == Wealth.POOR else 0.6
		FLOOR:
			return 1.2 if wealth == Wealth.POOR else 1.0
		WOOD:
			return 0.8
		FABRIC:
			return 0.5
	return 1.0


## Коробка из шести граней. UV считаются в метрах, поэтому текстура не
## растягивается на длинных стенах, а повторяется.
func _box(surf: int, mn: Vector3, mx: Vector3, color: Color, shade_bottom := true) -> void:
	var st := _tools[surf]
	var c := (mn + mx) * 0.5
	var e := (mx - mn) * 0.5
	var tile := _tile(surf)
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
	var walls: Callable
	var floor_tex: Callable
	match wealth:
		Wealth.POOR:
			walls = _tex_logs
			floor_tex = _tex_boards.bind(4, Color(0.85, 0.72, 0.55))
		Wealth.RICH:
			walls = _tex_damask
			floor_tex = _tex_parquet
		_:
			walls = _tex_wallpaper
			floor_tex = _tex_boards.bind(6, Color(1.05, 0.72, 0.45))
	var list: Array[StandardMaterial3D] = []
	for g in [walls, floor_tex, _tex_plaster, _tex_wood, _tex_fabric]:
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


## Бордовые обои с золотистым узором в ромб — для зажиточного дома.
func _tex_damask() -> Image:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := _rng()
	var base := Color(0.42, 0.1, 0.1)
	var gold := Color(0.72, 0.56, 0.3)
	for y in n:
		for x in n:
			var col := base
			var dx := absi((x % 32) - 16)
			var dy := absi((y % 64) - 32)
			var d := dx * 2 + dy
			if d == 28 or d == 29 or (d < 8 and d > 4):
				col = gold
			elif (x % 32) == 0:
				col = base.darkened(0.2)
			col = col.lerp(Color.BLACK, rng.randf() * 0.06)
			img.set_pixel(x, y, col)
	return img


## Сруб изнутри: четыре бревна на текстуру, круглые с тенью у пазов,
## в пазах светлая пакля.
func _tex_logs() -> Image:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := _rng()
	var logs := 4
	var lh := n / logs
	for y in n:
		var row := mini(y / lh, logs - 1)
		var t := float(y % lh) / lh
		var bulge := sin(t * PI)
		for x in n:
			var grain := sin(x * 0.12 + row * 7.0 + sin(x * 0.03) * 3.0) * 0.04
			var v := 0.35 + bulge * 0.4 + grain + rng.randf() * 0.04
			var col := Color(v * 1.0, v * 0.78, v * 0.55)
			if t < 0.06 or t > 0.94:
				col = Color(0.62, 0.55, 0.4).lerp(Color.BLACK, rng.randf() * 0.2)
			img.set_pixel(x, y, col)
	return img


## Дощатый пол: доски с разным тоном, волокна и тёмные швы.
func _tex_boards(boards: int, tint: Color) -> Image:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := _rng()
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
			var col := Color(v * tint.r, v * tint.g, v * tint.b)
			if y % bh == 0 or (x + offsets[b]) % n == 0:
				col = col.darkened(0.55)
			img.set_pixel(x, y, col)
	return img


## Паркет «ёлочкой»-квадратами: квадраты по 4 планки, направление чередуется.
func _tex_parquet() -> Image:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := _rng()
	var cell := 64
	var plank := 16
	var tones: Array[float] = []
	for i in 256:
		tones.append(rng.randf_range(-0.1, 0.1))
	for y in n:
		for x in n:
			var cx := x / cell
			var cy := y / cell
			var along := x if (cx + cy) % 2 == 0 else y
			var across := y if (cx + cy) % 2 == 0 else x
			var idx := ((cx * 7 + cy * 13) * 4 + (across % cell) / plank) % tones.size()
			var v := 0.6 + tones[idx] + sin(along * 0.4 + idx) * 0.03 + rng.randf() * 0.03
			var col := Color(v * 1.15, v * 0.75, v * 0.42)
			if across % plank == 0 or x % cell == 0 or y % cell == 0:
				col = col.darkened(0.5)
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
