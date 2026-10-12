extends SceneTree
## Роща «Берёзки» с тропинками и полянкой, лесополосы вдоль трассы: деревья
## густо, но не на тропинках, не на дороге и не у съездов к сёлам.
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
	var veg = W.get_node("Vegetation")
	var trees: Array[Vector2] = []
	for kind in veg._trees:
		for xf in veg._trees[kind]:
			var o: Vector3 = (xf as Transform3D).origin
			trees.append(Vector2(o.x, o.z))
	var WS = load("res://scripts/world/world.gd")

	print("== Роща «Берёзки»")
	var in_grove := 0
	var on_path := 0
	var in_clearing := 0
	for t in trees:
		if WS.GROVE.has_point(t): in_grove += 1
		for p in WS.GROVE_PATHS:
			if WS._polyline_dist(t, p) < 2.0: on_path += 1
		if t.distance_to(WS.GROVE_CLEARING) < 8.0: in_clearing += 1
	ok(in_grove > 150, "в роще густо: %d деревьев" % in_grove)
	ok(on_path == 0, "на тропинках деревьев нет: %d" % on_path)
	ok(in_clearing == 0, "полянка свободна")
	var sign := false
	for l in W.find_children("*", "Label3D", true, false):
		if l.text == "Роща «Берёзки»": sign = true
	ok(sign, "у входа табличка «Роща «Берёзки»»")
	var far_farm := true
	for t in trees:
		if Farm.AREA.has_point(t): far_farm = false
	ok(far_farm, "на ферме деревьев нет")

	print("== Лесополосы")
	var north := 0
	var south := 0
	var on_road := 0
	var at_exit := 0
	var exits := []
	for r in Region.ROADS:
		if absf((r[0] as Vector2).y) < 6.0: exits.append((r[0] as Vector2).x)
	for t in trees:
		if absf(t.y) < 9.0 and absf(t.x) < 1800.0: on_road += 1
		if t.x > 100.0 and t.x < 500.0:
			if t.y < -14.0 and t.y > -24.0: north += 1
			if t.y > 14.0 and t.y < 24.0: south += 1
		for ex in exits:
			if absf(t.x - float(ex)) < 20.0 and absf(t.y) < 24.0: at_exit += 1
	ok(north > 60 and south > 60, "вдоль трассы берёзы с обеих сторон: %d и %d на 400 м" % [north, south])
	ok(on_road == 0, "на трассе и обочинах деревьев нет: %d" % on_road)
	ok(at_exit == 0, "у съездов к сёлам — разрывы")

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
