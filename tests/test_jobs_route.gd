extends SceneTree
## Работы «по точкам» (посылки, попутчик, заправщик), подсветка того, с чем
## можно взаимодействовать, стрелка-навигатор и вода (колонка, магазин).
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
## Подвезти транспорт к точке и постоять.
func arrive(v, p: Vector3) -> void:
	v.global_position = p + Vector3(0, 0.2, 0)
	v.speed = 0.0; v.velocity = Vector3.ZERO
	await frames(6)

func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager"); var NM = root.get_node("NeedsManager")
	var QM = root.get_node("QuestManager")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	TM.minutes = 10 * 60.0
	var P = W.get_node("Player")
	var M = W.get_node("Moped")
	var hud = child("hud.gd")

	print("== Подсветка и навигатор")
	P.global_position = M.global_position + Vector3(0, 0.1, 1.2)
	await frames(4)
	for i in 3: await process_frame
	ok(P._mark.visible and P._mark.global_position.distance_to(M.global_position) < 0.6, "у мопеда — светящееся кольцо и стрелка")
	P.global_position = Vector3(-140, 0.1, -30)
	await frames(4)
	for i in 3: await process_frame
	ok(not P._mark.visible, "отошёл — подсветка погасла")
	var nav = hud.nav
	QM.quests.m_morning.state = 2
	QM.quests.m_wheels.state = 1
	QM.quests.m_wheels.step = 1
	for i in 3: await process_frame
	ok(nav.visible and nav._label.text.contains("АЗС"), "по заданию «заправься» стрелка ведёт на АЗС: " + nav._label.text)
	QM.quests.m_wheels.state = 0
	QM.quests.m_wheels.step = 0

	print("== Почта: посылки по домам на мопеде")
	var PS = W.post
	ok(PS.offices.size() == 6, "почты: %s" % ", ".join(PS.offices.map(func(o): return o.name)))
	var PJ = W.post_job
	P.global_position = PJ.giver + Vector3(0, 0.1, 0.3)
	await frames(4)
	ok(PJ._sign.visible and PJ._sign.text == "ПО ДОМАМ", "над окошком почты — «ПО ДОМАМ»")
	ok(P.current_prompt().contains("посылки по домам") and P.current_prompt().contains("грн"), "подсказка с заказом: " + P.current_prompt())
	var offered: Array = PJ.offer()
	PJ.start()
	ok(PJ.active and PJ.stops == offered and PJ.stops.size() == 3 and PJ.pay >= 100, "взял тот же заказ: 3 адреса, %d грн" % PJ.pay)
	ok(GM.nav_target == PJ.stops[0][1] and PJ._beacon.visible, "столб света и стрелка — к первому дому")
	ok(GM.challenge_line.contains("Почта") and GM.challenge_line.contains("дом"), "в строке задания: " + GM.challenge_line)
	ok(W.hitch_job.prompt().contains("сначала закончи"), "вторую работу сразу не взять")
	M._on_enter()
	await frames(3)
	var cargo: Node = M.get_node_or_null("Cargo")
	ok(cargo != null, "коробки — на багажнике мопеда")
	var money0: int = GM.money
	await arrive(M, PJ.stops[0][1])
	ok(PJ.idx == 1 and PJ._load == 2 and GM.nav_target == PJ.stops[1][1], "первую посылку вручил — осталось 2")
	var dropped: Array = PJ.get_children().filter(func(c): return c.name.begins_with("Dropped"))
	ok(dropped.size() == 1 and (dropped[0] as Node3D).global_position.distance_to(PJ.stops[0][2]) < 0.5, "коробка лежит у калитки")
	await arrive(M, PJ.stops[1][1])
	await arrive(M, PJ.stops[2][1])
	for i in 2: await process_frame
	ok(not PJ.active and GM.money == money0 + PJ.pay and GM.nav_target == Vector3.INF, "все три — +%d грн, стрелка погасла" % PJ.pay)
	ok(M.get_node_or_null("Cargo") == null, "багажник пуст")
	ok(QM.stats.earned >= PJ.pay, "заработок засчитан в задания")

	print("== Почта: мешок в другое отделение")
	var BJ = PS.offices[0].bag_job
	P.global_position = BJ.giver + Vector3(0, 0.1, 0.3)
	await frames(3)
	ok(BJ.prompt().contains("мешок посылок") and BJ.prompt().contains("почта"), "подсказка: " + BJ.prompt())
	BJ.start()
	await frames(2)
	for i in 2: await process_frame
	var bag: Node = M.get_node_or_null("Cargo")
	ok(BJ.active and BJ.stops.size() == 1 and bag != null, "мешок на мопеде: %s, %d грн" % [BJ.stops[0][0], BJ.pay])
	money0 = GM.money
	await arrive(M, BJ.stops[0][1])
	for i in 2: await process_frame
	ok(not BJ.active and GM.money == money0 + BJ.pay and BJ._load == 0, "сдал мешок: +%d грн" % BJ.pay)
	M.speed = 0.0; M.exit_car(); await frames(3)

	print("== Попутчик")
	var HJ = W.hitch_job
	ok(HJ._rider.visible and HJ._rider.global_position.distance_to(W.HITCH_POS) < 2.0, "у съезда на трассу голосует попутчик")
	P.global_position = W.HITCH_POS + Vector3(0, 0.1, 0.5)
	await frames(3)
	HJ.start()
	ok(HJ.active and HJ.stops.size() == 1, "взял попутчика: %s, %d грн" % [HJ.stops[0][0], HJ.pay])
	M.global_position = W.HITCH_POS + Vector3(2, 0.2, 0)
	M._on_enter()
	await frames(4)
	for i in 2: await process_frame
	ok(HJ._rider_sit.get_parent() == M and HJ._rider_sit.visible and not HJ._rider.visible, "попутчик сел сзади на мопед")
	money0 = GM.money
	await arrive(M, HJ.stops[0][1])
	for i in 2: await process_frame
	ok(not HJ.active and GM.money == money0 + HJ.pay, "довёз попутчика: +%d грн" % HJ.pay)
	ok(HJ._rider.visible and HJ._rider.global_position.distance_to(HJ.stops[0][1]) < 3.0 and not HJ._rider_sit.visible, "попутчик вышел у цели")
	M.speed = 0.0; M.exit_car(); await frames(3)

	print("== Заправщик на АЗС")
	var ZJ = W.pump_job
	P.global_position = ZJ.giver + Vector3(0, 0.1, 0)
	await frames(3)
	ZJ.start()
	ok(ZJ.active and ZJ.mode == "foot" and ZJ._prop != null, "смена заправщика: у колонки стоит машина клиента")
	var t0: float = TM.minutes
	money0 = GM.money
	for i in 4:
		P.global_position = ZJ.stops[i][1] + Vector3(0, 0.1, 0)
		await frames(4)
	ok(not ZJ.active and GM.money == money0 + 140, "заправил 4 машины: +140 грн")
	ok(TM.minutes - t0 < 10.0, "часы не перемотаны: прошло %.1f мин" % (TM.minutes - t0))

	print("== Вода")
	NM.water = 10.0
	P.global_position = W.PUMP_POS + Vector3(0, 0.1, 0.6)
	await frames(4)
	ok(P.current_prompt().contains("попить"), "у колонки: " + P.current_prompt())
	P._use()
	ok(NM.water == 100.0, "напился из колонки — 100%")
	NM.water = 30.0
	GM.money = 100
	W._buy_water()
	ok(NM.water == 100.0 and GM.money == 100 - W.WATER_PRICE, "бутылка воды в сельмаге")
	NM.water = 0.5; NM.energy = 80.0; NM.food = 80.0
	TM.advance(20.0)
	for i in 2: await process_frame
	ok(NM.water == 0.0 and NM.energy > 0.0 and last().contains("пить"), "жажда напоминает, но в обморок не валит: " + last())
	ok(hud._needs != null and hud.RINGS.size() == 3, "в HUD — кольцо воды")
	var st: Dictionary = NM.save_state()
	NM.water = 77.0
	NM.load_state(st)
	ok(NM.water == 0.0, "вода сохраняется")
	NM.load_state({"food": 50.0})
	ok(NM.water == 90.0, "старое сохранение — вода по умолчанию")
	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)
