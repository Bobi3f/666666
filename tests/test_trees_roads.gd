extends SceneTree
## На дорогах деревьев нет: трасса, грунтовки района, полевые и лесные
## дороги, улицы Каменки и города, рельсы.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func on_road(p: Vector3) -> String:
	if absf(p.z) < 6.5: return "трасса"
	if Region.road_dist(p.x, p.z) < Region.ROAD_HALF + 1.0: return "грунтовка района"
	for r in Roads.all_rects():
		if (r as Rect2).grow(1.0).has_point(Vector2(p.x, p.z)): return "полевая/лесная"
	if Rect2(-166, -43.5, 110, 7).has_point(Vector2(p.x, p.z)) or Rect2(-63, -43, 7, 38).has_point(Vector2(p.x, p.z)): return "улица Каменки"
	var l := Town.l(p)
	for r in [Rect2(93, 3, 8, 175), Rect2(39, 54, 152, 8), Rect2(189, 54, 18, 8), TownEast.EAST_STREET.grow(1.0), TownEast.EAST_ROAD.grow(1.0)]:
		if (r as Rect2).has_point(Vector2(l.x, l.z)): return "улица города"
	if Railway.dist(p.x, p.z) < 3.0: return "рельсы"
	return ""
func _run() -> void:
	for i in 5: await process_frame
	var veg = W.get_node("Vegetation")
	var bad := {}
	var total := 0
	for kind in veg._trees:
		for xf in veg._trees[kind]:
			total += 1
			var o: Vector3 = (xf as Transform3D).origin
			var w := on_road(o)
			if w != "":
				if not bad.has(w): bad[w] = []
				bad[w].append(o.round())
	print("== Деревья и дороги")
	ok(total > 5000, "деревьев в мире: %d" % total)
	for k in ["трасса", "грунтовка района", "полевая/лесная", "улица Каменки", "улица города", "рельсы"]:
		var list: Array = bad.get(k, [])
		ok(list.is_empty(), "%s — без деревьев%s" % [k, "" if list.is_empty() else ": %d, например %s" % [list.size(), str(list.slice(0, 3))]])
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
