extends SceneTree
## Документы и права: сельсовет (паспорт, прописка, трудовая), больница
## (медкомиссия, процедуры), автошкола (категории A, C, D, учебные машины),
## ГАИ проверяет категорию под машину, смена водителем автобуса.
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
func zone_in(node: Node, fragment: String) -> InteractZone:
	for c in node.get_children():
		if c is InteractZone and c.text().contains(fragment): return c
	return null

func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager")
	var PR = root.get_node("Progress"); var NM = root.get_node("NeedsManager")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	var CV: Civic = W.get_node("Civic")
	var AS: AutoSchool = W.get_node("AutoSchool")
	PR.docs = []; PR.categories = []; PR.license = false

	print("== Сельсовет")
	TM.day = 2; TM.minutes = 20 * 60.0
	ok(zone_in(CV, "закрыт") != null, "вечером сельсовет закрыт")
	TM.day = 7   # воскресенье
	TM.minutes = 10 * 60.0
	ok(zone_in(CV, "закрыт") != null, "в воскресенье закрыт")
	TM.day = 2
	GM.money = 1000
	var desk := zone_in(CV, "паспорт")
	ok(desk != null, "первым делом — паспорт: " + (desk.text() if desk else "—"))
	var t0: float = TM.minutes
	desk.activate()
	ok(PR.has_doc("passport") and GM.money == 900 and TM.minutes - t0 >= 119.0, "паспорт: 100 грн, два часа")
	ok(desk.text().contains("прописке"), "дальше — прописка: " + desk.text())
	desk.activate(); desk.activate()
	ok(PR.has_doc("propiska") and PR.has_doc("work_book") and GM.money == 850, "прописка и трудовая")
	ok(desk.text().contains("Все документы"), "всё оформлено")

	print("== Больница")
	PR.docs.erase("passport")
	var med := zone_in(CV, "паспорт")
	TM.minutes = 11 * 60.0
	med = zone_in(CV, "Без паспорта")
	ok(med != null, "без паспорта на медкомиссию не записывают")
	PR.add_doc("passport")
	med = zone_in(CV, "медкомиссия")
	med.activate()
	ok(PR.has_doc("med") and GM.money == 700, "медкомиссия 150 грн — годен")
	NM.energy = 20.0
	zone_in(CV, "процедуры").activate()
	ok(NM.energy >= 50.0 and GM.money == 600, "процедуры: силы +40 (за час немного устал): %.0f" % NM.energy)

	print("== Автошкола: категории")
	PR.docs.erase("med")
	ok(zone_in(AS, "медсправка") != null, "без медсправки экзамен не принимают")
	PR.add_doc("med")
	var cz := zone_in(AS, "категорию C")
	ok(cz != null and cz.text().contains("500"), "экзамен на C: " + (cz.text() if cz else "—"))
	ok(AS.truck.school and not AS.truck.allowed.call(), "учебный ГАЗ без экзамена не даёт")
	cz.activate()
	ok(AS.exam_cat == "C" and GM.money == 100 and AS.truck.allowed.call(), "экзамен на C взведён, ГАЗ доступен")
	# Сдал (результат экзамена — как от автодрома)
	(AS._exams["C"] as DrivingChallenge).finished.emit({"ok": true, "time": 95.0, "cones": 0, "why": ""})
	ok(PR.has_category("C") and AS.exam_cat == "" and last().contains("C"), "категория C: " + last())
	GM.money = 2000
	zone_in(AS, "категорию D").activate()
	(AS._exams["D"] as DrivingChallenge).finished.emit({"ok": false, "time": 0.0, "cones": 4, "why": "сбил 4 конуса"})
	ok(not PR.has_category("D") and last().contains("не сдана"), "D не сдал: " + last())
	zone_in(AS, "категорию D").activate()
	(AS._exams["D"] as DrivingChallenge).finished.emit({"ok": true, "time": 150.0, "cones": 1, "why": ""})
	ok(PR.has_category("D") and PR.categories_text() == "C, D", "категории: " + PR.categories_text())
	# После экзамена автобус отгоняют на стоянку; без экзамена из учебного
	# автобуса высаживают
	var P = W.get_node("Player")
	AS._park(AS.bus)
	await frames(2)
	ok(P.car == null and AS.bus.global_position.distance_to(Town.w(AS.BUS_SPOT)) < 1.0, "после экзамена ПАЗ на стоянке")
	AS.bus._on_enter()
	await frames(3)
	ok(AS.bus.driver == null and last().contains("только на экзамене"), "учебный ПАЗ без экзамена — высадили")
	await frames(3)

	print("== ГАИ смотрит категорию")
	var gai = W.get_node("GaiPost")
	var M = W.get_node("Moto")
	M._on_enter()
	await frames(2)
	GM.money = 1000
	gai._inspect(M)
	ok(GM.money == 700 and last().contains("Категории A нет"), "на мотоцикле без A — штраф: " + last())
	M.exit_car()
	await frames(3)

	print("== Водитель автобуса")
	TM.minutes = 8 * 60.0
	NM.energy = 100.0
	GM.money = 0
	var shift := zone_in(AS, "рейсового")
	ok(shift != null, "с D и трудовой — берут водителем")
	shift.activate()
	ok(GM.money == AutoSchool.BUS_SHIFT_PAY and TM.hour() >= 13.9, "смена 6 часов: +%d" % AutoSchool.BUS_SHIFT_PAY)
	ok(zone_in(AS, "уже отъездил") != null, "вторая смена за день — нет")

	print("== Сохранение")
	var st: Dictionary = PR.save_state()
	PR.docs = []; PR.categories = []
	PR.load_state(st)
	ok(PR.has_doc("work_book") and PR.has_category("D"), "документы и категории сохраняются")
	var old := st.duplicate(); old.erase("docs"); old.erase("cats")
	PR.load_state(old)
	ok(PR.docs.is_empty() and PR.categories.is_empty(), "старое сохранение — без документов")
	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)
