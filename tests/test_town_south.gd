extends SceneTree
## Южная часть города и железная дорога: путь, мост, переезды со шлагбаумами,
## электричка (ходит, стоит на станции, закрывает переезды), рынок,
## светофоры, футбол на стадионе, прохожие.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
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
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager")
	var NM = root.get_node("NeedsManager")
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var RW: Railway = W.get_node("Region/Railway")
	var TS: TownSouth = W.get_node("TownSouth")

	print("== Железная дорога")
	ok(Railway.crossings.size() >= 3, "переездов на грунтовках: %d" % Railway.crossings.size())
	ok(Railway.river_crossing() != Vector2.INF, "мост через Быструю")
	ok(RW.train.size() == Railway.CARS, "электричка из %d вагонов" % RW.train.size())
	ok(not Region.tree_ok(500.0, 205.0) and not Region.tree_ok(-150.0, 205.5), "на путях деревья не растут")
	ok(not Region.tree_ok(180.0 + Town.SHIFT.x, 230.0), "на заводе деревья не растут")
	for h in Landscape.hills:
		if Railway.dist((h[0] as Vector2).x, (h[0] as Vector2).y) < float(h[1]):
			ok(false, "холм на путях: %s" % str(h))
	ok(RW.state == "station", "электричка стоит на станции")
	# Отправление: гоняем физику поезда вручную, по 0.1 с
	RW.wait = 0.05
	var s0 := RW.s
	for i in 100: RW._process(0.1)
	ok(RW.state == "run" and absf(RW.s - s0) > 30.0, "электричка ушла со станции: %.0f м" % absf(RW.s - s0))
	# Перед переездом шлагбаум закрывается
	var c0: Dictionary = Railway.crossings[0]
	for c in Railway.crossings:
		if absf(float(c.along) - RW.s) < absf(float(c0.along) - RW.s): c0 = c
	RW.s = float(c0.along) - RW.dir * 60.0
	RW.v = Railway.SPEED
	RW.target = -1.0
	RW._process(0.05)
	for i in 40: RW._process(0.05)
	var arm: Node3D = c0.arms[0]
	var cp: Vector2 = c0.p
	var road_dir := Vector2(0, 1)
	ok(Railway.closed_ahead(cp - road_dir * 10.0, road_dir, 16.0) or Railway.closed_ahead(cp + road_dir * 10.0, -road_dir, 16.0) \
		or Railway.closed_ahead(cp - Vector2(10, 0), Vector2(1, 0), 16.0), "переезд закрыт для машин")
	ok(arm.rotation.z < 0.5, "шлагбаум опущен: %.2f" % arm.rotation.z)
	# Доезжает до конца, разворачивается и приходит на станцию
	var saw_end := false
	var saw_station := false
	for i in 6000:
		RW._process(0.1)
		if RW.state == "end": saw_end = true
		if saw_end and RW.state == "station":
			saw_station = true
			break
	ok(saw_end and saw_station, "дошла до края района, развернулась и вернулась на станцию")
	var head: Vector3 = RW.train[0].global_position
	var tail: Vector3 = RW.train[RW.train.size() - 1].global_position
	var mid := (head + tail) * 0.5
	ok(absf(mid.x - Railway.STATION.x) < 8.0, "стоит у платформы: середина состава x=%.0f" % mid.x)
	for i in 40: RW._process(0.05)
	ok(arm.rotation.z > 1.2, "без поезда шлагбаум поднят")

	print("== Рынок")
	TM.minutes = 10 * 60.0
	GM.money = 100
	var snacks: int = NM.snacks
	TS.buy()
	ok(GM.money == 100 - TownSouth.MARKET_PRICE and NM.snacks == snacks + 2, "купил на рынке: две порции еды")
	TM.minutes = 18 * 60.0
	TS.buy()
	ok(GM.money == 100 - TownSouth.MARKET_PRICE, "вечером рынок закрыт")
	var zones := 0
	for c in TS.get_children():
		if c is InteractZone and c.text().contains("Рынок"): zones += 1
	ok(zones >= 8, "прилавков с продавцами: %d" % zones)

	print("== Светофоры, стадион, прохожие")
	ok(TownSouth.light_state(1.0, true) == "green" and TownSouth.light_state(1.0, false) == "red", "одной улице зелёный — другой красный")
	ok(TownSouth.light_state(13.0, true) == "yellow" and TownSouth.light_state(20.0, false) == "green", "жёлтый и смена")
	var P = W.get_node("Player")
	P.global_position = Town.w(Vector3(97, 0.2, 120))
	TM.minutes = 17 * 60.0
	var w0: Vector3 = (TS.walkers[0].mesh as Node3D).position
	var b0: Vector3 = TS.ball.position
	await create_timer(1.5).timeout
	ok(TS.ball.visible and TS.ball.position.distance_to(b0) > 0.5, "вечером на стадионе гоняют мяч")
	var moved := 0
	for w in TS.walkers:
		if float(w.wait) <= 0.0: moved += 1
	ok((TS.walkers[0].mesh as Node3D).position.distance_to(w0) > 0.5 or moved < TS.walkers.size(), "прохожие ходят")
	TM.minutes = 11 * 60.0
	await create_timer(0.2).timeout
	ok(not TS.ball.visible, "днём ребята в школе — мяча нет")
	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)
