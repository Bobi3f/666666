extends SceneTree
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
func person(vil, name: String) -> Dictionary:
	for st in vil._people:
		if st.data.name == name: return st
	return {}
func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress"); var TM = root.get_node("TimeManager")
	var DL = root.get_node("Daily"); var NM = root.get_node("NeedsManager"); var SM = root.get_node("SaveManager")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var P = W.get_node("Player"); var C = W.get_node("Car")
	var vil = child("villagers.gd")

	print("== Распорядок жителей")
	P.global_position = Vector3(150, 0.2, 60)  # далеко — жители переходят сразу
	TM.day = 2; TM.minutes = 7 * 60.0
	await frames(3)
	var galya := person(vil, "Баба Галя")
	ok(galya.slot == "bench_galya" and galya.node.visible and galya.sit.visible and not galya.stand.visible, "7:00 — баба Галя сидит на лавочке")
	TM.minutes = 9.5 * 60.0
	await frames(3)
	ok(galya.slot == "shop_galya" and galya.node.position.distance_to(vil.SPOTS.shop_galya.pos) < 0.1 and galya.stand.visible, "9:30 — у сельмага (игрок далеко — сразу)")
	var mikh := person(vil, "Дед Михалыч")
	TM.minutes = 12.2 * 60.0
	await frames(3)
	ok(mikh.slot == "pond", "12:00 — Михалыч на пруду")
	# Игрок рядом — идёт пешком
	TM.minutes = 10.9 * 60.0
	await frames(3)
	P.global_position = vil.SPOTS.shop_galya.pos + Vector3(-3.0, 0.2, -6.0)
	await frames(3)
	TM.minutes = 11.0 * 60.0 + 1.0
	await frames(3)
	var p0: Vector3 = galya.node.position
	ok(galya.slot == "bench_galya" and not galya.path.is_empty(), "11:00 — игрок рядом, баба Галя пошла к лавочке пешком")
	TM.speed = 0.0
	await frames(120)
	TM.speed = 1.0
	var moved: float = galya.node.position.distance_to(p0)
	ok(moved > 1.5 and moved < 4.0, "идёт шагом: %.1f м за 2 с" % moved)
	P.global_position = Vector3(150, 0.2, 60)
	TM.minutes = 23 * 60.0
	await frames(3)
	var vasya := person(vil, "Механик Васёк")
	ok(not galya.node.visible and not vasya.node.visible, "ночью все дома — не видно")
	TM.minutes = 16.5 * 60.0
	# Жители обновляются в кадре отрисовки, а не физики
	for i in 3: await process_frame
	ok(mikh.slot == "bench_mikh" and mikh.sit.visible and galya.slot == "bench_galya", "вечером Михалыч и баба Галя на одной лавочке")

	print("== Реплики по сюжету")
	PR.house_level = 1
	var line: String = vil._news(galya.data, galya)
	ok(line.contains("дом-то какой"), "новый дом — баба Галя: " + line)
	ok(vil._news(galya.data, galya) == "", "второй раз не повторяет")
	PR.license = true
	line = vil._news(mikh.data, mikh)
	ok(line.contains("дом") and vil._news(mikh.data, mikh).contains("трактор"), "Михалыч: про дом, потом про права (своё)")
	PR.house_level = 0

	print("== Поручения")
	GM.in_game = true
	TM.day = 3; TM.minutes = 6.9 * 60.0
	DL.load_state({})
	await frames(3)
	TM.minutes = 7.05 * 60.0
	await frames(3)
	ok(DL.errand >= 0 and DL.errand_day == 3 and last().contains("Звонок"), "в 7:00 звонок с поручением: " + last())
	ok(DL.tracker_line().contains("Поручение"), "в строке задания: " + DL.tracker_line())
	var e: Array = DL.ERRANDS[DL.errand]
	GM.money = 1000
	root.get_node("QuestManager").event(e[2], float(e[3]))
	ok(DL.done and GM.money >= 1000 + int(e[4]) and DL.tracker_line() == "", "выполнил — +%d грн, строка убрана" % (GM.money - 1000))
	TM.day = 4; TM.minutes = 7.1 * 60.0
	await frames(3)
	ok(DL.errand_day == 4 and not DL.done and DL.errand != -1, "на следующий день — новое")

	print("== Своё дело")
	GM.money = 6000
	var biz = child("business_spots.gd")
	ok(biz._prompt("kiosk").contains("5000") and biz._prompt("kiosk").contains("+250"), "табличка: " + biz._prompt("kiosk"))
	ok(DL.buy("kiosk") and DL.owns("kiosk") and GM.money == 1000, "выкупил ларёк за 5000")
	ok(not DL.buy("sto"), "на СТО (15000) не хватает")
	GM.money = 0
	TM.day = 5; TM.minutes = 7.2 * 60.0
	await frames(3)
	ok(GM.money == 250 - DL.tax_of(250), "утром доход с ларька после налога: %d грн" % GM.money)
	var money: int = GM.money
	await frames(10)
	ok(GM.money == money, "доход — раз в день")
	ok(DL.rival == DL.Rival.ACTIVE and DL.income("kiosk") == 125, "в Озерцово открылся ларёк Жоры — свой даёт вдвое меньше")
	ok(biz._rival.visible and biz._rival_label.text == "ЛАРЁК ЖОРЫ", "ларёк Жоры стоит в Озерцово")
	print("== Конкурент: разорить акциями")
	GM.money = 1000
	ok(DL.dump() and GM.money == 700 and not DL.dump(), "акция у своего ларька — раз в день, 300 грн")
	for d in [6, 7]:
		TM.day = d; TM.minutes = 9 * 60.0
		await frames(2)
		DL.dump()
	ok(DL.rival == DL.Rival.RUINED and DL.income("kiosk") == 250 and biz._rival_label.text == "ЗАКРЫТО", "три дня акций — Жора закрылся, доход снова полный")
	print("== Конкурент: перекупить")
	DL.rival = DL.Rival.ACTIVE
	GM.money = 7500
	ok(DL.buy_rival() and DL.owns("kiosk2") and GM.money == 500 and DL.income("kiosk") == 250 and DL.income("kiosk2") == 300, "перекупил ларёк Жоры за 7000: +300 в день и свой — полный")
	print("== СТО и автопарк")
	GM.money = 15000
	ok(DL.buy("sto") and GM.money == 0 and DL.income("sto") == 600, "СТО у трассы — 15000, +600 в день")
	DL.hire("vasya")
	ok(DL.income("sto") == 900 and DL.save_state().hired == ["vasya"], "нанял Васька — СТО даёт +900")
	DL.hired.clear()
	for n in ["Car", "Niva", "Volga"]:
		var v = W.get_node(n)
		PR.owned_cars.erase(v.kind)
	ok(not DL.buy("fleet") and biz._prompt("fleet").contains("нужно 3"), "без трёх машин автопарка нет: " + biz._prompt("fleet"))
	for k in ["car", "niva", "volga"]:
		PR.buy_car(k)
	ok(DL.own_cars() >= 3 and DL.buy("fleet") and DL.income("fleet") == 800, "три своих машины — автопарк, +800 в день")
	PR.owned_cars.erase("volga"); PR.owned_cars.erase("niva")
	ok(DL.income("fleet") == 0, "продал машины — автопарк простаивает")
	for k in ["niva", "volga"]:
		PR.buy_car(k)

	print("== Банк")
	DL.deposit = 0
	GM.money = 28300
	ok(DL.put_money() == 28000 and GM.money == 300 and DL.deposit == 28000, "положил 28000, 300 на жизнь")
	TM.day = 9; TM.minutes = 7.3 * 60.0
	await frames(3)
	ok(DL.deposit == 28100, "утром проценты: 10%% годовых (год — 28 дней) → +100: %d" % DL.deposit)
	var took: int = DL.take_money()
	ok(took == 28100 and DL.deposit == 0 and GM.money >= 28100, "снял всё")
	print("== Ярмарка")
	var fair = child("fair.gd")
	TM.day = 6; TM.minutes = 10 * 60.0
	await frames(3)
	ok(not fair._stalls.visible, "в субботу прилавков нет")
	TM.day = 7; TM.minutes = 10 * 60.0
	await frames(3)
	ok(fair._stalls.visible and TM.clock_text().contains("вс"), "в воскресенье ярмарка: " + TM.clock_text())
	NM.fish = 3; GM.money = 0
	fair._use("fish")
	ok(GM.money == 360 and NM.fish == 0, "рыба по 120: +%d" % GM.money)
	GM.money = 1000
	for i in 6: fair._use("lottery")
	ok(fair._tickets_left() == 0, "лотерея: не больше 5 билетов в день")
	var sn: int = NM.snacks
	fair._use("pies")
	ok(NM.snacks == sn + 3, "пирожки: +3 еды")
	TM.minutes = 17 * 60.0
	await frames(3)
	ok(not fair._stalls.visible, "после 16:00 ярмарка закрыта")

	print("== Радио")
	var radio = W.get_node("Radio")
	TM.minutes = 12 * 60.0
	radio.toggle()
	ok(radio.station == -1, "пешком радио не включить")
	C.global_position = Vector3(-150, 0.1, 2.0)
	C._on_enter()
	await frames(3)
	radio.toggle()
	ok(radio.station == 0 and last().contains("Ретро"), "B — «Ретро-волна»: " + last())
	var t0 := Time.get_ticks_msec()
	for i in 1200:
		await process_frame
		if radio.playing(): break
	ok(radio.playing(), "настроилось и играет за %.1f с" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var SL = root.get_node("SoundLibrary")
	ok(SL._ducked, "фоновая музыка притихла")
	C.exit_car()
	await frames(3)
	ok(not radio.playing() and not SL._ducked, "вышел — радио молчит, музыка снова")
	C._on_enter()
	await frames(3)
	ok(radio.playing(), "сел — снова играет")
	radio.toggle()
	radio.toggle()
	ok(radio.station == -1 and last().contains("выключено"), "по кругу: Эстрада → выкл")
	await frames(3)
	ok(not radio.playing(), "выключено — тихо")
	C.exit_car()

	print("== Сохранение")
	DL.owned = ["kiosk"]; DL.done_total = 5
	SM.save_game(true)
	DL.load_state({})
	SM.load_game()
	ok(DL.owns("kiosk") and DL.done_total == 5, "своё дело и поручения сохраняются")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
