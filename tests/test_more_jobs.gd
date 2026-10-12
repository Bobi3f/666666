extends SceneTree
## Новые работы: хлебовоз (три села, лотки на транспорте), дворник (кучи
## листьев, у каждой — работа метлой), садовник в Липках, лесоруб (брёвна).
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
	await frames(10)
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager"); var NM = root.get_node("NeedsManager")
	var jobs: Dictionary = W.more_jobs
	ok(jobs.size() == 4, "четыре новые работы: %s" % ", ".join(jobs.keys()))

	print("== Хлебовоз")
	TM.minutes = 7 * 60.0
	var B: RouteJob = jobs.bread
	ok(B.prompt().begins_with("E — Хлебовоз: хлеб в"), "у хлебозавода: " + B.prompt())
	var m0: int = GM.money
	B.start()
	ok(B.active and B.stops.size() == 3 and B._load == 6, "взял 6 лотков на три села")
	var pay: int = B.pay
	B.complete_all()
	ok(not B.active and GM.money == m0 + pay and pay >= 100, "развёз хлеб: +%d грн" % pay)
	TM.minutes = 14 * 60.0
	ok(B.prompt().contains("с 5:00 до 12:00"), "после обеда хлеб не возят")

	print("== Дворник")
	TM.minutes = 9 * 60.0
	var S: RouteJob = jobs.sweep
	m0 = GM.money
	S.start()
	ok(S.active and S.stops.size() == 5 and S._prop != null, "у первой кучи листьев лежит куча")
	var t0: float = TM.minutes
	S._reach()
	ok(TM.busy() and TM.work_what == "Мету листья" and TM.minutes - t0 < 1.0, "подметает: часы идут своим ходом")
	TM.finish_work()
	while S.active:
		S._reach()
		TM.finish_work()
	ok(GM.money == m0 + 150, "подмёл пять куч: +150 грн")

	print("== Садовник в Липках")
	TM.minutes = 10 * 60.0
	var G: RouteJob = jobs.garden
	ok(G.giver.distance_to(Vector3(EliteDistrict.BOULEVARD.end.x, 0, EliteDistrict.BOULEVARD.end.y)) < 8.0, "раздатчик — у въезда в Липки")
	m0 = GM.money
	G.start()
	ok(G.active and G.stops.size() == 4 and String(G.stops[0][0]).begins_with("газон у дома"), "четыре газона: " + String(G.stops[0][0]))
	for s in G.stops:
		ok(EliteDistrict.AREA.grow(5.0).has_point(Vector2((s[1] as Vector3).x, (s[1] as Vector3).z)), "газон в Липках: %s" % s[0])
	while G.active:
		G._reach()
		TM.finish_work()
	ok(GM.money == m0 + 600, "подстриг четыре газона: +600 грн")

	print("== Лесоруб")
	TM.minutes = 10 * 60.0
	NM.energy = 100.0
	var L: CarryJob = jobs.logs
	ok(Region.road_dist(L.drop.x, L.drop.z) < 12.0, "штабель — у дороги: %.1f м" % Region.road_dist(L.drop.x, L.drop.z))
	ok(L.pickup.distance_to(L.drop) > 15.0, "до делянки нести: %.0f м" % L.pickup.distance_to(L.drop))
	m0 = GM.money
	L.start()
	for i in 6:
		L.pick(); L.put_down()
	ok(not L.active and GM.money == m0 + 6 * MoreJobs.LOG_PAY, "шесть брёвен: +%d грн" % (6 * MoreJobs.LOG_PAY))
	TM.minutes = 21 * 60.0
	ok(L.can_start.call().contains("темно"), "ночью в лес не ходят")

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit(1 if fails else 0)
