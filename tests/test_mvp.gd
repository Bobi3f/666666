extends SceneTree

var msgs: Array[String] = []
var fails := 0
var W: Node

func ok(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)

func tap(code: int) -> void:
	key(code, true)
	for i in 3: await process_frame
	key(code, false)
	for i in 3: await process_frame

func _zones(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is InteractZone:
			out.append(c)
		out.append_array(_zones(c))
	return out

func zone_with(text: String) -> InteractZone:
	for z in _zones(W):
		if z.text().contains(text):
			return z
	return null

func child(script_end: String) -> Node:
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(script_end):
			return c
	return null

func last() -> String:
	return msgs[-1] if msgs.size() else ""

func state(id: String) -> int:
	return root.get_node("QuestManager").quests[id].state

func talk(npc: String) -> void:
	var z := zone_with("поговорить: " + npc)
	z.activate()

func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	current_scene = W
	_run.call_deferred()

func _run() -> void:
	await frames(5)
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager"); var NM = root.get_node("NeedsManager")
	var QM = root.get_node("QuestManager"); var PR = root.get_node("Progress"); var SM = root.get_node("SaveManager")
	var WM = root.get_node("WeatherManager")
	GM.message.connect(func(t): msgs.append(t))
	# Ежедневные поручения и доход своего дела здесь мешают считать деньги
	var DL = root.get_node("Daily")
	TM.minute_passed.disconnect(DL._on_minutes)
	QM.fired.disconnect(DL._on_event)
	child("pause_menu.gd")._close()
	WM.set_kind(0, 99999.0)
	var P = W.get_node("Player"); var C = W.get_node("Car")
	var hud = child("hud.gd")
	var journal = child("journal.gd")
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("traffic.gd"):
			c.set_physics_process(false)
			for v in c.vehicles():
				v.body.global_position.y = -50.0

	print("== Сюжет 1: Первое утро")
	await frames(3)
	ok(state("m_morning") == 1 and hud._goal.text.contains("Первое утро"), "трекер: " + hud._goal.text.split("\n")[0])
	await tap(KEY_Q)
	ok(QM.quests.m_morning.step == 1, "поел (Q) — следующий шаг")
	await tap(KEY_M)
	await tap(KEY_M)
	ok(state("m_morning") == 2 and state("m_wheels") == 1, "открыл карту — задание выполнено, дальше «Старый мопед»")

	print("== Сюжет 2: Старый мопед")
	var M = W.get_node("Moped")
	M.global_position = Vector3(-195, 0.1, 2.0); M.rotation.y = -PI / 2.0; M.fuel = 5.0
	M.speed = 0.0; M.velocity = Vector3.ZERO
	await frames(3)
	M._on_enter()
	key(KEY_W, true)
	for i in 60 * 30:
		await physics_frame
		if QM.quests.m_wheels.step == 1:
			break
	key(KEY_W, false)
	var driven: float = QM.stats.km * 1000.0
	ok(driven > 300.0, "реальная езда на мопеде засчитывается: %.0f м" % driven)
	if QM.quests.m_wheels.step == 0:
		QM.event("drive_m", 500.0 - QM.quests.m_wheels.n + 1.0)
	ok(QM.quests.m_wheels.step == 1, "500 м набрано — следующий шаг: заправка")
	key(KEY_S, true)
	for i in 400:
		await physics_frame
		if M.speed_kmh() < 1.0:
			break
	key(KEY_S, false)
	M.exit_car()
	M.global_position = Vector3(-110, 0.1, 9.0); M.speed = 0.0; M.velocity = Vector3.ZERO
	await frames(3)
	GM.money = 2000
	zone_with("заправить").activate()
	ok(state("m_wheels") == 2 and state("m_money") == 1, "заправил мопед — «Первые деньги»")

	print("== Сюжет 3: Первые деньги")
	TM.minutes = 8 * 60.0; NM.energy = 100.0; NM.food = 90.0
	W.kolkhoz_job.simulate_all()
	TM.minutes = 12 * 60.0; NM.energy = 100.0
	W.kolkhoz_job.simulate_all()
	ok(state("m_money") == 2 and state("m_license") == 1, "две смены в колхозе (800) — «Права»")

	print("== Сюжет 4: Права")
	PR.add_doc("passport")
	PR.add_doc("med")
	QM.event("med_ok")
	ok(QM.quests.m_license.step == 1, "документы есть — шаг «сдай экзамен»")
	W._exam_result({"ok": true, "time": 70.0, "cones": 0})
	ok(PR.license and state("m_license") == 2 and state("m_car") == 1, "сдал на права — «Первая машина»")

	print("== Сюжет 5: Первая машина")
	P.global_position = C.global_position + Vector3(0, 0.1, 2.5)
	await frames(3)
	GM.money = 3000
	zone_with("купить «Семёрка»").activate()
	await frames(2)
	ok(C.owned() and state("m_car") == 2 and state("m_neighbours") == 1, "купил «Жигули» — «Свой среди своих»")
	P.global_position = Vector3(-60, 0.2, -30)
	await frames(2)

	print("== Просьбы жителей")
	# Баба Галя: рыба
	talk("Баба Галя")
	ok(state("s_galya") == 1 and last().contains("Новое задание"), "баба Галя дала задание")
	talk("Баба Галя")
	ok(state("s_galya") == 1 and last().contains("Жду"), "без рыбы — ждёт")
	NM.fish = 2
	var sn: int = NM.snacks
	var m0: int = GM.money
	talk("Баба Галя")
	ok(state("s_galya") == 2 and NM.fish == 0 and NM.snacks == sn + 2 and GM.money == m0 + 350, "отдал 2 рыбы: +350 грн и пирожки")
	# Петрович: две смены
	talk("Бригадир Петрович")
	TM.minutes = 8 * 60.0; NM.energy = 100.0
	W.kolkhoz_job.simulate_all()
	TM.minutes = 12 * 60.0; NM.energy = 100.0
	W.kolkhoz_job.simulate_all()
	ok(QM.quests.s_petrovich.step == 1, "две смены — вернуться к Петровичу")
	ok(zone_with("Петрович  (!)") != null, "у Петровича «(!)» в подсказке")
	talk("Бригадир Петрович")
	ok(state("s_petrovich") == 2, "Петрович выписал премию")
	ok(state("m_neighbours") == 2 and state("m_house") == 1, "две просьбы — сюжет дальше: «Новый дом»")
	# Тётя Люда: лекарство
	talk("Тётя Люда")
	var kiosk := zone_with("лекарство для тёти Люды")
	ok(kiosk != null, "в городском ларьке появилось лекарство")
	GM.money = 1000
	kiosk.activate()
	ok(QM.items.has("medicine") and QM.quests.s_lyuda.step == 1, "купил лекарство")
	ok(zone_with("батон") != null, "ларёк снова продаёт батон")
	talk("Тётя Люда")
	ok(state("s_lyuda") == 2 and not QM.items.has("medicine"), "отдал лекарство тёте Люде")
	# Почтальонка: письма
	talk("Почтальонка Оля")
	ok(int(QM.items.get("letters", 0)) == 3, "получил 3 письма")
	var vil = child("villagers.gd")
	await frames(2)
	var marks := 0
	for g in vil._letter_gates:
		if g[1].visible:
			marks += 1
	ok(marks == 3, "над тремя калитками — ✉")
	for g in vil._letter_gates:
		g[0].activate()
	await frames(2)
	ok(QM.quests.s_olya.step == 1 and not QM.items.has("letters"), "письма разнесены")
	ok(zone_with("опустить письмо") == null, "ящики больше не предлагают письмо")
	talk("Почтальонка Оля")
	ok(state("s_olya") == 2, "Оля довольна")
	# Васёк: механика
	talk("Механик Васёк")
	QM.event("manual_m", 1000.0)
	talk("Механик Васёк")
	ok(state("s_vasya") == 2, "школа механики пройдена")
	# Михалыч: картошка
	talk("Дед Михалыч")
	NM.snacks = 3
	talk("Дед Михалыч")
	ok(state("s_mikhalych") == 2 and NM.snacks == 0, "дед получил картошку")
	ok(QM.stats.quests == 12, "выполнено заданий: %d" % QM.stats.quests)

	print("== Журнал")
	await tap(KEY_J)
	ok(journal.is_open() and paused, "J открыл журнал, игра на паузе")
	ok(journal._text.text.contains("Хозяин Каменки") and journal._text.text.contains("СТАТИСТИКА"), "в журнале сюжет и статистика")
	await tap(KEY_ESCAPE)
	var menu = child("pause_menu.gd")
	ok(not journal.is_open() and not menu.is_open() and not paused, "Esc закрыл журнал, а не открыл паузу")

	print("== Обмороки")
	TM.minutes = 14 * 60.0
	P.global_position = Vector3(-60, 0.2, -30)
	GM.money = 1000
	NM.energy = 0.5
	NM.food = 80.0
	for i in 60:
		TM.advance(1.0)
		if last().contains("Очнулся"):
			break
	await frames(2)
	ok(last().contains("усталости") and GM.money == 850, "свалился от усталости: −150 грн")
	ok(P.global_position.distance_to(Vector3(-126.6, 0.15, -54)) < 1.0, "очнулся дома")
	ok(absf(TM.hour() - 22.0) < 0.2, "прошло 8 часов (сейчас %.1f ч)" % TM.hour())
	NM.energy = 100.0
	NM.food = 0.0
	GM.money = 100
	var fainted := false
	for i in 40:
		TM.advance(5.0)
		NM.energy = 100.0
		if last().contains("сознание"):
			fainted = true
			break
	ok(fainted and GM.money == 0, "от голода — обморок, денег было 100 — осталось 0")
	ok(QM.stats.fainted == 2, "в статистике 2 обморока")

	print("== Сохранение заданий")
	SM.save_game()
	var q_before: int = QM.stats.quests
	QM.reset()
	SM.load_game()
	await frames(2)
	ok(QM.stats.quests == q_before and state("s_olya") == 2 and state("m_house") == 1, "задания и статистика восстановлены")

	print("== Финал")
	TM.minutes = 10 * 60.0
	GM.money = 12000
	zone_with("прораб").activate()
	await frames(3)
	ok(state("m_house") == 2 and state("m_master") == 1, "построил дом — «Хозяин Каменки» (+1000 награда: %d грн)" % GM.money)
	GM.money = 30000
	zone_with("прораб").activate()
	await frames(3)
	ok(not QM.won and state("m_master") == 2 and state("m_park") == 1, "кирпичный дом — сюжет идёт в город: «Огни города»")
	ok(hud._goal.text.contains("Огни города"), "трекер: " + hud._goal.text.split("\n")[0])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
