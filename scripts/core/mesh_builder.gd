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
## Метка части тела в альфе цвета вершин: по ней шейдер ходьбы качает
## ноги и руки (1 — туловище, 0.9/0.8 — ноги, 0.7/0.6 — руки).
var alpha := 1.0

var _st := SurfaceTool.new()
## Нарезка на куски по chunk_size метров (0 — одним куском). Невидимые куски
## не рисуются, а фонарь или лампа перерисовывают только соседние куски,
## а не весь мир — на телефоне ночью это главное.
var chunk_size := 0.0
var _chunks := {}  # Vector2i → SurfaceTool
var _cur: SurfaceTool
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
	_cur = _st


## Куда класть треугольники с центром в p (уже в мировых координатах).
func _pick(p: Vector3) -> void:
	if chunk_size <= 0.0:
		return
	var key := Vector2i(floori(p.x / chunk_size), floori(p.z / chunk_size))
	var st: SurfaceTool = _chunks.get(key)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_chunks[key] = st
	_cur = st


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
			cols.append(Color(color.r * k, color.g * k, color.b * k, alpha))
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
	_pick(xf * ((a + b + c) / 3.0))
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
	if chunk_size > 0.0:
		_pick(xf * ((pts[0] + pts[2]) * 0.5))
	for i in [0, 2, 1, 0, 3, 2]:
		_emit(pts[i], n, cols[i])
	_count += 2


func _emit(p: Vector3, n: Vector3, color: Color) -> void:
	_cur.set_color(color)
	_cur.set_normal((xf.basis * n).normalized())
	_cur.add_vertex(xf * p)


## Мир кусками: узел с мешем на каждый квадрат chunk_size × chunk_size.
func build_chunked() -> Node3D:
	var root := Node3D.new()
	var mat := world_material()
	for key in _chunks:
		var mesh: ArrayMesh = (_chunks[key] as SurfaceTool).commit()
		mesh.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.name = "Chunk_%d_%d" % [key.x, key.y]
		root.add_child(mi)
	return root


## Готовый узел с мешем. unshaded — для светящихся окон.
func build_mesh(unshaded := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = build_array_mesh(unshaded)
	return mi


## Только меш с материалом, без узла — для MultiMesh.
func build_array_mesh(unshaded := false) -> ArrayMesh:
	var mat: Material
	if unshaded:
		var um := StandardMaterial3D.new()
		um.vertex_color_use_as_albedo = true
		um.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat = um
	else:
		mat = world_material()
	if _count == 0:
		return null
	var mesh := _st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## Общий материал всего мира: цвет вершин, зерно по трём осям (доски,
## штукатурка, асфальт и трава перестают быть ровной заливкой) и сезоны —
## осенью зелень желтеет, зимой земля и скаты крыш под снегом.
const WORLD_SHADER := """
shader_type spatial;

uniform sampler2D grain : source_color, filter_linear_mipmap, repeat_enable;
uniform float snow = 0.0;
uniform float autumn = 0.0;
uniform float spring = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = abs(wnrm);
	w /= (w.x + w.y + w.z);
	vec3 p = wpos * 0.9;
	float g = texture(grain, p.zy).r * w.x + texture(grain, p.xz).r * w.y + texture(grain, p.xy).r * w.z;
	vec3 c = COLOR.rgb;
	// Насколько цвет «зелёный» — трава, листва, ботва
	float green = clamp((c.g - max(c.r, c.b)) * 6.0, 0.0, 1.0);
	c = mix(c, vec3(c.g * 1.05 + 0.04, c.g * 0.7, c.b * 0.4), autumn * green);
	c = mix(c, c * vec3(1.0, 1.12, 0.95), spring * green);
	// Снег: на земле (низко и ровно) и на скатах крыш
	float flat_up = smoothstep(0.55, 0.85, wnrm.y);
	float ground = flat_up * (1.0 - smoothstep(0.1, 0.2, wpos.y)) * mix(0.6, 1.0, green);
	float roof = smoothstep(0.25, 0.45, wnrm.y) * (1.0 - smoothstep(0.9, 0.97, wnrm.y)) * smoothstep(2.0, 2.6, wpos.y);
	float s = snow * max(ground, roof);
	c = mix(c, vec3(0.9, 0.92, 0.96), s * (0.8 + 0.2 * g));
	ALBEDO = c * g * 1.08;
	ROUGHNESS = 0.92;
}
"""

static var _world_mat: ShaderMaterial


static func world_material() -> ShaderMaterial:
	if _world_mat == null:
		var sh := Shader.new()
		sh.code = WORLD_SHADER
		_world_mat = ShaderMaterial.new()
		_world_mat.shader = sh
		_world_mat.set_shader_parameter("grain", grain())
	return _world_mat


## Сезон для всего мира: снег, осень, весна — от 0 до 1.
static func set_season(snow: float, autumn: float, spring: float) -> void:
	var m := world_material()
	m.set_shader_parameter("snow", snow)
	m.set_shader_parameter("autumn", autumn)
	m.set_shader_parameter("spring", spring)


static var _grain: ImageTexture


## Общая для всех текстура-зерно: крупные пятна + мелкая крупка, яркость 0.8–1.05.
static func grain() -> ImageTexture:
	if _grain:
		return _grain
	var big := FastNoiseLite.new()
	big.seed = 7
	big.frequency = 0.04
	var fine := FastNoiseLite.new()
	fine.seed = 11
	fine.frequency = 0.35
	var n := 128
	var img := Image.create(n, n, true, Image.FORMAT_RGB8)
	# Бесшовно: шум на торе — четыре угла плитки усредняются
	for y in n:
		for x in n:
			var v := 0.0
			for dy in [0, n]:
				for dx in [0, n]:
					var w := (1.0 - absf(float(x + dx - n) / n)) * (1.0 - absf(float(y + dy - n) / n))
					v += w * (big.get_noise_2d(x + dx, y + dy) * 0.55 + fine.get_noise_2d(x + dx, y + dy) * 0.45)
			var k := clampf(0.93 + v * 0.22, 0.78, 1.06)
			img.set_pixel(x, y, Color(k, k, k))
	img.generate_mipmaps()
	_grain = ImageTexture.create_from_image(img)
	return _grain


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
