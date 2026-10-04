extends SceneTree
## Главный путь игрока: старый мопед → работа → права → первая машина.
## Мопед свой с начала и без прав; «Жигули» и «Ява» продаются; без прав
## за руль не пускают; экзамен — на учебных «Жигулях»; сюжет ведёт по
## шагам; старые сохранения ничего не теряют.
var fails := 0
var W
var held := {}
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func key(k: int, down: bool) -> void:
	if bool(held.get(k, false)) == down: return
	held[k] = down
	var e := InputEventKey.new()
	e.physical_keycode = k; e.keycode = k; e.pressed = down
	Input.parse_input_event(e)
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
func zone_of(v) -> InteractZone:
	for c in v.get_children():
		if c is InteractZone: return c
	return null

func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress"); var QM = root.get_node("QuestManager")
	var TM = root.get_node("TimeManager"); var WM = root.get_node("WeatherManager")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	WM.set_kind(0, 99999.0); WM.wetness = 0.0
	TM.minutes = 10 * 60.0
	var P = W.get_node("Player")
	var M = W.get_node("Moped")
	var C = W.get_node("Car")
	var J = W.get_node("Moto")

	print("== Начало: старый мопед")
	ok(M.kind == "moped" and M.owned() and M.may_drive(), "мопед «Карпаты» свой и без прав")
	ok(not C.owned() and not J.owned(), "«Жигули» и «Ява» не свои — продаются")
	ok(C._sale != null and C._sale.visible and C._sale.text.contains("%d" % C.price), "над «Жигулями» табличка: " + (C._sale.text.replace("\n", " ") if C._sale else "—"))
	ok(P.global_position.distance_to(M.global_position) < 14.0, "мопед у калитки, рядом с игроком")
	ok(QM.MAIN[1] == "m_wheels" and QM.QUESTS.m_wheels.steps[0].text.contains("мопед"), "второе сюжетное — про мопед")
	# Едет: разгон и максималка
	zone_of(M).activate()
	await frames(3)
	ok(GM.vehicle == M, "сел на мопед через E")
	M.global_position = Vector3(-150.0, 0.2, -2.0); M.rotation.y = -PI / 2.0
	M.speed = 0.0; M.velocity = Vector3.ZERO; M.fuel = 6.0
	key(KEY_W, true)
	var top := 0.0
	for i in 60 * 14:
		await physics_frame
		top = maxf(top, M.speed_kmh())
		if M.global_position.x > 180.0: break
	key(KEY_W, false)
	ok(top > 38.0 and top < 58.0, "мопед медленный: максимум %.0f км/ч" % top)
	ok(M.fuel < 6.0 and M.fuel > 5.5, "бензина ест мало: осталось %.2f л" % M.fuel)
	M.speed = 0.0; M.velocity = Vector3.ZERO
	await frames(10)
	M.exit_car()
	await frames(5)

	print("== Без прав — только мопед")
	PR.license = false
	GM.money = 5000
	P.global_position = C.global_position + Vector3(0, 0.1, 2.5)
	await frames(3)
	ok(zone_of(C).text().contains("купить") and zone_of(C).text().contains("%d" % C.price), "у «Жигулей»: " + zone_of(C).text())
	zone_of(C).activate()
	await frames(3)
	ok(C.owned() and GM.money == 5000 - C.price, "купил «Жигули» за %d" % C.price)
	ok(not C._sale.visible, "табличка «продаётся» снята")
	zone_of(C).activate()
	await frames(3)
	ok(GM.vehicle == null and last().contains("Без прав"), "без прав за руль не пускает: " + last())
	PR.license = true
	zone_of(C).activate()
	await frames(3)
	ok(GM.vehicle == C, "с правами — за руль")
	C.exit_car()
	await frames(5)
	# «Ява» — категория A
	PR.buy_car("moto")
	zone_of(J).activate()
	await frames(3)
	ok(GM.vehicle == null and last().contains("категория A"), "«Ява» без категории A — нельзя: " + last())
	Vehicle.exam_category = "A"
	zone_of(J).activate()
	await frames(3)
	ok(GM.vehicle == J, "на экзамене A — можно на своей «Яве»")
	J.exit_car()
	Vehicle.exam_category = ""
	await frames(5)

	print("== Экзамен на учебных «Жигулях»")
	var AS = W.get_node("AutoSchool")
	ok(AS.car != null and AS.car.school and AS.car.kind == "car", "учебные «Жигули» у автодрома")
	ok(not AS.car.allowed.call(), "без экзамена — не сесть")
	W._exam.arm()
	ok(AS.car.allowed.call(), "на экзамене — садись")
	W._exam.cancel() if W._exam.has_method("cancel") else null

	print("== Сюжет ведёт по шагам")
	ok(QM.QUESTS.has("m_license") and QM.QUESTS.has("m_car"), "есть «Права» и «Первая машина»")
	ok(QM.MAIN.find("m_license") > QM.MAIN.find("m_money") and QM.MAIN.find("m_car") == QM.MAIN.find("m_license") + 1, "сначала деньги, потом права, потом машина")

	print("== Старое сохранение")
	PR.load_state({"house": 0, "cars": [], "license": false})
	ok(PR.owns("car") and PR.owns("moto") and PR.license, "в старом сохранении «Жигули», «Ява» и права остаются")
	PR.load_state({})
	ok(not PR.owns("car") and not PR.license, "новая игра — с нуля")
	var st: Dictionary = PR.save_state()
	PR.load_state(st)
	ok(not PR.owns("car"), "новое сохранение не путается со старым")
	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)
