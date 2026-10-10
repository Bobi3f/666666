extends SceneTree
## Трава кусками вокруг камеры: вся трава района разом занимала в браузере
## ~56 МБ (каждый MultiMesh движок держит в памяти ещё трижды), и iPhone
## закрывал страницу. Теперь стоят только куски в пределах видимости травы,
## уезжаешь — дальние убираются, впереди строятся; каждый кусок всякий раз
## одинаковый.
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


func cells_near(veg: Vegetation, at: Vector3, dist: float) -> int:
	var n := 0
	for c in veg._cover:
		if ((c as Vector2) + Vector2(Vegetation.CHUNK, Vegetation.CHUNK) * 0.5).distance_to(Vector2(at.x, at.z)) <= dist:
			n += 1
	return n


func instances(veg: Vegetation) -> int:
	var n := 0
	for c in veg._cover:
		for mi in veg._cover[c]:
			n += (mi as MultiMeshInstance3D).multimesh.instance_count
	return n


func cell_print(veg: Vegetation, c: Vector2) -> String:
	var out := []
	for mi in veg._cover[c]:
		var mm := (mi as MultiMeshInstance3D).multimesh
		out.append("%s:%d:%s" % [mi.name.rstrip("0123456789@").get_slice("@", 0), mm.instance_count, str(mm.get_instance_transform(0).origin)])
	return ",".join(out)


func _run() -> void:
	await frames(3)
	var SM = root.get_node("SettingsManager")
	var veg: Vegetation = W.get_node("Vegetation")
	var P: Node3D = W.get_node("Player")
	# Детализация в чистых настройках бывает любой — дальность травы от неё
	var detail0: int = SM.detail
	SM.set_detail(1)
	veg.update_cover(P.global_position, INF)
	await frames(2)
	var total: int = veg.counts["grass_cells"]
	print("== Сразу после постройки")
	ok(total > 300, "кусков, где может расти трава: %d" % total)
	ok(veg.cover_count() > 0 and veg.cover_count() * 4 < total, "стоят только ближние: %d из %d" % [veg.cover_count(), total])
	ok(cells_near(veg, P.global_position, 40.0) >= 2, "вокруг игрока трава есть")
	ok(cells_near(veg, P.global_position + Vector3(0, 0, 0), 1000.0) == veg.cover_count() and cells_near(veg, P.global_position, veg.cover_radius() + 40.0) == veg.cover_count(),
		"все куски — в пределах %d м от игрока" % int(veg.cover_radius()))
	ok(Vegetation.grass_material != null, "материал травы на месте (сезоны и прогрев)")

	print("== Уехал — впереди трава, позади убрана")
	veg.set_process(false)
	var home := P.global_position
	# Кусок с травой подальше от дома — дальше, чем держится трава
	var far := home
	for cc in veg._cover_cells:
		var p3 := Vector3(cc.x + Vegetation.CHUNK * 0.5, 0.0, cc.y + Vegetation.CHUNK * 0.5)
		if p3.distance_to(Vector3(home.x, 0.0, home.z)) > 320.0:
			far = p3
			break
	veg.update_cover(far, INF)
	await frames(2)
	ok(cells_near(veg, home, 40.0) == 0, "у дома кусков не осталось")
	ok(cells_near(veg, far, 40.0) >= 2, "на новом месте — трава")
	var grass_nodes := 0
	for k in veg._cover: grass_nodes += (veg._cover[k] as Array).size()
	ok(grass_nodes > 0 and grass_nodes < 400, "узлов травы: %d (вся трава района — около 2300)" % grass_nodes)

	print("== Тот же кусок — та же трава")
	var c: Vector2 = veg._cover.keys()[0]
	for k in veg._cover:
		if (veg._cover[k] as Array).size() > 0 and ((k as Vector2) + Vector2(12.5, 12.5)).distance_to(Vector2(far.x, far.z)) < 30.0:
			c = k
	var before := cell_print(veg, c)
	veg.update_cover(Vector3(5000, 0, 5000), INF)
	await frames(2)
	ok(veg.cover_count() == 0, "далеко от сёл — ни одного куска")
	veg.update_cover(far, INF)
	ok(veg._cover.has(c) and cell_print(veg, c) == before, "кусок построен заново — травинки на тех же местах")

	print("== Детализация: выше — трава дальше и кусков больше")
	SM.set_detail(0)
	veg.update_cover(far, INF)
	await frames(2)
	var low := veg.cover_count()
	var low_inst := instances(veg)
	var mi0 := veg._cover[veg._cover.keys()[0]][0] as MultiMeshInstance3D
	ok(is_equal_approx(mi0.visibility_range_end, SM.grass_range() * (1.6 if mi0.name.begins_with("wheat") else 1.0)), "видно до %d м" % int(SM.grass_range()))
	SM.set_detail(2)
	veg.update_cover(far, INF)
	await frames(2)
	ok(veg.cover_count() > low, "на высокой кусков больше: %d против %d" % [veg.cover_count(), low])
	ok(low_inst < 60000, "на низкой травинок в памяти: %d (вся трава района — около 300 тысяч)" % low_inst)
	SM.set_detail(detail0)

	print("== Сама следует за камерой")
	veg.set_process(true)
	P.global_position = home
	await frames(5)
	var cam: Camera3D = W.get_viewport().get_camera_3d()
	var at: Vector3 = cam.global_position if cam else home
	var t0 := Time.get_ticks_msec()
	while cells_near(veg, at, 40.0) < 2 and Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	ok(cells_near(veg, at, 40.0) >= 2, "вернулся к дому — трава снова вокруг")
	ok(cells_near(veg, far, 40.0) == 0, "а там, где был, — убрана")

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
