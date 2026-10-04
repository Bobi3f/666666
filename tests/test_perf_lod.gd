extends SceneTree
## Оптимизация для телефона: мелочь мира и подробные деревья вдали не
## рисуются (вместо них — упрощённые), интерьер дома издали — простой фасад,
## лампы в домах и свет в салоне не задевают весь мир, фары попуток —
## один меш, 3D на телефоне — постоянное число строк.
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
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func tris(m: Mesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		n += m.surface_get_array_len(s) / 3
	return n

func _run() -> void:
	for i in 5: await process_frame
	var SM = root.get_node("SettingsManager")
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	# Детализацию меняем без записи настроек на диск — другим тестам не мешаем
	var detail0: int = SM.detail
	var set_detail := func(v: int) -> void:
		SM.detail = v
		SM.changed.emit()
	set_detail.call(0)

	print("== Мелочь мира — своими кусками, вдали не рисуется")
	for path in ["WorldMesh", "Region/RegionMesh"]:
		var small := 0
		var big := 0
		var ranges_ok := true
		for c in W.get_node(path).get_children():
			var gi := c as GeometryInstance3D
			if c.name.begins_with("Small_"):
				small += tris((c as MeshInstance3D).mesh)
				if gi.visibility_range_end != SM.small_range(): ranges_ok = false
			else:
				big += tris((c as MeshInstance3D).mesh)
		ok(small > 0 and ranges_ok, "%s: мелочь %d тыс. треугольников, видна до %d м" % [path, small / 1000, int(SM.small_range())])
		ok(small > big * 0.3, "%s: мелочь — заметная доля мира (%d из %d тыс.)" % [path, small / 1000, (small + big) / 1000])
	var wm_chunk: GeometryInstance3D = null
	for c in W.get_node("WorldMesh").get_children():
		if c.name.begins_with("Chunk_"): wm_chunk = c; break
	ok(wm_chunk.visibility_range_end == 0.0, "крупное (дома, дороги) видно всегда")
	set_detail.call(2)
	var sm0: GeometryInstance3D = null
	for c in W.get_node("WorldMesh").get_children():
		if c.name.begins_with("Small_"): sm0 = c; break
	ok(sm0.visibility_range_end == SM.small_range() and SM.small_range() > 100.0, "на высокой детализации мелочь видна дальше: %d м" % int(sm0.visibility_range_end))
	set_detail.call(0)

	print("== Деревья: подробные вблизи, упрощённые дальше, силуэты у горизонта")
	var V = W.get_node("Vegetation")
	var near: MultiMeshInstance3D = null
	var mid: MultiMeshInstance3D = null
	for c in V.get_children():
		if c.name.begins_with("Trees_0_") and near == null: near = c
		if c.name.begins_with("TreesMid_0_") and mid == null: mid = c
	ok(near != null and mid != null, "у ели две модели: %s, %s" % [near.name, mid.name])
	var full := tris(near.multimesh.mesh)
	var lite := tris(mid.multimesh.mesh)
	ok(lite * 8 < full, "упрощённая ель: %d треугольников вместо %d" % [lite, full])
	ok(near.visibility_range_end == SM.tree_lod_range() and mid.visibility_range_begin == SM.tree_lod_range()
		and mid.visibility_range_end == SM.tree_range(), "смена моделей на %d м, упрощённые — до %d м" % [int(SM.tree_lod_range()), int(SM.tree_range())])
	ok(mid.multimesh.instance_count == near.multimesh.instance_count, "в каждом куске те же деревья в обеих моделях")
	var kinds_ok := true
	for k in 4:
		var has := false
		for c in V.get_children():
			if c.name.begins_with("TreesMid_%d_" % k): has = true
		if not has: kinds_ok = false
	ok(kinds_ok, "упрощённые модели у ели, яблони, берёзы и куста")

	print("== Дом издали — фасад, лампы светят только внутри")
	var H = W.get_node("House_-125_-24")
	var im: MeshInstance3D = H.get_node("InteriorMesh")
	var fa: MeshInstance3D = H.get_node("Facade")
	ok(im.visibility_range_end == H.INSIDE_RANGE and fa.visibility_range_begin == H.INSIDE_RANGE, "интерьер — до %d м, дальше фасад" % int(H.INSIDE_RANGE))
	ok(tris(fa.mesh) < 300 and fa.mesh.get_surface_count() == 1, "фасад: %d треугольников одним мешем (интерьер — %d в %d поверхностях)" % [tris(fa.mesh), tris(im.mesh), im.mesh.get_surface_count()])
	var lamps := 0
	var masked := true
	for c in H.get_children():
		if c is OmniLight3D:
			lamps += 1
			if (c as OmniLight3D).light_cull_mask != H.INSIDE_LAYER: masked = false
	ok(lamps == 2 and masked and (im.layers & H.INSIDE_LAYER) != 0, "две лампы в доме светят только на интерьер")
	var P = W.get_node("Player")
	ok((P._body_mesh.layers & H.INSIDE_LAYER) != 0, "игрока в доме лампы освещают")
	var door_ok := false
	for c in H.get_children():
		if c.name.begins_with("Door") and c.get_child(0) is MeshInstance3D:
			door_ok = (c.get_child(0) as MeshInstance3D).visibility_range_end == H.INSIDE_RANGE
	ok(door_ok, "двери — тоже только вблизи")

	print("== Свет в салоне — только с водителем")
	var car = W.get_node("Niva")
	ok(car._cabin_light != null and not car._cabin_light.visible, "у стоящей машины свет в салоне выключен")
	ok(car._cabin_light.light_cull_mask == car.CABIN_LAYER and (car._paint_mesh.layers & car.CABIN_LAYER) != 0, "и светит он только на саму машину")
	P.global_position = car.global_position + Vector3(0, 0.1, 2.0)
	await frames(3)
	car._on_enter()
	await frames(2)
	ok(car._cabin_light.visible, "сел за руль — свет в салоне горит")
	car.speed = 0.0
	car.exit_car()
	await frames(2)
	ok(not car._cabin_light.visible, "вышел — погас")

	print("== Попутки: фары и стопы — один меш")
	var tr = child("traffic.gd")
	var body: Node3D = tr._vehicles[0].body
	var lights: MeshInstance3D = body.get_node("Lights")
	ok(lights.mesh.get_surface_count() == 2 and body.get_child_count() <= 5, "фары и стопы: %d поверхности, узлов у машины %d" % [lights.mesh.get_surface_count(), body.get_child_count()])
	tr._vehicles[0].head.albedo_color = Color.RED
	ok(lights.mesh.surface_get_material(0).albedo_color == Color.RED, "цвет фар по-прежнему меняется на ходу")

	print("== Дальние попутки молчат")
	await frames(3)
	var cam := root.get_viewport().get_camera_3d().global_position
	var near_on := true
	var far_off := true
	var heard := 0
	for v in tr._vehicles:
		var d: float = absf((v.body as Node3D).global_position.x - cam.x)
		var playing: bool = (v.snd as AudioStreamPlayer3D).playing
		if playing: heard += 1
		if d > tr.SOUND_RANGE + 20.0 and playing: far_off = false
		if d < tr.SOUND_RANGE - 20.0 and absf(cam.z) < 40.0 and not playing: near_on = false
	ok(far_off and near_on and heard < tr._vehicles.size(), "мотор слышно только у ближних: %d из %d" % [heard, tr._vehicles.size()])

	print("== Номерные знаки")
	var re := RegEx.create_from_string("^[а-я] \\d\\d-\\d\\d [А-Я]{2}$")
	var cplates: Node = W.get_node("Car/Body/Plates") if W.has_node("Car/Body/Plates") else W.get_node("Car").find_child("Plates", true, false)
	var clabels: Array = cplates.find_children("*", "Label3D", false, false)
	ok(clabels.size() == 2 and re.search((clabels[0] as Label3D).text) != null, "у «Жигулей» номер спереди и сзади: %s" % (clabels[0] as Label3D).text)
	var PL = load("res://scripts/vehicles/plates.gd")
	ok(PL.number(42) == PL.number(42) and PL.number(42) != PL.number(43), "номер у машины постоянный, у разных — разный")
	ok((clabels[0] as Label3D).visibility_range_end <= 20.0 and cplates.get_node_or_null("Plate") == null, "надпись — только вблизи, табличка — своя у модели")
	var mplates: Node = W.get_node("Moto").find_child("Plates", true, false)
	var mlabels: Array = mplates.find_children("*", "Label3D", false, false)
	ok(mlabels.size() == 1 and (mlabels[0] as Label3D).text.contains("\n"), "у Явы — один номер сзади, в две строки")
	var tplates: Node = tr._vehicles[0].body.get_node_or_null("Plates")
	ok(tplates != null and tplates.find_children("*", "Label3D", false, false).size() == 2, "у попуток тоже номера")

	print("== Телефон: 3D — постоянное число строк")
	var GM = root.get_node("GameManager")
	GM.touch_mode = true
	root.size = Vector2i(2400, 1080)
	W._fit_render_scale()
	var sc: float = root.scaling_3d_scale
	ok(absf(sc * 1080.0 - SM.render_lines()) < 2.0, "экран 2400×1080: 3D в %d%% — %d строк" % [int(sc * 100.0), int(sc * 1080.0)])
	root.size = Vector2i(1280, 600)
	W._fit_render_scale()
	ok(root.scaling_3d_scale <= 0.65 + 0.001, "на маленьком экране — не больше 65%%: %d%%" % int(root.scaling_3d_scale * 100.0))
	SM._lines_k = 0.75
	root.size = Vector2i(2400, 1080)
	W._fit_render_scale()
	ok(root.scaling_3d_scale < sc, "слабый телефон — картинка ещё проще: %d%%" % int(root.scaling_3d_scale * 100.0))
	SM._lines_k = 1.0
	GM.touch_mode = false
	set_detail.call(detail0)

	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)
