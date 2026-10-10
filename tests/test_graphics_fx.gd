extends SceneTree
## Классная графика: блестящая краска и хром у машин, тени облаков плывут по
## полям, закат светится в дымке, на высокой — сочнее и с виньеткой; на
## низкой (телефон) — ничего из этого не считается.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
## Параметр шейдера числом (не заданный — 0).
func par(m: ShaderMaterial, n: String) -> float:
	var v = m.get_shader_parameter(n)
	return 0.0 if v == null else float(v)
func frames(n: int) -> void:
	for i in n: await process_frame
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await frames(10)
	var SM = root.get_node("SettingsManager"); var TM = root.get_node("TimeManager"); var WM = root.get_node("WeatherManager")
	var was: int = SM.detail
	SM.set_detail(2)
	WM.set_kind(0, 9999.0)
	TM.minutes = 12 * 60.0
	await frames(3)

	print("== Машины блестят")
	var car: Vehicle = W.get_node("Car")
	ok(car._paint_mesh.material_override == MeshBuilder.vehicle_material(), "у «Жигулей» свой материал")
	ok(par(MeshBuilder.vehicle_material(), "gloss") == 1.0, "краска и хром блестят")
	ok(par(MeshBuilder.world_material(), "gloss") == 0.0, "дома и земля — матовые")
	var tr = null
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("traffic.gd"): tr = c
	if tr and not tr._vehicles.is_empty():
		var body: Node3D = tr._vehicles[0].body
		var mi: MeshInstance3D
		for ch in body.get_children():
			if ch is MeshInstance3D and ch.mesh and ch.mesh.get_surface_count() == 1 and ch.material_override == MeshBuilder.vehicle_material(): mi = ch
		ok(mi != null, "попутки тоже блестят")

	print("== Тени облаков")
	var k: float = par(MeshBuilder.world_material(), "clouds")
	ok(k > 0.5, "ясный полдень — тени облаков плывут: %.2f" % k)
	ok(par(Vegetation.grass_material, "clouds") == k, "и по траве тоже")
	WM.set_kind(3, 9999.0)
	for i in 30:
		WM.cloud = 1.0
		await process_frame
	k = par(MeshBuilder.world_material(), "clouds")
	ok(k < 0.05, "в сплошных тучах теней нет: %.2f" % k)
	WM.set_kind(0, 9999.0)
	WM.cloud = 0.0
	TM.minutes = 2 * 60.0
	await frames(3)
	ok(par(MeshBuilder.world_material(), "clouds") < 0.01, "ночью теней облаков нет")

	print("== Закат")
	TM.minutes = 19.6 * 60.0
	await frames(3)
	var env: Environment = W._env
	ok(env.fog_sun_scatter > 0.5, "на закате дымка у солнца светится: %.2f" % env.fog_sun_scatter)
	TM.minutes = 12 * 60.0
	await frames(3)
	ok(env.fog_sun_scatter < 0.3, "днём — как раньше")

	print("== Высокая и низкая")
	ok(W._vignette.visible and env.adjustment_saturation > 1.08, "на высокой — сочнее и с виньеткой")
	SM.set_detail(0)
	await frames(3)
	ok(not W._vignette.visible and par(MeshBuilder.world_material(), "clouds") == 0.0, "на низкой (телефон) — без виньетки и теней облаков")
	SM.set_detail(was)

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
