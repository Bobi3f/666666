extends SceneTree
## Принцесса: корона, розовое платье, две собачки и кот.
var W
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 12: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("TimeManager").minutes = 13 * 60.0
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var PR: Princess = W.princess
	PR.set_process(false)
	var g := PR.girl
	g.rotation.y = PI
	var basis := Basis(Vector3.UP, g.rotation.y)
	for i in PR.pets.size():
		var p: Node3D = PR.pets[i]
		p.position = g.position + basis * Princess.PET_OFFSETS[i] * 0.8
		p.rotation.y = g.rotation.y
	root.get_node("GameManager").player.global_position = g.global_position + Vector3(8, 0.1, 8)
	var cam := Camera3D.new(); cam.fov = 45; W.add_child(cam); cam.make_current()
	cam.global_position = g.global_position + Vector3(1.2, 1.5, 3.2)
	cam.look_at(g.global_position + Vector3(0, 0.8, 0.6))
	for i in 12: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/princess.png")
	cam.global_position = g.global_position + Vector3(0.35, 1.9, 0.9)
	cam.look_at(g.global_position + Vector3(0, 1.6, 0))
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/princess_crown.png")
	quit()
