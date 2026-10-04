extends SceneTree
## Поворотники: Z / X включают, мигают лампы с нужной стороны, после
## поворота руля гаснут сами, повторное нажатие выключает; на мотоцикле тоже.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)
func tap(code: int) -> void:
	key(code, true); await frames(2); key(code, false); await frames(2)
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func lit(v: Vehicle, side: int) -> int:
	var n := 0
	for l in v._turn_lamps:
		if int(l[1]) == side and (l[0] as Node3D).visible: n += 1
	return n

func _run() -> void:
	for i in 5: await process_frame
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	var PR = root.get_node("Progress")
	PR.buy_car("car"); PR.add_category("B"); PR.add_category("A"); PR.buy_car("moto")
	var C: Vehicle = W.get_node("Car")
	C.global_position = Vector3(60, 0.3, 2.0)
	C.rotation.y = -PI / 2.0
	await frames(5)
	C._on_enter()
	await frames(3)

	print("== «Жигули»")
	ok(C._turn_lamps.size() == 6, "по три лампы с каждой стороны: перед, зад, крыло")
	await tap(KEY_Z)
	ok(C.turn == -1, "Z — левый поворотник")
	var seen_on := false
	var seen_off := false
	for i in 90:
		await process_frame
		if lit(C, -1) == 3: seen_on = true
		if lit(C, -1) == 0: seen_off = true
	ok(seen_on and seen_off and lit(C, 1) == 0, "мигают левые лампы, правые не горят")
	await tap(KEY_Z)
	ok(C.turn == 0 and lit(C, -1) == 0, "ещё раз Z — выключил")
	await tap(KEY_X)
	ok(C.turn == 1, "X — правый")
	await tap(KEY_Z)
	ok(C.turn == -1, "Z при правом — сразу левый")
	# Поворот налево и руль обратно — гаснет сам
	C.speed = 8.0
	key(KEY_A, true)
	await frames(50)
	key(KEY_A, false)
	await frames(60)
	ok(C.turn == 0, "повернул налево и выровнял руль — поворотник погас сам")
	C.speed = 0.0
	C.exit_car()
	await frames(3)

	print("== «Ява»")
	var M: Vehicle = W.get_node("Moto")
	M.global_position = Vector3(60, 0.3, -2.0)
	M.rotation.y = -PI / 2.0
	await frames(5)
	M._on_enter()
	await frames(3)
	await tap(KEY_X)
	var moto_on := false
	for i in 60:
		await process_frame
		if lit(M, 1) == 2: moto_on = true
	ok(M.turn == 1 and moto_on and M._turn_lamps.size() == 4, "на «Яве» мигают правые — передний и задний")

	print("== Механика на компьютере")
	var SM = root.get_node("SettingsManager")
	M.exit_car()
	await frames(3)
	C.global_position = Vector3(60, 0.3, 6.0)
	C.rotation.y = -PI / 2.0
	await frames(5)
	SM.set_auto_gearbox(false)
	C._on_enter()
	await frames(3)
	C.engine_on = true
	C.rpm = 900.0
	C.gear = 0
	await tap(KEY_3)
	ok(C.gear == 0, "без сцепления 3 не включается — скрежет")
	key(KEY_SHIFT, true)
	await frames(20)
	await tap(KEY_1)
	ok(C.gear == 1, "Shift + 1 — первая")
	await tap(KEY_3)
	ok(C.gear == 3, "Shift + 3 — сразу третья")
	await tap(KEY_0)
	ok(C.gear == 0, "0 — нейтраль")
	await tap(KEY_MINUS)
	ok(C.gear == -1, "«−» с места — задняя")
	SM.bind_key(KEY_2, KEY_U)
	await tap(KEY_U)
	ok(C.gear == 2, "своя клавиша U на 2-ю передачу")
	SM.reset_keys()
	key(KEY_SHIFT, false)
	await frames(3)
	var sp = null
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("hud.gd"):
			for h in c.get_children():
				if h.get_script() and h.get_script().resource_path.ends_with("speedometer.gd"): sp = h
	for i in 3: await process_frame
	ok(sp != null and sp.visible, "схема коробки и сцепление рисуются у спидометра")
	SM.set_auto_gearbox(true)
	C.exit_car()
	await frames(3)

	print("== Оглядеться за рулём")
	var P = W.get_node("Player")
	root.get_node("Progress").buy_car("car")
	C.global_position = Vector3(-150, 0.1, 2.0); C.rotation.y = -PI / 2.0; C.speed = 0.0; C.velocity = Vector3.ZERO
	C._on_enter(); C.fuel = 30.0
	await frames(3)
	var yaw0: float = P.rotation.y
	P._look(0.8, 0.2)
	ok(absf(C.look_yaw - 0.8) < 0.01 and absf(C._seat_mark.rotation.y - 0.8) < 0.01 and P.rotation.y == yaw0, "из салона голова повернулась на 0.8 рад, игрок на месте")
	P._look(3.0, 0.0)
	ok(absf(C._seat_mark.rotation.y) <= C.LOOK_YAW_CABIN + 0.001, "из салона — не дальше, чем через плечо")
	C.look_yaw = 0.0; C.look_pitch = 0.0
	Vehicle.chase_view = true
	C._update_camera(1.0)
	var m0: Vector3 = C._chase_mark.global_position
	P._look(PI / 2.0, 0.0)
	C._update_camera(1.0)
	var m1: Vector3 = C._chase_mark.global_position
	ok(m0.distance_to(m1) > 3.0 and absf(m0.distance_to(C.global_position) - m1.distance_to(C.global_position)) < 0.5, "сзади камера облетает машину: %.1f м вбок" % m0.distance_to(m1))
	# Поехал и не трогаешь камеру — она возвращается вперёд
	C.speed = 15.0
	for i in 240:
		C.speed = 15.0
		await physics_frame
	ok(absf(C.look_yaw) < 0.05, "на ходу камера сама вернулась вперёд: %.2f" % C.look_yaw)
	Vehicle.chase_view = false
	C.speed = 0.0; C.velocity = Vector3.ZERO
	C.exit_car()
	await frames(3)
	var J = W.get_node("Moto")
	root.get_node("Progress").buy_car("moto")
	J.global_position = Vector3(-150, 0.1, 6.0); J._on_enter()
	await frames(3)
	P._look(-0.5, 0.0)
	ok(absf(J.look_yaw + 0.5) < 0.01, "на «Яве» тоже можно оглядеться")
	J.exit_car()
	await frames(3)

	print("== Кнопки на телефоне")
	var tc = null
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("touch_controls.gd"): tc = c
	ok(tc == null or (tc.button("◀") != null and tc.button("▶") != null), "стрелки ◀ ▶ есть")

	print("\nИТОГО: " + ("всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ, провалов: %d" % fails))
	quit(1 if fails else 0)
