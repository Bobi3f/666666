extends SceneTree
## Снимки: механика на компьютере — схема рычага «H» у «Жигулей» (третья,
## сцепление выжато) и столбик передач у «Явы».
var W
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c.get_script() and c.get_script().resource_path.ends_with("traffic.gd"): c.queue_free()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var SM = root.get_node("SettingsManager")
	var PR = root.get_node("Progress")
	PR.buy_car("car"); PR.add_category("B"); PR.add_category("A"); PR.buy_car("moto")
	SM.set_auto_gearbox(false)
	var C: Vehicle = W.get_node("Car")
	C.global_position = Vector3(-150, 0.3, 2.0); C.rotation.y = -PI / 2.0
	for i in 5: await physics_frame
	C._on_enter()
	C.chase_view = true
	C._update_camera(1.0)
	C.engine_on = true
	C.gear = 3
	C.clutch = 0.3
	C.set_physics_process(false)
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/manual_car.png")
	C.set_physics_process(true)
	C.exit_car()
	for i in 3: await physics_frame
	var M: Vehicle = W.get_node("Moto")
	M.global_position = Vector3(-150, 0.3, -2.0); M.rotation.y = -PI / 2.0
	for i in 5: await physics_frame
	M._on_enter()
	M.engine_on = true
	M.gear = 2
	M.set_physics_process(false)
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/manual_moto.png")
	SM.set_auto_gearbox(true)
	quit()
