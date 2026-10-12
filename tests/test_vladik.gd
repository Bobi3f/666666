extends SceneTree
## Дядя Владик: гараж на окраине, распорядок (не стоит столбом), замечает
## игрока, первая встреча и «Оживить Карпаты» от начала до награды,
## запчасти по состоянию, ремонт по уровню доверия, скупка, работа,
## уровни, ночью закрыто, сохранение.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func step(id: String) -> int:
	var Q = root.get_node("QuestManager")
	return int(Q.quests[id].step) if int(Q.quests[id].state) == 1 else -1
func _run() -> void:
	await frames(10)
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager"); var Q = root.get_node("QuestManager")
	var PR = root.get_node("Progress"); var WM = root.get_node("WeatherManager")
	WM.set_kind(0, 9999.0)
	TM.minutes = 10 * 60.0
	var vl: Vladik = W.get_node("Vladik")
	var P = W.get_node("Player")
	ok(vl != null and vl.global_position.distance_to(VladikGarage.POS) < 1.0, "Владик в своём гараже на окраине")
	ok(VladikGarage.POS.x < -200.0, "гараж — западнее домов Каменки")
	print("== Распорядок")
	P.global_position = VladikGarage.w(Vector3(0, 0.3, 30))
	var seen := {}
	for i in 1500:
		await process_frame
		# Ускоряем: каждое дело — по полсекунды
		if vl._timer > 0.2: vl._timer = 0.2
		seen[vl.state] = true
		if seen.size() >= 5: break
	ok(seen.has(Vladik.State.WALK) and seen.size() >= 5, "ходит и занимается делами: %s" % str(seen.keys().map(func(s): return Vladik.State.keys()[s])))
	vl._go("bench", Vladik.State.WORK_AT_BENCH, 5.0)
	for i in 300:
		await process_frame
		if vl.state == Vladik.State.WORK_AT_BENCH: break
	ok(vl.state == Vladik.State.WORK_AT_BENCH and vl.pose() == "work", "работает у верстака (поза work)")
	var a0: Basis = vl._arm.basis
	await frames(6)
	ok(not vl._arm.basis.is_equal_approx(a0), "рука с ключом ходит")
	P.global_position = vl._body.global_position + Vector3(1.5, 0.3, 1.5)
	await frames(4)
	ok(vl.state == Vladik.State.TALK and vl.pose() == "talk", "игрок подошёл — бросил дело и смотрит на него")
	P.global_position = VladikGarage.w(Vector3(0, 0.3, 30))
	await frames(4)
	ok(vl.state != Vladik.State.TALK, "игрок ушёл — снова за работу")
	print("== Первая встреча и «Оживить Карпаты»")
	var zone: InteractZone = vl._zone
	ok(zone.text().contains("Дядей Владиком") and zone.text().contains("(!)"), "подсказка: " + zone.text())
	var moped: Vehicle = GM.moped
	moped.global_position = VladikGarage.w(VladikGarage.MOPED_SPOT + Vector3(0, 0.15, 0))
	for i in 5: await physics_frame
	vl.open_talk()
	await frames(2)
	ok(vl.met and vl.panel.visible and vl.panel._said.text.contains("Это ты его таким купил?"), "первая встреча с мопедом: «Это ты его таким купил?»")
	vl.panel.close_panel()
	for i in 300:
		await process_frame
		if step("vl_karpaty") == 1: break
	ok(step("vl_karpaty") == 1, "задание начато, мопед в гараже засчитан (шаг %d)" % step("vl_karpaty"))
	ok(vl._moped_zone.text().contains("осмотреть двигатель"), "у мопеда: " + vl._moped_zone.text())
	vl.work_on_moped()
	ok(step("vl_karpaty") == 2, "осмотрели — нашли неисправность")
	GM.money = 1000
	ok(vl.buy_good("plug") and vl.buy_good("oil2t", "used"), "купил свечу и масло (б/у дешевле)")
	ok(GM.money == 1000 - Vladik.good_price("plug", "new") - Vladik.good_price("oil2t", "used"), "цены по состоянию: свеча %d, масло б/у %d" % [Vladik.good_price("plug", "new"), Vladik.good_price("oil2t", "used")])
	ok(Vladik.good_price("chain", "new") > Vladik.good_price("chain", "used") and Vladik.good_price("chain", "used") > Vladik.good_price("chain", "old"), "новая дороже б/у, б/у дороже старой")
	await frames(2)
	ok(step("vl_karpaty") == 4, "свеча и масло куплены — дальше цепь (шаг %d)" % step("vl_karpaty"))
	vl.work_on_moped(); vl.work_on_moped(); vl.work_on_moped()
	ok(step("vl_karpaty") == 7 and not Q.items.has("plug") and not Q.items.has("oil2t"), "цепь, бензокран, ремонт — свеча и масло ушли в мопед")
	moped.health["engine"] = 30.0
	moped.engine_on = true
	for i in 300:
		await process_frame
		if step("vl_karpaty") == 8: break
	ok(step("vl_karpaty") == 8, "завёл «Карпаты»")
	var money0: int = GM.money
	vl.open_talk()
	vl.panel._main()
	var said: String = vl.chat()
	vl.panel.close_panel()
	ok(said.contains("Слышишь, как поёт"), "вернулся к Владику: " + said.left(40))
	ok(Q.quests.vl_karpaty.state == 2 and GM.money == money0 + 300, "задание выполнено, +300 грн")
	ok(moped.part_health("engine") >= 99.0, "мопед — как новый")
	ok(vl.rep == VladikData.FIRST_REP and vl.level() == 2, "доверие %d — уровень %d (ремонт мотоциклов)" % [vl.rep, vl.level()])
	print("== Работа и уровни")
	var job: String = vl.offer_job()
	ok(job.contains("Новое задание") and Q.quests.vl_fuel.state == 1, "получил работу: " + job.left(50))
	ok(vl.offer_job().contains("сперва"), "пока не сделал — новую не даёт")
	PR.canister_l = 0.0
	W.buy_canister()
	ok(step("vl_fuel") == 1, "купил канистру на АЗС")
	Q.talk(VladikData.NAME)
	ok(Q.quests.vl_fuel.state == 2 and PR.canister_l < 0.5, "отдал канистру Владику — задание выполнено")
	ok(vl.offer_job().contains("Новое задание") and Q.quests.vl_junk.state == 1, "следующая работа — на свалку")
	ok(vl._junk_zone.text().contains("колесо"), "на свалке куча лома: " + vl._junk_zone.text())
	vl.search_junk()
	ok(int(Q.items.get("old_wheel", 0)) == 1 and step("vl_junk") == 1, "нашёл колесо")
	Q.talk(VladikData.NAME)
	ok(Q.quests.vl_junk.state == 2, "отдал колесо")
	vl.offer_job()
	ok(Q.quests.vl_dismantle.state == 1 and vl._wreck_zone.text().contains("разбирать"), "разборка «копейки»: " + vl._wreck_zone.text())
	for i in 3: vl.dismantle()
	ok(step("vl_dismantle") == 1 and vl.sellable().size() >= 1, "три захода — детали в запасе: %s" % str(vl.sellable()))
	Q.talk(VladikData.NAME)
	print("== Торговля")
	var sold: Array = vl.sellable()[0]
	var m1: int = GM.money
	ok(vl.sell_item(sold[0]) and GM.money == m1 + int(VladikData.BUYS[sold[0]][1]), "продал Владику %s за %d" % [sold[0], int(VladikData.BUYS[sold[0]][1])])
	var java: Vehicle = W.get_node("Moto")
	PR.buy_car("moto")
	java.global_position = VladikGarage.w(Vector3(-1.5, 0.2, 2.5))
	for i in 5: await physics_frame
	ok(vl.nearby_vehicles().has(java), "своя «Ява» у гаража видна")
	java.health["brakes"] = 10.0
	ok(vl.can_repair(java) and not vl.can_repair(W.get_node("Car")), "мотоциклы чинит (уровень %d), машины — пока нет" % vl.level())
	var pn: int = Vladik.repair_price(java, "brakes", "new"); var pu: int = Vladik.repair_price(java, "brakes", "used"); var po: int = Vladik.repair_price(java, "brakes", "old")
	ok(pn > pu and pu > po, "ремонт по состоянию детали: %d / %d / %d грн" % [pn, pu, po])
	GM.money = 5000
	ok(vl.repair_part(java, "brakes", "used") and is_equal_approx(java.part_health("brakes"), 70.0), "поставил б/у колодки — ресурс 70%")
	ok(not vl.repair_part(java, "brakes", "old"), "старая хуже стоящей — не ставит")
	var price: int = vl.vehicle_price(java)
	ok(price > JunkPanel.sell_price(java), "за «Яву» Владик даёт больше свалки: %d > %d" % [price, JunkPanel.sell_price(java)])
	ok(vl.sell_vehicle(java) and not PR.owns("moto"), "продал «Яву» Владику")
	print("== Доверие и редкое")
	vl.add_rep(60)
	ok(vl.level() == 5, "доверие %d — уровень 5" % vl.rep)
	ok(vl.can_repair(W.get_node("Car")) == PR.owns("car"), "машины чинит с уровня 4 (свои)")
	print("== Ночь и сохранение")
	TM.minutes = 22 * 60.0
	await frames(3)
	ok(not vl.visible and not vl._zone.monitoring, "ночью гараж закрыт")
	TM.minutes = 10 * 60.0
	var st: Dictionary = vl.save_state()
	vl.load_state({})
	ok(vl.rep == 0 and not vl.met, "старое сохранение — не знакомы")
	vl.load_state(st)
	ok(vl.rep == st.rep and vl.met, "доверие и знакомство сохраняются")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
