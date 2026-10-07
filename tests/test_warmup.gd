extends SceneTree
## Без подвисаний: шейдеры прогреваются за экраном загрузки — каждый
## материал мира рисуется один раз заранее, а не когда впервые попадёт в кадр;
## стоящие машины и камеры, в которые никто не смотрит, кадр не тратят.
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
	var mats := ShaderWarmup.collect(W)
	var shaders := {}
	for m in mats:
		if m is ShaderMaterial: shaders[(m as ShaderMaterial).shader] = true
	ok(mats.size() > 10, "материалов к прогреву: %d" % mats.size())
	ok(shaders.has(MeshBuilder.vehicle_material().shader), "среди них машины")
	ok(shaders.has(PersonModel.material().shader), "и люди — один шейдер на всех")
	ok(shaders.has(Vegetation.grass_material.shader), "и трава")
	var tree_mat := false
	for n in W.get_node("Vegetation").get_children():
		var mmi := n as MultiMeshInstance3D
		if mmi and n.name.begins_with("Trees_") and mmi.multimesh.mesh.get_surface_count() > 0:
			var tm := mmi.multimesh.mesh.surface_get_material(0)
			var key: Variant = (tm as ShaderMaterial).shader if tm is ShaderMaterial else tm
			for m in mats:
				var mk: Variant = (m as ShaderMaterial).shader if m is ShaderMaterial else m
				if mk == key: tree_mat = true
			break
	ok(tree_mat, "и деревья (материал внутри пачки)")
	var t := Time.get_ticks_msec()
	var n: int = await ShaderWarmup.run(W)
	print("  прогрев занял %d мс" % (Time.get_ticks_msec() - t))
	ok(n == mats.size(), "все нарисованы: %d" % n)
	await frames(2)
	ok(W.find_child("ShaderWarmup", true, false) == null, "квадратики убраны")
	print("== Лишняя работа каждый кадр")
	var car: Vehicle = W.get_node("Car")
	for i in 5: await physics_frame
	ok(car._asleep(), "стоящая машина без водителя спит — физику не считает")
	car.global_position += Vector3(0, 0, 0.5)
	ok(not car._asleep(), "сдвинули — проснулась")
	car.speed = 3.0
	ok(not car._asleep(), "катится — не спит")
	car.speed = 0.0
	var idle := 0
	for c in W.find_children("*", "SmoothCamera", true, false):
		if not c.current:
			c._ready_xf = true
			idle += 1
	await physics_frame
	var still := 0
	for c in W.find_children("*", "SmoothCamera", true, false):
		if not c.current and not c._ready_xf: still += 1
	ok(idle > 5 and still == idle, "камеры, в которые не смотрят, не считаются: %d из %d" % [still, idle])
	var boot := FileAccess.get_file_as_string("res://scripts/ui/boot.gd")
	ok(boot.contains("ShaderWarmup.run(world)"), "при запуске — за экраном загрузки")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
