extends SceneTree
## Снимки: приборы «ИЖ Юпитер-5» на экране (блок лампочек и спидометр до
## 160) и щиток на руле вблизи.
var W
func _initialize() -> void:
	root.size = Vector2i(int(OS.get_environment("SW")), int(OS.get_environment("SH")))
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
	var PR = root.get_node("Progress")
	PR.buy_car("izh"); PR.add_category("A")
	var I: Vehicle = W.get_node("Izh")
	I.global_position = Vector3(-150, 0.3, -2.0); I.rotation.y = -PI / 2.0
	for i in 5: await physics_frame
	I._on_enter()
	I.chase_view = true
	I._update_camera(1.0)
	I.engine_on = true
	I.speed = 17.0
	I.set_turn(1)
	I._turn_t = 0.1
	I.set_physics_process(false)
	I.set_process(false)
	I._show_turn(true)
	for i in 15: await process_frame
	var pfx := OS.get_environment("PFX")
	root.get_viewport().get_texture().get_image().save_png("%s/izh_dash_%s.png" % [OS.get_environment("SHOTS"), pfx])
	if pfx == "pc":
		var cam := Camera3D.new(); cam.fov = 35.0; W.add_child(cam)
		var xf := I.global_transform
		cam.global_position = xf * Vector3(0.0, 1.55, -0.2)
		cam.look_at(xf * Vector3(0.0, 1.15, -0.62))
		cam.make_current()
		for i in 8: await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/izh_panel3d.png" % OS.get_environment("SHOTS"))
	quit()
