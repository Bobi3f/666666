extends SceneTree
var W
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func snap(n: String) -> void:
	for i in 12: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	var TM = root.get_node("TimeManager"); var WM = root.get_node("WeatherManager")
	WM.set_kind(0, 99999.0); WM.cloud = 0.0
	var cam := Camera3D.new(); cam.far = 700.0
	W.add_child(cam)
	cam.global_position = Vector3(-100, 3, -40); cam.look_at(Vector3(-60, 30, -120)); cam.current = true
	for h in [["day", 12.0], ["sunset", 19.5], ["dawn", 6.2]]:
		TM.minutes = h[1] * 60.0
		W._update_daylight()
		await snap("sky_" + h[0])
	WM.set_kind(1, 99999.0); WM.cloud = 1.0
	TM.minutes = 12 * 60.0
	await snap("sky_cloudy")
	quit()
