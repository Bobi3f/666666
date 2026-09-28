extends Node3D
## Ночное небо: звёзды и луна. Висят вокруг камеры очень далеко, туман
## их не трогает. Проявляются в сумерках, за тучами не видно.

## Камеры видят до 700 м — небо ближе этого
const RADIUS := 500.0
const STARS := 700

var _stars: MeshInstance3D
var _star_mat: StandardMaterial3D
var _moon: MeshInstance3D
var _moon_mat: StandardMaterial3D


func _ready() -> void:
	top_level = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in STARS:
		# Равномерно по верхней полусфере, гуще к горизонту не надо
		var y := rng.randf_range(0.08, 1.0)
		var a := rng.randf() * TAU
		var r := sqrt(1.0 - y * y)
		var dir := Vector3(cos(a) * r, y, sin(a) * r)
		var size := rng.randf_range(0.55, 1.4) * (2.2 if rng.randf() < 0.04 else 1.0)
		var bright := rng.randf_range(0.5, 1.0)
		var col := Color(bright, bright, bright * rng.randf_range(0.9, 1.1))
		var c := dir * RADIUS
		var right := dir.cross(Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT).normalized() * size
		var up := dir.cross(right).normalized() * size
		for p in [c - right - up, c + right - up, c + right + up, c - right - up, c + right + up, c - right + up]:
			st.set_color(col)
			st.add_vertex(p)
	_star_mat = StandardMaterial3D.new()
	_star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_mat.vertex_color_use_as_albedo = true
	_star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_star_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_star_mat.disable_fog = true
	_star_mat.no_depth_test = false
	var mesh := st.commit()
	mesh.surface_set_material(0, _star_mat)
	_stars = MeshInstance3D.new()
	_stars.mesh = mesh
	_stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stars.extra_cull_margin = RADIUS * 2.0
	add_child(_stars)
	# Луна: диск с пятнами морей
	_moon = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(24, 24)
	_moon.mesh = q
	_moon_mat = StandardMaterial3D.new()
	_moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_moon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_moon_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_moon_mat.disable_fog = true
	_moon_mat.albedo_texture = _moon_texture()
	_moon.material_override = _moon_mat
	_moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_moon.extra_cull_margin = RADIUS * 2.0
	add_child(_moon)


func _moon_texture() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.08
	for y in n:
		for x in n:
			var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			if d > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var k := 0.9 + noise.get_noise_2d(x, y) * 0.25
			var a := clampf((1.0 - d) * 12.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(k, k, k * 0.95, a))
	return ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	global_position = cam.global_position
	var h := TimeManager.hour()
	# Темно с 21 до 5, в сумерках проявляются
	var night := clampf((absf(h - 12.5) - 6.8) / 1.5, 0.0, 1.0)
	var clear := 1.0 - WeatherManager.cloud * 0.95
	var a := night * clear
	_stars.visible = a > 0.01
	_moon.visible = a > 0.01
	_star_mat.albedo_color = Color(1, 1, 1, a)
	_moon_mat.albedo_color = Color(1, 1, 0.95, minf(a * 1.3, 1.0))
	# Луна идёт по небу за ночь: восходит в 20 на востоке, в 6 садится на западе
	var t := fposmod(h - 20.0, 24.0) / 10.0
	var elev := sin(clampf(t, 0.0, 1.0) * PI) * 0.9 + 0.08
	var az := lerpf(1.3, -1.3, clampf(t, 0.0, 1.0))
	_moon.position = Vector3(sin(az) * cos(elev), sin(elev), -cos(az) * cos(elev)) * (RADIUS * 0.9)
