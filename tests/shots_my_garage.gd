extends SceneTree
## Личный гараж у дома и его окно со списком техники.
var W
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("TimeManager").minutes = 15 * 60.0
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("Progress").owned_cars.append("car")
	var G: MyGarage = W.my_garage
	G.store_all()
	G.take_out(W.get_node("Car"))
	var cam := Camera3D.new(); cam.fov = 60; W.add_child(cam); cam.make_current()
	cam.global_position = Vector3(-110.0, 3.2, -38.0); cam.look_at(Vector3(-120.0, 1.0, -54.0))
	await save("garage_out")
	G.open()
	await save("garage_panel")
	quit()
