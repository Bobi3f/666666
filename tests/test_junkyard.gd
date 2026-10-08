extends SceneTree
## Свалка: забор с воротами, вагончик и сторож. Своя техника за воротами —
## можно продать (вернётся на место продажи, купить снова) или поставить б/у
## узел: дешевле нового, ресурс 70%. Мопед не берут, ночью закрыто.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 10: await process_frame
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress"); var TM = root.get_node("TimeManager")
	var lm: Landmarks = W.find_child("Landmarks", true, false)
	ok(lm != null, "достопримечательности на месте")
	var c := Landmarks.junk_center()
	var zone = lm.find_child("JunkZone", true, false)
	ok(zone != null and zone.global_position.distance_to(c) < 30.0, "сторож у вагончика на свалке")
	var sign := false
	for l in lm.find_children("*", "Label3D", true, false):
		if l.text.begins_with("ПРИЁМ ЛОМА"): sign = true
	ok(sign, "вывеска «ПРИЁМ ЛОМА / ЗАПЧАСТИ Б/У»")
	# Забор: в проёме ворот свободно, сбоку от ворот — стенка
	var space: PhysicsDirectSpaceState3D = W.get_world_3d().direct_space_state
	var gate_z := c.z + Landmarks.JUNK_YARD.end.y
	var ray := func(x: float) -> bool:
		var q := PhysicsRayQueryParameters3D.create(Vector3(c.x + x, 1.0, gate_z + 3.0), Vector3(c.x + x, 1.0, gate_z - 3.0))
		return not space.intersect_ray(q).is_empty()
	ok(not ray.call(0.0), "ворота открыты — можно заехать")
	ok(ray.call(-12.0) and ray.call(12.0), "по бокам от ворот — забор")

	print("== Часы работы")
	TM.minutes = 3 * 60.0
	ok(lm.junk_prompt().contains("Закрыто"), "ночью закрыто: " + lm.junk_prompt())
	TM.minutes = 12 * 60.0
	ok(lm.junk_prompt().begins_with("E — "), "днём: " + lm.junk_prompt())

	print("== Своя машина на свалке")
	var car: Vehicle = W.get_node("Car")
	var home := car.sale_xf.origin
	PR.buy_car("car")
	car.global_position = c + Vector3(0, 0.3, 12.0)
	car.health["brakes"] = 10.0
	car.health["tyres"] = 90.0
	var moped: Vehicle = W.get_node("Moped")
	moped.global_position = c + Vector3(4, 0.3, 12.0)
	var list: Array = lm.junk_vehicles()
	ok(list.has(car) and list.has(moped), "за воротами своя техника: %d" % list.size())
	lm.open_junk()
	var p: JunkPanel = lm.junk_panel
	ok(p.visible and paused, "окно сторожа открыто, игра на паузе")
	p.select(car)
	GM.money = 5000
	var used := JunkPanel.used_price(car, "brakes")
	ok(used < car.part_price("brakes"), "б/у колодки дешевле новых: %d < %d" % [used, car.part_price("brakes")])
	ok(p.fit_used("brakes") and is_equal_approx(car.part_health("brakes"), 70.0) and GM.money == 5000 - used, "поставили б/у колодки — ресурс 70%%, −%d грн" % used)
	ok(not p.fit_used("tyres"), "резина 90%% — б/у не нужна")
	ok(not JunkPanel.can_sell(moped), "мопед не берут")
	var money := JunkPanel.sell_price(car)
	ok(money > 0 and money <= int(car.price * 0.5), "цена за Жигули: %d (цена в продаже %d)" % [money, car.price])
	var m0: int = GM.money
	ok(p.sell(), "продали")
	ok(GM.money == m0 + money and not PR.owns("car"), "деньги получены, машина больше не своя")
	ok(car.global_position.distance_to(home) < 0.5 and not car.owned(), "машина вернулась туда, где продавалась — можно купить снова")
	ok(not lm.junk_vehicles().has(car), "за воротами её больше нет")
	p.close_panel()
	ok(not paused, "окно закрыто — игра идёт")

	print("== По-английски")
	var tr := LangTranslation.new()
	ok(tr.text(lm.junk_prompt()) == "E — Uncle Grisha: sell a car or motorbike, used parts", tr.text(lm.junk_prompt()))
	ok(tr.text("Свалка: «%s» продана за %d грн" % ["Семёрка", 1000]).begins_with("Junkyard:"), tr.text("Свалка: «%s» продана за %d грн" % ["Семёрка", 1000]))

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
