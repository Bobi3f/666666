class_name MeshBuilder
extends RefCounted
## Копит геометрию в один меш с цветом в вершинах — весь мир рисуется
## за один вызов отрисовки. Коллизии копятся списком коробок.
##
## xf — текущее преобразование: всё, что добавляется, сначала переводится им.
## Так один и тот же код строит дом, а xf ставит его на место и поворачивает.

var xf := Transform3D.IDENTITY
## Затемнять низ коробок: предмет «стоит» на земле, а не парит.
var ground_shade := true

var _st := SurfaceTool.new()
var _boxes: Array = []  # [Transform3D, Vector3 size]
var _count := 0

# Нормаль, «вправо» и «вверх» для каждой грани, глядя на неё снаружи.
const FACES := [
	[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
	[Vector3.LEFT, Vector3.BACK, Vector3.UP],
	[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
	[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
	[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
	[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
]
# Лёгкий разброс яркости по граням — плоскости не сливаются
const FACE_TINT := [0.93, 0.9, 1.0, 0.86, 1.06, 0.7]


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


func triangle_count() -> int:
	return _count


## Коробка от mn до mx в локальных координатах xf.
func box(mn: Vector3, mx: Vector3, color: Color, collide := false) -> void:
	var c := (mn + mx) * 0.5
	var e := (mx - mn) * 0.5
	for fi in FACES.size():
		var f: Array = FACES[fi]
		var n: Vector3 = f[0]
		var fc: Vector3 = c + n * e
		var rr: Vector3 = f[1] * e
		var uu: Vector3 = f[2] * e
		var tint: float = FACE_TINT[fi]
		var pts := [fc - rr - uu, fc + rr - uu, fc + rr + uu, fc - rr + uu]
		var cols: Array[Color] = []
		for p in pts:
			var k := tint
			if ground_shade:
				k *= lerpf(0.72, 1.0, clampf(p.y / 1.2, 0.0, 1.0))
			cols.append(Color(color.r * k, color.g * k, color.b * k))
		_quad_raw(pts, cols, n)
	if collide:
		_boxes.append([xf * Transform3D(Basis.IDENTITY, c), mx - mn])


## Коробка с поворотом вокруг вертикали — для деревьев, досок, столбов.
func box_rot(center: Vector3, size: Vector3, yaw: float, color: Color, collide := false) -> void:
	var saved := xf
	xf = xf * Transform3D(Basis(Vector3.UP, yaw), center)
	box(-size * 0.5, size * 0.5, color, collide)
	xf = saved


## Четырёхугольник a-b-c-d (против часовой, если смотреть с лицевой стороны).
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, two_sided := false) -> void:
	var n := (b - a).cross(c - a).normalized()
	_quad_raw([a, b, c, d], [color, color, color, color], n)
	if two_sided:
		_quad_raw([a, d, c, b], [color, color, color, color], -n)


## Четырёхугольник с отдельным цветом в каждой вершине (земля пятнами).
func quad_vc(pts: Array, cols: Array[Color]) -> void:
	var n: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
	_quad_raw(pts, cols, n)


func tri(a: Vector3, b: Vector3, c: Vector3, color: Color, two_sided := false) -> void:
	var n := (b - a).cross(c - a).normalized()
	_emit(a, n, color)
	_emit(c, n, color)
	_emit(b, n, color)
	_count += 1
	if two_sided:
		_emit(a, -n, color)
		_emit(b, -n, color)
		_emit(c, -n, color)
		_count += 1


func add_collider(mn: Vector3, mx: Vector3) -> void:
	_boxes.append([xf * Transform3D(Basis.IDENTITY, (mn + mx) * 0.5), mx - mn])


func _quad_raw(pts: Array, cols: Array, n: Vector3) -> void:
	# В Godot лицевая сторона — по часовой стрелке, поэтому порядок 0-2-1, 0-3-2
	for i in [0, 2, 1, 0, 3, 2]:
		_emit(pts[i], n, cols[i])
	_count += 2


func _emit(p: Vector3, n: Vector3, color: Color) -> void:
	_st.set_color(color)
	_st.set_normal((xf.basis * n).normalized())
	_st.add_vertex(xf * p)


## Готовый узел с мешем. unshaded — для светящихся окон.
func build_mesh(unshaded := false) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	if _count > 0:
		mi.mesh = _st.commit()
		mi.mesh.surface_set_material(0, mat)
	return mi


## Одно статическое тело со всеми коллизиями.
func build_body() -> StaticBody3D:
	var body := StaticBody3D.new()
	for b in _boxes:
		var shape := BoxShape3D.new()
		shape.size = b[1]
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = b[0]
		body.add_child(cs)
	return body
