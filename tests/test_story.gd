extends SceneTree
## Сюжет после кирпичного дома: главы 9–15 — колесо обозрения с Олей,
## бурса, подмастерье на СТО, своё СТО с Васьком, свадьба, рейсовый автобус,
## хозяин района и финал. Плюс просьбы жителей в городе и в сёлах района,
## доходы своего дела и старое сохранение.
var fails := 0
var W
var msgs: Array[String] = []
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func last() -> String:
	return msgs[-1] if msgs.size() else ""
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func _zones(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is InteractZone: out.append(c)
		out.append_array(_zones(c))
	return out
func zone_named(n: String) -> InteractZone:
	return W.find_child(n, true, false) as InteractZone
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	current_scene = W
	_run.call_deferred()
func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress"); var TM = root.get_node("TimeManager")
	var NM = root.get_node("NeedsManager"); var DL = root.get_node("Daily"); var QM = root.get_node("QuestManager")
	GM.message.connect(func(t: String) -> void: msgs.append(t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	# Поручения и доход дела мешают считать деньги — отключаем
	TM.minute_passed.disconnect(DL._on_minutes)
	QM.fired.disconnect(DL._on_event)
	await frames(3)
	var P = W.get_node("Player")
	var girl = W.get_tree().get_first_node_in_group("girl")
	var east = W.get_node("TownEast")
	var state := func(id: String) -> int: return QM.quests[id].state
	var step := func(id: String) -> int: return QM.quests[id].step
	var near := func(p: Vector3) -> void:
		P.global_position = p + Vector3(0, 0.1, 0)
		girl.doll.global_position = p + Vector3(1.5, 0, 0)

	print("== Старое сохранение: сюжет кончался кирпичным домом")
	var old := {"quests": {}, "won": true}
	for id in QM.MAIN.slice(0, 8):
		old.quests[id] = {"state": 2, "step": 0, "n": 0.0}
	QM.load_state(old)
	await frames(2)
	ok(state.call("m_park") == 1 and QM.active_main() == "m_park", "после «Хозяина Каменки» открылась глава «Огни города»")
	ok(QM.tracker_lines()[0].contains("колесе обозрения"), "трекер: " + QM.tracker_lines()[0])
	var nav = W.get_tree().get_first_node_in_group("nav")
	ok(nav.current()[0] == "Оля", "стрелка ведёт сперва к Оле: " + str(nav.current()))

	print("== Глава 9: колесо обозрения с Олей")
	TM.minutes = 15 * 60.0
	GM.money = 1000
	near.call(Town.w(east.WHEEL + Vector3(0, 0, 6.0)))
	east.ride_wheel()
	ok(state.call("m_park") == 1 and GM.money == 1000 - east.WHEEL_PRICE, "один — просто покатался, глава не засчитана")
	ok(girl.invite() != "" and girl.state == girl.State.FOLLOW, "позвал Олю гулять")
	near.call(Town.w(east.WHEEL + Vector3(0, 0, 6.0)))
	await frames(2)
	var rel0: int = girl.rel
	ok(zone_named("WheelZone").text().contains("с Олей"), "у колеса: " + zone_named("WheelZone").text())
	GM.money = 1000
	east.ride_wheel()
	await frames(2)
	ok(state.call("m_park") == 2 and girl.rel > rel0 and GM.money == 1000 - east.WHEEL_PRICE * 2 + 300, "с Олей на колесе — глава пройдена (+300)")
	ok(state.call("m_college") == 1, "дальше — «Бурса»")

	print("== Глава 10: бурса — три урока и экзамен")
	ok(nav.current()[0] == "Бурса", "стрелка — к бурсе")
	PR.home_items.erase("mechanic")
	GM.money = 1000
	var LP = null
	for d in 3:
		TM.day += 1; TM.minutes = 10 * 60.0
		east.take_course()
		LP = east.lesson_panel
		for i in 3: LP.answer(LP.right_index())
	await frames(2)
	ok(step.call("m_college") == 1, "три урока — шаг к экзамену")
	TM.day += 1; TM.minutes = 10 * 60.0
	east.take_course()
	for i in 5: LP.answer(LP.right_index())
	await frames(2)
	ok(PR.has_item("mechanic") and state.call("m_college") == 2 and state.call("m_sto_work") == 1, "экзамен сдан — «Подмастерье»")

	print("== Глава 11: подмастерье на СТО")
	for d in 2:
		TM.day += 1; TM.minutes = 10 * 60.0; NM.energy = 90.0
		east.shift()
	await frames(2)
	ok(step.call("m_sto_work") == 1, "две смены на СТО отработаны")
	GM.add_money(3000)
	await frames(2)
	ok(step.call("m_sto_work") == 2 and QM.has_line_for("Механик Васёк"), "заработал 3000 — Васёк ждёт разговора (!)")
	var say: String = QM.talk("Механик Васёк")
	await frames(2)
	ok(say.contains("15 000") and state.call("m_sto_work") == 2 and state.call("m_own_sto") == 1, "Васёк: «%s»" % say.left(50))

	print("== Глава 12: своё СТО и Васёк")
	GM.money = 15000
	ok(DL.buy("sto"), "выкупил СТО у Каменки")
	await frames(2)
	ok(step.call("m_own_sto") == 1 and DL.income("sto") == 600, "СТО твоё: +600 в день")
	say = QM.talk("Механик Васёк")
	await frames(2)
	ok(DL.hired.has("vasya") and DL.income("sto") == 900, "нанял Васька: СТО даёт +900 в день")
	ok(state.call("m_own_sto") == 2 and GM.money >= 1000 and state.call("m_wedding") == 1, "«Своё СТО» пройдено (+1000), дальше — «Свадьба»")

	print("== Своё дело окупается")
	var pay := func(id: String) -> float: return float(DL.BUSINESSES[id].price) / float(DL.BUSINESSES[id].income)
	ok(pay.call("kiosk") <= 25.0 and pay.call("sto") <= 25.0 and pay.call("kiosk2") <= 25.0, "ларёк, СТО, ларёк Жоры окупаются за %d, %d, %d дней" % [pay.call("kiosk"), pay.call("sto"), pay.call("kiosk2")])
	ok(DL.INTEREST_YEAR / DL.YEAR_DAYS * 25.0 < 0.15, "вклад за то же время даёт меньше 15%")

	print("== Глава 13: свадьба")
	girl.send_home()
	girl.rel = 69
	girl.like(1)
	await frames(2)
	ok(step.call("m_wedding") == 1, "Оля — твоя девушка")
	ok(nav.current()[0].contains("свадьбе"), "стрелка — к лавке на рынке: " + str(nav.current()))
	var south = W.get_node("TownSouth")
	var stall: InteractZone = null
	for z in _zones(south):
		if z.name.ends_with("wedding"): stall = z
	TM.minutes = 10 * 60.0
	ok(stall != null and stall.text().contains("кольцо"), "на рынке лавка «К свадьбе»: " + (stall.text() if stall else ""))
	ok(Town.w(Vector3(62.5, 0, 149.0)).distance_to(stall.global_position) < 3.0, "стрелка ведёт к самой лавке")
	stall.activated.emit()
	var MP = south.market_panel
	GM.money = 5000
	ok(MP.visible and MP.buy("ring") and MP.buy("dress") and GM.money == 5000 - 1500 - 1200, "купил кольцо и платье")
	MP.close_panel()
	await frames(2)
	ok(step.call("m_wedding") == 2, "дальше — столик в «Метелице»")
	var club = W.get_node("ClubTown")
	TM.minutes = 21.5 * 60.0
	var table := zone_named("DateTable")
	near.call(table.global_position)
	club._paid_day = club._night()
	ok(table.text().contains("девушкой"), "без Оли столик не дают: " + table.text())
	ok(girl.invite() != "" and girl.state == girl.State.FOLLOW, "своя девушка идёт гулять и в 21:30")
	near.call(table.global_position)
	await frames(2)
	ok(table.text().contains("столик на двоих"), "с Олей: " + table.text())
	GM.money = 1000
	club.date()
	await frames(2)
	ok(step.call("m_wedding") == 3 and GM.money == 700, "ужин при свечах — «%s»" % last().left(40))
	girl.send_home()
	ok(not girl.engaged and girl.propose().contains("Да") and girl.engaged and girl.level() == "невеста", "предложение — Оля сказала «да»")
	await frames(2)
	ok(step.call("m_wedding") == 4, "дальше — сельсовет")
	var civic = child("civic.gd")
	var zags := zone_named("ZagsZone")
	while TM.weekday() == "вс": TM.day += 1
	TM.minutes = 11 * 60.0
	near.call(zags.global_position)
	ok(zags.text().contains("невеста где"), "без невесты не распишут: " + zags.text())
	girl.invite()
	near.call(zags.global_position)
	await frames(2)
	ok(zags.text().contains("расписаться"), "ЗАГС: " + zags.text())
	GM.money = 0
	civic.wedding()
	await frames(2)
	ok(girl.married and state.call("m_wedding") == 2 and GM.money == 2000, "свадьба! +2000 от гостей")
	ok(girl.home_pos() == girl.WIFE_HOME and girl.level() == "жена", "Оля живёт у тебя во дворе")
	girl.send_home()
	TM.day += 1
	NM.food = 20.0
	girl.talk()
	ok(NM.food > 60.0 and girl.talk_day == TM.day, "жена кормит обедом: сытость %d" % int(NM.food))
	var gs: Dictionary = girl.save_state()
	girl.load_state({})
	ok(not girl.married, "старое сохранение — не женат")
	girl.load_state(gs)
	ok(girl.married and girl.engaged, "свадьба сохраняется")

	print("== Глава 14: рейсовый")
	ok(state.call("m_bus") == 1, "дальше — «Рейсовый»")
	PR.add_category("D"); QM.event("license_d")
	PR.add_doc("work_book"); QM.event("doc_work_book")
	await frames(2)
	ok(step.call("m_bus") == 2, "категория D и трудовая есть")
	var school = W.get_node("AutoSchool")
	TM.day += 1; TM.minutes = 8 * 60.0; NM.energy = 90.0
	GM.money = 0
	school._bus_shift(); school._bus_shift()
	await frames(2)
	ok(state.call("m_bus") == 2 and state.call("m_district") == 1 and GM.money == 2000, "два рейса по 500 (+1000 за главу) — «Хозяин района»")

	print("== Глава 15: хозяин района и финал")
	GM.money = 5000
	ok(DL.buy("kiosk"), "выкупил ларёк")
	await frames(2)
	ok(step.call("m_district") == 1, "дальше — Жора")
	DL.rival = DL.Rival.ACTIVE
	GM.money = 7000
	ok(DL.buy_rival(), "перекупил ларёк Жоры")
	await frames(2)
	ok(step.call("m_district") == 2, "дальше — автопарк")
	for k in ["car", "niva", "volga"]:
		PR.buy_car(k)
	var journal = child("journal.gd")
	ok(DL.buy("fleet"), "открыл автопарк")
	await frames(3)
	ok(QM.won and state.call("m_district") == 2, "победа: хозяин района")
	var t0 := Time.get_ticks_msec()
	while not journal.is_open() and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	ok(journal.is_open() and journal._title.text.contains("хозяин района"), "экран победы: " + journal._title.text)
	journal._close()
	ok(QM.tracker_lines()[0].contains("Мастер на все руки"), "после победы — вторая часть: " + QM.tracker_lines()[0])

	print("== Главы засчитываются наперёд")
	QM.reset()
	var old2 := {"quests": {}}
	for id in QM.MAIN.slice(0, 9):
		old2.quests[id] = {"state": 2, "step": 0, "n": 0.0}
	QM.load_state(old2)
	await frames(4)
	ok(state.call("m_college") == 2 and state.call("m_sto_work") == 1, "корочка уже есть — «Бурса» засчитана сама")

	print("== Просьбы в сёлах района")
	var region = W.get_node("Region")
	var names := []
	for v in region.VILLAGES:
		names.append(v.who)
	var found := 0
	for z in _zones(region):
		for n in names:
			if (z as InteractZone).text().contains(n): found += 1
	ok(found == 12, "у магазина каждого из 12 сёл — житель с именем: %d" % found)
	var with_quest := 0
	for n in names:
		for id in QM.QUESTS:
			if QM.QUESTS[id].get("giver", "") == n: with_quest += 1
	ok(with_quest == 12, "у каждого — своя просьба")
	NM.fish = 3
	ok(QM.talk("Дядя Коля из Озерцово").contains("три рыбы") and state.call("v_ozertsovo") == 1, "дядя Коля просит рыбу")
	ok(QM.talk("Дядя Коля из Озерцово").contains("уха") and state.call("v_ozertsovo") == 2 and NM.fish == 0, "отдал три рыбы")
	QM.talk("Пасечник Иван из Заречья")
	ok(int(QM.items.get("honey", 0)) == 1 and QM.has_line_for("Баба Галя"), "Иван дал мёд — у бабы Гали (!)")
	ok(QM.talk("Пасечник Иван из Заречья") == "", "Иван ждёт, пока отвезёшь")
	ok(QM.talk("Баба Галя").contains("Мёд от Ивана") and not QM.items.has("honey"), "отдал мёд бабе Гале")
	GM.money = 0
	QM.talk("Пасечник Иван из Заречья")
	ok(state.call("v_zarechye") == 2 and GM.money == 300, "Иван благодарит: +300")
	ok(state.call("s_galya") == 0, "своя просьба бабы Гали не началась от чужого мёда")

	print("== Просьбы в городе")
	var town := ["Мастер Николаич", "Продавщица Зоя", "Лейтенант Сидоренко", "Дворник Степаныч", "Студент Димка"]
	var tz := 0
	for z in _zones(east):
		for n in town:
			if (z as InteractZone).text().contains(n): tz += 1
	ok(tz == 5, "пять горожан с просьбами: %d" % tz)
	QM.talk("Студент Димка")
	QM.event("race_won")
	GM.money = 0
	ok(QM.talk("Студент Димка").contains("бурса") and GM.money == 400, "Димка: обогнал Кольку — +400")

	print("== Сельсовет: почта, паспорт и ЗАГС не перекрываются")
	var desk := zone_named("CouncilDesk")
	var post_z: InteractZone = null
	for z in _zones(W):
		if z.global_position.distance_to(Civic.COUNCIL + Civic.KAMENKA_WINDOW) < 1.5 and z != desk: post_z = z
	var box := func(z: InteractZone) -> AABB:
		var sh := (z.get_child(0) as CollisionShape3D).shape as BoxShape3D
		return AABB(z.global_position - sh.size * 0.5 + Vector3(0, sh.size.y * 0.5, 0), sh.size)
	ok(post_z != null, "окошко почты найдено")
	if post_z:
		ok(not box.call(desk).intersects(box.call(post_z)), "окошко почты и стол паспортистки не перекрываются")
		ok(not box.call(zags).intersects(box.call(post_z)) and not box.call(zags).intersects(box.call(desk)), "ЗАГС стоит отдельно")

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
