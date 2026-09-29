extends SceneTree
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func pf(n: int) -> void:
	for i in n: await process_frame
func hold(k: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k; e.keycode = k; e.pressed = down
	Input.parse_input_event(e)
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await pf(5)
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress"); var SM = root.get_node("SaveManager")
	var menu = child("pause_menu.gd")
	var P = W.get_node("Player"); var C = W.get_node("Car")
	print("== Обучение")
	var tut = child("tutorial.gd")
	ok(tut != null and tut._step == 0 and tut._text.text.contains("мышью"), "новая игра — обучение: " + (tut._text.text if tut else "нет"))
	P._look(1.0, 0.0)
	await pf(3)
	ok(tut._step == 1 and tut._text.text.contains("Жигулям"), "осмотрелся → иди к машине")
	P.global_position = C.global_position + Vector3(0, 0.2, 2.5)
	await frames(5)
	ok(tut._step == 2, "дошёл до машины → садись")
	C._on_enter()
	await pf(3)
	ok(tut._step == 3 and tut._text.text.contains("газ"), "сел → поехали: " + tut._text.text)
	C.fuel = 30.0
	hold(KEY_W, true)
	for i in 300:
		await physics_frame
		if tut._step == 4: break
	hold(KEY_W, false)
	ok(tut._step == 4, "разогнался %d км/ч → тормози" % int(C.speed_kmh()))
	hold(KEY_S, true)
	for i in 300:
		await physics_frame
		if tut._step == 5: break
	hold(KEY_S, false)
	ok(tut._step == 5 and tut._title.text.contains("Готово"), "остановился → готово")
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(tut) and Time.get_ticks_msec() - t0 < 10000:
		await process_frame
	ok(not is_instance_valid(tut) and PR.tutorial_done, "обучение закончилось и запомнилось")
	C.exit_car(); await frames(3)
	# «Пропустить»
	PR.tutorial_done = false
	var t2 = load("res://scripts/ui/tutorial.gd").new()
	W.add_child(t2)
	await pf(2)
	t2._skip.pressed.emit()
	await pf(2)
	ok(not is_instance_valid(t2) and PR.tutorial_done, "«Пропустить» — обучение сразу закрыто")

	print("== Автосохранение")
	ok(GM.in_game, "игра идёт")
	ok(not SM.has_save(), "сохранения нет")
	SM._since_save = SM.AUTOSAVE_EVERY - 0.05
	await pf(10)
	ok(SM.has_save() and SM._since_save < 1.0, "через %d с игры — тихое автосохранение" % int(SM.AUTOSAVE_EVERY))
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://save.json"))
	ok(saved.Progress.tutorial == true, "в сохранении отмечено, что обучение пройдено")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	paused = true
	SM._since_save = SM.AUTOSAVE_EVERY + 5.0
	await pf(5)
	ok(not SM.has_save(), "на паузе автосохранение не идёт")
	paused = false
	SM._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(SM.has_save(), "свернули игру — сразу сохранилась")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	GM.in_game = false
	SM._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(not SM.has_save() and not SM.autosave(), "в главном меню при запуске не сохраняет — не затрёт старую игру")
	GM.in_game = true

	print("== Пауза при сворачивании")
	ok(not menu.is_open() and not paused, "играем")
	menu._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(menu.is_open() and paused and menu._title.text == "Пауза", "свернули — пауза, время стоит")
	var m0: float = root.get_node("TimeManager").minutes
	await frames(60)
	ok(root.get_node("TimeManager").minutes == m0, "на паузе время не идёт")
	menu._close()
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
