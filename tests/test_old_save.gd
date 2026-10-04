extends SceneTree
## Старое сохранение (город ещё стоял у Каменки) грузится, а игрок и свои
## машины, оставленные в городе, переезжают вместе с ним.
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
	var SM = root.get_node("SaveManager")
	var P = W.get_node("Player"); var C = W.get_node("Car"); var M = W.get_node("Moped")
	root.get_node("Progress").buy_car("car")
	print("== Старое сохранение")
	ok(SM.save_game(true), "сохранил")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SM.PATH))
	ok(d.get("town_moved", false), "новые сохранения помечены")
	# Делаем из него «старое»: без пометки, игрок и машина — у прежнего города
	d.erase("town_moved")
	d[str(P.get_path())]["pos"] = [100.0, 0.2, 40.0]
	d[str(C.get_path())]["pos"] = [97.0, 0.1, 30.0]
	d[str(M.get_path())]["pos"] = [-131.0, 0.1, -46.5]
	var f := FileAccess.open(SM.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	ok(SM.load_game(), "старое сохранение загрузилось")
	for i in 5: await physics_frame
	ok(P.global_position.distance_to(Town.w(Vector3(100, 0.2, 40))) < 1.0, "игрок переехал в город: %s" % str(P.global_position.round()))
	ok(C.global_position.distance_to(Town.w(Vector3(97, 0.1, 30))) < 1.0, "«Жигули» — тоже")
	ok(M.global_position.distance_to(Vector3(-131, 0.1, -46.5)) < 1.0, "мопед в Каменке остался на месте")
	# Не оставлять сохранение — следующие наборы начинают с чистой игры
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SM.PATH))
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
