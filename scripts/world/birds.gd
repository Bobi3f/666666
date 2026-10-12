extends Node3D
## Стайка птиц над деревней: кружат днём в хорошую погоду, машут крыльями
## (шейдер по номеру птицы), на закате улетают. Одна MultiMesh — один вызов.

const COUNT := 9
const CENTER := Vector3(-105, 0, -40)

var _mm: MultiMesh
var _mi: MultiMeshInstance3D
var _t := 0.0
var _seeds: Array[Vector3] = []

const SHADER := """
shader_type spatial;
render_mode cull_disabled, unshaded;

void vertex() {
	float side = abs(VERTEX.x);
	VERTEX.y += sin(TIME * 11.0 + float(INSTANCE_ID) * 1.7) * side * 0.7;
}

void fragment() {
	ALBEDO = vec3(0.12, 0.12, 0.14);
}
"""


func _ready() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Тело и два крыла галочкой
	var pts := [
		[Vector3(0, 0, -0.18), Vector3(-0.55, 0.05, 0.05), Vector3(0, 0, 0.12)],
		[Vector3(0, 0, -0.18), Vector3(0, 0, 0.12), Vector3(0.55, 0.05, 0.05)],
		[Vector3(0, 0, 0.1), Vector3(-0.09, 0, 0.3), Vector3(0.09, 0, 0.3)],
	]
	for tri in pts:
		for p in tri:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	mesh.surface_set_material(0, mat)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = mesh
	_mm.instance_count = COUNT
	_mi = MultiMeshInstance3D.new()
	_mi.multimesh = _mm
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.extra_cull_margin = 200.0
	add_child(_mi)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in COUNT:
		# Своя высота, радиус и сдвиг по кругу — стая, а не строй
		_seeds.append(Vector3(rng.randf_range(12.0, 20.0), rng.randf_range(22.0, 38.0), rng.randf() * 0.6))


func _process(delta: float) -> void:
	var h := TimeManager.hour()
	var out := h > 6.5 and h < 19.5 and WeatherManager.rain < 0.3 and WeatherManager.season() != 2
	_mi.visible = out
	if not out:
		return
	_t += delta
	# Центр стаи медленно гуляет над деревней
	var c := CENTER + Vector3(sin(_t * 0.05) * 30.0, 0, cos(_t * 0.037) * 20.0)
	for i in COUNT:
		var s: Vector3 = _seeds[i]
		var a := _t * 0.35 + s.z + i * 0.15
		var p := c + Vector3(cos(a) * s.y, s.x + sin(_t * 0.7 + i) * 1.5, sin(a) * s.y)
		# Летят по касательной к кругу
		var dir := Vector3(-sin(a), 0, cos(a))
		var basis := Basis.looking_at(-dir, Vector3.UP).scaled(Vector3.ONE * 2.2)
		_mm.set_instance_transform(i, Transform3D(basis, p))
