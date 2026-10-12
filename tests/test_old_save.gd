extends SceneTree
## Старое сохранение (город ещё стоял у Каменки) грузится: машины салона
## переезжают вместе с городом, а игрок и своя техника — дома, во дворе.
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
	var P = W.get_node("Player"); var C = W.get_node("Car"); var M = W.get_node("Moped"); var V = W.get_node("Volga")
	root.get_node("Progress").buy_car("car")
	print("== Старое сохранение")
	ok(SM.save_game(true), "сохранил")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SM.PATH))
	ok(d.get("town_moved", false), "новые сохранения помечены")
	# Делаем из него «старое»: без пометки, игрок и машина — у прежнего города
	d.erase("town_moved")
	d[str(P.get_path())]["pos"] = [100.0, 0.2, 40.0]
	d[str(C.get_path())]["pos"] = [97.0, 0.1, 30.0]
	d[str(M.get_path())]["pos"] = [-60.0, 0.1, 30.0]
	d[str(V.get_path())]["pos"] = [60.0, 0.1, 17.0]
	var f := FileAccess.open(SM.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	ok(SM.load_game(), "старое сохранение загрузилось")
	for i in 5: await physics_frame
	var home := Vector3(W.PLAYER_HOUSE.x, 0, W.PLAYER_HOUSE.y)
	ok(P.global_position.distance_to(home) < 9.0 and P.car == null, "после загрузки игрок дома: %s" % str(P.global_position.round()))
	ok(Vector2(C.global_position.x - home.x, C.global_position.z + 39.5).length() < 30.0, "свои «Жигули» — у калитки: %s" % str(C.global_position.round()))
	ok(M.global_position.distance_to(home) < 14.0, "мопед — во дворе")
	ok(V.global_position.distance_to(Town.w(Vector3(60, 0.1, 17))) < 1.0, "чужая «Волга» из старого сохранения — в автосалоне на новом месте")
	# Не оставлять сохранение — следующие наборы начинают с чистой игры
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SM.PATH))
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
