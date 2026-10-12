extends SceneTree
## Уличный музыкант у сельмага: общий план и вблизи — гитара, кепка с деньгами.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func shot(n: String, at: Vector3, look: Vector3) -> void:
	cam.make_current(); cam.global_position = at; cam.look_at(look)
	await save(n)
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 15 * 60.0
	W.get_node("Player").global_position = Vector3(-60, 0.3, -40)
	cam = Camera3D.new(); cam.fov = 55; W.add_child(cam)
	var bk: Node3D = W.get_node("Busker")
	var xf: Transform3D = bk.global_transform
	await shot("busker_wide", xf * Vector3(3.0, 2.2, -6.5), xf * Vector3(0, 0.8, 0))
	await shot("busker_front", xf * Vector3(0.3, 1.25, -2.4), xf * Vector3(0.05, 0.75, -0.2))
	await shot("busker_cap", xf * Vector3(0.9, 1.0, -1.7), xf * Vector3(0.45, 0.05, -0.85))
	await shot("busker_side", xf * Vector3(2.2, 1.3, -1.2), xf * Vector3(0, 0.8, -0.2))
	quit()
