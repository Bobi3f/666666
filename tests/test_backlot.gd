extends SceneTree
## Задворки у бурсы: девятиэтажки, котельная с трубой, бетонный забор,
## теплотрасса, тусовка у бочки с огнём, граффити, мусор — и ничего не
## стоит на улице, в бурсе, пятиэтажках и гаражах.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await frames(10)
	var a := Backlot.AREA
	for r in [TownEast.EAST_STREET, TownEast.COLLEGE, TownEast.FLATS[0], TownEast.FLATS[1], TownEast.MY_GARAGES]:
		ok(not a.intersects(r), "задворки не налезают на %s" % r)
	ok(Railway.dist(Town.w(Vector3(a.get_center().x, 0, a.end.y)).x, a.end.y) > 10.0, "до железной дороги далеко")
	var labels := []
	for l in W.find_children("*", "Label3D", true, false): labels.append(l.text)
	ok(labels.has("ЦОЙ ЖИВ") and labels.has("ПРАВДА"), "граффити на заборе и котельной")
	# Деревьев на задворках нет
	var veg = W.get_node("Vegetation")
	var inside := 0
	for kind in veg._trees:
		for xf in veg._trees[kind]:
			var o := Town.l((xf as Transform3D).origin)
			if a.has_point(Vector2(o.x, o.z)): inside += 1
	ok(inside == 0, "деревьев на задворках нет: %d" % inside)
	# Стены и труба твёрдые: луч сверху в котельную упирается в крышу
	var space: PhysicsDirectSpaceState3D = W.get_world_3d().direct_space_state
	var from := Town.w(Vector3(Backlot.BOILER.get_center().x, 20, Backlot.BOILER.get_center().y))
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 30, 0)))
	ok(not hit.is_empty() and float(hit.position.y) > 5.0, "котельная твёрдая: крыша на %.1f м" % (float(hit.position.y) if not hit.is_empty() else -1.0))
	var VO = W.get_node("Voices")
	var spots := {}
	for i in VO.get_script().SPOTS.size(): spots[VO.get_script().SPOTS[i].name] = i
	root.get_node("TimeManager").minutes = 20 * 60.0
	ok(VO.audible(Town.w(Backlot.FIRE)).has(spots["backlot"]), "вечером у бочки голоса")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
