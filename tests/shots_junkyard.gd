extends SceneTree
## Свалка: территория за забором, вагончик со сторожем, окно продажи и запчастей.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 560)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 12 * 60.0
	var c := Landmarks.junk_center()
	var lm: Landmarks = W.find_child("Landmarks", true, false)
	W.get_node("Player").global_position = c + Vector3(6, 0.2, 26)
	var car: Vehicle = W.get_node("Car")
	root.get_node("Progress").buy_car("car")
	car.global_position = c + Vector3(-4, 0.3, 13)
	car.health["brakes"] = 15.0
	car.health["clutch"] = 40.0
	for i in 5: await physics_frame
	cam = Camera3D.new(); cam.far = 600; cam.fov = 60; W.add_child(cam); cam.make_current()
	cam.global_position = c + Vector3(14, 12, 42); cam.look_at(c + Vector3(0, 0, 4))
	await save("junk_overview")
	cam.global_position = c + Vector3(-9, 1.8, 19.5); cam.look_at(c + Vector3(-17.5, 1.6, 15.5))
	await save("junk_hut")
	lm.open_junk()
	await save("junk_panel")
	quit()
