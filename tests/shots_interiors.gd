extends SceneTree
## Интерьеры: банк, больница, ПТУ, завод — вид от входа в зал.
var W
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 12: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 12: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("TimeManager").minutes = 12 * 60.0
	var cam := Camera3D.new(); cam.fov = 70; W.add_child(cam)
	for id in Interiors.ROOMS:
		W.interiors.enter(id)
		cam.make_current()
		var o := Interiors.origin(id)
		var s := Interiors.size(id)
		cam.global_position = o + Vector3(s.x * 0.3, minf(s.y * 0.6, 2.6), s.z * 0.5 - 0.6)
		cam.look_at(o + Vector3(-s.x * 0.1, 1.0, -s.z * 0.35))
		await save("interior_" + id)
	quit()
