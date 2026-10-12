extends SceneTree
## Прохождение главной линии «как игрок»: задания через те же зоны и кнопки,
## деньги и игровое время по шагам, куда ведёт стрелка, сколько ехать.
## Печатает журнал — для разбора баланса и находок. Не набор тестов.
var W
var log_lines: Array[String] = []
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func zone_with(text: String) -> InteractZone:
	var P = W.get_node("Player")
	var best: InteractZone = null
	var bd := 40.0
	var stack: Array[Node] = [W]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(): stack.append(c)
		var z := n as InteractZone
		if z and z.monitoring and z.text().contains(text):
			var d: float = z.global_position.distance_to(P.global_position)
			if d < bd: bd = d; best = z
	return best
func note(t: String) -> void:
	var TM = root.get_node("TimeManager"); var GM = root.get_node("GameManager"); var QM = root.get_node("QuestManager")
	var main: String = QM.active_main()
	var nav = W.get_tree().get_first_node_in_group("nav")
	var tgt: Array = nav.current() if nav else ["", Vector3.INF]
	var line := "[день %d %s | %5d грн | %s] %s  → стрелка: %s" % [TM.day, TM.clock_text(), GM.money, main, t, tgt[0] if tgt[1] != Vector3.INF else "—"]
	print("PLAY ", line)
## Перейти/доехать к точке: игровое время — по расстоянию (пешком 1.6 м/с
## игровых в минуту ≈ ходьба; на мопеде 600 м/мин; на машине 900 м/мин)
func go(to: Vector3, mode := "foot") -> void:
	var P = W.get_node("Player")
	var GM = root.get_node("GameManager")
	var from: Vector3 = GM.vehicle.global_position if GM.vehicle else P.global_position
	var d := Vector2(to.x - from.x, to.z - from.z).length()
	var mpm: float = {"foot": 100.0, "moped": 600.0, "car": 900.0}[mode]
	root.get_node("TimeManager").advance(d / mpm)
	if GM.vehicle:
		GM.vehicle.global_position = to + Vector3(0, 0.1, 0); GM.vehicle.velocity = Vector3.ZERO; GM.vehicle.speed = 0.0
	else:
		P.global_position = to + Vector3(0, 0.2, 0); P.velocity = Vector3.ZERO
	await frames(4)
	print("PLAY      ход: %d м, %s, %.0f игровых мин" % [int(d), mode, d / mpm])
func _run() -> void:
	for i in 10: await process_frame
	child("pause_menu.gd")._close()
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress"); var TM = root.get_node("TimeManager")
	var NM = root.get_node("NeedsManager"); var QM = root.get_node("QuestManager")
	GM.message.connect(func(t: String) -> void: print("PLAY        » " + t))
	var P = W.get_node("Player")
	note("старт")
	var tut = child("tutorial.gd"); if tut: tut._finish()
	NM.eat_snack(); QM.event("map")
	await frames(3); note("позавтракал, открыл карту")
	# Мопед: 500 м по трассе, заправка
	var M = W.get_node("Moped")
	M._on_enter(); await frames(3)
	QM.event("drive_m", 520.0)
	await go(W.FUEL_POS + Vector3(-1.6, 0, -1.3), "moped")
	var fz := zone_with("заправить")
	note("у АЗС, зона заправки: %s" % (fz.text() if fz else "НЕТ"))
	if fz: fz.activate()
	await frames(3); note("заправился")
	M.exit_car(); await frames(3)
	# Первые деньги: колхоз (2 смены — заодно просьба Петровича)
	var pz := zone_with("Петрович")
	await go(W.BARN_POS + Vector3(0, 0, 6), "foot")
	for k in 2:
		W.kolkhoz_job.simulate_all(); await frames(2)
		TM.day += 0 
	note("2 смены в колхозе")
	QM.talk("Бригадир Петрович"); await frames(2)
	note("поговорил с Петровичем")
	# Права: паспорт в сельсовете, медсправка в больнице (город), экзамен
	await go(Civic.COUNCIL + Vector3(0, 0, 6.5), "foot")
	var cz := zone_with("E —")
	note("сельсовет: %s" % (cz.text() if cz else "НЕТ зоны"))
	if cz: cz.activate(); await frames(3)
	# В город — на автобусе
	await go(W.STOP_VILLAGE + Vector3(0, 0, 2), "foot")
	W._ride_bus(true); await frames(3)
	note("приехал автобусом в город")
	await go(Town.w(Civic.HOSPITAL) + Vector3(-1.2, 0, 6.2), "foot")
	var mz := zone_with("E —")
	note("больница: %s" % (mz.text() if mz else "НЕТ зоны"))
	if mz: mz.activate(); await frames(3)
	await go(W.get_node("InstructorZone").global_position, "foot")
	var ez := zone_with("сдать на права")
	note("инструктор: %s" % (ez.text() if ez else "НЕТ"))
	if ez:
		ez.activate(); await frames(5)
		note("на старте: в машине %s" % (GM.vehicle.name if GM.vehicle else "нет"))
		W._exam.finished.emit({"ok": true, "time": 70.0, "cones": 0, "why": ""}); await frames(3)
	await frames(260)
	note("права получены: %s" % PR.license)
	# Домой: автобус, первая машина
	await go(Town.w(W.STOP_TOWN) + Vector3(0, 0, -2), "foot")
	var bz := zone_with("автобус до")
	note("остановка в городе: %s" % (bz.text() if bz else "НЕТ"))
	if bz: bz.activate(); await frames(3)
	var C = W.get_node("Car")
	await go(C.global_position + Vector3(2.2, 0, 0), "foot")
	GM.money = maxi(GM.money, 2600)
	C._zone.activated.emit(); await frames(3)
	note("купил «Жигули»: %s" % C.owned())
	# Просьбы жителей: уха бабе Гале (2 рыбы)
	NM.fish = 2
	print("PLAY  Галя: ", QM.talk("Баба Галя"))
	print("PLAY  Галя: ", QM.talk("Баба Галя"))
	await frames(3); note("просьбы жителей")
	# Дом: сколько дней работы до 12 000 и 30 000 — по выгодным подработкам
	note("до нового дома не хватает %d грн, до кирпичного — %d" % [12000 - GM.money, 30000])
	print("PLAY ИТОГ: побывал в %d сёлах, достижений %d, заданий %d" % [W.region.visited.size(), root.get_node("Achievements").got.size(), QM.stats.quests])
	quit()
