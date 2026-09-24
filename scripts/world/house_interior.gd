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
## Окна — настоящие проёмы с рамой, переплётом, подоконником, стеклом
## и занавесками (у бедных — короткая занавеска, у средних — тюль и шторы,
## у зажиточных — тюль, тяжёлые портьеры и ламбрекен).
##
## Двери — настоящие створки на петлях: открываются сами, когда к ним
## подходит персонаж, и закрываются за ним. Входная дверь у среднего и
## зажиточного дома обита дерматином с гвоздиками, как в СССР.
##
## Всё строится в ОДИН меш с шестью поверхностями — по одной на текстуру
## (стены, пол, побелка, дерево, ткань) и полупрозрачная для стекла и тюля.
## Это 6 вызовов отрисовки на весь интерьер, сколько бы мебели ни было. Текстуры рисуются кодом при старте,
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
## Окна в наружных стенах. Изнутри сквозь них виден мир снаружи.
@export var windows := true
@export var window_size := Vector2(1.0, 1.2)
@export var window_sill_height := 0.9
## Двери сами открываются перед персонажем и закрываются за ним.
@export var auto_doors := true

enum { WALLS, FLOOR, PLASTER, WOOD, FABRIC, GLASS }

var _tools: Array[SurfaceTool] = []
var _mats: Array[StandardMaterial3D] = []
var _body: StaticBody3D


func _ready() -> void:
	build()


func build() -> void:
	for c in get_children():
		c.queue_free()
	_mats = _make_materials()
	_tools = _new_tools()

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
	_details()
	_build_lamps()

	var mi := MeshInstance3D.new()
	mi.name = "InteriorMesh"
	mi.mesh = _commit(_tools)
	add_child(mi)
	_tools.clear()


func _new_tools() -> Array[SurfaceTool]:
	var list: Array[SurfaceTool] = []
	for i in 6:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		list.append(st)
	return list


## Собирает меш из поверхностей; пустые пропускаются.
func _commit(tools: Array[SurfaceTool]) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for i in tools.size():
		var arrays := tools[i].commit_to_arrays()
		var verts = arrays[Mesh.ARRAY_VERTEX]
		if verts == null or verts.size() == 0:
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mats[i])
	return mesh


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
	# Проём: [расстояние от начала стены, ширина, верх, низ]. Низ 0 — дверь.
	var front := [[hx + t + entrance_offset, door_width, door_height, 0.0]]
	var left := []
	var right := []
	if windows:
		var wy0 := window_sill_height
		var wy1 := minf(wy0 + window_size.y, inner_size.y - 0.25)
		var ww := window_size.x
		# Кухня: окно над столом в торце и окно слева от входа
		left.append([hz + 0.55, ww, wy1, wy0])
		front.append([hx + t + (-hx + entrance_offset - door_width * 0.5) * 0.5, ww, wy1, wy0])
		# Комната: окно между кроватью и шкафом и окно на улицу по центру
		right.append([hz + 0.3, ww, wy1, wy0])
		front.append([hx + t + _room_rect().get_center().x, ww, wy1, wy0])
	_wall(Vector3(-hx - t, 0, hz + t * 0.5), Vector3(hx + t, 0, hz + t * 0.5), front)
	_wall(Vector3(-hx - t, 0, -hz - t * 0.5), Vector3(hx + t, 0, -hz - t * 0.5), [])
	_wall(Vector3(-hx - t * 0.5, 0, -hz), Vector3(-hx - t * 0.5, 0, hz), left)
	_wall(Vector3(hx + t * 0.5, 0, -hz), Vector3(hx + t * 0.5, 0, hz), right)

	# Перегородка кухня/комната с проходом ближе к задней стене
	var px := _partition_x()
	var pass_z := -hz * 0.45
	_wall(Vector3(px, 0, hz), Vector3(px, 0, -hz), [[hz - pass_z, door_width, door_height, 0.0]])


func _partition_x() -> float:
	return -inner_size.x * 0.5 + inner_size.x * partition_at


## Стена вдоль оси X или Z от a до b.
## openings: [[расстояние от a, ширина, верх, низ], ...]; низ 0 — дверь, иначе окно.
func _wall(a: Vector3, b: Vector3, openings: Array) -> void:
	var h := inner_size.y
	var t := wall_thickness
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var across := Vector3(absf(dir.z), 0, absf(dir.x)) * t * 0.5
	var wood := _trim_color()
	# Куда смотрит внутренняя сторона: к центру дома. У перегородки — ноль.
	var mid := (a + b) * 0.5
	var inward := -(mid * across.normalized())
	inward = inward.normalized() if inward.length() > 0.5 else Vector3.ZERO

	openings.sort_custom(func(p, q): return p[0] < q[0])
	var cursor := 0.0
	for o in openings:
		var o0: float = o[0] - o[1] * 0.5
		var o1: float = o[0] + o[1] * 0.5
		var top: float = o[2]
		var bottom: float = o[3]
		_wall_piece(a, dir, across, cursor, o0, 0.0, h)
		_wall_piece(a, dir, across, o0, o1, top, h)
		if bottom > 0.0:
			_wall_piece(a, dir, across, o0, o1, 0.0, bottom)
			_window(a, dir, across, inward, o0, o1, bottom, top)
		else:
			# Наличник: два косяка и перекладина, чуть толще стены
			var jamb := across + across.normalized() * 0.02
			_piece_box(WOOD, a, dir, jamb, o0 - 0.07, o0, 0.0, top + 0.07, wood)
			_piece_box(WOOD, a, dir, jamb, o1, o1 + 0.07, 0.0, top + 0.07, wood)
			_piece_box(WOOD, a, dir, jamb, o0, o1, top, top + 0.07, wood)
			# Выключатель рядом с дверью, с обеих сторон стены
			var sw := Color(0.15, 0.13, 0.12) if wealth == Wealth.POOR else Color(0.95, 0.95, 0.92)
			_piece_box(PLASTER, a, dir, across + across.normalized() * 0.012, o1 + 0.15, o1 + 0.23, 1.35, 1.43, sw)
			var swing := inward if inward != Vector3.ZERO else across.normalized()
			_door(a + dir * o0, dir, swing, o1 - o0, top, absf(inward.z) > 0.5)
		cursor = o1
	_wall_piece(a, dir, across, cursor, length, 0.0, h)


## Окно: наличник, подоконник, переплёт крестом, стекло, занавески, цветок.
func _window(a: Vector3, dir: Vector3, across: Vector3, inward: Vector3, o0: float, o1: float, y0: float, y1: float) -> void:
	var paint := _trim_color() if wealth == Wealth.POOR else Color(0.93, 0.93, 0.9)
	var casing := across + across.normalized() * 0.02
	var w := 0.07
	_piece_box(WOOD, a, dir, casing, o0 - w, o0, y0, y1 + w, paint)
	_piece_box(WOOD, a, dir, casing, o1, o1 + w, y0, y1 + w, paint)
	_piece_box(WOOD, a, dir, casing, o0 - w, o1 + w, y1, y1 + w, paint)
	_piece_box(WOOD, a, dir, across + across.normalized() * 0.1, o0 - 0.1, o1 + 0.1, y0 - 0.05, y0, paint.darkened(0.08))
	var thin := across * 0.4
	var mid := (o0 + o1) * 0.5
	var ty := y0 + (y1 - y0) * 0.66
	_piece_box(WOOD, a, dir, thin, mid - 0.025, mid + 0.025, y0, y1, paint)
	_piece_box(WOOD, a, dir, thin, o0, o1, ty - 0.025, ty + 0.025, paint)
	_piece_box(GLASS, a, dir, across * 0.1, o0, o1, y0, y1, Color(0.75, 0.88, 1.0, 0.15))
	if inward == Vector3.ZERO:
		return

	var face := wall_thickness * 0.5
	# Карниз
	_side_box(WOOD, a, dir, inward, o0 - 0.5, o1 + 0.5, y1 + 0.15, y1 + 0.18, face, face + 0.22, _trim_color())
	match wealth:
		Wealth.POOR:
			# Короткая занавеска на нижнюю половину окна
			_side_box(WOOD, a, dir, inward, o0, o1, ty - 0.01, ty + 0.01, face + 0.03, face + 0.05, _trim_color())
			_side_box(FABRIC, a, dir, inward, o0, o1, y0 + 0.05, ty, face + 0.035, face + 0.045, Color(0.92, 0.9, 0.84))
		Wealth.RICH:
			var drape := Color(0.5, 0.1, 0.12)
			_side_box(GLASS, a, dir, inward, o0 - 0.1, o1 + 0.1, 0.1, y1 + 0.15, face + 0.12, face + 0.125, Color(1, 1, 1, 0.5))
			_side_box(FABRIC, a, dir, inward, o0 - 0.45, o0 + 0.05, 0.03, y1 + 0.15, face + 0.13, face + 0.18, drape)
			_side_box(FABRIC, a, dir, inward, o1 - 0.05, o1 + 0.45, 0.03, y1 + 0.15, face + 0.13, face + 0.18, drape)
			_side_box(FABRIC, a, dir, inward, o0 - 0.45, o1 + 0.45, y1 - 0.1, y1 + 0.16, face + 0.18, face + 0.2, Color(0.65, 0.5, 0.25))
			_flower(a, dir, inward, mid - 0.28, y0, face)
			# Чугунная батарея под окном: секции и две трубы
			var rad := Color(0.92, 0.92, 0.9)
			var sx := o0 + 0.08
			while sx < o1 - 0.12:
				_side_box(PLASTER, a, dir, inward, sx, sx + 0.06, 0.15, 0.7, face + 0.03, face + 0.11, rad)
				sx += 0.08
			for py in [0.2, 0.62]:
				_side_box(PLASTER, a, dir, inward, o0 + 0.05, o1 - 0.05, py, py + 0.03, face + 0.06, face + 0.08, rad.darkened(0.1))
		_:
			var side := Color(0.55, 0.6, 0.35)
			_side_box(GLASS, a, dir, inward, o0 - 0.1, o1 + 0.1, y0 - 0.1, y1 + 0.15, face + 0.12, face + 0.125, Color(1, 1, 1, 0.45))
			_side_box(FABRIC, a, dir, inward, o0 - 0.35, o0 - 0.02, y0 - 0.25, y1 + 0.15, face + 0.13, face + 0.16, side)
			_side_box(FABRIC, a, dir, inward, o1 + 0.02, o1 + 0.35, y0 - 0.25, y1 + 0.15, face + 0.13, face + 0.16, side)
			_flower(a, dir, inward, mid - 0.28, y0, face)


## Горшок с цветком на подоконнике.
func _flower(a: Vector3, dir: Vector3, inward: Vector3, s: float, y: float, face: float) -> void:
	_side_box(PLASTER, a, dir, inward, s - 0.06, s + 0.06, y, y + 0.12, face - 0.02, face + 0.08, Color(0.7, 0.35, 0.2))
	_side_box(FABRIC, a, dir, inward, s - 0.09, s + 0.09, y + 0.12, y + 0.3, face - 0.04, face + 0.1, Color(0.2, 0.5, 0.2))


## Коробка у стены: s0..s1 вдоль стены, y0..y1 по высоте,
## d0..d1 — расстояние от середины стены в сторону комнаты.
func _side_box(surf: int, a: Vector3, dir: Vector3, inward: Vector3, s0: float, s1: float, y0: float, y1: float, d0: float, d1: float, color: Color) -> void:
	var p0 := a + dir * s0 + inward * d0
	var p1 := a + dir * s1 + inward * d1
	_box(surf, Vector3(minf(p0.x, p1.x), y0, minf(p0.z, p1.z)), Vector3(maxf(p0.x, p1.x), y1, maxf(p0.z, p1.z)), color)


func _wall_piece(a: Vector3, dir: Vector3, across: Vector3, s0: float, s1: float, y0: float, y1: float) -> void:
	if s1 - s0 < 0.01 or y1 - y0 < 0.01:
		return
	var box := _piece_box(WALLS, a, dir, across, s0, s1, y0, y1, Color.WHITE)
	_collide(box[0], box[1])
	if y1 > inner_size.y - 0.01 and wealth != Wealth.POOR:
		# Потолочный плинтус-карниз
		var cornice := across + across.normalized() * 0.03
		_piece_box(PLASTER, a, dir, cornice, s0, s1, inner_size.y - 0.07, inner_size.y, Color(0.98, 0.97, 0.94))
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
	var c := Vector3(x0 + 1.05, 0, z0 + 3.7)
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


# --- Двери ---------------------------------------------------------------

## Створка на петле в точке hinge. Открывается в сторону swing.
func _door(hinge: Vector3, dir: Vector3, swing: Vector3, width: float, height: float, entrance: bool) -> void:
	# Локальные оси створки: X — вдоль проёма, Z — поперёк стены
	var side := dir.cross(Vector3.UP)
	var pivot := Node3D.new()
	pivot.name = "Door%d" % get_child_count()
	pivot.basis = Basis(dir, Vector3.UP, side)
	pivot.position = hinge
	add_child(pivot)

	var main_tools := _tools
	_tools = _new_tools()
	var w := width - 0.02
	var h := height - 0.01
	var t := 0.02
	var handle := Color(0.75, 0.65, 0.35) if wealth == Wealth.RICH else Color(0.6, 0.6, 0.62)
	var padded := entrance and wealth != Wealth.POOR
	if padded:
		# Обивка дерматином с гвоздиками ромбом
		var leather := Color(0.3, 0.14, 0.09)
		_box(FABRIC, Vector3(0.01, 0.01, -t - 0.01), Vector3(w, h, t + 0.01), leather)
		for iy in range(1, 8):
			for ix in range(1, 4):
				if (ix + iy) % 2 == 0:
					var p := Vector3(w * ix / 4.0, h * iy / 8.0, 0)
					for z in [-1.0, 1.0]:
						var c := p + Vector3(0, 0, z * (t + 0.012))
						_box(PLASTER, c - Vector3(0.012, 0.012, 0.004), c + Vector3(0.012, 0.012, 0.004), Color(0.8, 0.7, 0.4), false)
	else:
		match wealth:
			Wealth.POOR:
				# Дощатая дверь: доски, щели и две поперечные планки
				var plank := Color(0.45, 0.35, 0.25)
				_box(WOOD, Vector3(0.01, 0.01, -t), Vector3(w, h, t), plank)
				var x := 0.15
				while x < w - 0.05:
					_box(WOOD, Vector3(x - 0.004, 0.02, -t - 0.002), Vector3(x + 0.004, h - 0.02, t + 0.002), plank.darkened(0.5), false)
					x += 0.15
				for y in [0.25, h - 0.35]:
					_box(WOOD, Vector3(0.04, y, t), Vector3(w - 0.04, y + 0.1, t + 0.025), plank.darkened(0.15))
			Wealth.RICH:
				# Лакированная филёнчатая дверь со стеклом наверху
				var lac := Color(0.35, 0.18, 0.1)
				_box(WOOD, Vector3(0.01, 0.01, -t), Vector3(w, 0.9, t), lac)
				_box(WOOD, Vector3(0.01, 1.75, -t), Vector3(w, h, t), lac)
				_box(WOOD, Vector3(0.01, 0.9, -t), Vector3(0.13, 1.75, t), lac)
				_box(WOOD, Vector3(w - 0.12, 0.9, -t), Vector3(w, 1.75, t), lac)
				_box(WOOD, Vector3(w * 0.5 - 0.02, 0.9, -t * 0.5), Vector3(w * 0.5 + 0.02, 1.75, t * 0.5), lac)
				_box(GLASS, Vector3(0.13, 0.9, -0.005), Vector3(w - 0.12, 1.75, 0.005), Color(0.85, 0.9, 0.85, 0.35))
				_box(WOOD, Vector3(0.12, 0.15, -t - 0.01), Vector3(w - 0.11, 0.75, t + 0.01), lac.lightened(0.08))
			_:
				# Крашеная дверь с двумя филёнками
				var paint := Color(0.92, 0.92, 0.88)
				_box(WOOD, Vector3(0.01, 0.01, -t), Vector3(w, h, t), paint)
				for y in [[0.15, 0.85], [1.05, h - 0.15]]:
					_box(WOOD, Vector3(0.12, y[0], -t - 0.008), Vector3(w - 0.11, y[1], t + 0.008), paint.darkened(0.06))
	# Ручки с обеих сторон
	for z in [-1.0, 1.0]:
		var hz: float = z * (t + 0.015)
		_box(PLASTER, Vector3(w - 0.14, 0.98, hz - 0.012), Vector3(w - 0.04, 1.01, hz + 0.012), handle, false)
	var leaf := MeshInstance3D.new()
	leaf.mesh = _commit(_tools)
	pivot.add_child(leaf)
	_tools = main_tools

	if not auto_doors:
		return
	# Открывается в сторону swing: при повороте на +угол створка уходит к -Z
	var open_angle := deg_to_rad(95.0) * (-1.0 if swing.dot(side) > 0.0 else 1.0)
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width + 1.2, 2.0, 3.2)
	shape.shape = box
	shape.position = Vector3(width * 0.5, 1.0, 0)
	area.add_child(shape)
	pivot.add_child(area)
	var inside := [0]
	area.body_entered.connect(func(b: Node3D) -> void:
		if b is CharacterBody3D:
			inside[0] += 1
			_swing(pivot, open_angle))
	area.body_exited.connect(func(b: Node3D) -> void:
		if b is CharacterBody3D:
			inside[0] = maxi(inside[0] - 1, 0)
			if inside[0] == 0:
				_swing(pivot, 0.0))


func _swing(pivot: Node3D, angle: float) -> void:
	var leaf: Node3D = pivot.get_child(0)
	if leaf.has_meta("tween"):
		var old: Tween = leaf.get_meta("tween")
		if old and old.is_valid():
			old.kill()
	var tw := create_tween()
	tw.tween_property(leaf, "rotation:y", angle, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	leaf.set_meta("tween", tw)


# --- Мелочи, которые делают дом жилым ------------------------------------

func _details() -> void:
	var k := _kitchen_rect()
	var r := _room_rect()
	var s0 := Vector3(k.position.x, 0, k.position.y)

	# Вешалка с одеждой у входа, на перегородке со стороны кухни
	var hx := k.end.x
	_box(WOOD, Vector3(hx - 0.03, 1.6, 1.5), Vector3(hx, 1.7, 2.6), _trim_color())
	_box(FABRIC, Vector3(hx - 0.2, 0.85, 1.62), Vector3(hx - 0.03, 1.62, 1.98), Color(0.25, 0.26, 0.3))
	_box(FABRIC, Vector3(hx - 0.18, 1.0, 2.1), Vector3(hx - 0.03, 1.62, 2.45), Color(0.42, 0.3, 0.2))

	match wealth:
		Wealth.POOR:
			_pot_on_stove(s0)
			# Рукомойник у стены: тумба с тазом, бачок, полотенце на гвозде
			var wz := k.position.y + 4.7
			var wood := Color(0.5, 0.38, 0.26)
			_solid(WOOD, Vector3(k.position.x, 0, wz), Vector3(k.position.x + 0.45, 0.8, wz + 0.5), wood)
			_box(PLASTER, Vector3(k.position.x + 0.08, 0.8, wz + 0.08), Vector3(k.position.x + 0.38, 0.88, wz + 0.42), Color(0.6, 0.62, 0.66))
			_box(PLASTER, Vector3(k.position.x, 1.1, wz + 0.12), Vector3(k.position.x + 0.2, 1.45, wz + 0.38), Color(0.55, 0.57, 0.6))
			_box(FABRIC, Vector3(k.position.x, 0.95, wz + 0.6), Vector3(k.position.x + 0.02, 1.5, wz + 0.9), Color(0.9, 0.88, 0.82))
			# Ходики с гирьками в комнате
			_wall_clock(r.position.x, -0.25, true)
		Wealth.RICH:
			# Чайник на плите
			var sx := k.position.x + 1.25
			_box(PLASTER, Vector3(sx + 0.05, 0.915, s0.z + 0.09), Vector3(sx + 0.21, 1.1, s0.z + 0.25), Color(0.8, 0.2, 0.15))
			_box(PLASTER, Vector3(sx + 0.1, 1.1, s0.z + 0.14), Vector3(sx + 0.16, 1.14, s0.z + 0.2), Color(0.1, 0.1, 0.1))
			# Сервировка обеденного стола и ваза с цветами
			var c := Vector3(k.position.x + 1.05, 0.76, k.position.y + 3.7)
			for p in [Vector2(-0.25, -0.3), Vector2(-0.25, 0.3), Vector2(0.25, -0.3), Vector2(0.25, 0.3)]:
				_plate(c + Vector3(p.x, 0, p.y))
			_box(PLASTER, c + Vector3(-0.05, 0, -0.05), c + Vector3(0.05, 0.22, 0.05), Color(0.3, 0.4, 0.7))
			_box(FABRIC, c + Vector3(-0.1, 0.22, -0.1), c + Vector3(0.1, 0.35, 0.1), Color(0.85, 0.25, 0.3))
			# Торшер у дивана и ваза на журнальном столике
			var fx := r.position.x + 2.8
			_box(WOOD, Vector3(fx - 0.15, 0, -0.45), Vector3(fx + 0.15, 0.04, -0.15), Color(0.2, 0.2, 0.2))
			_box(WOOD, Vector3(fx - 0.015, 0.04, -0.315), Vector3(fx + 0.015, 1.45, -0.285), Color(0.7, 0.6, 0.3))
			_box(FABRIC, Vector3(fx - 0.2, 1.4, -0.5), Vector3(fx + 0.2, 1.7, -0.1), Color(0.95, 0.85, 0.6))
			var t := Vector3(r.position.x + 1.45, 0.45, -1.7)
			_box(PLASTER, t + Vector3(-0.05, 0, -0.05), t + Vector3(0.05, 0.25, 0.05), Color(0.85, 0.85, 0.9))
			# Картина над кроватью
			_picture(Vector3(r.end.x - 1.2, 1.7, r.position.y), Vector2(0.8, 0.5), Color(0.3, 0.45, 0.35))
			_wall_clock(r.position.x, -0.25, false)
		_:
			_pot_on_stove(s0)
			# Радиоприёмник на кухонном шкафчике
			var rx := k.end.x - 0.45
			var rz := k.position.y + 0.4
			_box(WOOD, Vector3(rx, 0.89, rz), Vector3(rx + 0.2, 1.1, rz + 0.36), Color(0.35, 0.2, 0.1))
			_box(FABRIC, Vector3(rx - 0.005, 0.93, rz + 0.04), Vector3(rx, 1.06, rz + 0.22), Color(0.8, 0.7, 0.5))
			_box(PLASTER, Vector3(rx - 0.005, 0.95, rz + 0.26), Vector3(rx, 1.04, rz + 0.32), Color(0.9, 0.85, 0.6))
			# Тарелки на столе, отрывной календарь на стене
			var c := Vector3(k.position.x + 0.5, 0.75, k.position.y + 3.0)
			_plate(c + Vector3(0, 0, 0.3))
			_plate(c + Vector3(0, 0, 0.8))
			_box(PLASTER, Vector3(k.position.x, 1.35, 1.4), Vector3(k.position.x + 0.01, 1.85, 1.75), Color(0.95, 0.95, 0.92))
			_box(PLASTER, Vector3(k.position.x, 1.75, 1.4), Vector3(k.position.x + 0.015, 1.85, 1.75), Color(0.75, 0.15, 0.12))
			# Книги на полке, часы с маятником, фотографии
			_books(r.position.x, 1.43, r.end.y - 2.15, r.end.y - 1.25)
			_books(r.position.x, 1.78, r.end.y - 2.15, r.end.y - 1.6)
			_wall_clock(r.position.x, -0.25, false)
			_picture(Vector3(r.position.x + 1.0, 1.6, r.position.y), Vector2(0.3, 0.4), Color(0.6, 0.55, 0.45))
			_picture(Vector3(r.position.x + 1.5, 1.65, r.position.y), Vector2(0.3, 0.4), Color(0.5, 0.5, 0.5))


func _pot_on_stove(s0: Vector3) -> void:
	# Чугунок на уступе печи
	_box(PLASTER, s0 + Vector3(1.1, 1.5, 0.6), s0 + Vector3(1.4, 1.72, 0.9), Color(0.15, 0.15, 0.15))
	_box(WOOD, s0 + Vector3(1.08, 1.72, 0.58), s0 + Vector3(1.42, 1.74, 0.92), Color(0.4, 0.3, 0.2))


func _plate(c: Vector3) -> void:
	_box(PLASTER, c + Vector3(-0.1, 0, -0.1), c + Vector3(0.1, 0.012, 0.1), Color(0.97, 0.97, 0.95), false)


## Картина или фото в рамке на задней стене (z = стена), center — середина рамки.
func _picture(center: Vector3, size: Vector2, canvas: Color) -> void:
	var h := Vector3(size.x * 0.5, size.y * 0.5, 0)
	var z := Vector3(0, 0, 0.025)
	_box(WOOD, center - h, center + h + z, Color(0.6, 0.45, 0.2), false)
	_box(FABRIC, center - h + Vector3(0.04, 0.04, 0), center + h - Vector3(0.04, 0.04, 0) + z * 1.2, canvas, false)


## Настенные часы на перегородке со стороны комнаты.
func _wall_clock(x: float, z: float, weights: bool) -> void:
	var body := Color(0.35, 0.2, 0.1)
	if weights:
		# Ходики: маленький домик, циферблат, цепочки с гирьками
		_box(WOOD, Vector3(x, 1.75, z - 0.12), Vector3(x + 0.08, 2.0, z + 0.12), body, false)
		_box(PLASTER, Vector3(x + 0.08, 1.8, z - 0.09), Vector3(x + 0.085, 1.96, z + 0.09), Color(0.95, 0.92, 0.8), false)
		for dz in [-0.05, 0.05]:
			_box(WOOD, Vector3(x + 0.03, 1.3, z + dz - 0.005), Vector3(x + 0.04, 1.75, z + dz + 0.005), Color(0.3, 0.3, 0.3), false)
			_box(PLASTER, Vector3(x + 0.02, 1.2, z + dz - 0.02), Vector3(x + 0.05, 1.3, z + dz + 0.02), Color(0.2, 0.2, 0.2), false)
	else:
		# Часы с маятником в деревянном корпусе
		_box(WOOD, Vector3(x, 1.25, z - 0.17), Vector3(x + 0.12, 2.0, z + 0.17), body, false)
		_box(PLASTER, Vector3(x + 0.12, 1.72, z - 0.12), Vector3(x + 0.125, 1.94, z + 0.12), Color(0.95, 0.92, 0.8), false)
		_box(PLASTER, Vector3(x + 0.12, 1.32, z - 0.1), Vector3(x + 0.125, 1.66, z + 0.1), Color(0.15, 0.12, 0.1), false)
		_box(PLASTER, Vector3(x + 0.125, 1.36, z - 0.035), Vector3(x + 0.13, 1.44, z + 0.035), Color(0.8, 0.65, 0.3), false)


## Ряд книг на полке у перегородки (со стороны комнаты).
func _books(x: float, y: float, z0: float, z1: float) -> void:
	var rng := _rng()
	var colors := [Color(0.5, 0.1, 0.1), Color(0.15, 0.25, 0.45), Color(0.2, 0.35, 0.2), Color(0.55, 0.45, 0.25), Color(0.3, 0.3, 0.3)]
	var z := z0
	while z < z1:
		var w := rng.randf_range(0.03, 0.06)
		var hh := rng.randf_range(0.18, 0.26)
		_box(WOOD, Vector3(x + 0.02, y, z), Vector3(x + 0.2, y + hh, z + w), colors[rng.randi() % colors.size()], false)
		z += w + 0.004


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
			st.set_color(Color(color.r * k, color.g * k, color.b * k, color.a))
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
	# Стекло и тюль: без текстуры, прозрачность берётся из цвета вершин
	var glass := StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	list.append(glass)
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
