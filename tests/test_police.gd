extends SceneTree
## Пост ГАИ (проверка документов, штрафы в долг) и отделение милиции
## (оплата долга, вечерний обход дружинника).
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

func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager")
	var PR = root.get_node("Progress")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	var gai = W.get_node("GaiPost")
	var pol: Police = W.get_node("Police")
	var C = W.get_node("Car")
	TM.minutes = 12 * 60.0

	print("== Пост ГАИ: проверка документов")
	ok(gai._blink.size() == 2, "у поста милицейские «Жигули» с мигалкой")
	gai.check_chance = 1.0
	gai._check_day = -1
	PR.license = false
	GM.money = 1000
	C.global_position = Vector3(-125, 0.1, 2.0); C.rotation.y = -PI / 2.0
	C._on_enter(); C.fuel = 30.0
	C.speed = 12.0
	for i in 60:
		C.speed = 12.0
		await physics_frame
		if gai.stop_wanted: break
	ok(gai.stop_wanted and last().contains("остановитесь"), "инспектор машет жезлом: " + last())
	await frames(20)
	ok(gai._wand.rotation.z > 1.0, "жезл поднят")
	C.speed = 0.0
	C.global_position = Vector3(-99, 0.1, 2.0)
	await frames(5)
	ok(not gai.stop_wanted and GM.money == 700 and last().contains("Права"), "без прав — штраф 300: " + last())
	# С правами — счастливого пути
	PR.license = true
	gai.request_stop()
	await frames(5)
	ok(not gai.stop_wanted and GM.money == 700 and last().contains("Счастливого"), "с правами — счастливого пути")
	# Уехал от инспектора без денег — в долг (погоня сегодня уже была —
	# сразу штраф; сама погоня — в test_chase)
	W.get_node("Chase")._done_day = root.get_node("TimeManager").day
	GM.money = 0
	gai.request_stop()
	C.global_position = Vector3(-20, 0.1, 2.0)
	await frames(5)
	ok(pol.debt == 500 and last().contains("долг"), "уехал без денег — долг 500: " + last())
	C.speed = 0.0
	C.exit_car()
	await frames(3)

	print("== Отделение милиции")
	var desk: InteractZone = null
	for c in pol.get_children():
		if c is InteractZone and c.name != "PlateDesk": desk = c
	ok(desk.text().contains("не хватает"), "долг есть, денег нет: " + desk.text())
	GM.money = 800
	ok(desk.text().contains("оплатить штрафы: 500"), "у дежурного — оплатить штрафы")
	desk.activate()
	ok(pol.debt == 0 and GM.money == 300, "долг погашен")
	TM.minutes = 12 * 60.0
	ok(desk.text().contains("вечером"), "днём дружинники не нужны")
	TM.minutes = 19 * 60.0
	ok(desk.text().contains("обход"), "вечером — обход: " + desk.text())
	desk.activate()
	ok(pol.patrol_active and GM.challenge_line.contains("1 из 5"), "обход начался: " + GM.challenge_line)
	var P = W.get_node("Player")
	for pt in Police.PATROL:
		P.global_position = Town.w(pt) + Vector3(0, 0.2, 0)
		# Ждём, пока обход засчитает точку (не дольше двух секунд)
		for i in 120:
			await frames(1)
			if not pol.patrol_active or not GM.challenge_line.contains("%d из" % (Police.PATROL.find(pt) + 1)):
				break
	ok(not pol.patrol_active and GM.money == 300 + Police.PATROL_PAY, "обошёл пять точек: +%d" % Police.PATROL_PAY)
	ok(desk.text().contains("уже отдежурил"), "второй раз за вечер — нет")
	var st := pol.save_state()
	pol.debt = 0
	pol.add_debt(200)
	st = pol.save_state()
	pol.load_state({})
	ok(pol.debt == 0, "старое сохранение — без долга")
	pol.load_state(st)
	ok(pol.debt == 200, "долг сохраняется")

	print("== ГАИ: свой номер")
	var PRG = root.get_node("Progress")
	PRG.buy_car("car")
	var pd: InteractZone = pol.get_node("PlateDesk")
	TM.minutes = 20 * 60.0
	ok(pd.text().contains("с 8:00"), "вечером окошко закрыто: " + pd.text())
	TM.minutes = 10 * 60.0
	ok(pd.text().contains("новый номер"), "днём: " + pd.text())
	var PL = load("res://scripts/vehicles/plates.gd")
	ok(PL.parse("А1234км") == "а 12-34 КМ" and PL.parse(" б 77-77 хa") == "" and PL.parse("в 00-07 ОД") == "в 00-07 ОД",
		"свой номер пишется как надо: %s" % PL.parse("А1234км"))
	ok(PL.parse("12-34") == "" and PL.parse("аб 1234 КМ") == "", "кривой номер не принимают")
	var nice: Array = PL.nice_numbers(5, 3)
	ok(nice.size() == 3 and PL.parse(nice[0]) == nice[0], "красивые номера: %s" % ", ".join(nice))
	pd.activate()
	var panel = pol.plate_panel
	ok(panel.visible and paused and panel._cars_box.get_child_count() >= 2, "окошко ГАИ: машины на выбор — %d" % panel._cars_box.get_child_count())
	panel.select(C)
	GM.money = 1000
	var old: String = C.plate()
	ok(panel.buy("а 77-77 КМ", panel.NICE_PRICE) and C.plate() == "а 77-77 КМ" and GM.money == 1000 - panel.NICE_PRICE,
		"красивый номер за %d грн: %s → %s" % [panel.NICE_PRICE, old, C.plate()])
	var lbl: Label3D = C.find_child("Plates", true, false).find_children("*", "Label3D", false, false)[0]
	await process_frame
	ok(lbl.text == "а 77-77 КМ", "на машине — новый номер")
	var M = W.get_node("Moped")
	panel.select(M)
	ok(not panel.buy("а 77-77 КМ", panel.PLAIN_PRICE), "занятый номер второй раз не дадут: " + panel._status.text)
	GM.money = 10
	ok(not panel.buy("к 11-22 КМ", panel.PLAIN_PRICE) and panel._status.text.contains("денег"), "без денег — никак")
	panel.close_panel()
	ok(not panel.visible and not paused, "закрыл — игра идёт")
	var cst: Dictionary = C.save_state()
	C.set_plate("")
	ok(C.plate() != "а 77-77 КМ", "без регистрации — заводской номер")
	C.load_state(cst)
	ok(C.plate() == "а 77-77 КМ", "номер сохраняется")
	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)
