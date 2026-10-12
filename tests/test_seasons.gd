extends SceneTree
var fails := 0
var W
var held := {}
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func key(k: int, down: bool) -> void:
	if bool(held.get(k, false)) == down: return
	held[k] = down
	var e := InputEventKey.new()
	e.physical_keycode = k; e.keycode = k; e.pressed = down
	Input.parse_input_event(e)
func last() -> String:
	return root.get_node("GameManager").get_meta("last", "")
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress"); var TM = root.get_node("TimeManager")
	var WM = root.get_node("WeatherManager"); var NM = root.get_node("NeedsManager")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	var sl = child("street_life.gd"); if sl: sl.set_physics_process(false)
	WM.set_kind(0, 9999.0)
	var P = W.get_node("Player"); var C = W.get_node("Car")
	var mat: ShaderMaterial = MeshBuilder.world_material()

	print("== Времена года")
	TM.day = 1
	ok(WM.season_text() == "лето" and WM.name_text() == "ясно, лето", "день 1 — лето: " + WM.name_text())
	TM.day = 8
	WM._on_minutes(1500.0)
	ok(WM.season_text() == "осень" and WM.autumn > 0.9 and float(mat.get_shader_parameter("autumn")) > 0.9, "день 8 — осень, листва желтеет: %.2f" % WM.autumn)
	TM.day = 15
	WM._on_minutes(700.0)
	ok(WM.season_text() == "зима" and WM.snow >= 0.99 and float(mat.get_shader_parameter("snow")) >= 0.99, "день 15 — зима, снег лёг: %.2f" % WM.snow)
	ok(Vegetation.grass_material != null and float(Vegetation.grass_material.get_shader_parameter("snow")) > 0.9, "трава под снегом")
	var g_winter: float = C.surface().grip
	WM.set_kind(3, 9999.0)
	ok(WM.snowing() and WM.name_text().begins_with("снег"), "зимой вместо дождя — снег: " + WM.name_text())
	WM._on_minutes(30.0)
	ok(WM.wetness < 0.01, "зимой грязь не раскисает")
	WM.set_kind(0, 9999.0)
	TM.day = 22
	WM._on_minutes(1500.0)
	ok(WM.season_text() == "весна" and WM.snow < 0.01, "день 22 — весна, снег сошёл")
	var g_spring: float = C.surface().grip
	ok(g_winter < g_spring * 0.8, "зимой шины держат хуже: %.2f против %.2f" % [g_winter, g_spring])
	TM.day = 29
	WM._on_minutes(1500.0)
	ok(WM.season_text() == "лето" and WM.autumn < 0.01 and WM.spring < 0.01, "день 29 — снова лето")

	print("== Небо и туман")
	var sky = null
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("night_sky.gd"): sky = c
	TM.minutes = 23 * 60.0
	await process_frame; await process_frame
	ok(sky._stars.visible and sky._moon.visible, "ночью звёзды и луна")
	TM.minutes = 12 * 60.0
	await process_frame; await process_frame
	ok(not sky._stars.visible, "днём звёзд нет")
	TM.minutes = 6.2 * 60.0
	W._update_daylight()
	var fog_morning: float = W._env.fog_density
	TM.minutes = 12 * 60.0
	W._update_daylight()
	ok(fog_morning > W._env.fog_density * 2.0, "утром дымка: %.4f, днём %.4f" % [fog_morning, W._env.fog_density])

	print("== Приборы и звук дороги")
	ok(C._needles.size() == 2 and W.get_node("Moto")._dash_vp != null, "в Жигулях спидометр и тахометр, у «Явы» — живой щиток на руле")
	C.global_position = Vector3(2, 0.1, -100); C.rotation.y = -PI / 2.0
	C._on_enter(); C.fuel = 30.0
	await frames(3)
	var r0: float = C._needles[0].rotation.z
	key(KEY_W, true)
	await frames(150)
	var sp: float = C.speed_kmh()
	await process_frame
	ok(C._needles[0].rotation.z < r0 - 0.3, "стрелка спидометра пошла: %d км/ч" % int(sp))
	ok(C._road_snd.playing and C._road_snd.stream == root.get_node("SoundLibrary").stream("grass"), "по пашне — шорох травы")
	key(KEY_W, false)
	C.global_position = Vector3(-150, 0.1, 2.0); C.speed = 0.0; C.velocity = Vector3.ZERO
	await frames(10)
	ok(not C._road_snd.playing, "на асфальте — тихо")
	C.exit_car()
	await frames(3)

	print("== Трактор и пахота")
	var job = child("tractor_job.gd")
	var T: Vehicle = job.tractor
	ok(T != null and T.kind == "tractor" and T.owned() and T._needles.size() == 2, "у колхоза трактор МТ-80 с приборами")
	TM.minutes = 10 * 60.0
	ok(job._prompt().contains("наряд"), "щит: " + job._prompt())
	job._take_order()
	ok(job.challenge.active(), "наряд взят — старт на поле")
	C._on_enter()
	C.global_position = job.challenge.start_pos + Vector3(0, 0.1, 0)
	await frames(5)
	ok(job.challenge.state == 1, "на Жигулях пахать нельзя — ждёт трактор")
	C.exit_car(); C.global_position = Vector3(-150, 0.1, 30.0)
	await frames(3)
	# Разгон трактора по пашне
	T.global_position = Vector3(60, 0.1, -50); T.rotation.y = -PI / 2.0
	T._on_enter(); T.fuel = 60.0
	await frames(3)
	key(KEY_W, true)
	await frames(600)
	key(KEY_W, false)
	var tv: float = T.speed_kmh()
	ok(tv > 20.0 and tv < 42.0, "трактор по пашне: %d км/ч за 10 с" % int(tv))
	T.speed = 0.0; T.velocity = Vector3.ZERO
	GM.money = 0
	T.global_position = job.challenge.start_pos + Vector3(0, 0.1, 0)
	await frames(5)
	ok(job.challenge.state == 2, "трактор на старте — пошёл отсчёт")
	for p in job.challenge.points:
		T.global_position = p + Vector3(0, 0.1, 0)
		await frames(4)
	await frames(3)
	ok(not job.challenge.active() and GM.money >= job.PAY and job._strips.get_child_count() == 6, "6 борозд — поле вспахано: +%d грн" % GM.money)
	ok(job._prompt().contains("выполнен"), "второй раз в день — нет: " + job._prompt())
	T.exit_car()
	await frames(3)

	print("== Полив огорода")
	GM.money = 1000
	TM.minutes = 9 * 60.0
	PR.planted = false
	PR.use_garden()
	ok(PR.planted and PR.garden_prompt().contains("полить"), "посадил, можно полить: " + PR.garden_prompt())
	PR.use_garden()
	ok(PR.watered_days == 1 and PR.garden_prompt().contains("полита"), "полил: " + PR.garden_prompt())
	PR.use_garden()
	ok(PR.watered_days == 1, "второй раз за день не польёшь")
	TM.day += 1
	PR.use_garden()
	ok(PR.watered_days == 2 and PR.harvest_size() == 8, "на другой день снова: урожай %d" % PR.harvest_size())
	PR.planted_at -= PR.grow_time() + 10.0
	var sn: int = NM.snacks
	PR.use_garden()
	ok(NM.snacks == sn + 8 and last().contains("полив"), "выкопал 8 вместо 6: " + last())
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
