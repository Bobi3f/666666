extends Node3D
## Небо вокруг камеры: облака днём, звёзды и луна ночью. Висят далеко,
## туман их не трогает. Облака медленно плывут, в пасмурную погоду их
## больше и они темнее, на закате розовеют. Звёзды проявляются в сумерках.

## Камеры видят до 700 м — небо ближе этого
const RADIUS := 500.0
const STARS := 700

var _stars: MeshInstance3D
var _star_mat: StandardMaterial3D
var _moon: MeshInstance3D
var _moon_mat: StandardMaterial3D
var _clouds: MeshInstance3D
var _cloud_mat: StandardMaterial3D
var _drift := 0.0


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
	_build_clouds(rng)


## Облака: три десятка плоских кусков под небом, одним мешем.
func _build_clouds(rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 34:
		var a := rng.randf() * TAU
		var d := rng.randf_range(60.0, 430.0)
		var c := Vector3(cos(a) * d, rng.randf_range(150.0, 210.0), sin(a) * d)
		var w := rng.randf_range(70.0, 150.0)
		var h := w * rng.randf_range(0.35, 0.6)
		var rot := Basis(Vector3.UP, rng.randf() * TAU)
		var right := rot * Vector3(w, 0, 0)
		var fwd := rot * Vector3(0, 0, h)
		# Уголок атласа: 4 разных облака на текстуре
		var u0 := float(i % 2) * 0.5
		var v0 := float((i / 2) % 2) * 0.5
		var corners := [[c - right - fwd, Vector2(u0, v0)], [c + right - fwd, Vector2(u0 + 0.5, v0)],
			[c + right + fwd, Vector2(u0 + 0.5, v0 + 0.5)], [c - right + fwd, Vector2(u0, v0 + 0.5)]]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(corners[k][1])
			st.set_normal(Vector3.DOWN)
			st.add_vertex(corners[k][0])
	_cloud_mat = StandardMaterial3D.new()
	_cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cloud_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cloud_mat.disable_fog = true
	_cloud_mat.albedo_texture = _cloud_texture()
	var mesh := st.commit()
	mesh.surface_set_material(0, _cloud_mat)
	_clouds = MeshInstance3D.new()
	_clouds.mesh = mesh
	_clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clouds.extra_cull_margin = RADIUS * 2.0
	add_child(_clouds)


func _cloud_texture() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 21
	noise.frequency = 0.035
	noise.fractal_octaves = 4
	for y in n:
		for x in n:
			# Каждая четверть — отдельное облако, к краям прозрачное
			var lx := float(x % 64) / 64.0 - 0.5
			var ly := float(y % 64) / 64.0 - 0.5
			var edge := clampf(1.0 - Vector2(lx, ly * 1.4).length() * 2.1, 0.0, 1.0)
			var v := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var a := clampf((v * edge - 0.1) * 3.2, 0.0, 1.0)
			var shade := lerpf(0.82, 1.0, v)
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


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


func _process(delta: float) -> void:
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
	# Облака плывут по ветру и медленно поворачиваются вокруг
	_drift += delta * 0.004
	_clouds.rotation.y = _drift
	var cloud := WeatherManager.cloud
	var day := clampf(1.0 - night * 1.1, 0.0, 1.0)
	# Утром и вечером — розовые, днём белые, в тучу — серые, ночью почти не видно
	var dusk := clampf(1.0 - absf(absf(h - 13.0) - 6.5) / 1.6, 0.0, 1.0)
	var col := Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.72, 0.6), dusk).lerp(Color(0.62, 0.64, 0.68), cloud * 0.8)
	col = col.lerp(Color(0.12, 0.13, 0.18), 1.0 - day)
	_cloud_mat.albedo_color = Color(col.r, col.g, col.b, lerpf(0.85, 1.0, cloud))
