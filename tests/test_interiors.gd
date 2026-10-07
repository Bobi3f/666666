extends SceneTree
## Внутри зданий: банк, больница, ПТУ, завод — вход и выход через дверь,
## у каждого свой интерьер и дела внутри; смена на заводе (официальная
## работа); уровни работ: подработка — 3, официальная — 5, плата растёт.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await frames(12)
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress"); var TM = root.get_node("TimeManager")
	var I: Interiors = W.interiors
	var P: Node3D = GM.player
	ok(I != null and I.get_child_count() > 4, "интерьеры построены")
	print("== Вход и выход")
	for id in Interiors.ROOMS:
		var door: InteractZone = I.get_node("Door_" + id)
		ok(door.prompt_fn.call().begins_with("E — войти"), "%s: дверь — %s" % [id, door.prompt_fn.call()])
		door.activated.emit()
		await frames(3)
		var room: Node3D = I.get_node("Room_" + id)
		ok(GM.indoors == id and room.visible and P.global_position.y > 300.0, "%s: внутри, помещение видно" % id)
		ok(P.global_position.y > 399.0 and P.global_position.y < 402.0, "%s: стоит на полу (%.1f)" % [id, P.global_position.y])
		var zones := room.find_children("*", "InteractZone", true, false)
		# У завода работа — отдельный узел (отдел кадров), в комнате — выход
		ok(zones.size() >= (1 if id == "factory" else 2), "%s: внутри %d мест для дела" % [id, zones.size()])
		I.leave()
		await frames(3)
		ok(GM.indoors == "" and not room.visible and P.global_position.distance_to(Town.w(Interiors.ROOMS[id][2])) < 1.5, "%s: вышел на крыльцо" % id)
	print("== Банк внутри")
	I.enter("bank")
	await frames(2)
	GM.money = 1300
	var d0: int = root.get_node("Daily").deposit
	var put: InteractZone = null
	for z in I.get_node("Room_bank").find_children("*", "InteractZone", true, false):
		if String((z as InteractZone).prompt_fn.call()).contains("положить"): put = z
	put.activated.emit()
	ok(root.get_node("Daily").deposit == d0 + 1000 and GM.money == 300, "положил на вклад в окошке")
	print("== Сам вышел не через дверь (сон, автобус)")
	P.global_position = Vector3(-125, 0.2, -50)
	await create_timer(0.7).timeout
	ok(GM.indoors == "" and not I.get_node("Room_bank").visible, "помещение спряталось само")

	print("== Завод — официальная работа")
	var F: RouteJob = I.factory_job
	TM.minutes = 10 * 60.0
	TM.day = 2
	PR.docs.erase("work_book")
	ok(F.prompt().contains("трудовой книжки"), "без трудовой не берут: " + F.prompt())
	PR.add_doc("work_book")
	ok(F.prompt().begins_with("E — Завод") and F.prompt().contains("ур. 1/5"), "с трудовой: " + F.prompt())
	var m0: int = GM.money
	F.start()
	ok(F.active and F.stops.size() == 4 and (F.stops[0][1] as Vector3).y > 300.0, "смена: четыре станка в цеху")
	F.complete_all()
	TM.finish_work()
	ok(GM.money == m0 + 480 and JobLevels.xp("factory") == 1, "смена: +480 грн, опыт 1")

	print("== Уровни работ")
	ok(JobLevels.max_level("kolkhoz") == 3 and JobLevels.max_level("factory") == 5 and JobLevels.max_level("bus_shift") == 5, "подработка — 3 уровня, официальная — 5")
	PR.job_xp["factory"] = 25
	ok(JobLevels.level("factory") == 5 and JobLevels.pay("factory", 480) == 960, "завод, 25 смен: 5/5 «%s», плата ×2" % JobLevels.level_name("factory"))
	PR.job_xp["kolkhoz"] = 3
	var K = W.kolkhoz_job
	ok(K.start_prompt().contains("ур. 1/3"), "колхоз: " + K.start_prompt())
	JobLevels.add("kolkhoz")
	ok(JobLevels.level("kolkhoz") == 2 and K.start_prompt().contains("× 60 грн") and K.start_prompt().contains("опытный"), "4 смены — опытный, 60 грн за тюк: " + K.start_prompt())
	var st: Dictionary = PR.save_state()
	PR.job_xp = {}
	PR.load_state(st)
	ok(JobLevels.xp("kolkhoz") == 4 and JobLevels.xp("factory") == 25, "опыт работ сохраняется")
	PR.job_xp = {}

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit(1 if fails else 0)
