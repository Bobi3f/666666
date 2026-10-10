extends SceneTree
## Работы по шагам: сено в телегу в колхозе, мешки в грузовик на складе.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
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
func zone_at(job, pos: Vector3) -> InteractZone:
	for c in job.get_children():
		if c is InteractZone and c.position.distance_to(pos) < 0.1: return c
	return null

func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager")
	var NM = root.get_node("NeedsManager"); var WM = root.get_node("WeatherManager")
	var QM = root.get_node("QuestManager")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	var P = W.get_node("Player")
	WM.set_kind(0, 9999.0)
	var events := {}
	QM.fired.connect(func(n: String, _a: float) -> void: events[n] = int(events.get(n, 0)) + 1)

	print("== Колхоз: сено в телегу")
	var K: CarryJob = W.kolkhoz_job
	TM.minutes = 23 * 60.0
	K.start()
	ok(not K.active and last().contains("7:00"), "ночью бригадира нет: " + last())
	TM.minutes = 9 * 60.0
	NM.energy = 100.0
	GM.money = 0
	K.start()
	ok(K.active and GM.challenge_line.contains("0 из 8"), "смена началась: " + GM.challenge_line)
	ok(K._arrow.visible and K._arrow.global_position.distance_to(K.pickup) < 4.0, "стрелка над стогом")
	P.global_position = K.pickup + Vector3(0, 0.1, 0)
	await frames(5)
	var take := zone_at(K, K.pickup)
	ok(take != null and take.text().contains("взять"), "у стога: " + (take.text() if take else "нет зоны"))
	take.activate()
	await frames(3)
	ok(K.carrying and K._held.visible and not K._pile[0].visible, "тюк в руках, в куче меньше")
	ok(K._held.global_position.distance_to(P.global_position) < 1.6, "тюк перед грудью")
	ok(K._arrow.global_position.distance_to(K.drop) < 4.0, "стрелка над телегой")
	var t0: float = TM.minutes
	P.global_position = K.drop + Vector3(0, 0.1, 0)
	await frames(5)
	zone_at(K, K.drop).activate()
	ok(GM.money == 50 and K.done == 1 and K._stack[0].visible and not K._held.visible, "положил тюк в телегу: +50 грн")
	ok(TM.minutes - t0 < 5.0 and not TM.busy(), "часы не перемотаны: %.1f мин" % (TM.minutes - t0))
	for i in 7:
		K.pick(); K.put_down()
	ok(not K.active and GM.money == 400 and events.has("kolkhoz") and GM.challenge_line == "", "8 тюков — смена окончена, 400 грн: " + last())
	var visible := 0
	for s in K._stack: if s.visible: visible += 1
	ok(visible == 8, "в телеге 8 тюков")
	await create_timer(3.5).timeout
	ok(K.done == 0 and K._pile[0].visible and not K._stack[0].visible, "к новой смене куча снова полная")
	WM.set_kind(3, 9999.0); WM.rain = 1.0; WM.wetness = 1.0
	K.start()
	ok(not K.active and last().contains("дождь"), "в дождь сено не грузят")
	WM.set_kind(0, 9999.0); WM.rain = 0.0; WM.wetness = 0.0

	print("== Склад: мешки в грузовик")
	var S: CarryJob = W.warehouse_job
	TM.minutes = 10 * 60.0
	NM.energy = 100.0
	GM.money = 0
	S.start()
	ok(S.active and S.total == 10, "смена грузчика")
	P.global_position = S.pickup + Vector3(0, 0.1, 0)
	await frames(5)
	S.pick()
	P.global_position = S.drop + Vector3(0, 0.1, 0)
	await frames(3)
	S.put_down()
	S.pick(); S.put_down()
	ok(GM.money == 120 and S.done == 2, "два мешка в кузове: +120")
	# Ушёл далеко — смена брошена, заплачено за донесённое
	P.global_position = S.drop + Vector3(80, 0.1, 0)
	await frames(5)
	ok(not S.active and GM.money == 120 and last().contains("брошена"), "ушёл — смена брошена: " + last())
	events.erase("shift")
	S.simulate_all()
	ok(GM.money == 720 and events.has("shift"), "полная смена: 600 грн")
	NM.energy = 1.0
	await create_timer(3.5).timeout
	S.start()
	ok(not S.active, "без сил на склад не берут")
	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)
