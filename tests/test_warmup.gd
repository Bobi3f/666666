extends SceneTree
## Без подвисаний: шейдеры прогреваются за экраном загрузки — каждый
## материал мира рисуется один раз заранее, а не когда впервые попадёт в кадр.
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
	var t := Time.get_ticks_msec()
	var n: int = await ShaderWarmup.run(W)
	print("  прогрев занял %d мс" % (Time.get_ticks_msec() - t))
	ok(n == mats.size(), "все нарисованы: %d" % n)
	await frames(2)
	ok(W.find_child("ShaderWarmup", true, false) == null, "квадратики убраны")
	var boot := FileAccess.get_file_as_string("res://scripts/ui/boot.gd")
	ok(boot.contains("ShaderWarmup.run(world)"), "при запуске — за экраном загрузки")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
