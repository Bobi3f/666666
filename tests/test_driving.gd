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
func release_all() -> void:
	for k in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_SPACE]: key(k, false)
func zone_with(t: String) -> InteractZone:
	for z in W.get_children():
		if z is InteractZone and z.text().contains(t): return z
	return null
func last() -> String:
	return W.get_node("/root/GameManager").get_meta("last", "")
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()

## Автопилот: едет на точку target, держит скорость kmh.
func drive_to(C, target: Vector3, kmh: float, after = null) -> float:
	var local: Vector3 = C.to_local(target)
	var ang := atan2(local.x, -local.z)
	key(KEY_D, ang > 0.04)
	key(KEY_A, ang < -0.04)
	var want := kmh * clampf(1.2 - absf(ang), 0.35, 1.0)
	# Перед крутым поворотом — сбросить скорость, как сделал бы водитель
	if after != null:
		var d1: Vector3 = (target - C.global_position); d1.y = 0
		var d2: Vector3 = (after - target); d2.y = 0
		var turn := d1.angle_to(d2)
		if turn > 0.6 and d1.length() < 12.0 + C.speed_kmh() * 0.35:
			want = minf(want, 40.0 if turn < 1.2 else 24.0)
	key(KEY_W, C.speed_kmh() < want)
	key(KEY_S, C.speed_kmh() > want + 6.0 and C.speed > 0.5)
	return Vector2(local.x, local.z).length()

func run_course(C, ch, kmh: float, park_approach: Vector3) -> Dictionary:
	var result := {}
	ch.finished.connect(func(r: Dictionary) -> void: result.merge(r), CONNECT_ONE_SHOT)
	var guard := 0
	while result.is_empty() and guard < 60 * 200:
		guard += 1
		await physics_frame
		if ch.state != 2:
			await drive_to(C, ch.start_pos, 15.0)
			continue
		if ch.idx < ch.points.size():
			if ch.idx != C.get_meta("last_idx", -1):
				C.set_meta("last_idx", ch.idx)
				print("       точка %d  t=%.1f  %s  %d км/ч" % [ch.idx, ch.t, str(C.global_position.round()), int(C.speed_kmh())])
			# Смотрим дальше: подъезжая к точке, уже целимся в следующую
			var aim: Vector3 = ch.points[ch.idx]
			var nxt = ch.points[ch.idx + 1] if ch.idx + 1 < ch.points.size() else null
			var near: float = Vector2(C.global_position.x - aim.x, C.global_position.z - aim.z).length()
			if nxt != null and ch.point_radius > 3.5 and near < ch.point_radius + 3.0:
				aim = aim.lerp(nxt, 0.35)
			drive_to(C, aim, kmh, nxt)
			if guard % 60 == 0 and ch.title.contains("Колькой"):
				print("         t=%.0f %s %d км/ч" % [ch.t, str(C.global_position.round()), int(C.speed_kmh())])
		else:
			# Стоянка: сначала встать на линию разметки, потом въехать и тормозить
			var d_app := Vector2(C.global_position.x - park_approach.x, C.global_position.z - park_approach.z).length()
			if not C.has_meta("app") and d_app > 2.0:
				drive_to(C, park_approach, 14.0)
			else:
				C.set_meta("app", true)
				var d := drive_to(C, ch.park_center, 9.0)
				if d < 1.2 or (C.to_local(ch.park_center).z > 0.0):
					key(KEY_A, false); key(KEY_D, false); key(KEY_W, false)
					key(KEY_S, C.speed > 0.2)
	release_all()
	return result

func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress"); var TM = root.get_node("TimeManager")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("traffic.gd"): c.queue_free()
		# Светофор держим зелёным: иначе штраф за красный зависит от случайного времени
		if c.get_script() and c.get_script().resource_path.ends_with("street_life.gd"): c.set_physics_process(false)
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	TM.minutes = 10 * 60.0
	var P = W.get_node("Player"); var C = W.get_node("Car")
	var nm = root.get_node("NeedsManager")

	print("== Тюнинг в СТО")
	GM.money = 10000
	C.global_position = Vector3(-86, 0.1, 13); C.rotation.y = 0.0
	P.global_position = Vector3(-80, 0.2, 13.8)
	await frames(5)
	var tz := zone_with("всесезонная")
	ok(tz != null and tz.text().contains("1500"), "резина: " + (tz.text() if tz else "-"))
	tz.activate()
	ok(C.tires and GM.money == 8500 and last().contains("всесезонку"), "поставил всесезонку")
	ok(zone_with("уже всесезонная") != null, "второй раз не продаёт")
	zone_with("форсировать").activate()
	ok(C.engine_tuned and GM.money == 5500, "мотор форсирован")
	var old_paint: int = C.paint
	var pz := zone_with("перекрасить")
	ok(pz.text().contains("бежевый") and pz.text().contains("вишнёвый"), "покраска: " + pz.text())
	pz.activate()
	ok(C.paint == old_paint + 1 and last().contains("вишнёвый"), "перекрасил: " + last())
	var st: Dictionary = C.save_state()
	C.tires = false; C.engine_tuned = false
	C.load_state(st)
	ok(C.tires and C.engine_tuned and C.paint == 1, "тюнинг сохраняется")
	# Форсированный мотор разгоняет быстрее
	var speeds := []
	for tuned in [false, true]:
		C.engine_tuned = tuned
		C.global_position = Vector3(-150, 0.1, 2.0); C.rotation.y = -PI / 2.0; C.speed = 0.0; C.velocity = Vector3.ZERO
		if GM.vehicle != C: C._on_enter()
		C.fuel = 30.0
		await frames(3)
		key(KEY_W, true)
		await frames(60 * 4)
		key(KEY_W, false)
		speeds.append(C.speed_kmh())
		C.speed = 0.0; C.velocity = Vector3.ZERO
		await frames(3)
	ok(speeds[1] > speeds[0] + 3.0, "форсированный мотор быстрее: %d → %d км/ч за 4 с" % [int(speeds[0]), int(speeds[1])])
	C.engine_tuned = false; C.tires = false
	C.exit_car(); await frames(3)

	print("== Экзамен на права")
	var PRD = root.get_node("Progress")
	PRD.add_doc("passport"); PRD.add_doc("med")
	GM.money = 1000
	P.global_position = Vector3(-1.8, 0.2, -16.5)
	await frames(5)
	var ez := zone_with("сдать на права")
	ok(ez != null and ez.text().contains("300"), "инструктор: " + (ez.text() if ez else "-"))
	ez.activate()
	var EX = W.get_node("Exam")
	ok(EX.state == 1 and GM.money == 700 and GM.challenge_line.contains("старт"), "экзамен взведён: " + GM.challenge_line)
	C.global_position = Vector3(9, 0.1, -12); C.rotation.y = 0.0
	C._on_enter(); C.fuel = 30.0
	await frames(3)
	var t0 := Time.get_ticks_msec()
	var r: Dictionary = await run_course(C, EX, 28.0, Vector3(16.5, 0, -52))
	print("     экзамен: ", r, " за %.0f с настоящего времени" % ((Time.get_ticks_msec() - t0) / 1000.0))
	ok(r.get("ok", false) and PR.license, "автопилот сдал экзамен: %.0f с, конусов %d" % [r.get("time", 0.0), r.get("cones", -1)])
	ok(last().contains("Права") and PR.delivery_pay() == 650, "права: развоз платит %d грн" % PR.delivery_pay())
	# Провал: сбил конусы
	C.exit_car(); await frames(3)
	P.global_position = Vector3(-1.8, 0.2, -16.5); await frames(3)
	zone_with("потренироваться").activate()
	C.global_position = Vector3(9, 0.1, -12); C.rotation.y = 0.0; C.speed = 0.0; C.velocity = Vector3.ZERO
	C._on_enter()
	await frames(3)
	var fail := {}
	EX.finished.connect(func(x: Dictionary) -> void: fail.merge(x), CONNECT_ONE_SHOT)
	while EX.state != 2:
		drive_to(C, EX.start_pos, 12.0); await physics_frame
	# Прямо по конусам змейки
	for i in 60 * 12:
		if not fail.is_empty(): break
		drive_to(C, Vector3(9, 0, -60), 25.0)
		await physics_frame
	release_all()
	ok(not fail.is_empty() and not fail.ok and fail.why.contains("конус") and last().contains("Не сдал"), "по конусам — не сдал: " + last())
	C.speed = 0.0; C.velocity = Vector3.ZERO
	C.exit_car(); await frames(3)

	print("== Заезд с Колькой")
	TM.day = 2
	GM.money = 1000
	P.global_position = Vector3(-54, 0.2, -20.0); await frames(5)
	var rz := zone_with("Колька")
	ok(rz != null and rz.text().contains("200"), "Колька: " + (rz.text() if rz else "-"))
	rz.activate()
	var RC = W.get_node("Race")
	ok(RC.state == 1 and GM.money == 800 and PR.race_day == 2, "поспорили на 200")
	ok(zone_with("Колька").text().contains("Старт"), "пока заезд — подсказка о старте")
	C.global_position = Vector3(-59.5, 0.1, -27); C.rotation.y = PI; C.speed = 0.0; C.velocity = Vector3.ZERO
	C._on_enter(); C.fuel = 30.0
	await frames(3)
	var rr: Dictionary = await run_course(C, RC, 95.0, Vector3.ZERO)
	ok(rr.get("ok", false) and GM.money == 1200, "автопилот успел: %.1f с из %d (деньги %d)" % [rr.get("time", 0.0), int(RC.time_limit), GM.money])
	C.speed = 0.0; C.velocity = Vector3.ZERO
	C.exit_car(); await frames(3)
	P.global_position = Vector3(-54, 0.2, -20.0); await frames(3)
	ok(zone_with("Колька").text().contains("завтра"), "второй раз за день не спорит")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
