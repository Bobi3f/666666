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
func key(k: int) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k; e.keycode = k; e.pressed = down
		Input.parse_input_event(e)
		await pf(2)
func jaxis(axis: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0; e.axis = axis; e.axis_value = v
	Input.parse_input_event(e)
func jbtn(b: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0; e.button_index = b; e.pressed = down
	Input.parse_input_event(e)
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await pf(5)
	var menu = child("pause_menu.gd")
	var GM = root.get_node("GameManager")
	print("== Меню")
	ok(menu.is_open() and menu._title.text == "FIRST GEAR" and menu._page == "main", "главное меню при запуске")
	await pf(3)
	var f = root.gui_get_focus_owner()
	ok(f is Button and f.text == "Начать", "фокус на «Начать» — можно играть с клавиатуры и геймпада: %s" % (f.text if f else "нет"))
	menu._close()
	# Права и «Жигули» — как у игрока, прошедшего автошколу
	root.get_node("Progress").buy_car("car"); root.get_node("Progress").license = true
	await pf(2)
	await key(KEY_ESCAPE)
	ok(menu.is_open() and paused and menu._title.text == "Пауза", "Esc — пауза")
	ok(menu._save.visible and menu._new.visible, "в паузе: сохранить и новая игра")
	var settings: Button
	var controls: Button
	for b in menu._pages.main.find_children("*", "Button", true, false):
		if b.text == "Настройки": settings = b
		if b.text == "Управление": controls = b
	settings.pressed.emit()
	await pf(2)
	ok(menu._page == "settings" and menu._pages.settings.visible and not menu._pages.main.visible, "страница «Настройки»")
	var det: Array = menu._pages.settings.find_children("*", "Button", true, false).filter(func(b): return b.text == "Низкая")
	det[0].pressed.emit()
	ok(root.get_node("SettingsManager").detail == 0, "детализация «Низкая» выбирается кнопкой")
	await key(KEY_ESCAPE)
	ok(menu.is_open() and menu._page == "main", "Esc на странице — назад на главную, а не закрыть")
	controls.pressed.emit()
	await pf(2)
	ok(menu._page == "controls" and menu._controls_text.text.contains("ГЕЙМПАД") and menu._controls_text.text.contains("W A S D"), "страница «Управление» с клавиатурой и геймпадом")
	await key(KEY_ESCAPE)
	menu._new.pressed.emit()
	await pf(2)
	ok(menu._page == "confirm" and is_instance_valid(W) and W.is_inside_tree(), "«Новая игра» сначала переспрашивает")
	for b in menu._pages.confirm.find_children("*", "Button", true, false):
		if b.text == "Нет, назад": b.pressed.emit()
	await pf(2)
	ok(menu._page == "main" and menu.is_open(), "«Нет, назад» — ничего не сброшено")
	await key(KEY_ESCAPE)
	ok(not menu.is_open() and not paused, "Esc — закрыть паузу")

	print("== Геймпад")
	child("gamepad.gd").test_pad = 0
	var P = W.get_node("Player"); var C = W.get_node("Car")
	P.global_position = Vector3(-110, 0.2, -40); P.rotation.y = PI / 2.0
	await frames(10)
	var a: Vector3 = P.global_position
	jaxis(JOY_AXIS_LEFT_Y, -0.6)
	await pf(2); await frames(60)
	ok(GM.move_axis.y < -0.4 and GM.move_axis.y > -0.8 and P.global_position.distance_to(a) > 1.0, "левый стик — идёт плавно: %.1f м, ось %.2f" % [P.global_position.distance_to(a), GM.move_axis.y])
	jaxis(JOY_AXIS_LEFT_Y, 0.0)
	await pf(2); await frames(30)
	ok(GM.move_axis == Vector2.ZERO and Vector2(P.velocity.x, P.velocity.z).length() < 0.5, "отпустил стик — стоит")
	var yaw: float = P.rotation.y
	jaxis(JOY_AXIS_RIGHT_X, 1.0)
	# Поворот идёт по времени, а не по кадрам — держим стик полсекунды
	var t_end := Time.get_ticks_msec() + 500
	while Time.get_ticks_msec() < t_end:
		await process_frame
	jaxis(JOY_AXIS_RIGHT_X, 0.0)
	ok(absf(P.rotation.y - yaw) > 0.2, "правый стик — камера: %.2f рад" % (P.rotation.y - yaw))
	P.global_position = Vector3(-121, 0.2, -37.6)
	await frames(15)
	jbtn(JOY_BUTTON_X, true); await pf(3); jbtn(JOY_BUTTON_X, false); await pf(3)
	await frames(5)
	ok(GM.vehicle == C, "X — сел в машину")
	C.fuel = 30.0
	jaxis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await pf(2); await frames(150)
	ok(C.speed_kmh() > 10.0, "RT — газ: %d км/ч" % int(C.speed_kmh()))
	var cy: float = C.rotation.y
	jaxis(JOY_AXIS_LEFT_X, -1.0)
	await pf(2); await frames(60)
	ok(absf(angle_difference(cy, C.rotation.y)) > 0.1, "левый стик — руль: %.2f рад" % angle_difference(cy, C.rotation.y))
	jaxis(JOY_AXIS_LEFT_X, 0.0); jaxis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await pf(3)
	ok(not Input.is_physical_key_pressed(KEY_W) and not Input.is_physical_key_pressed(KEY_A), "отпустил — газ и руль отпущены")
	jbtn(JOY_BUTTON_START, true); await pf(3); jbtn(JOY_BUTTON_START, false); await pf(3)
	ok(menu.is_open() and paused, "Start — меню")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
