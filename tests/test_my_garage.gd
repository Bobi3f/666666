extends SceneTree
## Личный гараж у дома: вся своя техника внутри, выкатить любую, загнать
## обратно, сохранение; выключатель трафика на дорогах.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await frames(10)
	var PR = root.get_node("Progress"); var SM = root.get_node("SettingsManager")
	var G: MyGarage = W.my_garage
	ok(G != null and G.prompt().begins_with("E — гараж"), "гараж у дома: " + G.prompt())
	var moped: Vehicle = W.get_node("Moped")
	var car: Vehicle = W.get_node("Car")
	ok(moped.mine() and not car.mine() and not W.find_child("Tractor", true, false).mine() and not W.find_child("SchoolCar", true, false).mine(), "своё — только купленное (без учебных и трактора)")

	print("== В гараж и обратно")
	G.store_all()
	await frames(2)
	ok(moped.garaged and not moped.visible and moped.global_position.y < -100.0 and moped.process_mode == Node.PROCESS_MODE_DISABLED, "мопед в гараже: не виден, не считается")
	G.take_out(moped)
	await frames(2)
	ok(not moped.garaged and moped.visible and moped.global_position.distance_to(MyGarage.EXIT) < 1.0, "выкатил мопед на дорожку у дома")
	PR.owned_cars.append("car")
	ok(car.mine() and G.vehicles().size() == 2, "купил «Жигули» — в гараже уже две")
	G.take_out(car)
	await frames(2)
	ok(not car.garaged and car.global_position.distance_to(MyGarage.EXIT) < 1.0 and moped.garaged, "выкатил «Жигули», мопед с дорожки — в гараж")
	G.take_out(moped)
	await frames(2)
	ok(car.garaged and not moped.garaged, "снова мопед — «Жигули» сами заехали в гараж")

	print("== Сохранение")
	var st: Dictionary = car.save_state()
	ok(bool(st.get("garaged", false)), "в сохранении — «в гараже»")
	G.take_out(car)
	car.load_state(st)
	ok(car.garaged and not car.visible, "загрузил — снова в гараже")

	print("== Окно")
	G.open()
	await frames(2)
	var panel: GaragePanel = G.panel
	ok(panel.visible and paused and panel._list.get_child_count() == 2, "окно: две строки техники")
	panel.close_panel()
	ok(not paused, "закрыл — игра идёт")

	print("== Трафик")
	var T: Node3D = null
	for c in W.get_children():
		if c.get_script() and String(c.get_script().resource_path).ends_with("traffic.gd"): T = c
	ok(T != null and T.visible, "трафик есть")
	SM.set_traffic(false)
	await frames(2)
	var body: AnimatableBody3D = T._vehicles[0].body
	ok(not T.visible and T.process_mode == Node.PROCESS_MODE_DISABLED and body.collision_layer == 0, "выключил — машин нет, не сталкиваются")
	SM.set_traffic(true)
	await frames(2)
	ok(T.visible and body.collision_layer == 1, "включил — снова едут")
	PR.owned_cars.erase("car")

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit(1 if fails else 0)
