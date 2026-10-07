extends SceneTree
## Производительность: потолок кадров (вертикальная синхронизация, 60/120/144,
## без ограничения), сглаживание и чёткость 3D из настроек, «Держать FPS»
## (по шагам, только на этот запуск), интерфейс не пересчитывает строки
## каждый кадр, материалы мира и свет машин не перезаливаются зря.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await frames(10)
	var SM = root.get_node("SettingsManager"); var GM = root.get_node("GameManager")
	var vp := root.get_viewport()
	print("== Потолок кадров")
	ok(SM.FPS_LIMITS[2] == 120, "на компьютере по умолчанию — 120 FPS")
	SM.set_fps_limit(2)
	ok(Engine.max_fps == 120, "120: потолок %d" % Engine.max_fps)
	SM.set_fps_limit(4)
	ok(Engine.max_fps == 0, "без ограничения")
	SM.set_fps_limit(0)
	ok(Engine.max_fps == 0 and SM.fps_target() > 0.0, "как экран: синхронизация, цель %d" % int(SM.fps_target()))
	SM.set_fps_limit(2)
	print("== Сглаживание и чёткость")
	SM.set_detail(2)
	SM.set_aa(2)
	await frames(2)
	ok(vp.msaa_3d == Viewport.MSAA_4X, "сглаживание 4x")
	SM.set_aa(0)
	await frames(2)
	ok(vp.msaa_3d == Viewport.MSAA_DISABLED, "сглаживание выкл")
	SM.set_aa(1)
	SM.set_scale(1)
	await frames(2)
	ok(is_equal_approx(vp.scaling_3d_scale, 0.85), "чёткость 3D 85 %%: %.2f" % vp.scaling_3d_scale)
	SM.set_scale(0)
	await frames(2)
	ok(is_equal_approx(vp.scaling_3d_scale, 1.0) and vp.msaa_3d == Viewport.MSAA_2X, "по умолчанию — 100 % и 2x")
	print("== Держать FPS")
	GM.in_game = true
	SM._auto = true
	SM.set_auto_perf(true)
	for i in 3:
		SM._perf_slow = 0.0
		for k in 60: SM._keep_fps(SM.fps_target() * 0.5, 0.1)
	await frames(2)
	ok(SM._perf_step == 3, "кадров мало — три шага вниз")
	ok(vp.msaa_3d == Viewport.MSAA_DISABLED and is_equal_approx(vp.scaling_3d_scale, 0.75), "сглаживание выкл, чёткость 75 %")
	ok(SM.aa == 1 and SM.scale_i == 0, "настройки не тронуты — только на этот запуск")
	SM.set_auto_perf(true)
	await frames(2)
	ok(vp.msaa_3d == Viewport.MSAA_2X and is_equal_approx(vp.scaling_3d_scale, 1.0), "вернул в настройках — снова полное качество")
	SM._perf_slow = 0.0
	for k in 60: SM._keep_fps(SM.fps_target() * 0.95, 0.1)
	ok(SM._perf_step == 0, "кадров хватает — ничего не трогает")
	SM._auto = false
	print("== Без лишней работы каждый кадр")
	MeshBuilder.set_clouds(0.5)
	var m: ShaderMaterial = MeshBuilder.world_material()
	m.set_shader_parameter("clouds", 0.123)
	MeshBuilder.set_clouds(0.5)
	ok(is_equal_approx(float(m.get_shader_parameter("clouds")), 0.123), "те же тени облаков — материал не трогаем")
	MeshBuilder.set_clouds(0.7)
	ok(is_equal_approx(float(m.get_shader_parameter("clouds")), 0.7), "новые — задаём")
	var car: Vehicle = W.get_node("Car")
	car._update_lights()
	var key: int = car._lights_key
	car._brake_mat.albedo_color = Color(0, 1, 0)
	car._update_lights()
	ok(car._brake_mat.albedo_color == Color(0, 1, 0), "свет машины не менялся — материал не трогаем")
	car.light_mode = Vehicle.Light.PARKING
	car._update_lights()
	ok(car._lights_key != key and car._brake_mat.albedo_color.r > 0.5 and car._brake_mat.albedo_color.g < 0.5, "включил габариты — фонари обновились")
	var hud = W.find_children("*", "CanvasLayer", true, false).filter(func(n): return n.get_script() and n.get_script().resource_path.ends_with("hud.gd"))[0]
	await frames(3)
	var t0: String = hud._top.text
	hud._tick = 1.0
	GM.add_money(777)
	ok(hud._tick <= 0.0, "деньги изменились — строка обновится в этот же кадр")
	await frames(2)
	ok(hud._top.text != t0, "строка сверху обновилась: " + hud._top.text)
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
