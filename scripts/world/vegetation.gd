class_name Vegetation
extends Node3D
## Деревья, кусты, трава, цветы, пшеница и камни.
##
## Всё рисуется через MultiMesh: одна подробная модель — тысячи копий за
## один вызов отрисовки. Деревья — по MultiMesh на вид (их мало, видны
## издалека). Трава, цветы и колосья — кусками 50×50 м, дальние куски не
## рисуются (visibility_range), вблизи трава качается на ветру (шейдер).
##
## Мир сначала регистрирует деревья (add_tree) и места, где травы быть не
## должно (block: дороги, дома, площадки), потом вызывает build().

enum TreeKind { SPRUCE, APPLE, BIRCH, BUSH, POPLAR }

const CHUNK := 25.0
## Деревья — кусками 100×100 м: вызовов отрисовки вчетверо меньше, чем при 50 м,
## а тени всё равно не рисуют весь лес сразу.
const TREE_CHUNK := 100.0
const FAR_CHUNK := 400.0
const GRASS_RANGE := 75.0

const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform float sway = 0.07;
uniform float snow = 0.0;
uniform float autumn = 0.0;
uniform float clouds = 0.0;
uniform vec2 cloud_wind = vec2(3.0, 1.2);

varying vec3 gpos;
// Тень облака — по вершинам (травинки мелкие), а не по каждой точке экрана
varying float cshade;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Тени от облаков: плавный шум, плывёт по ветру
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float cloud_shadow(vec3 wp) {
	vec2 p = (wp.xz + cloud_wind * TIME) / 70.0;
	float n = vnoise(p) * 0.65 + vnoise(p * 2.3 + 7.1) * 0.35;
	return smoothstep(0.47, 0.6, n);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	gpos = wp;
	float h = max(VERTEX.y, 0.0);
	float t = TIME;
	VERTEX.x += sin(t * 1.7 + wp.x * 0.35 + wp.z * 0.21) * sway * h * 2.5;
	VERTEX.z += cos(t * 1.3 + wp.z * 0.31 + wp.x * 0.12) * sway * h * 1.8;
	cshade = clouds > 0.0 ? 1.0 - clouds * 0.42 * cloud_shadow(wp) : 1.0;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float green = clamp((c.g - max(c.r, c.b)) * 6.0, 0.0, 1.0);
	c = mix(c, vec3(c.g * 1.05 + 0.04, c.g * 0.7, c.b * 0.4), autumn * green);
	// Зимой трава под снегом, торчат только кончики
	c = mix(c, vec3(0.88, 0.9, 0.94), snow * 0.85);
	c *= cshade;
	ALBEDO = c;
	ROUGHNESS = 0.95;
	// Освещаем как землю, с обеих сторон травинки: иначе изнанка
	// считается смотрящей вниз и выходит чёрной
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
"""

var _trees := {TreeKind.SPRUCE: [], TreeKind.APPLE: [], TreeKind.BIRCH: [], TreeKind.BUSH: [], TreeKind.POPLAR: []}
var _blocked: Array[Rect2] = []
var _rng := RandomNumberGenerator.new()
var _grass_mat: ShaderMaterial
## Материал травы — один на всё; сезоны меняют его параметры.
static var grass_material: ShaderMaterial
## Сколько чего посажено — для отчёта в консоли и тестов.
var counts := {}
## Где растёт трава: Каменка и сёла района (дальше — только земля).
var areas: Array[Rect2] = [Rect2(-200, -200, 400, 400)]
## Деревья целиком рисуются до SettingsManager.tree_range(), дальше —
## простые силуэты (ель — конус, берёза — ромб) до края видимости: лес
## видно до горизонта, а треугольников в десятки раз меньше.


## Сдвиг для деревьев и запретов травы, пока строится город (Town.SHIFT).
var shift := Vector3.ZERO


func add_tree(kind: int, xf: Transform3D) -> void:
	_trees[kind].append(xf.translated(shift))


## Прямоугольник в плане (X, Z), где не растёт трава.
func block(x0: float, z0: float, x1: float, z1: float) -> void:
	_blocked.append(Rect2(minf(x0, x1) + shift.x, minf(z0, z1) + shift.z, absf(x1 - x0), absf(z1 - z0)))


func build() -> void:
	_rng.seed = 90210
	var models := {
		TreeKind.SPRUCE: _spruce_mesh(),
		TreeKind.APPLE: _apple_mesh(),
		TreeKind.BIRCH: _birch_mesh(),
		TreeKind.BUSH: _bush_mesh(),
		TreeKind.POPLAR: _poplar_mesh(),
	}
	var mid_models := {
		TreeKind.SPRUCE: _mid_spruce(),
		TreeKind.APPLE: _mid_apple(),
		TreeKind.BIRCH: _mid_birch(),
		TreeKind.BUSH: _mid_bush(),
		TreeKind.POPLAR: _mid_poplar(),
	}
	var far_models := {TreeKind.SPRUCE: _far_spruce(), TreeKind.BIRCH: _far_birch(), TreeKind.POPLAR: _far_poplar()}
	for kind in _trees:
		var list: Array = _trees[kind]
		if list.is_empty():
			continue
		counts["tree_%d" % kind] = list.size()
		# По участкам 50×50 м: невидимые участки отсекаются и в тенях
		var cells := {}
		for xf in list:
			var o: Vector3 = (xf as Transform3D).origin
			var key := Vector2i(floori(o.x / TREE_CHUNK), floori(o.z / TREE_CHUNK))
			if not cells.has(key):
				cells[key] = []
			cells[key].append(xf)
		# Вблизи — подробное дерево, дальше в том же куске — упрощённое
		# (в десять раз меньше треугольников): куски одни и те же, поэтому
		# одно сменяет другое без пропусков
		for key in cells:
			var part: Array = cells[key]
			for lod in ["Trees", "TreesMid"]:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = models[kind] if lod == "Trees" else mid_models[kind]
				mm.instance_count = part.size()
				for i in part.size():
					mm.set_instance_transform(i, part[i])
				var mi := MultiMeshInstance3D.new()
				mi.multimesh = mm
				mi.name = "%s_%d_%d_%d" % [lod, kind, key.x, key.y]
				add_child(mi)

		# Силуэты — крупными кусками по 400 м: вдали деревьев много, а
		# вызовов отрисовки должно быть мало
		if far_models.has(kind):
			var far_cells := {}
			for xf in list:
				var o: Vector3 = (xf as Transform3D).origin
				var key := Vector2i(floori(o.x / FAR_CHUNK), floori(o.z / FAR_CHUNK))
				if not far_cells.has(key):
					far_cells[key] = []
				far_cells[key].append(xf)
			for key in far_cells:
				var part: Array = far_cells[key]
				var fm := MultiMesh.new()
				fm.transform_format = MultiMesh.TRANSFORM_3D
				fm.mesh = far_models[kind]
				fm.instance_count = part.size()
				for i in part.size():
					fm.set_instance_transform(i, part[i])
				var fi := MultiMeshInstance3D.new()
				fi.multimesh = fm
				fi.name = "TreesFar_%d_%d_%d" % [kind, key.x, key.y]
				fi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(fi)
	_build_ground_cover()
	SettingsManager.changed.connect(apply_detail)
	apply_detail()


## Детализация из настроек: дальность травы (на низкой — только у самых ног).
func apply_detail() -> void:
	var r := SettingsManager.grass_range()
	var near := SettingsManager.tree_range()
	var lod := SettingsManager.tree_lod_range()
	for c in get_children():
		var gi := c as GeometryInstance3D
		if c.name.begins_with("TreesFar"):
			gi.visibility_range_begin = near
			gi.visibility_range_end = SettingsManager.view_range()
			continue
		if c.name.begins_with("TreesMid"):
			# Яблони и кусты силуэтов не имеют — они и так у домов
			gi.visibility_range_begin = lod
			gi.visibility_range_end = near if (c.name.begins_with("TreesMid_0") or c.name.begins_with("TreesMid_2") or c.name.begins_with("TreesMid_4")) else minf(near, 300.0)
			continue
		if c.name.begins_with("Trees"):
			gi.visibility_range_end = lod
			continue
		var mi := c as MultiMeshInstance3D
		mi.visible = r > 0.0
		mi.visibility_range_end = r * (1.6 if c.name.begins_with("wheat") else 1.0)


# --- Трава, цветы, колосья, камни ------------------------------------------

## Густота травы: на телефоне реже.
static func _density() -> float:
	return 0.6 if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") else 1.0


func _build_ground_cover() -> void:
	var sh := Shader.new()
	sh.code = GRASS_SHADER
	_grass_mat = ShaderMaterial.new()
	_grass_mat.shader = sh
	grass_material = _grass_mat
	var tuft := _tuft_mesh(0.34, 5, Color(0.26, 0.42, 0.16), Color(0.5, 0.66, 0.28))
	var tall := _tuft_mesh(0.7, 7, Color(0.3, 0.42, 0.18), Color(0.58, 0.64, 0.3))
	var wheat := _tuft_mesh(0.95, 6, Color(0.55, 0.47, 0.22), Color(0.92, 0.8, 0.42), true)
	var flower := _flower_mesh()
	var stone := _stone_mesh()
	var wheat_rect := Rect2(26.0, -184.0, 73.0, 73.0)
	var plough_rect := Rect2(25.0, -100.0, 165.0, 70.0)
	var total := {"grass": 0, "flowers": 0, "wheat": 0, "stones": 0}
	var cells_list: Array[Vector2] = []
	for area in areas:
		for cx in int(ceilf(area.size.x / CHUNK)):
			for cz in int(ceilf(area.size.y / CHUNK)):
				cells_list.append(area.position + Vector2(cx, cz) * CHUNK)
	for cell_pos in cells_list:
		var x0 := cell_pos.x
		var z0 := cell_pos.y
		var cell := Rect2(x0, z0, CHUNK, CHUNK)
		# Проверяем только те запреты, что задевают этот кусок
		var local: Array[Rect2] = []
		for r in _blocked:
			if r.intersects(cell):
				local.append(r)
		var grass := PackedFloat32Array()
		var tall_l := PackedFloat32Array()
		var flowers := PackedFloat32Array()
		var wheat_l := PackedFloat32Array()
		var stones := PackedFloat32Array()
		# Около 1.1 пучка на квадратный метр, пшеница — 5; на телефоне —
		# 60 % (видно её всё равно только рядом, а память и видеочип слабее)
		var tries := int(CHUNK * CHUNK * 1.1 * _density())
		if cell.intersects(wheat_rect):
			tries = int(CHUNK * CHUNK * 5.0 * _density())
		for i in tries:
			var x := x0 + _rng.randf() * CHUNK
			var z := z0 + _rng.randf() * CHUNK
			var pt := Vector2(x, z)
			if wheat_rect.has_point(pt):
				_push(wheat_l, x, 0.0, z, _rng.randf_range(0.85, 1.2))
				continue
			if plough_rect.has_point(pt):
				continue
			var blocked := false
			for r in local:
				if r.has_point(pt):
					blocked = true
					break
			if blocked:
				# На дорогах и площадках — только редкие камешки
				if _rng.randf() < 0.012:
					_push(stones, x, 0.03, z, _rng.randf_range(0.5, 1.3))
				continue
			if wheat_l.size() == 0 and tries > CHUNK * CHUNK * 2.0 and _rng.randf() < 0.78:
				# Кусок с полем — на лугу вокруг сажаем реже, чтобы не было втрое гуще
				continue
			var r := _rng.randf()
			if r < 0.03:
				_push(flowers, x, 0.0, z, _rng.randf_range(0.8, 1.2))
			elif r < 0.11:
				_push(tall_l, x, 0.0, z, _rng.randf_range(0.7, 1.3))
			else:
				_push(grass, x, 0.0, z, _rng.randf_range(0.7, 1.35))
		_chunk(tuft, grass, "grass")
		_chunk(tall, tall_l, "tall")
		_chunk(flower, flowers, "flowers")
		_chunk(wheat, wheat_l, "wheat")
		_chunk(stone, stones, "stones", false)
		total.grass += (grass.size() + tall_l.size()) / 12
		total.flowers += flowers.size() / 12
		total.wheat += wheat_l.size() / 12
		total.stones += stones.size() / 12
	counts.merge(total)


## Дописывает в буфер MultiMesh поворот вокруг вертикали, масштаб и место
## (12 чисел: три строки базиса и сдвиг, как ждёт MultiMesh).
func _push(buf: PackedFloat32Array, x: float, y: float, z: float, s: float) -> void:
	var a := _rng.randf() * TAU
	var c := cos(a) * s
	var n := sin(a) * s
	buf.append_array([c, 0.0, n, x, 0.0, s, 0.0, y, -n, 0.0, c, z])


func _chunk(mesh: Mesh, buf: PackedFloat32Array, label: String, sway := true) -> void:
	if buf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = buf.size() / 12
	mm.buffer = buf
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.name = label
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = GRASS_RANGE if label != "wheat" else GRASS_RANGE * 1.6
	if sway:
		mi.material_override = _grass_mat
	add_child(mi)


## Пучок травинок: узкие треугольники веером, у корня темнее.
func _tuft_mesh(height: float, blades: int, base: Color, tip: Color, ears := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = blades * 31 + int(height * 100)
	for i in blades:
		var a := TAU * i / blades + rng.randf() * 0.5
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.05, 0.16)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.022
		var h := height * rng.randf_range(0.7, 1.15)
		var root := Vector3(cos(a), 0, sin(a)) * 0.03
		var top := root + lean + Vector3(0, h, 0)
		for v in [[root - side, base], [root + side, base], [top, tip]]:
			st.set_color(v[1])
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
		if ears:
			# Колос — утолщение на верхушке
			var e := top - Vector3(0, 0.12, 0)
			for v in [[e - side * 1.8, tip.darkened(0.1)], [e + side * 1.8, tip.darkened(0.1)], [top + Vector3(0, 0.03, 0), tip]]:
				st.set_color(v[1])
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
	return st.commit()


## Цветок: стебель и венчик из четырёх лепестков; цвет выбирается по семени.
func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem := Color(0.28, 0.45, 0.18)
	var colors := [Color(0.95, 0.95, 0.9), Color(0.95, 0.85, 0.2), Color(0.6, 0.45, 0.9), Color(0.9, 0.3, 0.3)]
	for k in 4:
		var off := Vector3(cos(k * 1.7) * 0.12, 0, sin(k * 1.7) * 0.12)
		var h := 0.28 + k * 0.05
		var c: Color = colors[k]
		for v in [[off + Vector3(-0.01, 0, 0), stem], [off + Vector3(0.01, 0, 0), stem], [off + Vector3(0, h, 0), stem]]:
			st.set_color(v[1])
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
		var top := off + Vector3(0, h, 0)
		for p in 4:
			var a := p * PI * 0.5
			var d := Vector3(cos(a), 0, sin(a)) * 0.05
			var d2 := Vector3(cos(a + 0.8), 0, sin(a + 0.8)) * 0.05
			for v in [top, top + d, top + d2]:
				st.set_color(c)
				st.set_normal(Vector3.UP)
				st.add_vertex(v + Vector3(0, 0.01, 0))
	return st.commit()


func _stone_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.ground_shade = false
	b.box_rot(Vector3(0, 0.03, 0), Vector3(0.14, 0.07, 0.1), 0.3, Color(0.52, 0.5, 0.47))
	b.box_rot(Vector3(0.09, 0.02, 0.05), Vector3(0.07, 0.04, 0.06), 1.1, Color(0.45, 0.44, 0.42))
	return b.build_array_mesh()


# --- Деревья ---------------------------------------------------------------

## Ель: ствол и восемь ярусов лап, каждый — шесть свисающих веток.
func _spruce_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	b.box(Vector3(-0.16, 0, -0.16), Vector3(0.16, 6.6, 0.16), Color(0.33, 0.24, 0.17))
	var tiers := 8
	for t in tiers:
		var k := float(t) / tiers
		var y := 1.2 + k * 5.6
		var reach := lerpf(2.1, 0.45, k)
		var green := Color(0.12, 0.27, 0.14).lightened(k * 0.1 + rng.randf() * 0.04)
		for i in 6:
			var a := TAU * i / 6.0 + t * 0.5
			var dir := Vector3(cos(a), 0, sin(a))
			var mid := dir * reach * 0.5 + Vector3(0, y - reach * 0.18, 0)
			var saved := b.xf
			b.xf = Transform3D(Basis(Vector3.UP, -a).rotated(dir.cross(Vector3.UP).normalized(), -0.35), mid)
			b.box(Vector3(-reach * 0.5, -0.22, -0.32), Vector3(reach * 0.5, 0.22, 0.32), green)
			b.xf = saved
		b.box_rot(Vector3(0, y + 0.1, 0), Vector3(reach * 0.9, 0.5, reach * 0.9), t * 0.4, green.darkened(0.1))
	b.box(Vector3(-0.12, 7.0, -0.12), Vector3(0.12, 7.9, 0.12), Color(0.16, 0.33, 0.17))
	return b.build_array_mesh()


## Ель на средней дальности: ствол и три яруса-шатра (48 треугольников
## вместо 700) — тех же размеров и цвета, что подробная.
func _mid_spruce() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.box(Vector3(-0.16, 0, -0.16), Vector3(0.16, 1.4, 0.16), Color(0.33, 0.24, 0.17))
	var tiers := [[1.0, 3.6, 2.1], [2.9, 5.6, 1.5], [4.7, 7.9, 0.9]]
	for t in tiers.size():
		var y0: float = tiers[t][0]
		var y1: float = tiers[t][1]
		var r: float = tiers[t][2]
		var green := Color(0.13, 0.28, 0.15).lightened(t * 0.04)
		var top := Vector3(0, y1, 0)
		for i in 6:
			var a0 := TAU * i / 6.0 + t * 0.5
			var a1 := TAU * (i + 1) / 6.0 + t * 0.5
			var p0 := Vector3(cos(a0) * r, y0, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, y0, sin(a1) * r)
			b.tri(p0, top, p1, green)
			b.tri(p0, p1, Vector3(0, y0 + 0.3, 0), green.darkened(0.3))
	return b.build_array_mesh()


## Тополь вблизи: серый ствол и высокая узкая крона-колонна из комков
## листвы — как вдоль украинских дорог.
func _poplar_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bark := Color(0.5, 0.48, 0.42)
	_limb(b, Vector3.ZERO, Vector3(0, 9.5, 0), 0.2, bark)
	var leaf := Color(0.26, 0.45, 0.2)
	for i in 40:
		var y := rng.randf_range(2.2, 12.5)
		var k := sin(clampf((y - 2.0) / 10.8, 0.0, 1.0) * PI)
		var r := 1.15 * k * rng.randf_range(0.3, 1.0) + 0.2
		var a := rng.randf() * TAU
		var c := Vector3(cos(a) * r, y, sin(a) * r)
		b.box_rot(c, Vector3(0.7, 0.9, 0.7) * rng.randf_range(0.7, 1.2), rng.randf() * TAU, leaf.lightened(rng.randf() * 0.12 - 0.04))
	return b.build_array_mesh()


## Тополь на средней дальности: ствол и три вытянутых комка.
func _mid_poplar() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.box(Vector3(-0.16, 0, -0.16), Vector3(0.16, 3.0, 0.16), Color(0.5, 0.48, 0.42))
	var leaf := Color(0.26, 0.45, 0.2)
	b.box_rot(Vector3(0, 4.6, 0), Vector3(2.0, 3.4, 2.0), 0.3, leaf)
	b.box_rot(Vector3(0, 7.8, 0), Vector3(2.1, 3.4, 2.1), 1.0, leaf.lightened(0.05))
	b.box_rot(Vector3(0, 10.9, 0), Vector3(1.3, 2.8, 1.3), 0.6, leaf.lightened(0.09))
	return b.build_array_mesh()


## Силуэт тополя издали: высокий узкий ромб.
func _far_poplar() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.ground_shade = false
	var n := 6
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0) * 1.25, 6.8, sin(a0) * 1.25)
		var p1 := Vector3(cos(a1) * 1.25, 6.8, sin(a1) * 1.25)
		b.tri(p0, Vector3(0, 12.8, 0), p1, Color(0.27, 0.45, 0.21))
		b.tri(p0, p1, Vector3(0, 2.2, 0), Color(0.22, 0.38, 0.17))
	b.box(Vector3(-0.15, 0, -0.15), Vector3(0.15, 2.4, 0.15), Color(0.5, 0.48, 0.42))
	return b.build_array_mesh()


## Берёза на средней дальности: ствол и крона из трёх комков.
func _mid_birch() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.box(Vector3(-0.13, 0, -0.13), Vector3(0.13, 6.2, 0.13), Color(0.9, 0.9, 0.86))
	var leaf := Color(0.35, 0.55, 0.22)
	b.box_rot(Vector3(0, 3.9, 0), Vector3(2.6, 1.9, 2.6), 0.3, leaf)
	b.box_rot(Vector3(0.1, 5.4, -0.1), Vector3(2.3, 1.6, 2.3), 1.1, leaf.lightened(0.06))
	b.box_rot(Vector3(-0.1, 6.7, 0.1), Vector3(1.3, 1.1, 1.3), 0.7, leaf.lightened(0.1))
	return b.build_array_mesh()


## Яблоня на средней дальности: ствол и раскидистая крона.
func _mid_apple() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.box(Vector3(-0.13, 0, -0.13), Vector3(0.13, 1.4, 0.13), Color(0.38, 0.28, 0.2))
	b.box(Vector3(-0.14, 0, -0.14), Vector3(0.14, 0.7, 0.14), Color(0.92, 0.92, 0.88))
	var leaf := Color(0.24, 0.44, 0.19)
	b.box_rot(Vector3(0, 2.2, 0), Vector3(3.4, 1.5, 3.4), 0.4, leaf)
	b.box_rot(Vector3(0, 2.9, 0), Vector3(2.4, 1.0, 2.4), 1.2, leaf.lightened(0.06))
	return b.build_array_mesh()


## Куст на средней дальности: два комка.
func _mid_bush() -> ArrayMesh:
	var b := MeshBuilder.new()
	var leaf := Color(0.22, 0.4, 0.17)
	PersonModel.ball(b, Vector3(0, 0.5, 0), Vector3(0.8, 0.55, 0.75), leaf, 3, 6)
	return b.build_array_mesh()


## Силуэт ели издали: тёмный конус на коротком стволе (18 треугольников).
func _far_spruce() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.ground_shade = false
	var n := 6
	var top := Vector3(0, 7.9, 0)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0) * 2.1, 1.1, sin(a0) * 2.1)
		var p1 := Vector3(cos(a1) * 2.1, 1.1, sin(a1) * 2.1)
		b.tri(p0, top, p1, Color(0.13, 0.27, 0.15))
		b.tri(p0, p1, Vector3(0, 1.1, 0), Color(0.1, 0.2, 0.11))
	b.box(Vector3(-0.16, 0, -0.16), Vector3(0.16, 1.1, 0.16), Color(0.33, 0.24, 0.17))
	return b.build_array_mesh()


## Силуэт берёзы издали: белый ствол и крона-ромб.
func _far_birch() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.ground_shade = false
	var n := 6
	var top := Vector3(0, 7.4, 0)
	var bottom := Vector3(0, 2.6, 0)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0) * 1.8, 4.8, sin(a0) * 1.8)
		var p1 := Vector3(cos(a1) * 1.8, 4.8, sin(a1) * 1.8)
		b.tri(p0, top, p1, Color(0.36, 0.56, 0.23))
		b.tri(p0, p1, bottom, Color(0.28, 0.45, 0.18))
	b.box(Vector3(-0.13, 0, -0.13), Vector3(0.13, 2.8, 0.13), Color(0.9, 0.9, 0.86))
	return b.build_array_mesh()


## Берёза: белый ствол с чёрными полосками, ветки вверх и овальная крона
## из множества небольших комков листвы.
func _birch_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var bark := Color(0.9, 0.9, 0.86)
	b.box(Vector3(-0.13, 0, -0.13), Vector3(0.13, 6.2, 0.13), bark)
	for i in 11:
		var y := 0.4 + i * 0.5 + rng.randf() * 0.2
		var w := rng.randf_range(0.06, 0.14)
		var side := rng.randi() % 4
		var mn := Vector3(-0.14, y, -0.14)
		var mx := Vector3(0.14, y + w * 0.4, 0.14)
		if side < 2:
			mn.x = 0.0 if side == 0 else -0.14
			mx.x = 0.14 if side == 0 else 0.0
		b.box(mn, mx, Color(0.12, 0.12, 0.12))
	var leaf := Color(0.35, 0.55, 0.22)
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf() * 0.4
		var dir := Vector3(cos(a), 0, sin(a))
		var start := Vector3(0, 2.6 + i * 0.45, 0)
		var end := start + dir * rng.randf_range(0.8, 1.3) + Vector3(0, 1.3, 0)
		_limb(b, start, end, 0.045, bark.darkened(0.1))
	# Крона — овал из комков: шире в середине, уже к макушке
	for i in 34:
		var y := rng.randf_range(2.8, 7.2)
		var k := 1.0 - absf((y - 4.8) / 2.6)
		var r := 1.6 * k * rng.randf_range(0.4, 1.0)
		var a := rng.randf() * TAU
		var c := Vector3(cos(a) * r, y, sin(a) * r)
		b.box_rot(c, Vector3(0.75, 0.55, 0.75) * rng.randf_range(0.7, 1.2), rng.randf() * TAU, leaf.lightened(rng.randf() * 0.14 - 0.03))
	return b.build_array_mesh()


## Яблоня: низкий ствол с развилкой, раскидистая крона, яблоки.
func _apple_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var bark := Color(0.38, 0.28, 0.2)
	b.box(Vector3(-0.13, 0, -0.13), Vector3(0.13, 1.2, 0.13), bark)
	# Побелка ствола
	b.box(Vector3(-0.14, 0, -0.14), Vector3(0.14, 0.7, 0.14), Color(0.92, 0.92, 0.88))
	var leaf := Color(0.24, 0.44, 0.19)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var dir := Vector3(cos(a), 0, sin(a))
		var end := Vector3(0, 1.2, 0) + dir * 1.1 + Vector3(0, 0.9, 0)
		_limb(b, Vector3(0, 1.1, 0), end, 0.07, bark)
		for j in 2:
			b.box_rot(end + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.0, 0.4), rng.randf_range(-0.4, 0.4)),
				Vector3(1.4, 1.0, 1.4) * rng.randf_range(0.8, 1.1), rng.randf() * TAU, leaf.lightened(rng.randf() * 0.1))
	b.box_rot(Vector3(0, 2.7, 0), Vector3(1.8, 1.2, 1.8), 0.3, leaf.lightened(0.05))
	for i in 16:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.9, 1.7)
		var p := Vector3(cos(a) * r, rng.randf_range(1.5, 2.8), sin(a) * r)
		b.box(p - Vector3(0.06, 0.06, 0.06), p + Vector3(0.06, 0.06, 0.06), Color(0.82, 0.18, 0.12) if i % 3 else Color(0.85, 0.75, 0.2))
	return b.build_array_mesh()


## Куст: несколько округлых комков листвы.
func _bush_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var leaf := Color(0.22, 0.4, 0.17)
	# Округлые шапки листвы, а не кубики
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf_range(-0.4, 0.4)
		var p := Vector3(cos(a) * 0.35, rng.randf_range(0.45, 0.65), sin(a) * 0.35)
		var r := rng.randf_range(0.45, 0.6)
		PersonModel.ball(b, p, Vector3(r, r * 0.85, r), leaf.lightened(rng.randf() * 0.12), 3, 7)
	return b.build_array_mesh()


## Ветка от a до b — брусок, повёрнутый вдоль отрезка.
func _limb(b: MeshBuilder, a: Vector3, c: Vector3, r: float, color: Color) -> void:
	var d := c - a
	var length := d.length()
	var y := d / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var saved := b.xf
	b.xf = saved * Transform3D(Basis(x, y, z), (a + c) * 0.5)
	b.box(Vector3(-r, -length * 0.5, -r), Vector3(r, length * 0.5, r), color)
	b.xf = saved
