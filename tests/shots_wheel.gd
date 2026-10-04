extends SceneTree
var W
func _initialize() -> void:
	root.size = Vector2i(int(OS.get_environment("SW")), int(OS.get_environment("SH")))
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func snap(n: String) -> void:
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 10: await process_frame
	var tc
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c.get_script() and c.get_script().resource_path.ends_with("touch_controls.gd"): tc = c
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var V = W.get_node("Car")
	V.global_position = Vector3(-150, 0.1, 2.0); V.rotation.y = -PI / 2.0
	V._on_enter(); V.fuel = 25.0
	for i in 20: await process_frame
	tc._wheel_rot = -0.9
	tc._wheel_index = 5
	tc._wheel.queue_redraw()
	await snap("wheel_cockpit")
	V.chase_view = true
	V._update_camera(1.0)
	await snap("wheel_chase")
	quit()
