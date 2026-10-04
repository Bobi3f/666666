class_name WalkIn
extends RefCounted
## Здание, в которое можно войти: коробка со стенами, дверным проёмом
## спереди (+Z в своих координатах), полом, потолком и лампой. Строится в
## общий MeshBuilder (b.xf — где стоит и как повёрнуто здание), коллизии —
## тоже: стены держат, в проём проходишь.
##
## Внутри всё — простые коробки с цветом в вершинах: мелочь (товары, бумаги)
## сама уходит в «мелочь» MeshBuilder и вдали не рисуется.

const WALL := 0.2


## Коробка: size — снаружи (ширина X, высота Y, глубина Z), пол на floor_y
## (над цоколем), проём двери шириной door_w с центром door_x.
## lit — светящийся (unshaded) меш здания: в него потолок, иначе снизу он
## выходит чёрным (солнце сверху его не освещает).
static func shell(b: MeshBuilder, size: Vector3, floor_y: float, outer: Color, inner: Color,
		floor_col: Color, door_x := 0.0, door_w := 1.3, door_h := 2.3, lit: MeshBuilder = null) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var h := size.y
	var t := WALL
	# Пол и потолок
	b.box(Vector3(-hx, floor_y - 0.06, -hz), Vector3(hx, floor_y, hz), floor_col, true)
	b.box(Vector3(-hx, h - 0.12, -hz), Vector3(hx, h, hz), inner.lightened(0.15))
	if lit:
		var saved := lit.xf
		lit.xf = b.xf
		# Лицом вниз — его видно из комнаты
		lit.quad(Vector3(-hx + t, h - 0.125, -hz + t), Vector3(hx - t, h - 0.125, -hz + t), Vector3(hx - t, h - 0.125, hz - t), Vector3(-hx + t, h - 0.125, hz - t), Color(0.86, 0.86, 0.82))
		lit.xf = saved
	# Задняя и боковые стены
	b.box(Vector3(-hx, 0, -hz), Vector3(hx, h, -hz + t), outer, true)
	b.box(Vector3(-hx, 0, -hz), Vector3(-hx + t, h, hz), outer, true)
	b.box(Vector3(hx - t, 0, -hz), Vector3(hx, h, hz), outer, true)
	# Фасад: слева и справа от двери и перемычка над ней
	var d0 := door_x - door_w * 0.5
	var d1 := door_x + door_w * 0.5
	b.box(Vector3(-hx, 0, hz - t), Vector3(d0, h, hz), outer, true)
	b.box(Vector3(d1, 0, hz - t), Vector3(hx, h, hz), outer, true)
	b.box(Vector3(d0, floor_y + door_h, hz - t), Vector3(d1, h, hz), outer, true)
	# Внутренняя отделка — чуть внутри стен, чтобы изнутри был свой цвет
	var i0 := floor_y
	b.box(Vector3(-hx + t, i0, -hz + t), Vector3(hx - t, h - 0.12, -hz + t + 0.01), inner)
	b.box(Vector3(-hx + t, i0, -hz + t), Vector3(-hx + t + 0.01, h - 0.12, hz - t), inner)
	b.box(Vector3(hx - t - 0.01, i0, -hz + t), Vector3(hx - t, h - 0.12, hz - t), inner)
	b.box(Vector3(-hx + t, i0, hz - t - 0.01), Vector3(d0, h - 0.12, hz - t), inner)
	b.box(Vector3(d1, i0, hz - t - 0.01), Vector3(hx - t, h - 0.12, hz - t), inner)
	# Плинтус понизу — стены не «висят»
	var skirt := inner.darkened(0.45)
	b.box(Vector3(-hx + t, i0, -hz + t), Vector3(hx - t, i0 + 0.1, -hz + t + 0.025), skirt)
	b.box(Vector3(-hx + t, i0, -hz + t), Vector3(-hx + t + 0.025, i0 + 0.1, hz - t), skirt)
	b.box(Vector3(hx - t - 0.025, i0, -hz + t), Vector3(hx - t, i0 + 0.1, hz - t), skirt)


## Лампа под потолком: светится сама (glow — несветящийся меш с unshaded).
static func lamp(glow: MeshBuilder, p: Vector3, size := Vector2(1.2, 0.3)) -> void:
	glow.box(p - Vector3(size.x * 0.5, 0.06, size.y * 0.5), p + Vector3(size.x * 0.5, 0.0, size.y * 0.5), Color(1.0, 0.97, 0.88))


## Прилавок: столешница и короб до пола (с коллизией).
static func counter(b: MeshBuilder, mn: Vector3, mx: Vector3, body: Color, top: Color) -> void:
	b.box(mn, Vector3(mx.x, mx.y - 0.05, mx.z), body, true)
	b.box(Vector3(mn.x - 0.03, mx.y - 0.05, mn.z - 0.03), Vector3(mx.x + 0.03, mx.y, mx.z + 0.03), top)


## Стеллаж с товаром у стены: полки и пёстрые коробки/банки на них.
static func shelf(b: MeshBuilder, mn: Vector3, mx: Vector3, rng: RandomNumberGenerator) -> void:
	var wood := Color(0.5, 0.36, 0.24)
	b.box(Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mx.y, mn.z + 0.04), wood, true)
	b.box(Vector3(mn.x, mn.y, mn.z), Vector3(mn.x + 0.04, mx.y, mx.z), wood)
	b.box(Vector3(mx.x - 0.04, mn.y, mn.z), Vector3(mx.x, mx.y, mx.z), wood)
	var goods := [Color(0.85, 0.2, 0.15), Color(0.95, 0.8, 0.2), Color(0.25, 0.5, 0.8), Color(0.9, 0.9, 0.85),
		Color(0.35, 0.6, 0.3), Color(0.6, 0.35, 0.2), Color(0.9, 0.55, 0.2)]
	var y := mn.y + 0.35
	while y < mx.y - 0.2:
		b.box(Vector3(mn.x, y - 0.03, mn.z), Vector3(mx.x, y, mx.z), wood)
		var x := mn.x + 0.08
		while x < mx.x - 0.15:
			var w := rng.randf_range(0.08, 0.18)
			var hh := rng.randf_range(0.12, 0.26)
			var d := rng.randf_range(0.08, mx.z - mn.z - 0.06)
			b.box(Vector3(x, y, mn.z + 0.04), Vector3(x + w, y + hh, mn.z + 0.04 + d), goods[rng.randi() % goods.size()])
			x += w + rng.randf_range(0.02, 0.06)
		y += 0.45
