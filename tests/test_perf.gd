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
	# Экран 60 Гц (так в тестах): 120 он не покажет — синхронизация, цель 60
	ok(SM.screen_hz() < 119.0 and SM._vsync_on() and Engine.max_fps == 0 and is_equal_approx(SM.fps_target(), SM.screen_hz()),
		"120 на экране %d Гц: синхронизация, цель %d — «Держать FPS» не портит картинку зря" % [int(SM.screen_hz()), int(SM.fps_target())])
	ok(not SM._vsync_on() or SM.screen_hz() < 121.0, "на экране 144 Гц было бы без синхронизации с потолком 120")
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
	var d0: int = SM.detail
	for i in 3:
		SM._perf_slow = 0.0
		for k in 60: SM._keep_fps(SM.fps_target() * 0.5, 0.1)
	await frames(2)
	ok(SM._perf_step == 3, "кадров мало — три шага вниз")
	ok(vp.msaa_3d == Viewport.MSAA_DISABLED and is_equal_approx(vp.scaling_3d_scale, 0.85) and SM.eff_detail() == maxi(d0 - 1, 0), "сглаживание выкл, чёткость 85 %, детализация ниже")
	for i in 10:
		SM._perf_slow = 0.0
		for k in 60: SM._keep_fps(SM.fps_target() * 0.3, 0.1)
	await frames(2)
	ok(SM._perf_step == SM.PERF_LADDER.size() and is_equal_approx(vp.scaling_3d_scale, 0.5) and SM.eff_detail() == maxi(d0 - 2, 0), "совсем мало — до низкой детализации и чёткости 50 %")
	var cfg := ConfigFile.new()
	cfg.load(SM.PATH)
	ok(int(cfg.get_value("graphics", "perf_step", 0)) == SM.PERF_LADDER.size(), "шаг запомнен до следующего запуска")
	ok(SM.aa == 1 and SM.scale_i == 0, "свои настройки не тронуты")
	SM.set_auto_perf(true)
	await frames(2)
	ok(vp.msaa_3d == Viewport.MSAA_2X and is_equal_approx(vp.scaling_3d_scale, 1.0), "вернул в настройках — снова полное качество")
	SM._perf_slow = 0.0
	for k in 60: SM._keep_fps(SM.fps_target() * 0.95, 0.1)
	ok(SM._perf_step == 0, "кадров хватает — ничего не трогает")
	print("== Запас кадров — качество обратно")
	SM._perf_step = 3
	SM._ceiling = 0
	SM._good = 0.0
	for k in 220: SM._try_better(SM.fps_target(), 0.1)
	ok(SM._perf_step == 2, "20 секунд с запасом — шаг вверх")
	SM._perf_slow = 0.0
	for k in 60: SM._keep_fps(SM.fps_target() * 0.5, 0.1)
	ok(SM._perf_step == 3 and SM._ceiling == 3, "снова не хватило — назад, выше не лезет")
	SM._good = 0.0
	for k in 300: SM._try_better(SM.fps_target(), 0.1)
	ok(SM._perf_step == 3, "второй раз не пробует")
	SM._ceiling = 0
	SM.set_auto_perf(true)
	print("== Под видеокарту")
	ok(SM.hardware_preset("NVIDIA GeForce RTX 3060", 12) == 0, "мощная видеокарта — полное качество")
	ok(SM.hardware_preset("Intel(R) UHD Graphics 620", 8) == 3, "встроенная Intel — сразу три шага вниз")
	ok(SM.hardware_preset("AMD Radeon(TM) Graphics", 4) == 4, "встроенная AMD и 4 ядра — четыре шага")
	ok(SM.hardware_preset("llvmpipe (LLVM 15.0.7, 256 bits)", 8) == 5, "программная — пять шагов")
	SM._auto = false
	print("== Люди вдали")
	var d_keep: int = SM.detail
	SM._perf_step = 0
	SM.set_detail(0)
	var far := 0
	var people := 0
	for p in W.get_tree().get_nodes_in_group("people"):
		var gi := p as GeometryInstance3D
		if gi and gi.visibility_range_end > 0.0:
			people += 1
			if gi.visibility_range_end > 90.5: far += 1
	ok(people > 50 and far == 0, "низкая детализация: людей видно не дальше 90 м (%d человек)" % people)
	SM.set_detail(d_keep)
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
	print("== Память")
	var reg = W.get_node("Region")
	ok(reg._d.triangle_count() == 0 and reg._d._chunks.is_empty(), "заготовки округи освобождены после постройки")
	var mem: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	ok(mem < 600.0, "память игры: %.0f МБ (было ~950 — iPhone не тянул)" % mem)
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
