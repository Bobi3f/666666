extends SceneTree
var W
func _initialize() -> void:
	root.size = Vector2i(1400, 1000)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
	root.get_node("TimeManager").minutes = 12 * 60.0
	W.get_node("Player").set_physics_process(false)
	var cam := Camera3D.new()
	W.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(OS.get_environment("SZ"))
	cam.far = 500
	var c := Vector3(float(OS.get_environment("CX")), 200, float(OS.get_environment("CZ")))
	cam.global_position = c
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.make_current()
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
	quit()
