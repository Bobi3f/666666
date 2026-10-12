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
func drive_to(C, target: Vector3, kmh: float) -> float:
	var local: Vector3 = C.to_local(target)
	var ang := atan2(local.x, -local.z)
	key(KEY_D, ang > 0.04)
	key(KEY_A, ang < -0.04)
	var want := kmh * clampf(1.2 - absf(ang), 0.3, 1.0)
	key(KEY_W, C.speed_kmh() < want)
	key(KEY_S, C.speed_kmh() > want + 6.0 and C.speed > 0.5)
	return Vector2(local.x, local.z).length()
## Проехать по точкам; вернуть, сколько секунд заняло (или -1, если застрял).
func route(C, pts: Array, kmh: float, limit: float) -> float:
	var t0 := Time.get_ticks_msec()
	var i := 0
	var stuck := 0.0
	while i < pts.size():
		await physics_frame
		if (Time.get_ticks_msec() - t0) / 1000.0 > limit:
			release_all()
			print("       застрял у точки %d, машина в %s" % [i, str(C.global_position.round())])
			return -1.0
		var d := drive_to(C, pts[i], kmh)
		if d < 4.0: i += 1
	release_all()
	return (Time.get_ticks_msec() - t0) / 1000.0
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress"); var TM = root.get_node("TimeManager")
	var NM = root.get_node("NeedsManager"); var WM = root.get_node("WeatherManager")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("traffic.gd"): c.queue_free()
		# Светофор держим зелёным: иначе штраф за красный зависит от случайного времени
		if c.get_script() and c.get_script().resource_path.ends_with("street_life.gd"): c.set_physics_process(false)
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	# Права и «Жигули» — как у игрока, прошедшего автошколу
	root.get_node("Progress").buy_car("car"); root.get_node("Progress").license = true
	WM.set_kind(0, 9999.0)
	TM.minutes = 11 * 60.0
	NM.food = 100.0; NM.energy = 100.0
	var P = W.get_node("Player"); var C = W.get_node("Car")

	print("== Камера персонажа")
	var cam = P.camera
	P.global_position = Vector3(-80, 0.3, -60)
	for i in 10: await physics_frame
	for i in 3: await process_frame
	var yaw0: float = P.rotation.y
	P._look(0.6, 0.0)
	await process_frame
	var cam_yaw: float = cam.global_transform.basis.get_euler().y
	ok(absf(angle_difference(cam_yaw, P.rotation.y)) < 0.01, "поворот головы — сразу, без задержки: %.2f → %.2f рад" % [yaw0, cam_yaw])
	P.global_position = Vector3(-60, 0.3, -60)
	for i in 3: await physics_frame
	await process_frame
	ok(cam.global_position.distance_to(P._eye.global_position) < 0.5, "после телепорта камера сразу на месте, без перелёта")
	cam.kick(Vector3(0, 0.4, 0))
	await process_frame
	var lag: float = P._eye.global_position.y - cam.global_position.y
	var tk := Time.get_ticks_msec()
	while Time.get_ticks_msec() - tk < 350: await process_frame
	var lag2: float = P._eye.global_position.y - cam.global_position.y
	# Сколько камера отстанет за первый кадр — зависит от длины кадра
	ok(lag > 0.1 and absf(lag2) < 0.05, "ступенька: камера догоняет плавно (%.2f → %.2f м)" % [lag, lag2])
	print("== Машина")
	C.global_position = Vector3(-80, 0.3, -60); C.speed = 0.0; C.velocity = Vector3.ZERO
	await frames(30)
	ok(absf(C.global_position.y) < 0.03, "стоит колёсами на земле, не проваливается: y=%.3f" % C.global_position.y)
	var glass_ok := false
	for m in C._paint_mesh.get_children():
		if m is MeshInstance3D and m.material_override and m.material_override.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			glass_ok = true
	ok(glass_ok, "стёкла прозрачные — из салона видно дорогу")
	var sp = null
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("hud.gd"):
			for h in c.get_children():
				if h.get_script() and h.get_script().resource_path.ends_with("speedometer.gd"): sp = h
	await frames(2)
	ok(sp != null and not sp.visible, "пешком спидометра нет")
	C._on_enter(); C.fuel = 40.0
	C.speed = 15.0
	for i in 40: await process_frame
	ok(sp.visible and absf(sp._shown - C.speed_kmh()) < 6.0, "за рулём — спидометр: стрелка %d, скорость %d км/ч" % [int(sp._shown), int(C.speed_kmh())])
	C.speed = 0.0; C.velocity = Vector3.ZERO
	C.exit_car(); await frames(3)
	for i in 3: await process_frame
	ok(not sp.visible, "вышел — спидометр спрятался")
	print("== Покрытие")
	C.global_position = Vector3(-6.5, 0.1, -60)
	ok(C.surface().roll < 2.0 and C.surface().roll > 1.0, "полевая дорога — гравий: качение %.1f" % C.surface().roll)
	C.global_position = Vector3(-120, 0.1, -86.5)
	ok(C.surface().roll >= 2.0 and C.surface().roll < 3.0, "лесная дорога — грунт: %.1f" % C.surface().roll)
	C.global_position = Vector3(-80, 0.1, -60)
	ok(C.surface().roll >= 5.0, "за дорогой — трава: %.1f" % C.surface().roll)

	print("== Полевое кольцо")
	C.global_position = Vector3(-59.5, 0.1, -39.5); C.rotation.y = -PI / 2.0; C.speed = 0.0; C.velocity = Vector3.ZERO
	C._on_enter(); C.fuel = 40.0
	await frames(3)
	var t := await route(C, [Vector3(-30, 0, -37.5), Vector3(-6.5, 0, -40), Vector3(-6.5, 0, -86.5), Vector3(23, 0, -86.5),
		Vector3(23, 0, -20), Vector3(23, 0, -8), Vector3(23, 0, 0), Vector3(0, 0, 1.5)], 55.0, 90.0)
	ok(t > 0.0, "проехал кольцо: деревня → колхоз → поля → трасса за %.0f с" % t)

	print("== Лесная дорога и мост")
	C.global_position = Vector3(-164.7, 0.1, -45); C.rotation.y = 0.0; C.speed = 0.0; C.velocity = Vector3.ZERO
	await frames(3)
	var t2 := await route(C, [Vector3(-164.7, 0, -86.5), Vector3(-130, 0, -86.5), Vector3(-110, 0, -86.5),
		Vector3(-90, 0, -86.5), Vector3(-20, 0, -86.5)], 45.0, 90.0)
	ok(t2 > 0.0, "проехал лес и мост через речку за %.0f с, состояние машины %d%%" % [t2, int(C.condition)])
	# Мимо моста — речку не переехать
	C.global_position = Vector3(-122, 0.1, -130); C.rotation.y = -PI / 2.0; C.speed = 0.0; C.velocity = Vector3.ZERO
	await frames(3)
	key(KEY_W, true); await frames(60 * 4); key(KEY_W, false)
	ok(C.global_position.x < -112.2, "в речку не въехать — берег держит (x=%.1f)" % C.global_position.x)
	C.speed = 0.0; C.velocity = Vector3.ZERO

	print("== Ямы и лужи")
	var holes: Array = W._potholes
	ok(holes.size() > 30, "ям на грунтовках: %d" % holes.size())
	# Яма на деревенской улице: едем прямо на неё
	var h: Vector3 = holes[0]
	for hh in holes:
		if hh.x > -150 and hh.x < -70 and hh.z < -38.5 and hh.z > -41.5:
			h = hh
			break
	C.condition = 100.0
	C.global_position = Vector3(h.x - 8.0, 0.1, h.z); C.rotation.y = -PI / 2.0; C.speed = 10.0; C.velocity = Vector3.ZERO
	await frames(2)
	var shook := false
	for i in 60:
		C.speed = maxf(C.speed, 10.0)
		await physics_frame
		if C._shake > 0.0: shook = true; break
	ok(shook and C.condition < 100.0 and C.condition > 98.0, "яма на скорости — тряхнуло, подвеска 100 → %.1f%%" % C.condition)
	WM.wetness = 0.8
	await frames(3)
	ok(W._puddles != null and W._puddles.visible and W._puddles.get_child_count() > 10, "после дождя на грунтовках лужи")
	WM.wetness = 0.0
	await frames(3)
	ok(not W._puddles.visible, "высохло — луж нет")
	C.speed = 0.0; C.velocity = Vector3.ZERO

	print("== Стыки дорог")
	# С полевой на трассу и с трассы на городскую улицу
	C.global_position = Vector3(23, 0.1, -20); C.rotation.y = PI; C.speed = 0.0; C.velocity = Vector3.ZERO
	await frames(3)
	key(KEY_W, true); await frames(60 * 5); key(KEY_W, false)
	ok(C.global_position.z > 3.0, "с гравийки выехал на трассу (z=%.1f)" % C.global_position.z)
	C.global_position = Vector3(97, 0.1, -3); C.rotation.y = PI; C.speed = 0.0; C.velocity = Vector3.ZERO
	await frames(3)
	key(KEY_W, true); await frames(60 * 3); key(KEY_W, false)
	ok(C.global_position.z > 12.0, "с трассы — в город (z=%.1f)" % C.global_position.z)
	C.global_position = Vector3(97, 0.1, 20); C.rotation.y = 0.0; C.speed = 0.0; C.velocity = Vector3.ZERO
	await frames(3)
	key(KEY_W, true); await frames(60 * 4); key(KEY_W, false)
	ok(C.global_position.z < -3.0, "из города на трассу (z=%.1f)" % C.global_position.z)
	C.speed = 0.0; C.velocity = Vector3.ZERO
	C.exit_car(); await frames(3)

	print("== Город: кафе и «Хозтовары»")
	GM.money = 10000
	NM.food = 30.0
	P.global_position = Vector3(92.5, 0.2, 16.5); await frames(5)
	var cafe := zone_with("пообедать")
	ok(cafe != null, "кафе: " + (cafe.text() if cafe else "-"))
	cafe.activate()
	ok(NM.food > 80.0 and GM.money == 9910, "пообедал: сытость %d%%, деньги %d" % [int(NM.food), GM.money])
	TM.minutes = 22 * 60.0
	cafe.activate()
	ok(last().contains("закрыто") and GM.money == 9910, "ночью кафе закрыто")
	TM.minutes = 12 * 60.0
	for id in ["tv", "dog", "greenhouse"]:
		var z := zone_with({"tv": "телевизор", "dog": "Шарика", "greenhouse": "теплицу"}[id])
		ok(z != null and z.text().begins_with("E — купить"), "в продаже: " + (z.text() if z else "-"))
		z.activate()
	ok(PR.has_item("tv") and PR.has_item("dog") and PR.has_item("greenhouse") and GM.money == 9910 - 6300, "купил всё, осталось %d" % GM.money)
	await frames(3)
	var home = W.get_node("HomeItems")
	ok(home.get_node_or_null("TV") != null and home.get_node_or_null("Dog") != null and home.get_node_or_null("GreenhouseFilm") != null, "дома — телевизор, пёс и теплица")
	ok(PR.grow_time() < PR.GROW_TIME, "в теплице картошка растёт быстрее: %.1f дня вместо 3" % (PR.grow_time() / 1440.0))
	ok(zone_with("уже есть") != null, "второй раз не продают")
	var st: Dictionary = PR.save_state()
	PR.load_state({})
	await frames(3)
	ok(home.get_node_or_null("TV") == null, "новая игра — покупок нет")
	PR.load_state(st)
	await frames(3)
	ok(home.get_node_or_null("TV") != null and PR.has_item("dog"), "после загрузки покупки на месте")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
