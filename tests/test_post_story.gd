extends SceneTree
## Вторая часть сюжета после победы: «Мастер на все руки» (новые работы),
## «Правая рука Владика», «Коллекционер» (гараж), «Свой дом в Липках»,
## «Легенда района». И старое сохранение с победой — вторая часть начнётся.
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
	var QM = root.get_node("QuestManager"); var PR = root.get_node("Progress"); var GM = root.get_node("GameManager")
	var state := func(id: String) -> int: return int(QM.quests[id].state)
	print("== Старое сохранение с победой")
	var st: Dictionary = QM.save_state().duplicate(true)
	for id in QM.MAIN:
		if id.begins_with("p_"): break
		st.quests[id] = {"state": 2, "step": 0, "n": 0.0}
	st.won = true
	QM.load_state(st)
	await frames(2)
	ok(QM.won and state.call("p_jobs") == 1, "победа была — началась вторая часть: " + QM.tracker_lines()[0])

	print("== Мастер на все руки")
	var m0: int = GM.money
	for e in ["bread", "sweep", "garden_job", "logs"]:
		QM.event(e)
	await frames(2)
	ok(state.call("p_jobs") == 2 and state.call("p_vladik") == 1, "четыре новые работы — глава пройдена, дальше Владик")
	ok(GM.money >= m0 + 2000, "награда 2000 грн")

	print("== Правая рука Владика")
	var vl = W.get_tree().get_first_node_in_group("vladik")
	vl.rep = 60
	vl.add_rep(15)
	await frames(2)
	ok(vl.level() == 5 and state.call("p_vladik") == 2 and state.call("p_collector") == 1, "полное доверие Владика — дальше гараж")

	print("== Коллекционер")
	for k in ["car", "moto", "izh", "niva"]:
		if not PR.owned_cars.has(k): PR.owned_cars.append(k)
	W.my_garage.open()
	W.my_garage.panel.close_panel()
	await frames(2)
	ok(QM.quests.p_collector.step == 1, "пять своих машин в гараже")
	QM.event("drive_m", 30000.0)
	await frames(2)
	ok(state.call("p_collector") == 2 and state.call("p_lipki") == 1, "30 км — глава пройдена, дальше Липки")

	print("== Дом в Липках и легенда")
	PR.add_item("lipki_house")
	QM.event("lipki_house")
	await frames(2)
	ok(state.call("p_lipki") == 2 and state.call("p_legend") == 1, "купил дом в Липках — последняя глава")
	QM.event("earned", 100000.0)
	await frames(2)
	ok(state.call("p_legend") == 2 and QM.tracker_lines()[0].contains("легенда"), "легенда района: " + QM.tracker_lines()[0])
	for k in ["car", "moto", "izh", "niva"]: PR.owned_cars.erase(k)

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit(1 if fails else 0)
