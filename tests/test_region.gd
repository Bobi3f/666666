extends SceneTree
## Район вокруг Каменки: сёла, река с мостами, грунтовки, край мира,
## районный автобус, рыбалка на озере, карта.
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

## Автопилот: едет на точку, держит скорость.
func drive_to(C, target: Vector3, kmh: float) -> float:
	var local: Vector3 = C.to_local(target)
	var ang := atan2(local.x, -local.z)
	key(KEY_D, ang > 0.04)
	key(KEY_A, ang < -0.04)
	var want := kmh * clampf(1.2 - absf(ang), 0.35, 1.0)
	key(KEY_W, C.speed_kmh() < want)
	key(KEY_S, C.speed_kmh() > want + 6.0 and C.speed > 0.5)
	return Vector2(local.x, local.z).length()

## Проезд по точкам; возвращает, до какой точки доехал.
func route(C, pts: Array, kmh: float, limit_s: float) -> int:
	var i := 0
	var t := 0.0
	while i < pts.size() and t < limit_s:
		await physics_frame
		t += 1.0 / 60.0
		if drive_to(C, pts[i], kmh) < 5.0:
			i += 1
	release_all()
	return i

func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager")
	var AC = root.get_node("Achievements")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd")
	print("== Район")
	var R = W.get_node("Region")
	ok(R != null and Region.VILLAGES.size() == 4, "четыре соседних села")
	ok(R._bridges.size() == 2, "мосты через реку: %d" % R._bridges.size())
	ok(tr.WORLD_X > 600.0, "попутки ездят по всей трассе района")
	var veg = W.get_node("Vegetation")
	ok(int(veg.counts.get("tree_0", 0)) > 700, "леса района: елей %d" % int(veg.counts.get("tree_0", 0)))
	ok(W.get_node("Region/RegionMesh").get_child_count() >= 8, "дома района — кусками")
	var far_chunk: GeometryInstance3D = W.get_node("Region/RegionMesh").get_child(0)
	ok(far_chunk.visibility_range_end > 0.0, "дальние сёла не рисуются: %d м" % int(far_chunk.visibility_range_end))
	print("== Дороги")
	var c0: Vector2 = Region.VILLAGES[0].c
	ok(Region.on_road(c0.x, c0.y), "улица Озерцово — грунтовка")
	ok(Roads.on_forest_road(-380, -100), "дорога на Озерцово — грунт для машины")
	ok(not Region.on_road(-600, -600), "в лесу дороги нет")
	ok(not Roads.on_asphalt(400, 60), "за рекой не асфальт (город кончается)")
	ok(Roads.on_asphalt(500, 1), "трасса до края района")
	ok(not Region.on_road(-100, -40), "в Каменке дороги района не мешают")
	ok(Region.tree_ok(-600, -600) and not Region.tree_ok(c0.x, c0.y), "лес не растёт в сёлах")
	tr.queue_free()
	await frames(2)

	print("== Мост на трассе")
	var C = W.get_node("Car")
	TM.minutes = 12 * 60.0
	C.global_position = Vector3(250, 0.3, 2.0); C.rotation = Vector3(0, -PI / 2.0, 0)
	C._on_enter(); C.fuel = 40.0; C.condition = 100.0
	await frames(5)
	var got: int = await route(C, [Vector3(300, 0, 2), Vector3(330, 0, 2), Vector3(380, 0, 2)], 50.0, 25.0)
	ok(got == 3 and C.global_position.x > 370.0, "переехал реку по мосту: x=%d" % int(C.global_position.x))

	print("== Берег не пускает в реку")
	var rv := Region.river()
	var zr := 120.0
	var xr := 0.0
	for q in rv:
		if absf(q.y - zr) < 3.0: xr = q.x
	C.global_position = Vector3(xr - 40.0, 0.3, zr); C.rotation = Vector3(0, -PI / 2.0, 0)
	C.speed = 0.0
	await frames(5)
	await route(C, [Vector3(xr + 30.0, 0, zr)], 35.0, 8.0)
	ok(C.global_position.x < xr - Region.RIVER_HALF + 1.5, "упёрся в берег: x=%.1f, река на %.1f" % [C.global_position.x, xr])

	print("== Деревянный мост к Первомаю")
	var br: Vector2 = Vector2.ZERO
	for b in R._bridges:
		if absf((b[0] as Vector2).y) > 50.0: br = b[0]
	ok(br != Vector2.ZERO, "мост на грунтовке: %s" % str(br.round()))
	var dir: Vector2 = (Vector2(420, -350) - Vector2(150, -300)).normalized()
	var a := br - dir * 40.0
	var z := br + dir * 40.0
	C.global_position = Vector3(a.x, 0.3, a.y); C.rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
	C.speed = 0.0
	await frames(5)
	got = await route(C, [Vector3(br.x, 0, br.y), Vector3(z.x, 0, z.y)], 30.0, 20.0)
	ok(got == 2, "проехал по деревянному мосту: %s" % str(C.global_position.round()))
	var sf: Dictionary = C.surface()
	ok(float(sf.roll) < 3.0, "на грунтовке катится как по дороге: %.1f" % float(sf.roll))

	print("== Край района")
	C.global_position = Vector3(640, 0.3, 2.0); C.rotation = Vector3(0, -PI / 2.0, 0)
	C.speed = 0.0
	await frames(5)
	await route(C, [Vector3(760, 0, 2)], 60.0, 6.0)
	ok(C.global_position.x < 700.5, "за край района не уехать: x=%.1f" % C.global_position.x)
	C.speed = 0.0
	C.exit_car()
	await frames(3)

	print("== Сёла и автобус")
	var P = GM.player
	AC.counts.erase("village_visit"); AC.got.erase("region")
	R.visited.clear()
	for i in Region.VILLAGES.size():
		var vc: Vector2 = Region.VILLAGES[i].c
		P.global_position = Vector3(vc.x, 0.1, vc.y)
		await frames(40)
		ok(R.visited.has(Region.VILLAGES[i].name), "побывал: " + Region.VILLAGES[i].name + " — " + last())
	ok(AC.got.has("region"), "достижение «Весь район»")
	TM.minutes = 10 * 60.0
	GM.money = 100
	P.global_position = W.STOP_VILLAGE + Vector3(-5, 0.1, 1.0)
	R.ride_district()
	var t := Region.bus_target(10.0)
	ok(GM.money == 100 - Region.BUS_FARE and P.global_position.distance_to(Region.stop_pos(t)) < 4.0,
		"районный автобус: " + last())
	ok(TM.hour() >= 10.4, "полчаса в дороге")
	TM.minutes = 23 * 60.0
	GM.money = 100
	R.ride_district()
	ok(GM.money == 100 and last().contains("6:00"), "ночью не ходит")
	print("== Магазин и житель")
	TM.minutes = 12 * 60.0
	var NM = root.get_node("NeedsManager")
	var sn: int = NM.snacks
	W._buy_village_food()
	ok(NM.snacks == sn + 1, "хлеб в сельском магазине")
	var talk: InteractZone = null
	for c in R.get_children():
		if c is InteractZone and c.prompt.contains("поговорить"): talk = c; break
	talk.activated.emit()
	ok(last().contains("«"), "житель рассказывает: " + last())
	print("== Рыбалка на озере")
	var lake: InteractZone = null
	for c in R.get_children():
		if c is InteractZone and c.prompt_fn.is_valid() and c.text().contains("озере"): lake = c; break
	ok(lake != null, "мостки на озере")
	TM.minutes = 7 * 60.0
	NM.energy = 100.0
	lake.activated.emit()
	ok(W._fishing.active() and W._fishing.spot.distance_to(lake.position) < 1.0, "закинул удочку на озере")
	print("== Сохранение")
	var st: Dictionary = R.save_state()
	R.visited.clear()
	R.load_state(st)
	ok(R.visited.size() == 4, "посещённые сёла сохраняются")
	R.load_state({})
	ok(R.visited.is_empty(), "старое сохранение — без сёл")
	print("== Карта")
	var map = child("map.gd")
	map.mode = 2; map._canvas.visible = true
	await process_frame; await process_frame
	ok(map._view.size.x == map.WORLD, "карта района целиком")
	map.mode = 1
	await process_frame; await process_frame
	ok(map._view.size.x == map.LOCAL_M and map._view.has_point(Vector2(P.global_position.x, P.global_position.z)), "окрестности вокруг игрока")
	map._canvas.visible = false
	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)
