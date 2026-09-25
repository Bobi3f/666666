extends Node3D
## Мир 400×400 м: деревня из 8 дворов трёх уровней достатка, город из
## панелек, магистраль, ЛЭП, лес и поля.
##
## Вся неподвижная геометрия копится в один меш (MeshBuilder) — мир рисуется
## за один вызов отрисовки. Светящиеся окна — второй меш: днём тусклые,
## ночью горят. Внутри каждого дома — HouseInterior со своей обстановкой.

const HouseInteriorScript := preload("res://scripts/world/house_interior.gd")
const W := HouseInterior.Wealth

# Деревня: два ряда по 4 двора вдоль деревенской улицы (z = -40)
const VILLAGE_X := [-150.0, -125.0, -100.0, -75.0]
const ROW_A_Z := -56.0  # фасадом к улице (+Z)
const ROW_B_Z := -24.0  # развёрнуты на 180°
const ROW_A := [W.POOR, W.MIDDLE, W.RICH, W.MIDDLE]
const ROW_B := [W.RICH, W.POOR, W.MIDDLE, W.POOR]
## Дом игрока — второй в первом ряду.
const PLAYER_HOUSE := Vector2(-125.0, ROW_A_Z)

const HOUSE_Y := 0.05  # пол дома чуть выше земли
const SKIN := 0.1       # толщина наружной обшивки

var _sun: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _glow_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260925
	_setup_environment()

	var b := MeshBuilder.new()
	var glow := MeshBuilder.new()
	glow.ground_shade = false
	_build_ground(b)
	_build_roads(b)
	_build_power_line(b)
	_build_village(b)
	_build_town(b, glow)
	_build_shops(b)
	_build_forest(b)

	var world_mesh := b.build_mesh()
	world_mesh.name = "WorldMesh"
	add_child(world_mesh)
	var body := b.build_body()
	body.name = "WorldCollision"
	add_child(body)
	var glow_mesh := glow.build_mesh(true)
	glow_mesh.name = "WindowGlow"
	_glow_mat = glow_mesh.mesh.surface_get_material(0) if glow_mesh.mesh else null
	add_child(glow_mesh)
	print("Мир: %d треугольников в одном меше, %d коллизий" % [b.triangle_count(), body.get_child_count()])

	_spawn_player_and_car()
	add_child(preload("res://scripts/ui/hud.gd").new())
	GameManager.notify("Ты дома. F1 — управление. Работа — склад в городе")


func _process(_delta: float) -> void:
	_update_daylight()


# --- Небо, солнце, смена дня и ночи ----------------------------------------

func _setup_environment() -> void:
	_sky = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_density = 0.0025
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 70.0
	add_child(_sun)
	_update_daylight()


func _update_daylight() -> void:
	var h := TimeManager.hour()
	# Солнце встаёт в 6, садится в 20
	var t := (h - 6.0) / 14.0
	var elev := sin(clampf(t, 0.0, 1.0) * PI)
	var day := clampf(elev * 3.0, 0.0, 1.0)
	_sun.rotation = Vector3(-lerpf(0.08, 1.1, elev), lerpf(-1.9, 1.9, clampf(t, 0.0, 1.0)), 0.0)
	_sun.light_energy = lerpf(0.0, 1.15, day)
	_sun.light_color = Color(1.0, 0.75, 0.5).lerp(Color(1.0, 0.97, 0.92), clampf(elev * 2.0, 0.0, 1.0))
	_sun.visible = day > 0.01
	_env.background_energy_multiplier = lerpf(0.06, 1.0, day)
	_env.ambient_light_energy = lerpf(0.12, 1.0, day)
	_env.fog_light_color = Color(0.05, 0.06, 0.1).lerp(Color(0.7, 0.78, 0.88), day)
	if _glow_mat:
		_glow_mat.albedo_color = Color(0.3, 0.32, 0.36).lerp(Color(1.0, 1.0, 1.0), 1.0 - day)


# --- Земля и дороги ---------------------------------------------------------

func _build_ground(b: MeshBuilder) -> void:
	var n := 40
	var cell := 400.0 / n
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.02
	var grass := Color(0.32, 0.47, 0.21)
	var dry := Color(0.47, 0.5, 0.27)
	for i in n:
		for j in n:
			var x0 := -200.0 + i * cell
			var z0 := -200.0 + j * cell
			var pts := [Vector3(x0, 0, z0 + cell), Vector3(x0 + cell, 0, z0 + cell), Vector3(x0 + cell, 0, z0), Vector3(x0, 0, z0)]
			var cols: Array[Color] = []
			for p in pts:
				cols.append(grass.lerp(dry, clampf(noise.get_noise_2d(p.x, p.z) * 0.8 + 0.35, 0.0, 1.0)))
			b.quad_vc(pts, cols)
	b.add_collider(Vector3(-200, -1, -200), Vector3(200, 0, 200))
	# Невидимые стены по краю мира
	for side in [[Vector3(-201, 0, -200), Vector3(-200, 5, 200)], [Vector3(200, 0, -200), Vector3(201, 5, 200)],
			[Vector3(-200, 0, -201), Vector3(200, 5, -200)], [Vector3(-200, 0, 200), Vector3(200, 5, 201)]]:
		b.add_collider(side[0], side[1])
	# Поля на северо-востоке: пшеница, зелень, пашня с бороздами
	b.box(Vector3(25, 0, -185), Vector3(100, 0.03, -110), Color(0.78, 0.68, 0.33))
	b.box(Vector3(110, 0, -185), Vector3(190, 0.03, -110), Color(0.36, 0.55, 0.2))
	b.box(Vector3(25, 0, -100), Vector3(190, 0.03, -30), Color(0.4, 0.3, 0.2))
	var z := -99.0
	while z < -31.0:
		b.box(Vector3(26, 0.03, z), Vector3(189, 0.07, z + 0.4), Color(0.33, 0.24, 0.16))
		z += 1.2


func _build_roads(b: MeshBuilder) -> void:
	var asphalt := Color(0.24, 0.24, 0.25)
	var dirt := Color(0.46, 0.39, 0.28)
	var white := Color(0.92, 0.92, 0.9)
	# Магистраль вдоль X: обочины, асфальт, разметка
	b.box(Vector3(-200, 0, -5.5), Vector3(200, 0.02, 5.5), dirt)
	b.box(Vector3(-200, 0, -4), Vector3(200, 0.05, 4), asphalt, true)
	var x := -198.0
	while x < 198.0:
		b.box(Vector3(x, 0.05, -0.08), Vector3(x + 3.0, 0.06, 0.08), white)
		x += 6.0
	for zz in [-3.7, 3.55]:
		b.box(Vector3(-200, 0.05, zz), Vector3(200, 0.06, zz + 0.15), white)
	# Деревенская улица и съезд к магистрали
	b.box(Vector3(-165, 0, -42.5), Vector3(-57, 0.04, -37.5), dirt)
	b.box(Vector3(-62, 0, -42.5), Vector3(-57, 0.04, -5.5), dirt)
	# Городские дороги, тротуар с бордюром вдоль магистрали
	b.box(Vector3(94, 0, 4), Vector3(100, 0.05, 100), asphalt)
	b.box(Vector3(40, 0, 55), Vector3(190, 0.05, 61), asphalt)
	b.box(Vector3(10, 0, 5), Vector3(190, 0.12, 7.5), Color(0.5, 0.5, 0.49))
	x = 10.0
	while x < 190.0:
		b.box(Vector3(x, 0, 4.85), Vector3(x + 0.95, 0.18 + _rng.randf() * 0.02, 5.05), Color(0.6, 0.6, 0.58))
		x += 1.0
	# Пешеходный переход у ларька
	for i in 7:
		b.box(Vector3(22 + i * 0.9, 0.05, -3.5), Vector3(22.5 + i * 0.9, 0.06, 3.5), white)


func _build_power_line(b: MeshBuilder) -> void:
	var wood := Color(0.35, 0.28, 0.2)
	var x := -195.0
	while x <= 195.0:
		b.box(Vector3(x - 0.13, 0, -9.13), Vector3(x + 0.13, 9.0, -8.87), wood, true)
		b.box(Vector3(x - 0.08, 8.3, -10.2), Vector3(x + 0.08, 8.45, -7.8), wood)
		for dz in [-1.0, 0.0, 1.0]:
			b.box(Vector3(x - 0.05, 8.45, -9.0 + dz - 0.05), Vector3(x + 0.05, 8.6, -9.0 + dz + 0.05), Color(0.85, 0.85, 0.8))
		if x < 195.0:
			for dz in [-1.0, 0.0, 1.0]:
				b.box(Vector3(x, 8.55, -9.0 + dz - 0.015), Vector3(x + 30.0, 8.58, -9.0 + dz + 0.015), Color(0.1, 0.1, 0.1))
		x += 30.0


# --- Деревня ----------------------------------------------------------------

func _build_village(b: MeshBuilder) -> void:
	for i in 4:
		_build_yard(b, Vector3(VILLAGE_X[i], 0, ROW_A_Z), 0.0, ROW_A[i])
		_build_yard(b, Vector3(VILLAGE_X[i], 0, ROW_B_Z), PI, ROW_B[i])


func _build_yard(b: MeshBuilder, pos: Vector3, yaw: float, wealth: int) -> void:
	var hi: HouseInterior = HouseInteriorScript.new()
	hi.wealth = wealth
	hi.position = pos + Vector3(0, HOUSE_Y, 0)
	hi.rotation.y = yaw
	hi.name = "House_%d_%d" % [int(pos.x), int(pos.z)]
	b.xf = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0, HOUSE_Y, 0))
	_house_exterior(b, hi)
	b.xf = Transform3D(Basis(Vector3.UP, yaw), pos)
	_yard_fence(b, hi)
	_yard_extras(b, hi)
	b.xf = Transform3D.IDENTITY
	add_child(hi)
	if Vector2(pos.x, pos.z) == PLAYER_HOUSE:
		var bed := InteractZone.create("E — лечь спать до 7:00", Vector3(1.6, 1.4, 2.6))
		bed.position = hi.position + Basis(Vector3.UP, yaw) * hi.bed_center() - Vector3(0, 0.5, 0)
		bed.rotation.y = yaw
		bed.activated.connect(_sleep)
		add_child(bed)


## Наружные стены с проёмами ровно там, где окна и дверь интерьера, крыша, труба.
func _house_exterior(b: MeshBuilder, hi: HouseInterior) -> void:
	var hx := hi.inner_size.x * 0.5 + hi.wall_thickness
	var hz := hi.inner_size.z * 0.5 + hi.wall_thickness
	var H := hi.inner_size.y + 0.06
	var ox := hx + SKIN
	var oz := hz + SKIN
	var style := _house_style(hi.wealth)
	var open := hi.exterior_openings()
	var y0 := -HOUSE_Y
	# Стены: фасад, зад, левая и правая
	_skin_wall(b, Vector3(-ox, y0, hz), Vector3(ox, H, oz), 0, open.front, Vector3.BACK, style)
	_skin_wall(b, Vector3(-ox, y0, -oz), Vector3(ox, H, -hz), 0, [], Vector3.FORWARD, style)
	_skin_wall(b, Vector3(-ox, y0, -hz), Vector3(-hx, H, hz), 2, open.left, Vector3.LEFT, style)
	_skin_wall(b, Vector3(hx, y0, -hz), Vector3(ox, H, hz), 2, open.right, Vector3.RIGHT, style)
	# Крыльцо-ступенька у двери
	var door: Array = open.front[0]
	b.box(Vector3(door[0] - 0.8, y0, oz), Vector3(door[0] + 0.8, 0.0, oz + 0.7), Color(0.55, 0.55, 0.53))
	# Двускатная крыша вдоль длинной стороны, фронтоны по торцам
	var e := 0.45
	var rh: float = style.roof_h
	var drop := e * rh / oz
	var ridge_y := H + rh
	var wall_c: Color = style.wall
	for s in [-1.0, 1.0]:
		b.tri(Vector3(s * ox, H, -oz), Vector3(s * ox, H, oz), Vector3(s * ox, ridge_y, 0), wall_c, true)
	var roof_c: Color = style.roof
	var front_eave := [Vector3(-ox - e, H - drop, oz + e), Vector3(ox + e, H - drop, oz + e)]
	var back_eave := [Vector3(ox + e, H - drop, -oz - e), Vector3(-ox - e, H - drop, -oz - e)]
	b.quad(front_eave[0], front_eave[1], Vector3(ox + e, ridge_y, 0), Vector3(-ox - e, ridge_y, 0), roof_c, true)
	b.quad(back_eave[0], back_eave[1], Vector3(-ox - e, ridge_y, 0), Vector3(ox + e, ridge_y, 0), roof_c, true)
	_roof_pattern(b, ox + e, oz + e, H - drop, ridge_y, style)
	b.box(Vector3(-ox - e, ridge_y - 0.05, -0.1), Vector3(ox + e, ridge_y + 0.08, 0.1), roof_c.darkened(0.25))
	# Печная труба над печью (задний левый угол кухни) с колпаком
	var cx := -hi.inner_size.x * 0.5 + 0.2
	var cz := -hi.inner_size.z * 0.5 + 0.2
	b.box(Vector3(cx, H, cz), Vector3(cx + 0.55, ridge_y + 0.7, cz + 0.55), style.chimney)
	b.box(Vector3(cx - 0.08, ridge_y + 0.7, cz - 0.08), Vector3(cx + 0.63, ridge_y + 0.78, cz + 0.63), Color(0.3, 0.3, 0.3))
	if hi.wealth == W.RICH:
		# Спутниковая тарелка на фасаде
		b.box(Vector3(ox - 1.2, H - 0.6, oz), Vector3(ox - 1.15, H - 0.5, oz + 0.35), Color(0.6, 0.6, 0.6))
		b.box(Vector3(ox - 1.5, H - 0.85, oz + 0.3), Vector3(ox - 0.85, H - 0.2, oz + 0.36), Color(0.9, 0.9, 0.9))


func _house_style(wealth: int) -> Dictionary:
	match wealth:
		W.POOR:
			return {"wall": Color(0.45, 0.33, 0.22), "line": Color(0.3, 0.22, 0.15), "step": 0.27,
				"roof": Color(0.5, 0.3, 0.2), "roof_h": 1.6, "trim": Color(0.35, 0.5, 0.75),
				"base": Color(0.35, 0.33, 0.3), "chimney": Color(0.55, 0.3, 0.22)}
		W.RICH:
			return {"wall": Color(0.62, 0.27, 0.19), "line": Color(0.78, 0.72, 0.62), "step": 0.15,
				"roof": Color(0.55, 0.2, 0.14), "roof_h": 2.2, "trim": Color(0.95, 0.95, 0.92),
				"base": Color(0.45, 0.44, 0.42), "chimney": Color(0.6, 0.26, 0.18)}
	return {"wall": Color(0.88, 0.83, 0.68), "line": Color(0, 0, 0, 0), "step": 0.0,
		"roof": Color(0.56, 0.58, 0.57), "roof_h": 1.9, "trim": Color(0.95, 0.95, 0.93),
		"base": Color(0.5, 0.5, 0.48), "chimney": Color(0.62, 0.3, 0.22)}


## Стена обшивки от mn до mx; axis 0 — стена вдоль X, 2 — вдоль Z.
## openings: [[центр, ширина, верх, низ]] вдоль оси стены.
func _skin_wall(b: MeshBuilder, mn: Vector3, mx: Vector3, axis: int, openings: Array, n: Vector3, style: Dictionary) -> void:
	var a0 := mn[axis]
	var a1 := mx[axis]
	var cursor := a0
	var list := openings.duplicate()
	list.sort_custom(func(p, q): return p[0] < q[0])
	for o in list:
		var o0: float = o[0] - o[1] * 0.5
		var o1: float = o[0] + o[1] * 0.5
		var top: float = o[2]
		var bottom: float = o[3]
		_skin_piece(b, mn, mx, axis, cursor, o0, mn.y, mx.y, n, style)
		_skin_piece(b, mn, mx, axis, o0, o1, top, mx.y, n, style)
		if bottom > 0.0:
			_skin_piece(b, mn, mx, axis, o0, o1, mn.y, bottom, n, style)
		_opening_trim(b, mn, mx, axis, o0, o1, bottom, top, n, style)
		cursor = o1
	_skin_piece(b, mn, mx, axis, cursor, a1, mn.y, mx.y, n, style)


func _span(mn: Vector3, mx: Vector3, axis: int, s0: float, s1: float, y0: float, y1: float) -> Array:
	var a := mn
	var c := mx
	a[axis] = s0
	c[axis] = s1
	a.y = y0
	c.y = y1
	return [a, c]


## Коробка, прилипшая к наружной стороне стены: выступ d наружу по нормали n.
func _outer(r: Array, n: Vector3, d0: float, d1: float) -> Array:
	var a: Vector3 = r[0]
	var c: Vector3 = r[1]
	for i in [0, 2]:
		if n[i] > 0.0:
			a[i] = c[i] + d0
			c[i] = c[i] + d1
		elif n[i] < 0.0:
			c[i] = a[i] - d0
			a[i] = a[i] - d1
	return [a, c]


func _skin_piece(b: MeshBuilder, mn: Vector3, mx: Vector3, axis: int, s0: float, s1: float, y0: float, y1: float, n: Vector3, style: Dictionary) -> void:
	if s1 - s0 < 0.01 or y1 - y0 < 0.01:
		return
	var r := _span(mn, mx, axis, s0, s1, y0, y1)
	b.box(r[0], r[1], style.wall)
	# Цоколь
	if y0 < 0.0:
		var base := _outer(_span(mn, mx, axis, s0, s1, y0, 0.35), n, -0.01, 0.03)
		b.box(base[0], base[1], style.base)
	# Пазы между брёвнами или швы кирпичной кладки
	var step: float = style.step
	if step > 0.0:
		var y := ceilf(maxf(y0, 0.35) / step) * step
		while y < y1 - 0.02:
			var line := _outer(_span(mn, mx, axis, s0, s1, y, y + (0.05 if step > 0.2 else 0.015)), n, 0.0, 0.012)
			b.box(line[0], line[1], style.line)
			y += step


## Наличник и подоконник снаружи окна, наличник вокруг двери.
func _opening_trim(b: MeshBuilder, mn: Vector3, mx: Vector3, axis: int, o0: float, o1: float, bottom: float, top: float, n: Vector3, style: Dictionary) -> void:
	var trim: Color = style.trim
	var w := 0.09
	var y_bottom := bottom - w if bottom > 0.0 else mn.y
	for piece in [_span(mn, mx, axis, o0 - w, o0, y_bottom, top + w), _span(mn, mx, axis, o1, o1 + w, y_bottom, top + w),
			_span(mn, mx, axis, o0 - w, o1 + w, top, top + w)]:
		var r := _outer(piece, n, 0.0, 0.04)
		b.box(r[0], r[1], trim)
	if bottom > 0.0:
		var sill := _outer(_span(mn, mx, axis, o0 - 0.12, o1 + 0.12, bottom - 0.06, bottom), n, 0.0, 0.14)
		b.box(sill[0], sill[1], trim.darkened(0.1))
		if style.step > 0.2:
			# Резной кокошник над деревенским окном
			var crown := _outer(_span(mn, mx, axis, o0 - 0.15, o1 + 0.15, top + w, top + w + 0.22), n, 0.0, 0.05)
			b.box(crown[0], crown[1], trim)


## Рёбра на железной и шиферной крыше, ряды черепицы на зажиточной.
func _roof_pattern(b: MeshBuilder, rx: float, rz: float, eave_y: float, ridge_y: float, style: Dictionary) -> void:
	var roof: Color = style.roof
	for s in [-1.0, 1.0]:
		var eave := Vector3(0, eave_y, s * rz)
		var ridge := Vector3(0, ridge_y, 0)
		var up := (ridge - eave)
		var nrm := Vector3(0, rz, s * (ridge_y - eave_y)).normalized() * 0.025
		if style.step == 0.15:
			# Черепица рядами поперёк ската
			for k in range(1, 9):
				var p := eave + up * (k / 9.0) + nrm
				var q := p + up.normalized() * 0.08
				if s > 0.0:
					b.quad(Vector3(-rx, p.y, p.z), Vector3(rx, p.y, p.z), Vector3(rx, q.y, q.z), Vector3(-rx, q.y, q.z), roof.darkened(0.2))
				else:
					b.quad(Vector3(rx, p.y, p.z), Vector3(-rx, p.y, p.z), Vector3(-rx, q.y, q.z), Vector3(rx, q.y, q.z), roof.darkened(0.2))
		else:
			# Рёбра вдоль ската
			var x := -rx + 0.25
			while x < rx:
				var a := Vector3(x, eave.y, eave.z) + nrm
				var c := Vector3(x, ridge.y, ridge.z) + nrm
				if s > 0.0:
					b.quad(a + Vector3(-0.03, 0, 0), a + Vector3(0.03, 0, 0), c + Vector3(0.03, 0, 0), c + Vector3(-0.03, 0, 0), roof.darkened(0.18))
				else:
					b.quad(a + Vector3(0.03, 0, 0), a + Vector3(-0.03, 0, 0), c + Vector3(-0.03, 0, 0), c + Vector3(0.03, 0, 0), roof.darkened(0.18))
				x += 0.5 if style.step > 0.2 else 0.35


## Забор вокруг двора с калиткой напротив двери.
func _yard_fence(b: MeshBuilder, hi: HouseInterior) -> void:
	var x0 := -11.0
	var x1 := 11.0
	var z0 := -9.0
	var z1 := 12.0
	var gate0 := hi.entrance_offset - 1.6
	var gate1 := hi.entrance_offset + 1.6
	# Дорожка от калитки к двери
	b.box(Vector3(hi.entrance_offset - 0.6, 0, hi.inner_size.z * 0.5 + 0.9), Vector3(hi.entrance_offset + 0.6, 0.025, z1), Color(0.5, 0.44, 0.34))
	var runs := [
		[Vector3(x0, 0, z1), Vector3(gate0, 0, z1)],
		[Vector3(gate1, 0, z1), Vector3(x1, 0, z1)],
		[Vector3(x0, 0, z0), Vector3(x1, 0, z0)],
		[Vector3(x0, 0, z0), Vector3(x0, 0, z1)],
		[Vector3(x1, 0, z0), Vector3(x1, 0, z1)],
	]
	for r in runs:
		_fence_run(b, r[0], r[1], hi.wealth)


func _fence_run(b: MeshBuilder, a: Vector3, c: Vector3, wealth: int) -> void:
	var length := a.distance_to(c)
	var dir := (c - a) / length
	var along_x := absf(dir.x) > 0.5
	var mn := Vector3(minf(a.x, c.x), 0, minf(a.z, c.z))
	var mx := Vector3(maxf(a.x, c.x), 0, maxf(a.z, c.z))
	var thin := Vector3(0, 0, 0.04) if along_x else Vector3(0.04, 0, 0)
	match wealth:
		W.RICH:
			# Сплошной забор 1.9 м на кирпичных столбах
			b.box(mn - thin + Vector3(0, 0, 0), mx + thin + Vector3(0, 1.9, 0), Color(0.42, 0.3, 0.2), true)
			var s := 0.0
			while s <= length + 0.01:
				var p := a + dir * s
				b.box(p + Vector3(-0.22, 0, -0.22), p + Vector3(0.22, 2.1, 0.22), Color(0.6, 0.27, 0.2))
				s += 3.0
		_:
			var poor := wealth == W.POOR
			var wood := Color(0.52, 0.42, 0.3) if poor else Color(0.62, 0.5, 0.34)
			# Две жерди и столбы
			for y in [0.35, 1.0]:
				b.box(mn - thin * 0.5 + Vector3(0, y, 0), mx + thin * 0.5 + Vector3(0, y + 0.07, 0), wood.darkened(0.2))
			b.add_collider(mn - thin, mx + thin + Vector3(0, 1.2, 0))
			var s := 0.0
			while s <= length:
				var p := a + dir * s
				b.box(p + Vector3(-0.07, 0, -0.07), p + Vector3(0.07, 1.4, 0.07), wood.darkened(0.3))
				s += 2.5
			# Штакетник: у бедного разной высоты и с выломанными
			s = 0.1
			var off := thin * 1.5
			while s < length - 0.05:
				var p := a + dir * s
				var h := 1.25
				var skip := false
				if poor:
					h = _rng.randf_range(0.95, 1.35)
					skip = _rng.randf() < 0.1
				if not skip:
					var half := Vector3(0.04, 0, 0) if along_x else Vector3(0, 0, 0.04)
					b.box(p - half - off * 0.4, p + half + off * 0.4 + Vector3(0, h, 0), wood)
				s += 0.22 if not poor else 0.26


## Хозяйство во дворе по достатку.
func _yard_extras(b: MeshBuilder, hi: HouseInterior) -> void:
	# Яблоня во дворе у всех
	_tree(b, Vector3(7.5, 0, -6.0), 0.0, 1)
	match hi.wealth:
		W.POOR:
			# Уличный туалет
			b.box(Vector3(8.5, 0, -8.5), Vector3(9.8, 2.2, -7.2), Color(0.45, 0.35, 0.25), true)
			b.box(Vector3(8.4, 2.2, -8.6), Vector3(9.9, 2.3, -7.1), Color(0.5, 0.3, 0.2))
			b.box(Vector3(8.9, 0.1, -7.2), Vector3(9.4, 1.9, -7.18), Color(0.3, 0.22, 0.15))
			# Дрова навалом и две грядки
			for i in 14:
				b.box_rot(Vector3(-8.0 + _rng.randf() * 1.6, 0.1 + _rng.randf() * 0.35, -6.5 + _rng.randf() * 1.2),
					Vector3(0.12, 0.12, 0.5), _rng.randf() * TAU, Color(0.55, 0.42, 0.28))
			for i in 2:
				b.box(Vector3(-9.5 + i * 2.2, 0, -3.0), Vector3(-8.3 + i * 2.2, 0.18, 2.0), Color(0.3, 0.22, 0.15))
		W.RICH:
			# Гараж с воротами
			b.box(Vector3(5.5, 0, -3.0), Vector3(10.2, 2.6, 3.0), Color(0.62, 0.27, 0.19), true)
			b.box(Vector3(5.4, 2.6, -3.1), Vector3(10.3, 2.75, 3.1), Color(0.35, 0.35, 0.35))
			b.box(Vector3(6.2, 0, 3.0), Vector3(9.5, 2.2, 3.05), Color(0.55, 0.57, 0.6))
			# Теплица и лавочка у ворот
			b.box(Vector3(-9.5, 0, -8.0), Vector3(-5.5, 2.0, -5.0), Color(0.75, 0.88, 0.9), true)
			b.box(Vector3(-2.0, 0.4, 12.2), Vector3(0.0, 0.45, 12.6), Color(0.5, 0.35, 0.2))
			for x in [-1.9, -0.2]:
				b.box(Vector3(x, 0, 12.25), Vector3(x + 0.1, 0.4, 12.55), Color(0.3, 0.3, 0.3))
		_:
			# Колодец с воротом и навесом
			b.box(Vector3(-8.0, 0, -6.0), Vector3(-6.8, 0.8, -4.8), Color(0.45, 0.35, 0.25), true)
			for x in [-8.0, -6.9]:
				b.box(Vector3(x, 0.8, -5.45), Vector3(x + 0.1, 2.0, -5.35), Color(0.4, 0.3, 0.2))
			b.box(Vector3(-8.0, 1.5, -5.43), Vector3(-6.8, 1.6, -5.37), Color(0.35, 0.25, 0.18))
			b.quad(Vector3(-8.3, 1.9, -4.6), Vector3(-6.5, 1.9, -4.6), Vector3(-6.5, 2.3, -5.4), Vector3(-8.3, 2.3, -5.4), Color(0.4, 0.3, 0.2), true)
			b.quad(Vector3(-6.5, 1.9, -6.2), Vector3(-8.3, 1.9, -6.2), Vector3(-8.3, 2.3, -5.4), Vector3(-6.5, 2.3, -5.4), Color(0.4, 0.3, 0.2), true)
			# Бельевая верёвка с бельём
			for z in [-2.0, 3.0]:
				b.box(Vector3(8.0, 0, z), Vector3(8.08, 1.8, z + 0.08), Color(0.4, 0.3, 0.2))
			b.box(Vector3(8.02, 1.75, -2.0), Vector3(8.06, 1.77, 3.08), Color(0.8, 0.8, 0.8))
			var cols := [Color(0.9, 0.9, 0.95), Color(0.7, 0.3, 0.3), Color(0.4, 0.5, 0.8)]
			for i in 3:
				b.box(Vector3(7.99, 1.15, -1.3 + i * 1.3), Vector3(8.09, 1.75, -0.6 + i * 1.3), cols[i])
			# Поленница штабелем
			b.box(Vector3(-10.5, 0, 0.0), Vector3(-9.9, 1.2, 4.0), Color(0.55, 0.42, 0.28), true)
			b.box(Vector3(-10.6, 1.2, -0.1), Vector3(-9.8, 1.3, 4.1), Color(0.4, 0.4, 0.4))


# --- Город ------------------------------------------------------------------

func _build_town(b: MeshBuilder, glow: MeshBuilder) -> void:
	# Панельные пятиэтажки, подъездами к дороге
	_panel_building(b, glow, Vector3(70, 0, 41), 42.0, PI)
	_panel_building(b, glow, Vector3(125, 0, 41), 42.0, PI)
	_panel_building(b, glow, Vector3(70, 0, 74), 42.0, PI)
	_panel_building(b, glow, Vector3(125, 0, 74), 42.0, PI)
	_panel_building(b, glow, Vector3(171, 0, 75), 42.0, -PI / 2.0)
	# Детская площадка между домами: песочница, качели
	b.box(Vector3(60, 0, 50), Vector3(64, 0.3, 54), Color(0.55, 0.4, 0.25))
	b.box(Vector3(60.2, 0.25, 50.2), Vector3(63.8, 0.28, 53.8), Color(0.85, 0.75, 0.5))
	for x in [70.0, 72.5]:
		b.box(Vector3(x, 0, 51.5), Vector3(x + 0.1, 2.2, 51.6), Color(0.3, 0.45, 0.7))
	b.box(Vector3(70, 2.1, 51.5), Vector3(72.6, 2.2, 51.6), Color(0.3, 0.45, 0.7))


## Пятиэтажка длиной length. Локально: фасад с подъездами смотрит на +Z,
## yaw разворачивает дом к дороге.
func _panel_building(b: MeshBuilder, glow: MeshBuilder, center: Vector3, length: float, yaw: float) -> void:
	var floors := 5
	var fh := 2.8
	var depth := 12.0
	var h := floors * fh + 0.6
	var hl := length * 0.5
	var hd := depth * 0.5
	var xf := Transform3D(Basis(Vector3.UP, yaw), center)
	b.xf = xf
	glow.xf = xf
	var panel := Color(0.74, 0.74, 0.71)
	b.box(Vector3(-hl, 0, -hd), Vector3(hl, h, hd), panel, true)
	# Швы между панелями
	for f in range(1, floors + 1):
		for s in [-1.0, 1.0]:
			var z: float = s * hd
			b.box(Vector3(-hl, f * fh + 0.3, minf(z, z + s * 0.02)), Vector3(hl, f * fh + 0.35, maxf(z, z + s * 0.02)), panel.darkened(0.2))
	var modules := int(length / 3.0)
	var start := -modules * 3.0 * 0.5
	var entrances := [modules / 6, modules / 2, modules - 1 - modules / 6]
	for f in floors:
		for m in modules:
			var x := start + m * 3.0 + 1.5
			var y := 0.6 + f * fh + 0.7
			for s in [-1.0, 1.0]:
				if f == 0 and s > 0.0 and entrances.has(m):
					continue
				var z: float = s * hd
				b.box(Vector3(x - 0.7, y, minf(z, z + s * 0.03)), Vector3(x + 0.7, y + 1.4, maxf(z, z + s * 0.03)), Color(0.2, 0.24, 0.28))
				if _rng.randf() < 0.35:
					var gz: float = z + s * 0.04
					var c := Color(1.0, 0.85, 0.55) if _rng.randf() < 0.8 else Color(0.7, 0.85, 1.0)
					if s > 0.0:
						glow.quad(Vector3(x - 0.65, y + 0.05, gz), Vector3(x + 0.65, y + 0.05, gz), Vector3(x + 0.65, y + 1.35, gz), Vector3(x - 0.65, y + 1.35, gz), c)
					else:
						glow.quad(Vector3(x + 0.65, y + 0.05, gz), Vector3(x - 0.65, y + 0.05, gz), Vector3(x - 0.65, y + 1.35, gz), Vector3(x + 0.65, y + 1.35, gz), c)
				# Балконы с тыльной стороны через модуль
				if s < 0.0 and f > 0 and m % 2 == 0:
					b.box(Vector3(x - 1.3, y - 0.75, -hd - 1.1), Vector3(x + 1.3, y - 0.6, -hd), panel.darkened(0.1))
					b.box(Vector3(x - 1.3, y - 0.6, -hd - 1.1), Vector3(x + 1.3, y + 0.35, -hd - 1.02), Color(0.55, 0.6, 0.62))
	# Подъезды: дверь, козырёк, ступени, лавочка
	for m in entrances:
		var x: float = start + m * 3.0 + 1.5
		b.box(Vector3(x - 0.7, 0.3, hd), Vector3(x + 0.7, 2.4, hd + 0.05), Color(0.35, 0.25, 0.18))
		b.box(Vector3(x - 1.4, 2.7, hd), Vector3(x + 1.4, 2.85, hd + 1.4), panel.darkened(0.15))
		b.box(Vector3(x - 1.2, 0, hd), Vector3(x + 1.2, 0.3, hd + 1.2), Color(0.55, 0.55, 0.53))
		b.box(Vector3(x + 1.8, 0.4, hd + 1.0), Vector3(x + 3.3, 0.45, hd + 1.4), Color(0.5, 0.35, 0.2))
		b.box(Vector3(x - 0.2, 2.5, hd + 0.05), Vector3(x + 0.2, 2.65, hd + 0.07), Color(0.2, 0.35, 0.6))
	# Парапет и машинное отделение лифта на крыше
	b.box(Vector3(-hl, h, -hd), Vector3(hl, h + 0.4, -hd + 0.2), panel.darkened(0.1))
	b.box(Vector3(-hl, h, hd - 0.2), Vector3(hl, h + 0.4, hd), panel.darkened(0.1))
	b.box(Vector3(-2, h, -2), Vector3(2, h + 2.2, 2), panel.darkened(0.05))
	b.xf = Transform3D.IDENTITY
	glow.xf = Transform3D.IDENTITY


# --- Ларёк и склад: где тратить и где зарабатывать ---------------------------

func _build_shops(b: MeshBuilder) -> void:
	# Ларёк «Продукты» у перехода
	var k := Vector3(25, 0, 9)
	b.box(k + Vector3(-1.8, 0, 0), k + Vector3(1.8, 2.6, 2.8), Color(0.25, 0.45, 0.7), true)
	b.box(k + Vector3(-2.0, 2.6, -0.4), k + Vector3(2.0, 2.75, 3.0), Color(0.9, 0.9, 0.9))
	b.box(k + Vector3(-1.2, 1.0, -0.02), k + Vector3(1.2, 2.0, 0.0), Color(0.85, 0.9, 0.95))
	b.box(k + Vector3(-1.3, 0.9, -0.25), k + Vector3(1.3, 0.97, 0.0), Color(0.7, 0.7, 0.7))
	b.box(k + Vector3(-1.5, 2.2, -0.05), k + Vector3(1.5, 2.55, -0.02), Color(0.85, 0.2, 0.15))
	var kiosk := InteractZone.create("E — купить батон и кефир (45 грн)", Vector3(3.0, 2.0, 2.2))
	kiosk.position = k + Vector3(0, 0, -1.2)
	kiosk.activated.connect(_buy_food)
	add_child(kiosk)

	# Склад: здесь можно подработать грузчиком
	var s := Vector3(27.5, 0, 37)
	b.box(s + Vector3(-12, 0, -7), s + Vector3(12, 6, 7), Color(0.6, 0.58, 0.52), true)
	b.quad(s + Vector3(-12.3, 6, 7.3), s + Vector3(12.3, 6, 7.3), s + Vector3(12.3, 7.5, 0), s + Vector3(-12.3, 7.5, 0), Color(0.45, 0.45, 0.47), true)
	b.quad(s + Vector3(12.3, 6, -7.3), s + Vector3(-12.3, 6, -7.3), s + Vector3(-12.3, 7.5, 0), s + Vector3(12.3, 7.5, 0), Color(0.45, 0.45, 0.47), true)
	for sx in [-1.0, 1.0]:
		b.tri(s + Vector3(sx * 12, 6, -7), s + Vector3(sx * 12, 6, 7), s + Vector3(sx * 12, 7.5, 0), Color(0.6, 0.58, 0.52), true)
	b.box(s + Vector3(-2.5, 0, -7.05), s + Vector3(2.5, 4.0, -7.0), Color(0.4, 0.42, 0.45))
	b.box(s + Vector3(-3.0, 4.3, -7.08), s + Vector3(3.0, 5.0, -7.0), Color(0.9, 0.85, 0.3))
	for i in 6:
		b.box(s + Vector3(4.0 + (i % 3) * 1.3, (i / 3) * 1.0, -9.5), s + Vector3(5.1 + (i % 3) * 1.3, 0.95 + (i / 3) * 1.0, -8.4), Color(0.6, 0.45, 0.3), true)
	var job := InteractZone.create("E — поработать грузчиком: 4 часа, +600 грн", Vector3(5.0, 2.0, 3.0))
	job.position = s + Vector3(0, 0, -8.5)
	job.activated.connect(_work)
	add_child(job)


func _buy_food() -> void:
	if GameManager.spend(45):
		NeedsManager.snacks += 1
		GameManager.notify("Купил батон и кефир. Съесть — Q")


func _work() -> void:
	var h := TimeManager.hour()
	if h < 6.0 or h > 20.0:
		GameManager.notify("Склад закрыт. Работа с 6:00 до 20:00")
		return
	if NeedsManager.energy < 25.0:
		GameManager.notify("Слишком устал, чтобы таскать мешки. Выспись")
		return
	TimeManager.advance(240.0)
	NeedsManager.rest(-20.0)
	GameManager.add_money(600)
	GameManager.notify("Отработал смену: +600 грн. %s" % TimeManager.clock_text())


func _sleep() -> void:
	if NeedsManager.energy > 80.0:
		GameManager.notify("Спать пока не хочется")
		return
	TimeManager.skip_to(7.0)
	NeedsManager.rest(100.0)
	GameManager.notify("Выспался. %s" % TimeManager.clock_text())


# --- Лес --------------------------------------------------------------------

func _build_forest(b: MeshBuilder) -> void:
	for area in [Rect2(-200, -195, 180, 115), Rect2(-200, 22, 150, 173)]:
		var count := int(area.get_area() / 220.0)
		for i in count:
			var p := Vector3(area.position.x + _rng.randf() * area.size.x, 0, area.position.y + _rng.randf() * area.size.y)
			_tree(b, p, _rng.randf() * TAU, 0 if _rng.randf() < 0.65 else 2)
	# Деревья вдоль деревенской улицы
	for x in [-160.0, -137.5, -112.5, -87.5, -65.0]:
		_tree(b, Vector3(x, 0, -44.5), _rng.randf() * TAU, 2)


## kind: 0 — ель, 1 — яблоня, 2 — берёза. Крона из повёрнутых кусков.
func _tree(b: MeshBuilder, p: Vector3, yaw: float, kind: int) -> void:
	var s := _rng.randf_range(0.85, 1.25)
	var saved := b.xf
	b.xf = b.xf * Transform3D(Basis(Vector3.UP, yaw), p)
	# Тень под деревом
	b.box(Vector3(-1.4, 0, -1.4) * s, Vector3(1.4, 0.015, 1.4) * s, Color(0.2, 0.3, 0.14))
	match kind:
		0:
			b.box(Vector3(-0.15, 0, -0.15) * s, Vector3(0.15, 2.0, 0.15) * s, Color(0.35, 0.25, 0.18), true)
			var green := Color(0.14, 0.3, 0.15)
			for i in 4:
				var w := (2.2 - i * 0.5) * s
				b.box_rot(Vector3(0, (1.5 + i * 1.4) * s, 0), Vector3(w, 1.5 * s, w), i * 0.4, green.lightened(i * 0.04))
		1:
			b.box(Vector3(-0.12, 0, -0.12) * s, Vector3(0.12, 1.4, 0.12) * s, Color(0.4, 0.3, 0.2), true)
			for i in 3:
				b.box_rot(Vector3(0, 2.0 * s, 0), Vector3(2.2, 1.4, 2.2) * s, i * 0.5, Color(0.25, 0.45, 0.2))
			for i in 5:
				b.box(Vector3(-1.0 + i * 0.45, 1.3, 1.05) * s, Vector3(-0.9 + i * 0.45, 1.4, 1.15) * s, Color(0.8, 0.2, 0.15))
		_:
			b.box(Vector3(-0.12, 0, -0.12) * s, Vector3(0.12, 4.5, 0.12) * s, Color(0.9, 0.9, 0.86), true)
			for i in 3:
				b.box(Vector3(-0.13, 1.0 + i * 1.1, -0.13) * s, Vector3(0.13, 1.08 + i * 1.1, 0.13) * s, Color(0.15, 0.15, 0.15))
			for i in 3:
				b.box_rot(Vector3(0, (4.2 + i * 0.6) * s, 0), Vector3(2.4 - i * 0.5, 1.2, 2.4 - i * 0.5) * s, i * 0.6, Color(0.35, 0.55, 0.22))
	b.xf = saved


# --- Игрок и машина ---------------------------------------------------------

func _spawn_player_and_car() -> void:
	var player := Player.new()
	player.name = "Player"
	add_child(player)
	# Внутри своего дома, на кухне у входа, лицом к печи
	player.global_position = Vector3(PLAYER_HOUSE.x - 1.6, HOUSE_Y + 0.05, PLAYER_HOUSE.y + 2.0)
	var car := Car.new()
	car.name = "Car"
	add_child(car)
	# Жигули на улице перед домом, носом вдоль улицы
	car.global_position = Vector3(PLAYER_HOUSE.x + 4.0, 0.1, -39.5)
	car.rotation.y = -PI / 2.0
