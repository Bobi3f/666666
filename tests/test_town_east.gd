extends SceneTree
## Город на новом месте и его восточная часть: до города — дорога через
## природу, всё городское стоит со сдвигом Town.SHIFT; бурса, СТО, гараж,
## колесо обозрения, банк, авторынок.
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
func ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	return W.get_world_3d().direct_space_state.intersect_ray(q)
func zone_named(n: String) -> InteractZone:
	return W.find_child(n, true, false) as InteractZone
func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress"); var TM = root.get_node("TimeManager")
	var NM = root.get_node("NeedsManager"); var DL = root.get_node("Daily")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	await frames(3)

	print("== Город отодвинут от Каменки")
	ok(Town.SHIFT.x >= 600.0, "город в %d м восточнее прежнего места" % int(Town.SHIFT.x))
	# Где стоял склад (27.5, 37) — теперь луг и ферма, а склад — на новом месте
	var q := PhysicsRayQueryParameters3D.create(Vector3(27.5, 3, 25), Vector3(27.5, 3, 50))
	var farm_bodies: Array[RID] = []
	for b in W.get_node("Farm").find_children("*", "CollisionObject3D", true, false):
		farm_bodies.append((b as CollisionObject3D).get_rid())
	q.exclude = farm_bodies
	ok(W.get_world_3d().direct_space_state.intersect_ray(q).is_empty(), "на старом месте склада — только ферма")
	ok(not ray(Town.w(Vector3(27.5, 3, 25)), Town.w(Vector3(27.5, 3, 50))).is_empty(), "склад стоит в городе")
	ok(ray(Vector3(70, 5, 25), Vector3(70, 5, 60)).is_empty() and not ray(Town.w(Vector3(70, 5, 25)), Town.w(Vector3(70, 5, 60))).is_empty(), "пятиэтажка переехала")
	ok(W.get_node("TownSouth").position == Town.SHIFT and W.get_node("Police").position == Town.SHIFT and W.get_node("AutoSchool").position == Town.SHIFT, "южная часть, милиция и автошкола — на месте города")
	ok(W.get_node("Volga").global_position.x > Town.SHIFT.x, "машины автосалона в городе")
	ok(absf(Railway.STATION.x - Town.w(Vector3(97, 0, 0)).x) < 0.1, "станция у вокзала города")
	ok(Roads.on_asphalt(Town.SHIFT.x + 97.0, 30.0) and not Roads.on_asphalt(97.0, 30.0), "асфальт города переехал вместе с ним")
	ok(not Region.tree_ok(Town.SHIFT.x + 120.0, 60.0), "в городе лес не растёт")
	var trees := 0
	var veg = W.get_node("Vegetation")
	for kind in veg._trees:
		for xf in veg._trees[kind]:
			var o: Vector3 = (xf as Transform3D).origin
			if o.x > 0.0 and o.x < 200.0 and o.z > 10.0 and o.z < 200.0: trees += 1
	ok(trees >= 30, "на месте города — берёзовые колки и кусты: %d деревьев" % trees)
	var P = W.get_node("Player")

	print("== Автобус, такси, почта, больница")
	GM.money = 100; TM.minutes = 9 * 60.0
	W._ride_bus(true)
	ok(P.global_position.distance_to(Town.w(W.STOP_TOWN)) < 4.0, "автобус привозит на городскую остановку")
	var post = W.get_node("Post")
	var town_post: Dictionary = {}
	for o in post.offices:
		if o.name == "Город": town_post = o
	ok(not town_post.is_empty() and (town_post.window as Vector3).x > Town.SHIFT.x, "почта города — в городе")
	var dests: Array = W.JOB_DESTS
	ok((dests[4][1] as Vector3).x > Town.SHIFT.x + 100.0, "попутчика везут в больницу в городе")

	print("== Бурса и СТО")
	PR.home_items.erase("mechanic")
	var east = W.get_node("TownEast")
	var course := zone_named("CollegeZone")
	TM.minutes = 10 * 60.0
	ok(course != null and course.text().contains("курсы"), "в бурсе — курсы: " + (course.text() if course else ""))
	var shift_zone := zone_named("StoShiftZone")
	ok(shift_zone.text().contains("корочки"), "без курсов на СТО не берут: " + shift_zone.text())
	GM.money = 1000
	east.take_course()
	var LP = east.lesson_panel
	ok(LP.visible and GM.money == 1000 - east.COURSE_PRICE and LP._items.size() == 3, "курсы оплачены, урок 1 — три вопроса")
	for i in 3: LP.answer(LP.right_index())
	ok(east.course_lessons == 1 and not LP.visible and not PR.has_item("mechanic"), "урок пройден: 1 из 3")
	east.take_course()
	ok(not LP.visible and course.text().contains("завтра"), "второй урок за день — нет: " + course.text())
	var day0: int = TM.day
	for d in 2:
		TM.day += 1; TM.minutes = 10 * 60.0
		east.take_course()
		for i in 3: LP.answer(LP.right_index())
	ok(east.course_lessons == 3 and GM.money == 1000 - east.COURSE_PRICE, "три урока, платил один раз")
	TM.day += 1; TM.minutes = 10 * 60.0
	ok(course.text().contains("экзамен"), "дальше экзамен: " + course.text())
	east.take_course()
	ok(LP._items.size() == 5, "на экзамене пять вопросов")
	for i in 5: LP.answer((LP.right_index() + 1) % 3)
	ok(not PR.has_item("mechanic") and last().contains("не сдан"), "двойка на экзамене — пересдача: " + last())
	TM.day += 1; TM.minutes = 10 * 60.0
	east.take_course()
	for i in 4: LP.answer(LP.right_index())
	LP.answer((LP.right_index() + 1) % 3)
	ok(PR.has_item("mechanic") and last().contains("Экзамен сдан"), "4 из 5 — корочка автослесаря")
	var st0: Dictionary = east.save_state()
	east.load_state({})
	ok(east.course_lessons == 0, "старое сохранение — курсы с нуля")
	east.load_state(st0)
	ok(east.course_lessons == 3 and east.course_paid, "курсы сохраняются")
	TM.day = day0
	TM.minutes = 10 * 60.0
	NM.energy = 80.0
	var m0: int = GM.money
	# Три этапа: принять машину — найти поломку — сдать
	east._shift()
	ok(east.sto_stage == 1 and east.find_child("StoClientCar", true, false) != null, "этап 1: машина клиента на подъёмнике")
	east._inspect()
	var LP2: LessonPanel = east.lesson_panel
	ok(LP2.visible and LP2._question.text.contains("Клиент"), "этап 2: жалоба клиента и три узла на выбор")
	LP2.answer((LP2.right_index() + 1) % 3)
	ok(east.sto_stage == 1 and east.sto_miss == 1, "не тот узел — ищи дальше")
	east._inspect()
	LP2.answer(LP2.right_index())
	ok(east.sto_stage == 2, "верный узел — починено")
	ok(east._shift_prompt().begins_with("E — сдать"), "этап 3: " + east._shift_prompt())
	east._shift()
	ok(GM.money == m0 + east.SHIFT_PAY and east.sto_day == TM.day and east.sto_stage == 0, "сдал машину: +%d грн (с ошибкой — без премии)" % east.SHIFT_PAY)
	await frames(2)
	ok(east.find_child("StoClientCar", true, false) == null, "клиент уехал")
	east.shift()
	ok(GM.money == m0 + east.SHIFT_PAY, "вторая смена за день — нет")
	TM.day += 1
	TM.minutes = 10 * 60.0
	ok(east.shift() == east.SHIFT_PAY + east.STO_BONUS, "без ошибок — с премией +%d" % east.STO_BONUS)
	TM.day = day0
	# Ремонт на городском СТО
	var C = W.get_node("Car")
	PR.buy_car("car")
	C.global_position = Town.w(Vector3(248, 0.1, 67)); C.condition = 40.0
	await frames(3)
	var fix := zone_named("TownStoZone")
	ok(fix.text().contains("починить"), "СТО в городе чинит: " + fix.text())
	GM.money = 5000
	fix.activated.emit()
	ok(C.condition > 99.0, "машину починили в городе")

	print("== Мастер СТО: покраска и запчасти")
	TM.minutes = 11 * 60.0
	C.global_position = Town.w(Vector3(248, 0.1, 67))
	await frames(3)
	var mz := zone_named("StoMasterZone")
	ok(mz != null and mz.text().contains("покраска"), "у СТО мастер: " + (mz.text() if mz else ""))
	east.open_master()
	var SP: StoPanel = east.master_panel
	ok(SP.visible and SP._car == C, "окно мастера открыто для «Жигулей»")
	GM.money = 10000
	ok(SP.paint(3) and C.paint == 3 and GM.money == 10000 - SP.PAINT_PRICE[0], "перекрасил в %s" % C.paint_name())
	ok(not SP.paint(3), "в тот же цвет не красят")
	C.health = {"brakes": 10.0, "engine": 40.0}
	var t_old: float = C._torque()
	ok(not SP.renew("clutch"), "новое сцепление не меняют")
	var m1: int = GM.money
	ok(SP.renew("brakes") and C.part_health("brakes") == 100.0 and GM.money == m1 - C.part_price("brakes"), "поставили новые колодки")
	ok(SP.renew("engine") and C._torque() > t_old * 1.1, "после капремонта мотор тянет сильнее")
	var st: Dictionary = C.save_state()
	C.health = {"tyres": 5.0}
	C.load_state(st)
	ok(C.part_health("tyres") == 100.0 and C.part_health("engine") == 100.0, "ресурс узлов сохраняется")
	C.health = {}
	C._odo = 0.0
	C._wear_parts(1000.0)
	ok(C.part_health("brakes") < 100.0 and C.part_health("tyres") < 100.0, "за километр узлы чуть изнашиваются")
	SP.close_panel()
	C.health = {}

	print("== Гараж")
	PR.home_items.erase("garage")
	east._update_garage()
	GM.money = 3000
	ok(east._garage_label.text.contains("ПРОДАЁТСЯ"), "гараж продаётся")
	east.use_garage()
	ok(PR.has_item("garage") and GM.money == 3000 - east.GARAGE_PRICE and east._garage_label.text == "ТВОЙ ГАРАЖ", "купил гараж")
	C.global_position = Town.w(Vector3(east.MY_GARAGES.position.x - 2.5, 0.1, east.MY_GARAGES.position.y + 3.1)); C.condition = 50.0
	await frames(3)
	east.use_garage()
	ok(absf(C.condition - 80.0) < 0.5, "подлатал сам: %d%%" % int(C.condition))

	print("== Парк, банк, авторынок")
	TM.minutes = 15 * 60.0
	GM.money = 100
	var e0: float = NM.energy
	NM.energy = 50.0
	east.ride_wheel()
	ok(GM.money == 100 - east.WHEEL_PRICE and NM.energy > 50.0, "покатался на колесе обозрения")
	var r0: float = east._rotor.rotation.z
	await frames(30)
	ok(east._rotor.rotation.z > r0, "колесо крутится")
	NM.energy = e0
	var bank_zone: InteractZone = null
	for z in W.get_node("Business").get_children():
		if z is InteractZone and (z as InteractZone).text().contains("вклад"): bank_zone = z
	ok(bank_zone != null and bank_zone.global_position.distance_to(Town.w(Vector3(201, 0, 10))) < 3.0, "окошко вклада — у банка")
	var N = W.get_node("Niva")
	ok(east.CAR_MARKET.has_point(Vector2(Town.l(N.global_position).x, Town.l(N.global_position).z)), "«Нива» продаётся на авторынке")

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
