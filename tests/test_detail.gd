extends SceneTree
## Детальнее: во дворах газовая труба, шины-клумбы, бочка, велосипед,
## вёдра, скворечник; у машин зеркала, ручки, дворники, поворотники; собаки
## и куры округлые; на компьютере — высокая детализация со сглаживанием.
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
	var SM = root.get_node("SettingsManager")

	print("== Двор")
	var b := MeshBuilder.new()
	YardProps.add(b, 7, 4.5, 4.0, 0.5, false, false)
	var aabb: AABB = b.build_array_mesh().get_aabb()
	ok(aabb.position.x <= -12.4 and aabb.end.x >= 12.4, "газовая труба от соседа к соседу: x %.1f…%.1f" % [aabb.position.x, aabb.end.x])
	ok(aabb.end.y > 3.7, "скворечник на шесте: верх %.1f м" % aabb.end.y)
	ok(aabb.end.z > 12.9, "шины-клумбы на улице у забора")
	var rich := MeshBuilder.new()
	YardProps.add(rich, 7, 4.5, 4.0, 0.5, false, true)
	ok(rich._count < b._count, "у богатых велосипеда нет (у них гараж)")
	var yard: MeshInstance3D = W.get_node("PlayerYardMesh")
	ok(yard.mesh.get_aabb().size.x >= 24.9, "у своего дома тоже: ширина двора %.1f м" % yard.mesh.get_aabb().size.x)

	print("== Машины")
	for kind in ["niva", "volga", "moskvich", "zaz", "uaz", "truck", "kamaz", "bus"]:
		var mb := MeshBuilder.new()
		VehicleModels.npc(mb, kind, Color(0.5, 0.2, 0.2))
		var w: float = mb.build_array_mesh().get_aabb().size.x
		var body: float = VehicleModels.NPC_SIZE[kind].x
		ok(w > body + 0.12, "%s: зеркала по бокам — ширина %.2f м при кузове %.2f" % [kind, w, body])

	print("== Звери")
	var vil = null
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("villagers.gd"): vil = c
	var dog: MeshInstance3D = vil._dogs[0].node.get_child(0)
	var chick: MeshInstance3D = vil._chickens[0].node.get_child(0)
	var dv: int = dog.mesh.surface_get_array_len(0)
	var cv: int = chick.mesh.surface_get_array_len(0)
	ok(dv > 600, "собака округлая: %d вершин" % dv)
	ok(cv > 300, "курица округлая: %d вершин" % cv)
	ok(dog.material_override is ShaderMaterial, "собака по-прежнему виляет хвостом и бегает (шейдер)")

	print("== Люди")
	var specs := 0
	for s in range(0, 40):
		var p1 := MeshBuilder.new()
		PersonModel.person(p1, Color(float(s) / 40.0, 0.3, 0.5), Color(0.2, 0.2, 0.2), false, false)
		specs += p1._count
	ok(specs > 0, "люди строятся")

	print("== Графика")
	var fresh = load("res://scripts/core/settings_manager.gd").new()
	ok(fresh.detail == 2, "на компьютере по умолчанию высокая детализация")
	fresh.free()
	var was: int = SM.detail
	SM.set_detail(2)
	await frames(2)
	ok(root.get_viewport().msaa_3d == Viewport.MSAA_2X, "сглаживание краёв на высокой")
	SM.set_detail(1)
	await frames(2)
	ok(root.get_viewport().msaa_3d == Viewport.MSAA_DISABLED, "на средней — без сглаживания")
	SM.set_detail(was)

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
