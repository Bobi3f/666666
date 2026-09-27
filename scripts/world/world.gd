extends Node3D
## Мир 400×400 м: деревня из 8 дворов трёх уровней достатка с сельмагом,
## фонарями, прудом и огородами, город из панелек, магистраль, ЛЭП, лес и поля.
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

## Фонари вдоль деревенской улицы — в просветах между дворами.
const LAMP_X := [-162.0, -137.5, -112.5, -87.5, -63.0]
const LAMP_Z := -36.9
## Сельмаг за съездом к трассе, дверью к деревне.
const SHOP_POS := Vector3(-45.0, 0, -24.0)
const POND_POS := Vector3(-182.0, 0, -40.0)
## Остановки: у Каменки (северная обочина) и в городе у склада (южная).
const STOP_VILLAGE := Vector3(-68.5, 0, -7.6)
const STOP_TOWN := Vector3(32.0, 0, 10.5)
const BUS_FARE := 15
## АЗС и СТО у трассы напротив деревни.
const FUEL_POS := Vector3(-110.0, 0, 13.0)
const GARAGE_POS := Vector3(-86.0, 0, 14.0)
const FUEL_PRICE := 32
const FISH_PRICE := 60
## Колхозный сарай у стогов.
const BARN_POS := Vector3(-35.0, 0, -47.0)

const HOUSE_Y := 0.05  # пол дома чуть выше земли
const SKIN := 0.1       # толщина наружной обшивки

var _sun: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _glow_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
## Отдельный генератор для деревенских мелочей: лес и город остаются прежними.
var _vrng := RandomNumberGenerator.new()
## И ещё один — для мелких деталей (трещины, столбики, знаки, двор города).
var _drng := RandomNumberGenerator.new()
## Лампы фонарей и пятна света под ними: видны только в темноте.
var _street_lights: Array[Node3D] = []
var _light_pool_mat: StandardMaterial3D
## Двор игрока строится отдельно от общего меша: его перестраивают.
var _yard_nodes: Array[Node] = []
## Смещение двери своего дома вдоль фасада — от неё считаем стартовую точку.
var _home_door_x := 0.0
var _fishing: FishingGame
var _fishing_water := Vector3.ZERO
## Деревья, трава и цветы — отдельными MultiMesh (vegetation.gd).
var _veg := Vegetation.new()
var _sky_top: Color
var _sky_horizon: Color


func _ready() -> void:
	_rng.seed = 20260925
	_vrng.seed = 1986
	_drng.seed = 1991
	_setup_environment()

	var b := MeshBuilder.new()
	var glow := MeshBuilder.new()
	glow.ground_shade = false
	_build_ground(b)
	_build_roads(b)
	_road_details(b)
	_build_power_line(b)
	_build_village(b)
	_build_village_life(b, glow)
	_build_roadside(b)
	_build_town(b, glow)
	_town_details(b, glow)
	_build_shops(b)
	_build_forest(b)
	_block_grass()
	# Двор игрока — до сборки растительности: его яблоня и кусты регистрируются
	# один раз, при перестройке дома они стоят на тех же местах
	_build_player_yard()

	var world_mesh := b.build_mesh()
	world_mesh.name = "WorldMesh"
	add_child(world_mesh)
	var body := b.build_body()
	body.name = "WorldCollision"
	add_child(body)
	_veg.name = "Vegetation"
	_veg.build()
	add_child(_veg)
	print("Растительность: ", _veg.counts)
	var glow_mesh := glow.build_mesh(true)
	glow_mesh.name = "WindowGlow"
	_glow_mat = glow_mesh.mesh.surface_get_material(0) if glow_mesh.mesh else null
	add_child(glow_mesh)
	print("Мир: %d треугольников в одном меше, %d коллизий" % [b.triangle_count(), body.get_child_count()])

	Progress.house_changed.connect(func(_l: int) -> void: _build_player_yard())
	NeedsManager.fainted.connect(_faint)
	_spawn_player_and_car()
	add_child(preload("res://scripts/world/ambience.gd").new())
	add_child(preload("res://scripts/world/traffic.gd").new())
	add_child(preload("res://scripts/world/villagers.gd").new())
	var garden: Node3D = preload("res://scripts/world/garden.gd").new()
	garden.position = Vector3(PLAYER_HOUSE.x, 0, PLAYER_HOUSE.y)
	add_child(garden)
	add_child(preload("res://scripts/ui/map.gd").new())
	add_child(preload("res://scripts/ui/hud.gd").new())
	add_child(preload("res://scripts/ui/pause_menu.gd").new())
	# Журнал — после меню: Esc при открытом журнале закрывает журнал, а не открывает паузу
	add_child(preload("res://scripts/ui/journal.gd").new())
	add_child(preload("res://scripts/ui/gamepad.gd").new())
	# Новая игра — короткое обучение; в загруженной игре оно само уберётся
	if not Progress.tutorial_done:
		add_child(preload("res://scripts/ui/tutorial.gd").new())
	if GameManager.touch_mode or "--touch" in OS.get_cmdline_user_args():
		GameManager.touch_mode = true
		# Кнопок сцепления и передач на экране нет — на телефоне только автомат
		SettingsManager.auto_gearbox = true
		add_child(preload("res://scripts/ui/touch_controls.gd").new())
		# Телефон: экран с высокой плотностью точек — 3D рисуем в 65 %
		# разрешения, интерфейс остаётся чётким
		get_viewport().scaling_3d_scale = 0.65
		# Интерфейс под высоту экрана: около 600 точек по высоте, как на мониторе,
		# иначе на плотном экране телефона надписи и кнопки крошечные
		var win := get_window()
		var fit := func() -> void:
			win.content_scale_factor = maxf(1.0, win.size.y / 600.0)
		fit.call()
		win.size_changed.connect(fit)
	GameManager.notify("Утро в Каменке. Задание — слева вверху, журнал — J, управление — F1")


func _process(_delta: float) -> void:
	_update_daylight()
	_check_delivery()


# --- Небо, солнце, смена дня и ночи ----------------------------------------

func _setup_environment() -> void:
	_sky = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky
	_sky_top = _sky.sky_top_color
	_sky_horizon = _sky.sky_horizon_color
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
	SettingsManager.changed.connect(_apply_detail)
	_apply_detail()
	_update_daylight()


## Детализация: на высокой — тени в два каскада, на средней — один
## (дешевле вдвое), на низкой — без теней.
func _apply_detail() -> void:
	var r := SettingsManager.shadow_range()
	_sun.shadow_enabled = r > 0.0
	_sun.directional_shadow_max_distance = maxf(r, 1.0)
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if SettingsManager.detail >= 2 \
		else DirectionalLight3D.SHADOW_ORTHOGONAL


func _update_daylight() -> void:
	var h := TimeManager.hour()
	# Солнце встаёт в 6, садится в 20
	var t := (h - 6.0) / 14.0
	var elev := sin(clampf(t, 0.0, 1.0) * PI)
	var day := clampf(elev * 3.0, 0.0, 1.0)
	# Тучи гасят солнце и серят небо, туман и дождь сжимают видимость
	var cloud := WeatherManager.cloud
	_sun.rotation = Vector3(-lerpf(0.08, 1.1, elev), lerpf(-1.9, 1.9, clampf(t, 0.0, 1.0)), 0.0)
	_sun.light_energy = lerpf(0.0, 1.15, day) * (1.0 - cloud * 0.65)
	var grey := Color(0.52, 0.54, 0.56)
	_sky.sky_top_color = _sky_top.lerp(grey, cloud * 0.8)
	_sky.sky_horizon_color = _sky_horizon.lerp(grey.lightened(0.15), cloud * 0.8)
	_env.fog_density = 0.0025 + WeatherManager.rain * 0.007 + WeatherManager.fog * 0.03
	_sun.light_color = Color(1.0, 0.75, 0.5).lerp(Color(1.0, 0.97, 0.92), clampf(elev * 2.0, 0.0, 1.0))
	_sun.visible = day > 0.01
	_env.background_energy_multiplier = lerpf(0.06, 1.0, day)
	_env.ambient_light_energy = lerpf(0.12, 1.0, day)
	_env.fog_light_color = Color(0.05, 0.06, 0.1).lerp(Color(0.7, 0.78, 0.88).lerp(Color(0.5, 0.52, 0.55), cloud * 0.8), day)
	if _glow_mat:
		_glow_mat.albedo_color = Color(0.3, 0.32, 0.36).lerp(Color(1.0, 1.0, 1.0), 1.0 - day)
	# Фонари зажигаются в сумерках
	var lit := day < 0.35
	for l in _street_lights:
		l.visible = lit


# --- Земля и дороги ---------------------------------------------------------

func _build_ground(b: MeshBuilder) -> void:
	# Земля пятнами: крупные — сухая и сочная трава, мелкие — проплешины
	# и тёмные влажные места. Сетка 4×4 м, цвет в каждой вершине.
	var n := 100
	var cell := 400.0 / n
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.02
	var detail := FastNoiseLite.new()
	detail.seed = 8
	detail.frequency = 0.11
	var grass := Color(0.32, 0.47, 0.21)
	var dry := Color(0.47, 0.5, 0.27)
	var damp := Color(0.24, 0.38, 0.17)
	var bare := Color(0.45, 0.4, 0.28)
	var cols_at := {}
	for i in n + 1:
		for j in n + 1:
			var x := -200.0 + i * cell
			var z := -200.0 + j * cell
			var c := grass.lerp(dry, clampf(noise.get_noise_2d(x, z) * 0.8 + 0.35, 0.0, 1.0))
			var d := detail.get_noise_2d(x, z)
			if d > 0.35:
				c = c.lerp(bare, (d - 0.35) * 0.9)
			elif d < -0.3:
				c = c.lerp(damp, (-0.3 - d) * 1.2)
			cols_at[Vector2i(i, j)] = c
	for i in n:
		for j in n:
			var x0 := -200.0 + i * cell
			var z0 := -200.0 + j * cell
			var pts := [Vector3(x0, 0, z0 + cell), Vector3(x0 + cell, 0, z0 + cell), Vector3(x0 + cell, 0, z0), Vector3(x0, 0, z0)]
			var cols: Array[Color] = [cols_at[Vector2i(i, j + 1)], cols_at[Vector2i(i + 1, j + 1)], cols_at[Vector2i(i + 1, j)], cols_at[Vector2i(i, j)]]
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
		if Vector2(VILLAGE_X[i], ROW_A_Z) != PLAYER_HOUSE:
			_build_yard(b, Vector3(VILLAGE_X[i], 0, ROW_A_Z), 0.0, ROW_A[i])
		_build_yard(b, Vector3(VILLAGE_X[i], 0, ROW_B_Z), PI, ROW_B[i])


## Двор игрока: свой меш и коллизии, перестраивается при каждом новом уровне дома.
func _build_player_yard() -> void:
	for n in _yard_nodes:
		# Имя освобождаем сразу: новый дом должен получить то же имя
		n.name = "%s_old" % n.name
		n.queue_free()
	_yard_nodes.clear()
	var yb := MeshBuilder.new()
	var level: int = clampi(Progress.house_level, W.POOR, W.RICH)
	_yard_nodes.append_array(_build_yard(yb, Vector3(PLAYER_HOUSE.x, 0, PLAYER_HOUSE.y), 0.0, level))
	var mesh := yb.build_mesh()
	mesh.name = "PlayerYardMesh"
	add_child(mesh)
	_yard_nodes.append(mesh)
	var body := yb.build_body()
	body.name = "PlayerYardCollision"
	add_child(body)
	_yard_nodes.append(body)


## Строит двор в b и возвращает созданные узлы (интерьер, зоны).
func _build_yard(b: MeshBuilder, pos: Vector3, yaw: float, wealth: int) -> Array[Node]:
	var nodes: Array[Node] = []
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
	nodes.append(hi)
	if Vector2(pos.x, pos.z) == PLAYER_HOUSE:
		_home_door_x = hi.entrance_offset
		var bed := InteractZone.create("E — лечь спать до 7:00", Vector3(1.6, 1.4, 2.6))
		bed.position = hi.position + Basis(Vector3.UP, yaw) * hi.bed_center() - Vector3(0, 0.5, 0)
		bed.rotation.y = yaw
		bed.activated.connect(_sleep)
		add_child(bed)
		nodes.append(bed)
		# Прораб у калитки: перестройка дома за деньги
		var boss := InteractZone.create("", Vector3(2.6, 2.0, 2.0))
		boss.position = pos + Basis(Vector3.UP, yaw) * Vector3(hi.entrance_offset, 0, 13.4)
		boss.rotation.y = yaw
		boss.activated.connect(Progress.upgrade_house)
		boss.prompt_fn = _upgrade_prompt
		add_child(boss)
		nodes.append(boss)
	return nodes


func _upgrade_prompt() -> String:
	if Progress.max_level():
		return "Прораб: «Лучше дома в Каменке нет, хозяин!»"
	return "E — прораб: построить %s за %d грн" % [Progress.UPGRADE_TEXT[Progress.house_level], Progress.next_cost()]


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
	_house_details(b, hi, ox, oz, H, e, drop, ridge_y, style, open)


## Мелочи снаружи дома: водостоки с трубами, козырёк над дверью, ставни,
## антенна на коньке, продухи в цоколе, табличка с номером, лампочка у входа.
func _house_details(b: MeshBuilder, hi: HouseInterior, ox: float, oz: float, H: float, e: float, drop: float,
		ridge_y: float, style: Dictionary, open: Dictionary) -> void:
	var metal := Color(0.55, 0.57, 0.58) if hi.wealth != W.POOR else Color(0.45, 0.38, 0.32)
	var gy := H - drop
	for sz in [1.0, -1.0]:
		var z0: float = sz * (oz + e)
		b.box(Vector3(-ox - e, gy - 0.14, minf(z0, z0 + sz * 0.13)), Vector3(ox + e, gy - 0.04, maxf(z0, z0 + sz * 0.13)), metal)
		for sx in [-1.0, 1.0]:
			var x: float = sx * (ox + e - 0.12)
			var pz: float = z0 + sz * 0.06
			b.box(Vector3(x - 0.05, 0.25, pz - 0.05), Vector3(x + 0.05, gy - 0.1, pz + 0.05), metal)
			b.box(Vector3(x - 0.06, 0.05, pz - 0.06), Vector3(x + 0.06, 0.3, pz + sz * 0.25 + 0.06 * sz), metal.darkened(0.1))
	# Козырёк над дверью на кронштейнах
	var door: Array = open.front[0]
	var dx: float = door[0]
	b.box(Vector3(dx - 0.85, 2.32, oz), Vector3(dx + 0.85, 2.4, oz + 0.95), style.roof)
	for x in [dx - 0.75, dx + 0.7]:
		b.box(Vector3(x, 2.0, oz), Vector3(x + 0.05, 2.32, oz + 0.05), style.trim)
		b.box(Vector3(x, 2.28, oz), Vector3(x + 0.05, 2.33, oz + 0.85), style.trim)
	# Лампочка у двери и табличка с номером дома
	b.box(Vector3(dx + 0.6, 2.05, oz), Vector3(dx + 0.72, 2.2, oz + 0.12), Color(0.95, 0.92, 0.75))
	b.box(Vector3(dx + 0.85, 1.65, oz), Vector3(dx + 1.2, 1.85, oz + 0.03), Color(0.15, 0.3, 0.6))
	b.box(Vector3(dx + 0.95, 1.7, oz + 0.03), Vector3(dx + 1.1, 1.8, oz + 0.035), Color(0.95, 0.95, 0.95))
	# Ставни у окон фасада (кроме кирпичного дома)
	if hi.wealth != W.RICH:
		for o in open.front:
			var bottom: float = o[3]
			if bottom <= 0.0:
				continue
			var c: float = o[0]
			var w: float = o[1]
			var top: float = o[2]
			for side in [-1.0, 1.0]:
				var x0: float = c + side * (w * 0.5 + 0.1)
				var x1: float = x0 + side * w * 0.5
				b.box(Vector3(minf(x0, x1), bottom, oz), Vector3(maxf(x0, x1), top, oz + 0.04), style.trim.darkened(0.1))
				for k in 3:
					var y := bottom + (top - bottom) * (0.2 + k * 0.3)
					b.box(Vector3(minf(x0, x1), y, oz + 0.04), Vector3(maxf(x0, x1), y + 0.03, oz + 0.05), style.trim.darkened(0.3))
	# Продухи в цоколе
	var x := -ox + 0.8
	while x < ox - 0.5:
		if absf(x - dx) > 1.0:
			b.box(Vector3(x, 0.08, oz), Vector3(x + 0.18, 0.2, oz + 0.02), Color(0.12, 0.12, 0.12))
		x += 2.0
	# Антенна на коньке — «ёлочка»
	if hi.wealth != W.RICH:
		var ax := ox - 1.4
		b.box(Vector3(ax - 0.025, ridge_y, -0.025), Vector3(ax + 0.025, ridge_y + 2.0, 0.025), Color(0.4, 0.4, 0.42))
		for k in 4:
			var y := ridge_y + 1.2 + k * 0.22
			var half := 0.55 - k * 0.1
			b.box(Vector3(ax - 0.015, y, -half), Vector3(ax + 0.015, y + 0.02, half), Color(0.4, 0.4, 0.42))


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
	# Кусты сирени и смородины вдоль забора
	for p in [Vector3(-10.0, 0, 10.8), Vector3(-10.0, 0, 3.0), Vector3(10.0, 0, 11.0), Vector3(-6.0, 0, -8.0)]:
		_tree(b, p, _rng.randf() * TAU, Vegetation.TreeKind.BUSH)
	_gate_bench(b, hi.wealth)
	_front_garden(b, hi)
	# На огороде игрока растёт то, что он сам посадил (garden.gd)
	var own := is_equal_approx(hi.position.x, PLAYER_HOUSE.x) and is_equal_approx(hi.position.z, PLAYER_HOUSE.y)
	_vegetable_plot(b, hi.wealth, not own)
	if hi.wealth != W.RICH:
		_kennel(b, Vector3(3.6, 0, 8.2))
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
			# Теплица
			b.box(Vector3(-9.5, 0, -8.0), Vector3(-5.5, 2.0, -5.0), Color(0.75, 0.88, 0.9), true)
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


## Лавочка у забора справа от калитки — посидеть с соседями.
func _gate_bench(b: MeshBuilder, wealth: int) -> void:
	var wood := Color(0.5, 0.35, 0.2) if wealth == W.RICH else Color(0.55, 0.45, 0.32)
	b.box(Vector3(1.0, 0.42, 12.25), Vector3(3.0, 0.47, 12.65), wood)
	if wealth != W.POOR:
		b.box(Vector3(1.0, 0.47, 12.15), Vector3(3.0, 0.85, 12.2), wood)
	for x in [1.1, 2.8]:
		b.box(Vector3(x, 0, 12.3), Vector3(x + 0.1, 0.42, 12.6), wood.darkened(0.35))


## Палисадник: клумба вдоль фасада, у бедных — лопухи и крапива.
func _front_garden(b: MeshBuilder, hi: HouseInterior) -> void:
	var ox := hi.inner_size.x * 0.5 + hi.wall_thickness + SKIN
	var oz := hi.inner_size.z * 0.5 + hi.wall_thickness + SKIN
	var z0 := oz + 0.9
	var z1 := oz + 1.6
	var poor := hi.wealth == W.POOR
	var flowers := [Color(0.9, 0.2, 0.25), Color(0.95, 0.85, 0.2), Color(0.95, 0.95, 0.95), Color(0.75, 0.4, 0.85), Color(0.95, 0.55, 0.15)]
	for side in [[-ox + 0.2, hi.entrance_offset - 1.1], [hi.entrance_offset + 1.1, ox - 0.2]]:
		var x0: float = side[0]
		var x1: float = side[1]
		if x1 - x0 < 0.5:
			continue
		if not poor:
			# Бордюр из дощечек и чёрная земля
			b.box(Vector3(x0, 0, z0), Vector3(x1, 0.08, z1), Color(0.28, 0.2, 0.14))
			b.box(Vector3(x0 - 0.05, 0, z1), Vector3(x1 + 0.05, 0.16, z1 + 0.05), Color(0.9, 0.9, 0.88))
		var x := x0 + 0.15
		while x < x1 - 0.1:
			var h := _vrng.randf_range(0.25, 0.6)
			var zz := _vrng.randf_range(z0 + 0.1, z1 - 0.15)
			if poor:
				b.box_rot(Vector3(x, h * 0.5, zz), Vector3(0.35, h, 0.3), _vrng.randf() * TAU, Color(0.22, 0.38, 0.16))
			else:
				b.box(Vector3(x - 0.02, 0.08, zz - 0.02), Vector3(x + 0.02, h, zz + 0.02), Color(0.2, 0.4, 0.15))
				var c: Color = flowers[_vrng.randi() % flowers.size()]
				b.box(Vector3(x - 0.08, h, zz - 0.08), Vector3(x + 0.08, h + 0.1, zz + 0.08), c)
			x += _vrng.randf_range(0.25, 0.45)


## Огород за задним забором: картошка рядами, у бедных ещё и пугало.
func _vegetable_plot(b: MeshBuilder, wealth: int, plants := true) -> void:
	var soil := Color(0.33, 0.24, 0.16)
	var leaf := Color(0.26, 0.45, 0.18)
	b.box(Vector3(-10.5, 0, -14.0), Vector3(10.5, 0.03, -9.5), soil.lightened(0.08))
	var z := -13.6
	while z < -9.8:
		b.box(Vector3(-10.2, 0, z), Vector3(10.2, 0.16, z + 0.45), soil)
		var x := -10.0
		while plants and x < 10.0:
			b.box_rot(Vector3(x, 0.26, z + 0.22), Vector3(0.45, 0.22, 0.4), _vrng.randf() * TAU,
				leaf.lightened(_vrng.randf() * 0.12))
			x += _vrng.randf_range(0.8, 1.1)
		z += 0.9
	if wealth == W.POOR:
		# Пугало: крест из жердей, старая куртка и ведро вместо головы
		var p := Vector3(4.0, 0, -11.8)
		b.box(p + Vector3(-0.05, 0, -0.05), p + Vector3(0.05, 2.0, 0.05), Color(0.45, 0.35, 0.22))
		b.box(p + Vector3(-0.8, 1.45, -0.04), p + Vector3(0.8, 1.53, 0.04), Color(0.45, 0.35, 0.22))
		b.box(p + Vector3(-0.3, 0.9, -0.15), p + Vector3(0.3, 1.55, 0.15), Color(0.3, 0.32, 0.45))
		b.box(p + Vector3(-0.15, 1.9, -0.15), p + Vector3(0.15, 2.2, 0.15), Color(0.6, 0.6, 0.62))


## Собачья будка с двускатной крышей и тёмным лазом.
func _kennel(b: MeshBuilder, p: Vector3) -> void:
	var wood := Color(0.5, 0.38, 0.25)
	b.box(p + Vector3(-0.5, 0, -0.6), p + Vector3(0.5, 0.75, 0.6), wood, true)
	b.box(p + Vector3(-0.2, 0.05, 0.6), p + Vector3(0.2, 0.5, 0.61), Color(0.08, 0.07, 0.06))
	for s in [-1.0, 1.0]:
		b.quad(p + Vector3(s * 0.62, 0.7, 0.68), p + Vector3(s * 0.62, 0.7, -0.68), p + Vector3(0, 1.05, -0.68), p + Vector3(0, 1.05, 0.68),
			Color(0.35, 0.33, 0.32), true)
	# Миска
	b.box(p + Vector3(0.3, 0, 0.9), p + Vector3(0.55, 0.08, 1.15), Color(0.55, 0.55, 0.6))


# --- Жизнь села: фонари, сельмаг, остановка, пруд, стога ---------------------

func _build_village_life(b: MeshBuilder, glow: MeshBuilder) -> void:
	_street_ruts(b)
	for x in LAMP_X:
		_street_lamp(b, glow, Vector3(x, 0, LAMP_Z))
	_village_shop(b, glow)
	_bus_stop(b, STOP_VILLAGE, 0.0, true)
	_village_sign(b, Vector3(-54.5, 0, -7.2))
	_pond(b, POND_POS)
	for p in [Vector3(-42, 0, -62), Vector3(-33, 0, -70), Vector3(-26, 0, -57)]:
		_haystack(b, p)


## Колеи и лужи на грунтовке — видно, что по ней ездят.
func _street_ruts(b: MeshBuilder) -> void:
	var rut := Color(0.38, 0.32, 0.23)
	for z in [-41.0, -39.3]:
		b.box(Vector3(-164, 0.04, z), Vector3(-58, 0.043, z + 0.5), rut)
	for i in 9:
		var x := _vrng.randf_range(-160.0, -62.0)
		var z: float = [-41.0, -39.3][i % 2] + _vrng.randf_range(-0.2, 0.3)
		var l := _vrng.randf_range(1.0, 2.6)
		b.box(Vector3(x, 0.043, z), Vector3(x + l, 0.047, z + _vrng.randf_range(0.5, 0.9)), Color(0.36, 0.4, 0.44))


## Деревянный столб с железным плафоном; лампа горит в сумерках.
func _street_lamp(b: MeshBuilder, glow: MeshBuilder, p: Vector3) -> void:
	var wood := Color(0.33, 0.26, 0.19)
	b.box(p + Vector3(-0.1, 0, -0.1), p + Vector3(0.1, 6.0, 0.1), wood, true)
	# Кронштейн к середине улицы
	b.box(p + Vector3(-0.04, 5.6, -1.6), p + Vector3(0.04, 5.68, 0.0), Color(0.25, 0.25, 0.25))
	b.box(p + Vector3(-0.04, 5.35, -0.1), p + Vector3(0.04, 5.68, -0.02), Color(0.25, 0.25, 0.25))
	b.box(p + Vector3(-0.28, 5.42, -1.9), p + Vector3(0.28, 5.62, -1.35), Color(0.3, 0.32, 0.3))
	glow.box(p + Vector3(-0.14, 5.3, -1.75), p + Vector3(0.14, 5.42, -1.5), Color(1.0, 0.82, 0.5))
	var light := OmniLight3D.new()
	light.position = p + Vector3(0, 5.1, -1.6)
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = 1.4
	light.omni_range = 11.0
	light.visible = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 40.0
	light.distance_fade_length = 10.0
	add_child(light)
	_street_lights.append(light)
	# Мир — один меш, а в Compatibility на объект влияют не больше 8 ламп,
	# их уже заняли лампы в домах. Поэтому свет на земле — отдельное пятно.
	var pool := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.0, 10.0)
	pool.mesh = plane
	pool.material_override = _light_pool_material()
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.position = p + Vector3(0, 0.06, -1.6)
	pool.visible = false
	add_child(pool)
	_street_lights.append(pool)


func _light_pool_material() -> StandardMaterial3D:
	if _light_pool_mat:
		return _light_pool_mat
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.8, 0.5, 0.55))
	g.set_color(1, Color(1.0, 0.8, 0.5, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_light_pool_mat = StandardMaterial3D.new()
	_light_pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_light_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_light_pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_light_pool_mat.albedo_texture = tex
	return _light_pool_mat


## Сельмаг: кирпичная коробка с крыльцом и вывеской. Хлеб дешевле, чем
## в городском ларьке, но работает только днём.
func _village_shop(b: MeshBuilder, glow: MeshBuilder) -> void:
	# Локально фасад смотрит на +Z, разворот — дверью к съезду
	var yaw := -PI / 2.0
	var xf := Transform3D(Basis(Vector3.UP, yaw), SHOP_POS)
	b.xf = xf
	glow.xf = xf
	var brick := Color(0.66, 0.36, 0.26)
	var h := 3.4
	b.box(Vector3(-4.5, 0, -3.0), Vector3(4.5, h, 3.0), brick, true)
	# Швы кладки на фасаде
	var y := 0.4
	while y < h:
		b.box(Vector3(-4.5, y, 3.0), Vector3(4.5, y + 0.015, 3.012), Color(0.8, 0.74, 0.64))
		y += 0.2
	b.box(Vector3(-4.6, 0, -3.1), Vector3(4.6, 0.4, 3.1), Color(0.45, 0.44, 0.42))
	# Плоская крыша с парапетом
	b.box(Vector3(-4.7, h, -3.2), Vector3(4.7, h + 0.25, 3.2), Color(0.35, 0.35, 0.36))
	# Дверь, крыльцо с козырьком
	b.box(Vector3(-0.6, 0.4, 3.0), Vector3(0.6, 2.5, 3.05), Color(0.3, 0.42, 0.35))
	b.box(Vector3(-1.4, 0, 3.0), Vector3(1.4, 0.4, 4.4), Color(0.58, 0.58, 0.56), true)
	b.box(Vector3(-1.6, 2.8, 3.0), Vector3(1.6, 2.92, 4.5), Color(0.5, 0.52, 0.55))
	for x in [-1.5, 1.4]:
		b.box(Vector3(x, 0.4, 4.3), Vector3(x + 0.1, 2.8, 4.4), Color(0.4, 0.4, 0.42))
	# Витрины по бокам от двери: днём тёмное стекло, вечером свет внутри
	for x in [-3.6, 1.4]:
		b.box(Vector3(x - 0.08, 0.92, 3.0), Vector3(x + 2.28, 2.48, 3.06), Color(0.9, 0.9, 0.88))
		glow.quad(Vector3(x, 1.0, 3.07), Vector3(x + 2.2, 1.0, 3.07), Vector3(x + 2.2, 2.4, 3.07), Vector3(x, 2.4, 3.07), Color(1.0, 0.9, 0.7))
	# Вывеска
	b.box(Vector3(-3.0, 2.95, 3.0), Vector3(3.0, 3.35, 3.1), Color(0.85, 0.2, 0.15))
	# Ящики и урна у входа
	b.box(Vector3(2.0, 0, 3.4), Vector3(2.6, 0.4, 3.9), Color(0.6, 0.45, 0.3))
	b.box(Vector3(2.1, 0.4, 3.45), Vector3(2.5, 0.75, 3.85), Color(0.6, 0.45, 0.3))
	b.box(Vector3(-2.3, 0, 3.4), Vector3(-1.9, 0.7, 3.8), Color(0.35, 0.4, 0.35))
	b.xf = Transform3D.IDENTITY
	glow.xf = Transform3D.IDENTITY
	# Тропинка от деревенского съезда к крыльцу
	b.box(Vector3(-57.0, 0, -25.0), Vector3(SHOP_POS.x - 4.4, 0.03, -23.0), Color(0.46, 0.39, 0.28))

	var sign := Label3D.new()
	sign.text = "ПРОДУКТЫ"
	sign.font_size = 96
	sign.pixel_size = 0.004
	sign.outline_size = 0
	sign.modulate = Color(1, 1, 0.9)
	sign.position = xf * Vector3(0, 3.15, 3.12)
	sign.rotation.y = yaw
	add_child(sign)

	var zone := InteractZone.create("E — сельмаг: хлеб и молоко (40 грн)", Vector3(2.8, 2.4, 3.2))
	zone.position = xf * Vector3(0, 0, 4.5)
	zone.rotation.y = yaw
	zone.activated.connect(_buy_village_food)
	add_child(zone)

	var fish_zone := InteractZone.create("", Vector3(1.8, 2.4, 1.8))
	fish_zone.position = xf * Vector3(3.4, 0, 4.6)
	fish_zone.rotation.y = yaw
	fish_zone.prompt_fn = func() -> String:
		if NeedsManager.fish <= 0:
			return "Продавщица принимает рыбу по %d грн" % FISH_PRICE
		return "E — сдать рыбу: %d шт × %d грн" % [NeedsManager.fish, FISH_PRICE]
	fish_zone.activated.connect(_sell_fish)
	add_child(fish_zone)


func _sell_fish() -> void:
	if NeedsManager.fish <= 0:
		GameManager.notify("Рыбы нет. Порыбачь на пруду с мостков")
		return
	var pay := NeedsManager.fish * FISH_PRICE
	NeedsManager.fish = 0
	GameManager.add_money(pay)
	SoundLibrary.play("cash")
	GameManager.notify("Сдал рыбу: +%d грн" % pay)


func _buy_village_food() -> void:
	var h := TimeManager.hour()
	if h < 8.0 or h >= 21.0:
		GameManager.notify("Сельмаг закрыт. Работает с 8:00 до 21:00")
		return
	if GameManager.spend(40):
		NeedsManager.snacks += 1
		GameManager.notify("Купил хлеб и молоко. Съесть — Q")


## Бетонная остановка у трассы: стенка, крыша, лавка, табличка «А».
## Локально дорога — со стороны +Z, yaw разворачивает к ней.
func _bus_stop(b: MeshBuilder, p: Vector3, yaw: float, to_town: bool) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	b.xf = xf
	var concrete := Color(0.7, 0.7, 0.67)
	b.box(Vector3(-2.5, 0, -1.25), Vector3(2.5, 0.12, 1.2), Color(0.55, 0.55, 0.53))
	b.box(Vector3(-2.5, 0, -1.25), Vector3(2.5, 2.6, -1.05), concrete, true)
	for s in [-1.0, 1.0]:
		b.box(Vector3(s * 2.5 - 0.1, 0, -1.25), Vector3(s * 2.5 + 0.1, 2.6, 0.2), concrete, true)
	b.box(Vector3(-2.8, 2.6, -1.4), Vector3(2.8, 2.8, 1.3), concrete.darkened(0.1))
	# Мозаика на задней стенке
	for i in 5:
		var c: Color = [Color(0.3, 0.5, 0.75), Color(0.9, 0.75, 0.3), Color(0.8, 0.3, 0.25)][i % 3]
		b.box(Vector3(-2.0 + i * 0.85, 1.0, -1.06), Vector3(-1.4 + i * 0.85, 2.0, -1.03), c)
	b.box(Vector3(-2.0, 0.45, -1.05), Vector3(2.0, 0.52, -0.65), Color(0.5, 0.35, 0.2))
	# Табличка на столбе
	var s := Vector3(3.3, 0, 0.6)
	b.box(s + Vector3(-0.04, 0, -0.04), s + Vector3(0.04, 2.5, 0.04), Color(0.4, 0.4, 0.4))
	b.box(s + Vector3(-0.3, 2.0, 0.04), s + Vector3(0.3, 2.6, 0.07), Color(0.95, 0.85, 0.2))
	b.xf = Transform3D.IDENTITY
	var lbl := Label3D.new()
	lbl.text = "А"
	lbl.font_size = 96
	lbl.pixel_size = 0.004
	lbl.modulate = Color(0.1, 0.1, 0.1)
	lbl.outline_size = 0
	lbl.position = xf * (s + Vector3(0, 2.3, 0.08))
	lbl.rotation.y = yaw
	add_child(lbl)
	var zone := InteractZone.create("E — автобус до %s (%d грн)" % ["города" if to_town else "Каменки", BUS_FARE], Vector3(5.0, 2.2, 3.0))
	zone.position = xf * Vector3(0, 0, 0.3)
	zone.rotation.y = yaw
	zone.activated.connect(_ride_bus.bind(to_town))
	add_child(zone)


## Автобус: ждёшь минут двадцать и выходишь на другой остановке.
func _ride_bus(to_town: bool) -> void:
	var h := TimeManager.hour()
	if h < 6.0 or h >= 22.0:
		GameManager.notify("Автобусы ходят с 6:00 до 22:00")
		return
	if not GameManager.spend(BUS_FARE):
		return
	TimeManager.advance(20.0)
	var p := GameManager.player as Player
	var stop := STOP_TOWN if to_town else STOP_VILLAGE
	# Выходим на обочину перед остановкой, лицом от дороги
	var out := stop + (Vector3(0, 0.1, -2.2) if to_town else Vector3(0, 0.1, 2.2))
	p.global_position = out
	p.velocity = Vector3.ZERO
	p.rotation.y = PI if to_town else 0.0
	GameManager.notify("Приехал %s. %s" % ["в город" if to_town else "в Каменку", TimeManager.clock_text()])


## Синий указатель с названием села у съезда с трассы.
func _village_sign(b: MeshBuilder, p: Vector3) -> void:
	for x in [-1.1, 1.0]:
		b.box(p + Vector3(x, 0, -0.04), p + Vector3(x + 0.08, 2.4, 0.04), Color(0.45, 0.45, 0.45))
	b.box(p + Vector3(-1.3, 1.6, 0.04), p + Vector3(1.3, 2.4, 0.08), Color(0.12, 0.3, 0.65))
	b.box(p + Vector3(-1.3, 1.6, 0.0), p + Vector3(1.3, 2.4, 0.04), Color(0.6, 0.6, 0.6))
	var lbl := Label3D.new()
	lbl.text = "Каменка"
	lbl.font_size = 96
	lbl.pixel_size = 0.005
	lbl.outline_size = 0
	lbl.position = p + Vector3(0, 2.0, 0.09)
	add_child(lbl)


## Пруд за околицей: вода, илистый берег, камыш и мостки.
func _pond(b: MeshBuilder, c: Vector3) -> void:
	var segs := 20
	var pts: Array[Vector3] = []
	for i in segs:
		var a := TAU * i / segs
		var r := 8.0 + sin(a * 3.0) * 1.2 + _vrng.randf_range(-0.4, 0.4)
		pts.append(Vector3(cos(a) * r * 1.3, 0, sin(a) * r))
	for i in segs:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[(i + 1) % segs]
		b.tri(c + Vector3(0, 0.02, 0), c + p1 * 1.15 + Vector3(0, 0.02, 0), c + p0 * 1.15 + Vector3(0, 0.02, 0), Color(0.36, 0.3, 0.2))
		b.tri(c + Vector3(0, 0.035, 0), c + p1 + Vector3(0, 0.035, 0), c + p0 + Vector3(0, 0.035, 0), Color(0.2, 0.32, 0.36))
	# Камыш по берегу
	for i in 40:
		var p: Vector3 = pts[_vrng.randi() % segs] * _vrng.randf_range(0.95, 1.12)
		var h := _vrng.randf_range(0.8, 1.6)
		b.box(c + p + Vector3(-0.03, 0, -0.03), c + p + Vector3(0.03, h, 0.03), Color(0.35, 0.45, 0.2))
		if _vrng.randf() < 0.4:
			b.box(c + p + Vector3(-0.05, h - 0.25, -0.05), c + p + Vector3(0.05, h, 0.05), Color(0.35, 0.22, 0.12))
	# Мостки с восточного берега, тропинка от улицы
	var m := c + Vector3(pts[0].x - 0.8, 0, 0)
	b.box(m + Vector3(-3.5, 0.3, -0.6), m + Vector3(0.8, 0.38, 0.6), Color(0.5, 0.4, 0.28), true)
	for x in [-3.3, -1.8, -0.3]:
		for z in [-0.55, 0.45]:
			b.box(m + Vector3(x, -0.3, z), m + Vector3(x + 0.1, 0.3, z + 0.1), Color(0.3, 0.24, 0.16))
	b.box(Vector3(m.x + 0.8, 0, -40.6), Vector3(-164.0, 0.03, -39.4), Color(0.46, 0.39, 0.28))
	# Рыбалка — с конца мостков, поплавок — в паре метров от края
	_fishing = FishingGame.new()
	_fishing.name = "FishingGame"
	add_child(_fishing)
	_fishing.spot = m + Vector3(-2.4, 0.38, 0)
	_fishing_water = m + Vector3(-6.2, 0.06, 0.3)
	_fishing.finished.connect(_fish_result)
	var fishing := InteractZone.create("", Vector3(2.4, 2.0, 1.6))
	fishing.position = m + Vector3(-2.4, 0.38, 0)
	fishing.prompt_fn = func() -> String:
		match _fishing.state:
			FishingGame.State.WAIT:
				return "Поплавок на воде — жди, пока нырнёт"
			FishingGame.State.BITE:
				return "КЛЮЁТ! E — подсекай!"
		return "E — порыбачить: закинуть удочку"
	fishing.activated.connect(_fish)
	add_child(fishing)


## Закинуть удочку или подсечь. Каждый заброс — четверть часа игрового
## времени. Клюёт по-разному: на рассвете и в пасмурную погоду лучше, ночью — никак.
func _fish() -> void:
	if _fishing.active():
		_fishing.pull()
		return
	var h := TimeManager.hour()
	if h < 4.0 or h >= 22.0:
		GameManager.notify("Ночью не клюёт. Лучше всего — на рассвете")
		return
	if NeedsManager.energy < 10.0:
		GameManager.notify("Глаза слипаются — уснёшь с удочкой")
		return
	TimeManager.advance(15.0)
	NeedsManager.rest(-1.0)
	var luck := 0.5 + (0.2 if h < 8.0 else 0.0) + (0.15 if WeatherManager.cloud > 0.5 else 0.0)
	_fishing.cast(_fishing_water, luck)


func _fish_result(result: String) -> void:
	match result:
		"fish":
			NeedsManager.fish += 1
			QuestManager.event("fish", 1)
			SoundLibrary.play("splash", -2.0, 1.3)
			var kinds := ["карась", "окунь", "плотва", "линь"]
			GameManager.notify("Есть! %s на %d г. Рыбы в ведре: %d — сдай в сельмаг" % [
				kinds[randi() % kinds.size()].capitalize(), randi_range(150, 600), NeedsManager.fish])
		"early":
			GameManager.notify("Рано дёрнул — рыба ушла. Жди, пока поплавок нырнёт")
		"miss":
			GameManager.notify("Сорвалась! Подсекай сразу, как поплавок уйдёт под воду")
		"nobite":
			GameManager.notify("Не клюёт. Закинь ещё раз")


## Стог сена на лугу с шестом посередине.
func _haystack(b: MeshBuilder, p: Vector3) -> void:
	var hay := Color(0.72, 0.62, 0.35)
	for i in 5:
		var w := 3.2 - i * 0.6
		b.box_rot(p + Vector3(0, 0.45 + i * 0.7, 0), Vector3(w, 0.9, w), i * 0.35 + _vrng.randf() * 0.2, hay.darkened(i * 0.03), i == 0)
	b.box(p + Vector3(-0.05, 3.5, -0.05), p + Vector3(0.05, 4.4, 0.05), Color(0.4, 0.3, 0.2))


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
				# Рама с переплётом и форточкой, отлив под окном
				var fz0 := minf(z + s * 0.03, z + s * 0.05)
				var fz1 := maxf(z + s * 0.03, z + s * 0.05)
				var frame := Color(0.88, 0.87, 0.82) if _drng.randf() < 0.7 else Color(0.55, 0.4, 0.28)
				b.box(Vector3(x - 0.04, y, fz0), Vector3(x + 0.04, y + 1.4, fz1), frame)
				b.box(Vector3(x - 0.7, y + 0.95, fz0), Vector3(x + 0.7, y + 1.0, fz1), frame)
				b.box(Vector3(x - 0.74, y - 0.06, minf(z, z + s * 0.12)), Vector3(x + 0.74, y, maxf(z, z + s * 0.12)), Color(0.6, 0.62, 0.64))
				# Кое-где занавески видны сквозь стекло
				if _drng.randf() < 0.4:
					var cur := [Color(0.8, 0.65, 0.5), Color(0.75, 0.8, 0.85), Color(0.85, 0.75, 0.55)][_drng.randi() % 3] as Color
					b.box(Vector3(x - 0.66, y + 0.05, minf(z + s * 0.03, z + s * 0.036)), Vector3(x - 0.3, y + 1.35, maxf(z + s * 0.03, z + s * 0.036)), cur)
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
					for bx in [x - 1.3, x + 1.24]:
						b.box(Vector3(bx, y - 0.6, -hd - 1.1), Vector3(bx + 0.06, y + 0.35, -hd), Color(0.5, 0.55, 0.57))
					var kind := _drng.randf()
					if kind < 0.4:
						# Застеклённый балкон — рамы и стёкла до потолка
						b.box(Vector3(x - 1.28, y + 0.35, -hd - 1.08), Vector3(x + 1.28, y + 1.9, -hd - 1.04), Color(0.3, 0.38, 0.44))
						for k in 5:
							b.box(Vector3(x - 1.3 + k * 0.64, y + 0.35, -hd - 1.1), Vector3(x - 1.26 + k * 0.64, y + 1.9, -hd - 1.02), Color(0.85, 0.85, 0.82))
						b.box(Vector3(x - 1.35, y + 1.9, -hd - 1.15), Vector3(x + 1.35, y + 1.98, -hd), Color(0.5, 0.5, 0.52))
					elif kind < 0.6:
						# Бельё на верёвках
						b.box(Vector3(x - 1.2, y + 1.3, -hd - 0.9), Vector3(x + 1.2, y + 1.32, -hd - 0.88), Color(0.8, 0.8, 0.8))
						for k in 4:
							var cl := [Color(0.9, 0.9, 0.95), Color(0.75, 0.3, 0.3), Color(0.35, 0.5, 0.8), Color(0.9, 0.8, 0.4)][k] as Color
							b.box(Vector3(x - 1.0 + k * 0.55, y + 0.8, -hd - 0.91), Vector3(x - 0.6 + k * 0.55, y + 1.3, -hd - 0.87), cl)
					if _drng.randf() < 0.18:
						# Спутниковая тарелка на ограждении
						b.box(Vector3(x + 0.6, y + 0.1, -hd - 1.4), Vector3(x + 1.2, y + 0.7, -hd - 1.34), Color(0.88, 0.88, 0.88))
						b.box(Vector3(x + 0.85, y + 0.35, -hd - 1.34), Vector3(x + 0.95, y + 0.45, -hd - 1.1), Color(0.5, 0.5, 0.5))
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
	# Антенны и вентшахты на крыше, водосток на торцах
	for k in 4:
		var ax := -hl + 4.0 + k * (length - 8.0) / 3.0
		b.box(Vector3(ax - 0.03, h, -0.03), Vector3(ax + 0.03, h + 2.4, 0.03), Color(0.45, 0.45, 0.47))
		for j in 3:
			b.box(Vector3(ax - 0.5 + j * 0.1, h + 1.6 + j * 0.25, -0.02), Vector3(ax + 0.5 - j * 0.1, h + 1.63 + j * 0.25, 0.02), Color(0.45, 0.45, 0.47))
		b.box(Vector3(ax + 2.0, h, -3.5), Vector3(ax + 3.0, h + 1.0, -2.5), panel.darkened(0.12))
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * hl - 0.08, 0.2, hd - 0.2), Vector3(sx * hl + 0.08, h, hd - 0.04), Color(0.5, 0.52, 0.53))
	b.xf = Transform3D.IDENTITY
	glow.xf = Transform3D.IDENTITY


# --- Мелочи на дорогах и в городе ----------------------------------------------

## Трещины и заплатки на асфальте, выбоины на грунтовке, белые столбики
## вдоль трассы, километровые столбы, дорожные знаки, люки.
func _road_details(b: MeshBuilder) -> void:
	var r := _drng
	var crack := Color(0.17, 0.17, 0.18)
	# Трещины: ломаные из коротких отрезков
	for i in 260:
		var p := Vector3(r.randf_range(-198, 198), 0.051, r.randf_range(-3.6, 3.6))
		var a := r.randf() * TAU
		for k in r.randi_range(2, 5):
			var seg := r.randf_range(0.3, 1.1)
			b.box_rot(p, Vector3(seg, 0.004, 0.035), a, crack)
			p += Vector3(cos(a), 0, -sin(a)) * seg * 0.5
			a += r.randf_range(-0.8, 0.8)
	# Заплатки свежего и старого асфальта
	for i in 45:
		var x := r.randf_range(-195, 195)
		var z := r.randf_range(-3.5, 2.0)
		var shade := Color(0.2, 0.2, 0.21) if r.randf() < 0.5 else Color(0.3, 0.3, 0.3)
		b.box(Vector3(x, 0.05, z), Vector3(x + r.randf_range(0.8, 3.0), 0.054, z + r.randf_range(0.6, 1.6)), shade)
	# Выбоины на деревенской улице и съезде
	for i in 28:
		var x := r.randf_range(-163, -58)
		var z := r.randf_range(-42, -38)
		if i % 4 == 0:
			x = r.randf_range(-61.5, -57.5)
			z = r.randf_range(-36, -7)
		b.box_rot(Vector3(x, 0.04, z), Vector3(r.randf_range(0.4, 1.0), 0.005, r.randf_range(0.3, 0.8)), r.randf() * TAU, Color(0.33, 0.28, 0.2))
	# Белые столбики с чёрной полосой и катафотом вдоль обочин
	var x := -195.0
	while x < 195.0:
		for zs in [-1.0, 1.0]:
			var z: float = zs * 6.3
			if _post_clear(x, z):
				b.box(Vector3(x - 0.06, 0, z - 0.06), Vector3(x + 0.06, 0.95, z + 0.06), Color(0.93, 0.93, 0.9))
				b.box(Vector3(x - 0.065, 0.62, z - 0.065), Vector3(x + 0.065, 0.82, z + 0.065), Color(0.1, 0.1, 0.1))
				b.box(Vector3(x - 0.03, 0.7, z - zs * 0.07), Vector3(x + 0.03, 0.78, z - zs * 0.066), Color(0.95, 0.5, 0.1))
		x += 20.0
	# Километровые столбы
	for kx in [-150.0, -50.0, 50.0, 150.0]:
		b.box(Vector3(kx - 0.12, 0, 6.9), Vector3(kx + 0.12, 1.1, 7.1), Color(0.93, 0.93, 0.9))
		b.box(Vector3(kx - 0.13, 0.75, 6.88), Vector3(kx + 0.13, 1.05, 6.9), Color(0.1, 0.1, 0.1))
	# Знаки: ограничение 60 перед селом, пешеходный переход, АЗС, остановка
	_round_sign(b, Vector3(-40.0, 0, -6.6), 0.0, "60")
	_round_sign(b, Vector3(-190.0, 0, 6.6), PI, "60")
	_square_sign(b, Vector3(19.0, 0, 6.2), PI, Color(0.15, 0.35, 0.7), "Пеше-\nходный\nпереход")
	_square_sign(b, Vector3(-135.0, 0, 6.6), PI, Color(0.15, 0.35, 0.7), "АЗС\n200 м")
	# Люки на городских улицах
	for p in [Vector3(97, 0.051, 20), Vector3(97, 0.051, 45), Vector3(60, 0.051, 58), Vector3(120, 0.051, 58), Vector3(160, 0.051, 58)]:
		for k in 4:
			b.box_rot(p, Vector3(0.7, 0.01, 0.29), k * PI / 4.0, Color(0.2, 0.2, 0.2))


## Столбики не ставим на съездах, у АЗС и остановок.
func _post_clear(x: float, z: float) -> bool:
	if x > -64.0 and x < -54.0:
		return false
	if absf(x - STOP_VILLAGE.x) < 4.0 and z < 0.0:
		return false
	if x > -122.0 and x < -76.0 and z > 0.0:
		return false
	if x > 10.0 and z > 0.0:
		return false
	return true


## Круглый знак: белый круг в красном ободе на столбе, число — надписью.
func _round_sign(b: MeshBuilder, p: Vector3, yaw: float, text: String) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	b.xf = xf
	b.box(Vector3(-0.04, 0, -0.04), Vector3(0.04, 2.6, 0.04), Color(0.55, 0.55, 0.57))
	for k in 4:
		var saved := b.xf
		b.xf = xf * Transform3D(Basis(Vector3.BACK, k * PI / 4.0), Vector3(0, 2.2, 0.05))
		b.box(Vector3(-0.35, -0.145, 0), Vector3(0.35, 0.145, 0.02), Color(0.85, 0.12, 0.1))
		b.box(Vector3(-0.27, -0.112, 0.02), Vector3(0.27, 0.112, 0.03), Color(0.95, 0.95, 0.93))
		b.xf = saved
	b.xf = Transform3D.IDENTITY
	_label(text, xf * Vector3(0, 2.2, 0.09), yaw, 0.004, Color(0.05, 0.05, 0.05))


func _square_sign(b: MeshBuilder, p: Vector3, yaw: float, color: Color, text: String) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	b.xf = xf
	b.box(Vector3(-0.04, 0, -0.04), Vector3(0.04, 2.6, 0.04), Color(0.55, 0.55, 0.57))
	b.box(Vector3(-0.4, 1.85, 0.04), Vector3(0.4, 2.65, 0.07), Color(0.95, 0.95, 0.93))
	b.box(Vector3(-0.36, 1.89, 0.07), Vector3(0.36, 2.61, 0.08), color)
	b.xf = Transform3D.IDENTITY
	_label(text, xf * Vector3(0, 2.25, 0.09), yaw, 0.0028, Color(1, 1, 1))


## Двор в городе: припаркованные машины, мусорные баки, фонари вдоль
## улицы, ряд гаражей, берёзы, скамейки и столбы для белья.
func _town_details(b: MeshBuilder, glow: MeshBuilder) -> void:
	var r := _drng
	var colors := [Color(0.7, 0.15, 0.12), Color(0.2, 0.35, 0.6), Color(0.9, 0.9, 0.88), Color(0.25, 0.45, 0.3),
		Color(0.6, 0.6, 0.62), Color(0.85, 0.7, 0.3), Color(0.35, 0.2, 0.3)]
	# Машины вдоль внутриквартальной дороги (z 55–61), у подъездов второго ряда
	for i in 9:
		var x := 52.0 + i * 13.5 + r.randf_range(-2.0, 2.0)
		if absf(x - 97.0) < 5.0:
			continue
		var yaw := PI / 2.0 if r.randf() < 0.5 else -PI / 2.0
		b.xf = Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0, 63.4))
		VehicleModels.zhiguli(b, colors[r.randi() % colors.size()], false)
		for wp in [Vector3(-0.78, 0.29, -1.3), Vector3(0.78, 0.29, -1.3), Vector3(-0.78, 0.29, 1.3), Vector3(0.78, 0.29, 1.3)]:
			var saved := b.xf
			b.xf = saved * Transform3D(Basis.IDENTITY, wp)
			VehicleModels.car_wheel(b, 0.29, 0.2)
			b.xf = saved
		b.add_collider(Vector3(-0.85, 0, -2.1), Vector3(0.85, 1.45, 2.1))
		b.xf = Transform3D.IDENTITY
	# Мусорные контейнеры на площадке
	for i in 3:
		var p := Vector3(44.0 + i * 1.6, 0, 62.5)
		b.box(p + Vector3(-0.7, 0.15, -0.55), p + Vector3(0.7, 1.25, 0.55), Color(0.25, 0.4, 0.3), true)
		b.box(p + Vector3(-0.75, 1.25, -0.6), p + Vector3(0.75, 1.32, 0.6), Color(0.2, 0.32, 0.24))
		for dx in [-0.55, 0.45]:
			b.box(p + Vector3(dx, 0, -0.5), p + Vector3(dx + 0.1, 0.15, -0.4), Color(0.1, 0.1, 0.1))
	b.box(Vector3(42.5, 0, 61.6), Vector3(49.5, 0.06, 63.6), Color(0.55, 0.55, 0.53))
	# Фонари вдоль улицы: бетонная опора и плафон — светится ночью
	var x := 45.0
	while x < 190.0:
		b.box(Vector3(x - 0.1, 0, 53.9), Vector3(x + 0.1, 7.5, 54.1), Color(0.6, 0.6, 0.58), true)
		b.box(Vector3(x - 0.04, 7.3, 54.0), Vector3(x + 0.04, 7.38, 55.6), Color(0.5, 0.5, 0.5))
		b.box(Vector3(x - 0.22, 7.1, 55.4), Vector3(x + 0.22, 7.32, 56.0), Color(0.4, 0.4, 0.42))
		glow.box(Vector3(x - 0.16, 7.04, 55.48), Vector3(x + 0.16, 7.1, 55.92), Color(1.0, 0.85, 0.55))
		x += 22.0
	# Ряд гаражей с воротами и номерами
	for i in 7:
		var gx := 148.0 + i * 5.2
		b.box(Vector3(gx, 0, 17), Vector3(gx + 5.0, 2.6, 23), Color(0.58, 0.56, 0.52), true)
		b.box(Vector3(gx - 0.1, 2.6, 16.6), Vector3(gx + 5.1, 2.72, 23.2), Color(0.35, 0.35, 0.36))
		var door := [Color(0.45, 0.5, 0.55), Color(0.55, 0.35, 0.25), Color(0.3, 0.45, 0.35)][i % 3] as Color
		b.box(Vector3(gx + 0.5, 0.05, 16.95), Vector3(gx + 4.5, 2.25, 17.0), door)
		b.box(Vector3(gx + 2.48, 0.05, 16.93), Vector3(gx + 2.52, 2.25, 16.95), door.darkened(0.4))
		b.box(Vector3(gx + 2.2, 1.1, 16.92), Vector3(gx + 2.35, 1.2, 16.94), Color(0.7, 0.7, 0.7))
	b.box(Vector3(146, 0, 12), Vector3(186, 0.04, 17), Color(0.4, 0.38, 0.35))
	# Берёзы и кусты во дворах, скамейки, столбы для белья
	for p in [Vector3(56, 0, 50), Vector3(84, 0, 51), Vector3(108, 0, 50), Vector3(140, 0, 51), Vector3(150, 0, 49),
			Vector3(58, 0, 86), Vector3(90, 0, 88), Vector3(115, 0, 87), Vector3(145, 0, 86), Vector3(30, 0, 50), Vector3(20, 0, 60)]:
		_tree(b, p, r.randf() * TAU, Vegetation.TreeKind.BIRCH)
	for p in [Vector3(78, 0, 49), Vector3(102, 0, 49), Vector3(132, 0, 49), Vector3(64, 0, 88), Vector3(104, 0, 88)]:
		_tree(b, p, r.randf() * TAU, Vegetation.TreeKind.BUSH)
	for p in [Vector3(88, 0, 50.5), Vector3(118, 0, 50.5)]:
		b.box(p + Vector3(-0.9, 0.42, -0.2), p + Vector3(0.9, 0.47, 0.2), Color(0.5, 0.35, 0.2))
		b.box(p + Vector3(-0.9, 0.47, 0.18), p + Vector3(0.9, 0.85, 0.22), Color(0.5, 0.35, 0.2))
		for dx in [-0.8, 0.7]:
			b.box(p + Vector3(dx, 0, -0.18), p + Vector3(dx + 0.1, 0.42, 0.18), Color(0.3, 0.3, 0.3))
	for px in [150.0, 160.0]:
		b.box(Vector3(px - 0.05, 0, 88.0), Vector3(px + 0.05, 2.2, 88.1), Color(0.4, 0.4, 0.42))
		b.box(Vector3(px - 0.6, 2.1, 88.0), Vector3(px + 0.6, 2.16, 88.1), Color(0.4, 0.4, 0.42))
	b.box(Vector3(149.5, 2.0, 88.03), Vector3(160.5, 2.02, 88.07), Color(0.8, 0.8, 0.8))


# --- У трассы: АЗС, СТО, городская остановка; колхоз у села ------------------

func _build_roadside(b: MeshBuilder) -> void:
	_bus_stop(b, STOP_TOWN, PI, false)
	_fuel_station(b)
	_repair_garage(b)
	_kolkhoz_barn(b)


## АЗС: навес на столбах, две колонки, будка кассира, стела.
func _fuel_station(b: MeshBuilder) -> void:
	var c := FUEL_POS
	var asphalt := Color(0.3, 0.3, 0.31)
	b.box(c + Vector3(-9, 0, -7.5), c + Vector3(9, 0.05, 7), asphalt)
	for x in [-4.5, 4.5]:
		for z in [-3.0, 3.0]:
			b.box(c + Vector3(x - 0.2, 0, z - 0.2), c + Vector3(x + 0.2, 4.6, z + 0.2), Color(0.85, 0.85, 0.85), true)
	b.box(c + Vector3(-6, 4.6, -4.5), c + Vector3(6, 5.2, 4.5), Color(0.9, 0.9, 0.9))
	b.box(c + Vector3(-6.05, 4.7, -4.55), c + Vector3(6.05, 5.1, -4.45), Color(0.15, 0.45, 0.25))
	# Колонки на островке
	b.box(c + Vector3(-3.0, 0, -0.6), c + Vector3(3.0, 0.2, 0.6), Color(0.6, 0.6, 0.58))
	for x in [-1.6, 1.6]:
		b.box(c + Vector3(x - 0.4, 0.2, -0.3), c + Vector3(x + 0.4, 1.8, 0.3), Color(0.9, 0.3, 0.2), true)
		b.box(c + Vector3(x - 0.3, 1.1, -0.31), c + Vector3(x + 0.3, 1.5, -0.3), Color(0.15, 0.2, 0.15))
		b.box(c + Vector3(x + 0.4, 0.9, -0.05), c + Vector3(x + 0.55, 1.2, 0.05), Color(0.1, 0.1, 0.1))
	# Будка кассира
	b.box(c + Vector3(-3, 0, 4.5), c + Vector3(3, 2.8, 7), Color(0.85, 0.82, 0.72), true)
	b.box(c + Vector3(-3.2, 2.8, 4.3), c + Vector3(3.2, 3.0, 7.2), Color(0.35, 0.35, 0.36))
	b.box(c + Vector3(-1.2, 1.0, 4.48), c + Vector3(1.2, 2.2, 4.5), Color(0.25, 0.3, 0.35))
	# Стела с ценой
	var p := c + Vector3(-8, 0, -6.5)
	b.box(p + Vector3(-0.8, 0, -0.2), p + Vector3(0.8, 4.0, 0.2), Color(0.15, 0.45, 0.25), true)
	_label("АЗС\n%d грн/л" % FUEL_PRICE, p + Vector3(0, 3.0, -0.22), PI, 0.006, Color(1, 1, 0.8))
	var zone := InteractZone.create("", Vector3(9.0, 2.4, 6.0))
	zone.position = c + Vector3(0, 0, 0)
	zone.prompt_fn = _fuel_prompt
	zone.activated.connect(_refuel)
	add_child(zone)


## Ближайший к точке транспорт игрока (машина или мотоцикл).
func _car_near(p: Vector3, dist: float) -> Vehicle:
	var best: Vehicle = null
	for v in get_tree().get_nodes_in_group("vehicles"):
		var d: float = (v as Vehicle).global_position.distance_to(p)
		if d < dist:
			dist = d
			best = v
	return best


func _fuel_prompt() -> String:
	var car := _car_near(FUEL_POS, 14.0)
	if car == null:
		return "Заправка: подгони машину или мотоцикл к колонкам"
	var need := int(ceilf(car.tank() - car.fuel))
	if need <= 0:
		return "Бак полный (%d л)" % int(car.fuel)
	return "E — заправить %d л за %d грн (в баке %d л)" % [need, need * FUEL_PRICE, int(car.fuel)]


func _refuel() -> void:
	var car := _car_near(FUEL_POS, 14.0)
	if car == null:
		GameManager.notify("У колонок нет ни машины, ни мотоцикла")
		return
	var need := car.tank() - car.fuel
	var liters := minf(need, floorf(GameManager.money / float(FUEL_PRICE)))
	if liters < 1.0:
		GameManager.notify("Бак полный" if need < 1.0 else "Не хватает денег даже на литр")
		return
	GameManager.spend(int(ceilf(liters)) * FUEL_PRICE)
	car.refuel(liters)
	QuestManager.event("refuel")
	GameManager.notify("Заправил %d л. В баке %d л" % [int(liters), int(car.fuel)])


## СТО: гараж с открытыми воротами, покрышки, вывеска.
func _repair_garage(b: MeshBuilder) -> void:
	var c := GARAGE_POS
	var wall := Color(0.62, 0.62, 0.6)
	b.box(c + Vector3(-7, 0, -5.5), c + Vector3(7, 0.05, 6), Color(0.35, 0.35, 0.34))
	# Стены: зад и бока, спереди — широкие ворота
	b.box(c + Vector3(-5, 0, 5.5), c + Vector3(5, 4, 6), wall, true)
	b.box(c + Vector3(-5, 0, -1), c + Vector3(-4.6, 4, 6), wall, true)
	b.box(c + Vector3(4.6, 0, -1), c + Vector3(5, 4, 6), wall, true)
	b.box(c + Vector3(-5, 3.0, -1), c + Vector3(5, 4, -0.6), wall, true)
	b.box(c + Vector3(-5.3, 4, -1.3), c + Vector3(5.3, 4.25, 6.3), Color(0.4, 0.4, 0.42))
	b.box(c + Vector3(-4.5, 0.05, 1.5), c + Vector3(-3.5, 0.08, 4.5), Color(0.15, 0.15, 0.15))
	# Покрышки стопкой
	for i in 4:
		b.box(c + Vector3(5.4, i * 0.25, -0.6), c + Vector3(6.2, i * 0.25 + 0.24, 0.2), Color(0.1, 0.1, 0.1))
	b.box(c + Vector3(-3, 3.1, -1.05), c + Vector3(3, 3.9, -1.0), Color(0.2, 0.3, 0.6))
	_label("СТО", c + Vector3(0, 3.5, -1.07), PI, 0.006, Color(1, 1, 1))
	var zone := InteractZone.create("", Vector3(9.0, 2.4, 8.0))
	zone.position = c + Vector3(0, 0, 1.0)
	zone.prompt_fn = _repair_prompt
	zone.activated.connect(_repair)
	add_child(zone)


func _repair_cost(car: Vehicle) -> int:
	return int(ceilf((100.0 - car.condition) * 25.0))


func _repair_prompt() -> String:
	var car := _car_near(GARAGE_POS, 14.0)
	if car == null:
		return "СТО: загони машину или мотоцикл в гараж"
	if car.condition >= 99.5:
		return "Механик: «%s в порядке — %d%%»" % [car.spec.title, int(car.condition)]
	return "E — починить: %s (%d%%) за %d грн, 1 час" % [car.spec.title, int(car.condition), _repair_cost(car)]


func _repair() -> void:
	var car := _car_near(GARAGE_POS, 14.0)
	if car == null or car.condition >= 99.5:
		return
	if not GameManager.spend(_repair_cost(car)):
		return
	SoundLibrary.play("hammer")
	TimeManager.advance(60.0)
	car.repair()
	GameManager.notify("Механик перебрал машину: 100%%. %s" % TimeManager.clock_text())


## Колхозный сарай у стогов: здесь можно подработать на сене.
func _kolkhoz_barn(b: MeshBuilder) -> void:
	var c := BARN_POS
	var wood := Color(0.45, 0.32, 0.22)
	b.box(c + Vector3(-6, 0, -4), c + Vector3(6, 4, 4), wood, true)
	# Вертикальные доски
	var x := -6.0
	while x < 6.0:
		b.box(c + Vector3(x, 0, 4.0), c + Vector3(x + 0.05, 4, 4.03), wood.darkened(0.25))
		x += 0.6
	for sx in [-1.0, 1.0]:
		b.tri(c + Vector3(sx * 6, 4, -4), c + Vector3(sx * 6, 4, 4), c + Vector3(sx * 6, 6, 0), wood, true)
	var slate := Color(0.38, 0.4, 0.4)
	b.quad(c + Vector3(-6.4, 3.8, 4.4), c + Vector3(6.4, 3.8, 4.4), c + Vector3(6.4, 6.1, 0), c + Vector3(-6.4, 6.1, 0), slate, true)
	b.quad(c + Vector3(6.4, 3.8, -4.4), c + Vector3(-6.4, 3.8, -4.4), c + Vector3(-6.4, 6.1, 0), c + Vector3(6.4, 6.1, 0), slate, true)
	# Ворота и тюки сена у входа
	b.box(c + Vector3(-1.8, 0, 4.03), c + Vector3(1.8, 3.2, 4.08), Color(0.3, 0.2, 0.14))
	for i in 5:
		b.box(c + Vector3(2.5 + (i % 3) * 1.1, (i / 3) * 0.5, 4.6), c + Vector3(3.5 + (i % 3) * 1.1, 0.5 + (i / 3) * 0.5, 5.4), Color(0.75, 0.65, 0.35), true)
	# Тропинка от съезда
	b.box(Vector3(-57.0, 0, -42.2), Vector3(c.x - 1.0, 0.03, -40.8), Color(0.46, 0.39, 0.28))
	b.box(c + Vector3(-2.6, 3.28, 4.03), c + Vector3(2.6, 3.72, 4.08), Color(0.75, 0.2, 0.15))
	_label("КОЛХОЗ «ЗАРЯ»", c + Vector3(0, 3.5, 4.1), 0.0, 0.004, Color(1, 0.95, 0.8))
	var zone := InteractZone.create("E — колхоз: грузить сено, 3 часа, +400 грн", Vector3(6.0, 2.2, 3.0))
	zone.position = c + Vector3(0, 0, 5.5)
	zone.activated.connect(_kolkhoz_work)
	add_child(zone)


func _kolkhoz_work() -> void:
	var h := TimeManager.hour()
	if h < 7.0 or h > 19.0:
		GameManager.notify("Бригадир ушёл домой. Работа в колхозе с 7:00 до 19:00")
		return
	if NeedsManager.energy < 25.0:
		GameManager.notify("Сил нет вилы держать. Выспись")
		return
	if WeatherManager.kind == WeatherManager.Kind.RAIN:
		GameManager.notify("Сено в дождь не грузят — приходи, как распогодится")
		return
	TimeManager.advance(180.0)
	NeedsManager.rest(-18.0)
	GameManager.add_money(400)
	SoundLibrary.play("cash")
	GameManager.notify("Отработал в колхозе: +400 грн. %s" % TimeManager.clock_text())
	QuestManager.event("kolkhoz")


## Развоз: хлеб грузится на складе, сдаётся у сельмага — только на машине.
func _check_delivery() -> void:
	if not Progress.delivery_active:
		return
	var car := GameManager.car as Vehicle
	if car == null:
		return
	# Тряска: по грунту быстрее 40 км/ч и по траве быстрее 25 — буханки мнутся
	var kmh := car.speed_kmh()
	if not car.on_asphalt():
		var limit := 40.0 if car.surface().roll < 3.0 else 25.0
		if kmh > limit:
			Progress.damage_bread((kmh - limit) * 0.02 * get_process_delta_time())
	if car.driver and car.global_position.distance_to(SHOP_POS + Vector3(-6.0, 0, 0)) < 9.0 and kmh < 5.0:
		Progress.finish_delivery()


func _label(text: String, pos: Vector3, yaw: float, px: float, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = px
	l.outline_size = 0
	l.modulate = color
	l.position = pos
	l.rotation.y = yaw
	add_child(l)
	return l


# --- Ларёк и склад: где тратить и где зарабатывать ---------------------------

func _build_shops(b: MeshBuilder) -> void:
	# Ларёк «Продукты» у перехода
	var k := Vector3(25, 0, 9)
	b.box(k + Vector3(-1.8, 0, 0), k + Vector3(1.8, 2.6, 2.8), Color(0.25, 0.45, 0.7), true)
	b.box(k + Vector3(-2.0, 2.6, -0.4), k + Vector3(2.0, 2.75, 3.0), Color(0.9, 0.9, 0.9))
	b.box(k + Vector3(-1.2, 1.0, -0.02), k + Vector3(1.2, 2.0, 0.0), Color(0.85, 0.9, 0.95))
	b.box(k + Vector3(-1.3, 0.9, -0.25), k + Vector3(1.3, 0.97, 0.0), Color(0.7, 0.7, 0.7))
	b.box(k + Vector3(-1.5, 2.2, -0.05), k + Vector3(1.5, 2.55, -0.02), Color(0.85, 0.2, 0.15))
	var kiosk := InteractZone.create("", Vector3(3.0, 2.0, 2.2))
	kiosk.position = k + Vector3(0, 0, -1.2)
	kiosk.prompt_fn = func() -> String:
		if _wants_medicine():
			return "E — купить лекарство для тёти Люды (60 грн)"
		return "E — купить батон и кефир (45 грн)"
	kiosk.activated.connect(_kiosk_use)
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
	var bread := InteractZone.create("", Vector3(4.0, 2.0, 3.0))
	bread.position = s + Vector3(-7.5, 0, -8.5)
	bread.prompt_fn = func() -> String:
		if Progress.delivery_active:
			return "Хлеб в машине — вези в сельмаг «Каменка»"
		return "E — развоз: хлеб в сельмаг на машине, +%d грн" % Progress.DELIVERY_PAY
	bread.activated.connect(_take_delivery)
	add_child(bread)


func _take_delivery() -> void:
	var car := GameManager.car as Vehicle
	if car == null or car.global_position.distance_to(Vector3(27.5, 0, 28.0)) > 25.0:
		GameManager.notify("Подгони машину к складу — хлеб грузят в багажник")
		return
	Progress.start_delivery()


func _wants_medicine() -> bool:
	var q: Dictionary = QuestManager.quests["s_lyuda"]
	return q.state == 1 and q.step == 0


func _kiosk_use() -> void:
	if _wants_medicine():
		if GameManager.spend(60):
			QuestManager.give_item("medicine")
			QuestManager.event("medicine")
			GameManager.notify("Купил лекарство. Отвези тёте Люде на остановку у Каменки")
		return
	_buy_food()


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
	QuestManager.event("shift")


## Обморок от голода или усталости: просыпаешься дома через 8 часов,
## соседи тратились на лекарства — минус до 150 грн.
func _faint(reason: String) -> void:
	var p := GameManager.player as Player
	var v := GameManager.vehicle as Vehicle
	if v:
		v.speed = 0.0
		v.lateral = 0.0
		v.velocity = Vector3.ZERO
		v.engine_on = false
		v._drop_driver()
	# Там же, где игрок просыпается в начале игры — у входа на кухне
	var bed := Vector3(PLAYER_HOUSE.x - 1.6, HOUSE_Y + 0.1, PLAYER_HOUSE.y + 2.0)
	if p:
		p.global_position = bed
		p.velocity = Vector3.ZERO
	TimeManager.advance(8.0 * 60.0)
	NeedsManager.rest(70.0)
	NeedsManager.food = maxf(NeedsManager.food, 30.0)
	var loss := mini(GameManager.money, 150)
	GameManager.money -= loss
	GameManager.money_changed.emit(GameManager.money)
	QuestManager.stats.fainted += 1
	SoundLibrary.play("land", 0.0, 0.6)
	GameManager.notify("%s Очнулся дома — соседи дотащили. На лекарства ушло %d грн" % [reason, loss])


func _sleep() -> void:
	if NeedsManager.energy > 80.0:
		GameManager.notify("Спать пока не хочется")
		return
	TimeManager.skip_to(7.0)
	NeedsManager.rest(100.0)
	# Автосохранение: утро после сна — надёжная точка
	SaveManager.save_game()
	GameManager.notify("Выспался. %s. Игра сохранена" % TimeManager.clock_text())


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


## kind: 0 — ель, 1 — яблоня, 2 — берёза, 3 — куст (Vegetation.TreeKind).
## Сама модель — в vegetation.gd (MultiMesh), здесь — тень, ствол-коллизия
## и регистрация места.
func _tree(b: MeshBuilder, p: Vector3, yaw: float, kind: int) -> void:
	var s := _rng.randf_range(0.85, 1.25)
	var saved := b.xf
	b.xf = b.xf * Transform3D(Basis(Vector3.UP, yaw), p)
	var shade := 1.0 if kind != Vegetation.TreeKind.BUSH else 0.6
	b.box(Vector3(-1.4, 0, -1.4) * s * shade, Vector3(1.4, 0.015, 1.4) * s * shade, Color(0.2, 0.3, 0.14))
	if kind != Vegetation.TreeKind.BUSH:
		b.add_collider(Vector3(-0.16, 0, -0.16) * s, Vector3(0.16, 3.0, 0.16) * s)
	if not _veg.is_inside_tree():
		_veg.add_tree(kind, b.xf * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3.ZERO))
	b.xf = saved


## Где травы нет: дороги, дворы у домов, площадки, город, пруд.
func _block_grass() -> void:
	var v := _veg
	v.block(-200, -6, 200, 6)
	v.block(-166, -43, -56, -37)
	v.block(-63, -43, -56, -5)
	for x in VILLAGE_X:
		for z in [ROW_A_Z, ROW_B_Z]:
			v.block(x - 5, z - 4.2, x + 5, z + 4.2)
	# Город: дороги, тротуар, дома, склад, площадка, гаражи; во дворах — трава
	v.block(10, 4, 200, 7.6)
	v.block(93.5, 4, 100.5, 100)
	v.block(40, 54.5, 190, 61.5)
	for c in [Vector2(70, 41), Vector2(125, 41), Vector2(70, 74), Vector2(125, 74)]:
		v.block(c.x - 22, c.y - 8.5, c.x + 22, c.y + 8.5)
	v.block(163, 52, 180, 98)
	v.block(14, 26, 41, 45)
	v.block(22, 8, 29, 13)
	v.block(59, 49, 74, 55)
	v.block(146, 16, 186, 29)
	v.block(STOP_VILLAGE.x - 3, STOP_VILLAGE.z - 1.5, STOP_VILLAGE.x + 3, STOP_VILLAGE.z + 1.5)
	v.block(FUEL_POS.x - 9, FUEL_POS.z - 7.5, FUEL_POS.x + 9, FUEL_POS.z + 7.5)
	v.block(GARAGE_POS.x - 7, GARAGE_POS.z - 5.5, GARAGE_POS.x + 7, GARAGE_POS.z + 6.5)
	v.block(SHOP_POS.x - 5, SHOP_POS.z - 5, SHOP_POS.x + 3.5, SHOP_POS.z + 5)
	v.block(-57, -25, SHOP_POS.x - 4, -23)
	v.block(BARN_POS.x - 6.5, BARN_POS.z - 4.5, BARN_POS.x + 6.5, BARN_POS.z + 6)
	v.block(-57, -42.2, BARN_POS.x, -40.8)
	v.block(POND_POS.x - 13, POND_POS.z - 10, POND_POS.x + 13, POND_POS.z + 10)
	v.block(POND_POS.x + 9, -40.6, -164, -39.4)
	# Огороды за домами
	for x in VILLAGE_X:
		v.block(x - 10.5, ROW_A_Z - 14, x + 10.5, ROW_A_Z - 9.5)
		v.block(x - 10.5, ROW_B_Z + 9.5, x + 10.5, ROW_B_Z + 14)


# --- Игрок и машина ---------------------------------------------------------

func _spawn_player_and_car() -> void:
	var player := Player.new()
	player.name = "Player"
	add_child(player)
	# На дорожке у калитки, лицом к улице: первым делом видно деревню
	# и свои «Жигули» — хочется сразу пойти и посмотреть
	player.global_position = Vector3(PLAYER_HOUSE.x + _home_door_x, 0.05, PLAYER_HOUSE.y + 10.0)
	var to_car := Vector3(PLAYER_HOUSE.x + 4.0, 0, -39.5) - player.global_position
	player.rotation.y = atan2(-to_car.x, -to_car.z)
	var car := Vehicle.new()
	car.kind = "car"
	car.name = "Car"
	add_child(car)
	GameManager.car = car
	# Жигули на улице перед домом, носом вдоль улицы
	car.global_position = Vector3(PLAYER_HOUSE.x + 4.0, 0.1, -39.5)
	car.rotation.y = -PI / 2.0
	# Ява у забора через дорогу от калитки
	var moto := Vehicle.new()
	moto.kind = "moto"
	moto.name = "Moto"
	add_child(moto)
	GameManager.moto = moto
	moto.global_position = Vector3(PLAYER_HOUSE.x - 5.0, 0.1, -41.6)
	moto.rotation.y = -PI / 2.0
