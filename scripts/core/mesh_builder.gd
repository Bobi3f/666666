class_name MeshBuilder
extends RefCounted
## Копит геометрию в один меш с цветом в вершинах — весь мир рисуется
## за один вызов отрисовки. Коллизии копятся списком коробок.
##
## xf — текущее преобразование: всё, что добавляется, сначала переводится им.
## Так один и тот же код строит дом, а xf ставит его на место и поворачивает.

var xf := Transform3D.IDENTITY
## Сдвиг всего, что добавляется, поверх xf — так город строится тем же
## кодом в своих координатах, а встаёт на своё место в мире (Town.SHIFT).
var shift := Vector3.ZERO
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
var _chunks := {}  # Vector3i(x, z, мелочь 0/1) → SurfaceTool
## Мелочь — коробки меньше SMALL_SIZE метров по диагонали (штакетник, рамы,
## ящики): при нарезке идёт в свои куски по SMALL_CHUNK м, которые вдали не
## рисуются (SettingsManager.small_range). Это почти половина треугольников
## мира, а за сотню метров её всё равно не разглядеть.
const SMALL_SIZE := 1.6
const SMALL_CHUNK := 50.0
var _small := false
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
	var size := SMALL_CHUNK if _small else chunk_size
	var key := Vector3i(floori(p.x / size), floori(p.z / size), 1 if _small else 0)
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
	if chunk_size > 0.0:
		_small = (xf.basis * (mx - mn)).length() < SMALL_SIZE
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
	_small = false
	if collide:
		_boxes.append([Transform3D(Basis.IDENTITY, shift) * xf * Transform3D(Basis.IDENTITY, c), mx - mn])


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


## Четырёхугольник с нормалью в каждой вершине — гладкие округлые формы
## (руки, головы людей). Цвет с текущей альфой (метка части тела).
func smooth_quad(pts: Array, ns: Array, color: Color) -> void:
	var c := Color(color.r, color.g, color.b, alpha)
	if chunk_size > 0.0:
		_pick(xf * ((pts[0] + pts[2]) * 0.5) + shift)
	for i in [0, 2, 1, 0, 3, 2]:
		_emit(pts[i], ns[i], c)
	_count += 2


func tri(a: Vector3, b: Vector3, c: Vector3, color: Color, two_sided := false) -> void:
	var n := (b - a).cross(c - a).normalized()
	_pick(xf * ((a + b + c) / 3.0) + shift)
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
	_boxes.append([Transform3D(Basis.IDENTITY, shift) * xf * Transform3D(Basis.IDENTITY, (mn + mx) * 0.5), mx - mn])


func _quad_raw(pts: Array, cols: Array, n: Vector3) -> void:
	# В Godot лицевая сторона — по часовой стрелке, поэтому порядок 0-2-1, 0-3-2
	if chunk_size > 0.0:
		_pick(xf * ((pts[0] + pts[2]) * 0.5) + shift)
	for i in [0, 2, 1, 0, 3, 2]:
		_emit(pts[i], n, cols[i])
	_count += 2


func _emit(p: Vector3, n: Vector3, color: Color) -> void:
	_cur.set_color(color)
	_cur.set_normal((xf.basis * n).normalized())
	_cur.add_vertex(xf * p + shift)


## Мир кусками: узел с мешем на каждый квадрат chunk_size × chunk_size
## (Chunk_x_z) и куски мелочи (Small_x_z) с короткой дальностью.
func build_chunked() -> Node3D:
	var root := Node3D.new()
	var mat := detail_material()
	for key in _chunks:
		var mesh: ArrayMesh = (_chunks[key] as SurfaceTool).commit()
		mesh.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.name = ("Small_%d_%d" if key.z == 1 else "Chunk_%d_%d") % [key.x, key.y]
		root.add_child(mi)
	set_small_range(root)
	var watch := func() -> void:
		if is_instance_valid(root):
			set_small_range(root)
	SettingsManager.changed.connect(watch)
	root.tree_exited.connect(func() -> void:
		if SettingsManager.changed.is_connected(watch):
			SettingsManager.changed.disconnect(watch))
	return root


## Дальность мелочи — по детализации из настроек.
static func set_small_range(root: Node) -> void:
	for c in root.get_children():
		if c.name.begins_with("Small_"):
			var gi := c as GeometryInstance3D
			gi.visibility_range_end = SettingsManager.small_range()
			gi.visibility_range_end_margin = 10.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


## Готовый узел с мешем. unshaded — для светящихся окон.
func build_mesh(unshaded := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = build_array_mesh(unshaded)
	# Один человек — свой шейдер (шаг, взгляд) и в группу «люди»
	if has_meta("person"):
		mi.material_override = PersonModel.material()
		mi.set_meta("sit", get_meta("person"))
		mi.add_to_group("people")
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

uniform sampler2D grain : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float snow = 0.0;
uniform float autumn = 0.0;
uniform float spring = 0.0;
// Мокро после дождя: земля и асфальт темнеют и блестят
uniform float wet = 0.0;
// Неподвижный мир — с рисунком поверхностей (доски, кирпич, асфальт, черепица);
// машины, люди и мелочь — без него
uniform bool detailed = false;
// 0 — низкая детализация: рисунок не считаем
uniform float quality = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 w = abs(wnrm);
	w /= (w.x + w.y + w.z);
	vec3 p = wpos * 0.9;
	float g = texture(grain, p.zy).r * w.x + texture(grain, p.xz).r * w.y + texture(grain, p.xy).r * w.z;
	vec3 c = COLOR.rgb;
	// Насколько цвет «зелёный» — трава, листва, ботва
	float green = clamp((c.g - max(c.r, c.b)) * 6.0, 0.0, 1.0);
	float rough = 0.92;
	float up = smoothstep(0.7, 0.9, wnrm.y);
	float low = 1.0 - smoothstep(0.06, 0.35, wpos.y);
	float ground_lvl = up * low;
	if (detailed && quality > 0.5) {
		float mx = max(c.r, max(c.g, c.b));
		float mn = min(c.r, min(c.g, c.b));
		float sat = (mx - mn) / (mx + 0.001);
		float lum = dot(c, vec3(0.3, 0.59, 0.11));
		float grey = 1.0 - clamp(sat * 5.0, 0.0, 1.0);
		float brown = clamp((c.r - c.b) * 5.0, 0.0, 1.0) * (1.0 - green) * clamp(sat * 4.0, 0.0, 1.0);
		// Кирпич — красно-бурый, не яркая краска (вывески, машины)
		float red = clamp((c.r - c.g * 1.3) * 6.0, 0.0, 1.0) * (1.0 - smoothstep(0.7, 0.78, sat));
		float vert = 1.0 - smoothstep(0.2, 0.45, abs(wnrm.y));
		float slope = smoothstep(0.22, 0.4, wnrm.y) * (1.0 - smoothstep(0.86, 0.95, wnrm.y)) * smoothstep(1.6, 2.4, wpos.y);
		// Рисунок вблизи, издалека — ровный цвет (без ряби)
		float dist = length(wpos - CAMERA_POSITION_WORLD);
		float near = 1.0 - smoothstep(22.0, 55.0, dist);
		vec3 big3 = texture(grain, wpos.xz * 0.031).rgb;
		vec3 fine3 = texture(grain, wpos.xz * 3.7).rgb;
		// Средний масштаб: кочки и стебли травы, проплешины, пятна на асфальте
		vec3 mid3 = texture(grain, wpos.xz * 0.27).rgb;
		float big = big3.r;
		float fine = fine3.r;
		// Трава: крупные пятна посветлее и потемнее, выгоревшие места, мелкая крупка
		float grass = ground_lvl * green;
		c *= mix(1.0, mix(0.84, 1.16, (big - 0.78) / 0.28), grass);
		c = mix(c, c * vec3(1.12, 1.06, 0.78), grass * smoothstep(0.98, 1.04, texture(grain, wpos.xz * 0.011).r) * 0.8);
		c *= mix(1.0, 0.88 + 0.16 * (fine - 0.78) / 0.28, grass * near);
		// Кочки и стебли: тёмные промежутки между кочками, светлые макушки;
		// сухие желтоватые проплешины и сочные тёмные пятна
		c *= mix(1.0, 0.68 + 0.48 * mid3.g, grass * near);
		c = mix(c, c * vec3(1.16, 1.04, 0.62), grass * smoothstep(0.62, 0.8, mid3.b) * 0.7);
		c = mix(c, c * vec3(0.78, 0.92, 0.82), grass * (1.0 - smoothstep(0.2, 0.36, mid3.b)) * 0.6);
		// Цветы в траве: редкие точки — белые, жёлтые, лиловые
		vec2 fc = wpos.xz * 1.6;
		float fh = hash(floor(fc));
		float fdot = 1.0 - smoothstep(0.05, 0.09, length(fract(fc) - 0.5));
		vec3 flower = fh > 0.995 ? vec3(0.75, 0.55, 0.95) : (fh > 0.985 ? vec3(1.0, 0.9, 0.25) : vec3(0.97, 0.97, 0.92));
		c = mix(c, flower, grass * fdot * step(0.975, fh) * (1.0 - smoothstep(10.0, 25.0, dist)) * (1.0 - autumn) * (1.0 - snow));
		// Асфальт: крошка и трещины
		float asph = ground_lvl * grey * (1.0 - smoothstep(0.34, 0.5, lum));
		float crack_n = texture(grain, wpos.xz * 0.19).r;
		// Трещины — редкие: тонкая линия шума и только там, где асфальт старый
		float old = smoothstep(0.99, 1.03, big);
		float crack = (1.0 - smoothstep(0.0, 0.004, abs(crack_n - 0.925))) * old;
		c *= mix(1.0, 0.82 + 0.3 * (fine - 0.78) / 0.28, asph * near);
		c *= 1.0 - asph * crack * 0.35 * near;
		// Щебёнка в асфальте и тёмные заплатки, где латали ямы
		c = mix(c, c * 1.28 + 0.02, asph * near * smoothstep(0.82, 0.92, fine3.g) * 0.7);
		c *= mix(1.0, 0.84 + 0.26 * mid3.g, asph * near);
		// Масляные пятна и колеи — темнее
		c *= 1.0 - 0.1 * asph * smoothstep(0.7, 0.85, mid3.b);
		c *= 1.0 - 0.16 * asph * (1.0 - smoothstep(0.14, 0.2, big3.g));
		// Грунт и гравий: камешки светлее, выбоины темнее
		float dirt = ground_lvl * brown * (1.0 - green);
		float pebble = smoothstep(1.015, 1.045, fine);
		c = mix(c, c * 1.3 + 0.03, dirt * pebble * near);
		c *= mix(1.0, mix(0.86, 1.08, (big - 0.78) / 0.28), dirt);
		// Камешки покрупнее и сырые низинки (темнее, с отливом)
		c = mix(c, vec3(0.62, 0.6, 0.56), dirt * near * smoothstep(0.88, 0.95, mid3.g) * 0.8);
		c *= mix(1.0, 0.85 + 0.25 * mid3.r, dirt * near);
		float damp = dirt * (1.0 - smoothstep(0.25, 0.4, big3.b));
		c *= 1.0 - 0.18 * damp;
		rough = mix(rough, 0.6, damp);
		// Стены из досок: щели между досками и волокна дерева
		float wood = vert * brown * (1.0 - red) * (1.0 - smoothstep(0.45, 0.6, lum));
		float along = wpos.x * abs(wnrm.z) + wpos.z * abs(wnrm.x);
		float fy = fract(wpos.y / 0.19);
		float gap = smoothstep(0.9, 0.97, fy) + (1.0 - smoothstep(0.0, 0.03, fy));
		vec3 fib3 = texture(grain, vec2(along * 0.35, wpos.y * 7.0)).rgb;
		float fibre = fib3.r * 0.5 + (0.78 + fib3.b * 0.28) * 0.5;
		// Сучки — тёмные пятнышки на досках
		float knot = smoothstep(0.9, 0.97, fib3.g);
		float board = hash(vec2(floor(wpos.y / 0.19), floor(along / 2.3)));
		c *= mix(1.0, (1.0 - 0.45 * gap) * (0.82 + 0.28 * (fibre - 0.78) / 0.28) * (0.9 + 0.2 * board) * (1.0 - 0.35 * knot), wood * near);
		// Кирпич: ряды со сдвигом, светлый шов, кирпичи разного тона
		float brick = vert * red * smoothstep(0.2, 0.3, lum) * (1.0 - wood);
		float row = floor(wpos.y / 0.075);
		float u = along / 0.26 + row * 0.5;
		float seam = max(1.0 - smoothstep(0.0, 0.07, fract(u)), 1.0 - smoothstep(0.0, 0.14, fract(wpos.y / 0.075)));
		float tone = hash(vec2(floor(u), row));
		vec3 bc = c * (0.86 + 0.26 * tone);
		c = mix(c, mix(bc, vec3(0.72, 0.7, 0.64), seam * 0.8), brick * near);
		// Штукатурка и панели: подтёки и швы между плитами
		float plaster = vert * grey * smoothstep(0.4, 0.55, lum) * step(0.9, wpos.y);
		float pseam = max(1.0 - smoothstep(0.0, 0.012, abs(fract(wpos.y / 2.8) - 0.5) - 0.488),
			1.0 - smoothstep(0.0, 0.01, abs(fract(along / 3.2) - 0.5) - 0.49));
		vec3 st3 = texture(grain, vec2(along * 0.4, wpos.y * 0.12)).rgb;
		float stain = st3.r;
		c *= mix(1.0, (0.9 + 0.14 * (stain - 0.78) / 0.28) * (1.0 - 0.18 * pseam), plaster * near);
		// Облезлая краска пятнами и потёки от дождя сверху вниз
		c = mix(c, c * vec3(0.9, 0.88, 0.84), plaster * near * smoothstep(0.86, 0.93, st3.g));
		float streak = texture(grain, vec2(along * 1.7, wpos.y * 0.03)).b;
		c *= 1.0 - 0.12 * plaster * near * smoothstep(0.62, 0.8, streak);
		// Крыши: ряды черепицы или шифера вдоль ската и волна поперёк
		float fr = fract(wpos.y * 5.0);
		float wave = 0.5 + 0.5 * sin((wpos.x + wpos.z) * 11.0);
		c *= mix(1.0, (1.0 - 0.3 * smoothstep(0.82, 0.98, fr)) * (0.9 + 0.12 * wave), slope * near);
		rough = mix(rough, 0.75, slope);
		// Шифер серый — с зелёными пятнами мха и лишайника
		float moss = slope * grey * smoothstep(0.75, 0.9, big3.g) * (0.6 + 0.4 * fine3.g);
		c = mix(c, vec3(0.38, 0.45, 0.25) * (0.8 + 0.3 * fine), moss * 0.55);
		// Грязь у низа стен: брызги с земли, тёмная полоса цоколя
		float base = vert * (1.0 - smoothstep(0.05, 0.55, wpos.y)) * (1.0 - green);
		c = mix(c, c * vec3(0.7, 0.64, 0.56), base * (0.5 + 0.5 * fine3.g) * 0.8);
	}
	c = mix(c, vec3(c.g * 1.05 + 0.04, c.g * 0.7, c.b * 0.4), autumn * green);
	c = mix(c, c * vec3(1.0, 1.12, 0.95), spring * green);
	// Мокро: земля и дороги темнее и блестят лужицами
	float wetk = wet * ground_lvl * (1.0 - snow);
	c *= 1.0 - 0.3 * wetk;
	rough = mix(rough, 0.25, wetk * (1.0 - green * 0.7));
	// Снег: на земле (низко и ровно) и на скатах крыш
	float flat_up = smoothstep(0.55, 0.85, wnrm.y);
	float ground = flat_up * (1.0 - smoothstep(0.1, 0.2, wpos.y)) * mix(0.6, 1.0, green);
	float roof = smoothstep(0.25, 0.45, wnrm.y) * (1.0 - smoothstep(0.9, 0.97, wnrm.y)) * smoothstep(2.0, 2.6, wpos.y);
	float s = snow * max(ground, roof);
	c = mix(c, vec3(0.9, 0.92, 0.96), s * (0.8 + 0.2 * g));
	ALBEDO = c * g * 1.08;
	ROUGHNESS = rough;
	SPECULAR = mix(0.4, 0.7, wetk);
}
"""

static var _world_mat: ShaderMaterial
static var _detail_mat: ShaderMaterial


static func world_material() -> ShaderMaterial:
	if _world_mat == null:
		var sh := Shader.new()
		sh.code = WORLD_SHADER
		_world_mat = ShaderMaterial.new()
		_world_mat.shader = sh
		_world_mat.set_shader_parameter("grain", grain())
	return _world_mat


## Материал неподвижного мира: тот же шейдер, но с рисунком поверхностей.
static func detail_material() -> ShaderMaterial:
	if _detail_mat == null:
		_detail_mat = world_material().duplicate() as ShaderMaterial
		_detail_mat.set_shader_parameter("detailed", true)
	return _detail_mat


## Сезон для всего мира: снег, осень, весна — от 0 до 1.
static func set_season(snow: float, autumn: float, spring: float) -> void:
	for m in [world_material(), detail_material()]:
		m.set_shader_parameter("snow", snow)
		m.set_shader_parameter("autumn", autumn)
		m.set_shader_parameter("spring", spring)


## Мокрая земля после дождя (0..1) и качество рисунка из настроек.
static func set_surface(wet: float, quality: float) -> void:
	for m in [world_material(), detail_material()]:
		m.set_shader_parameter("wet", wet)
		m.set_shader_parameter("quality", quality)


static var _grain: Texture2D


## Общая для всех текстура-зерно — textures/world/grain.png (см. Assets).
static func grain() -> Texture2D:
	if _grain == null:
		_grain = Assets.texture("world/grain", grain_image, true)
	return _grain


## Зерно, 256 × 256, бесшовное. Три узора в каналах (одна выборка в шейдере):
## R — крупные пятна + мелкая крупка, яркость 0.78–1.06 (общий тон
## поверхностей); G — ячейки (камешки, щебёнка, кочки травы, пятна мха и
## заплаток), 0..1; B — вытянутые волокна (доски, потёки на стенах), 0..1.
static func grain_image() -> Image:
	var big := FastNoiseLite.new()
	big.seed = 7
	big.frequency = 0.02
	var fine := FastNoiseLite.new()
	fine.seed = 11
	fine.frequency = 0.175
	var cells := FastNoiseLite.new()
	cells.seed = 23
	cells.noise_type = FastNoiseLite.TYPE_CELLULAR
	cells.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
	cells.frequency = 0.06
	var fib := FastNoiseLite.new()
	fib.seed = 31
	fib.frequency = 0.02
	fib.fractal_octaves = 3
	var n := 256
	var img := Image.create(n, n, true, Image.FORMAT_RGB8)
	# Бесшовно: шум на торе — четыре угла плитки усредняются
	for y in n:
		for x in n:
			var v := 0.0
			var cg := 0.0
			var fb := 0.0
			for dy in [0, n]:
				for dx in [0, n]:
					var w := (1.0 - absf(float(x + dx - n) / n)) * (1.0 - absf(float(y + dy - n) / n))
					v += w * (big.get_noise_2d(x + dx, y + dy) * 0.55 + fine.get_noise_2d(x + dx, y + dy) * 0.45)
					cg += w * cells.get_noise_2d(x + dx, y + dy)
					# Волокна вдоль X: по Y частые, по X редкие
					fb += w * fib.get_noise_2d((x + dx) * 0.12, (y + dy) * 2.2)
			var k := clampf(0.93 + v * 0.22, 0.78, 1.06)
			img.set_pixel(x, y, Color(k, clampf((cg + 0.74) / 0.62, 0.0, 1.0), clampf(fb * 0.9 + 0.5, 0.0, 1.0)))
	img.generate_mipmaps()
	return img


## Одно статическое тело со всеми коллизиями.
## Тело со всеми коробками-коллизиями. Формы отдаются прямо физическому
## серверу, без узла CollisionShape3D на каждую: в мире их десятки тысяч
## (стволы, заборы, стены) — узлы съедали бы память и время загрузки на
## телефоне. Коробки одного размера делят одну форму.
func build_body() -> StaticBody3D:
	var body := StaticBody3D.new()
	var shapes := {}
	var rid := body.get_rid()
	for b in _boxes:
		var size: Vector3 = b[1]
		var key := Vector3i((size * 1000.0).round())
		var shape: BoxShape3D = shapes.get(key)
		if shape == null:
			shape = BoxShape3D.new()
			shape.size = size
			shapes[key] = shape
		PhysicsServer3D.body_add_shape(rid, shape.get_rid(), b[0])
	# Формы живут, пока на них ссылается тело
	body.set_meta("shapes", shapes.values())
	body.set_meta("shape_count", _boxes.size())
	return body
