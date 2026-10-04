extends SceneTree
## Снимки: трактор МТЗ-80 как на фото — спереди сбоку, сбоку, сзади и
## кабина изнутри с места тракториста.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func shot(name: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c.get_script() and c.get_script().resource_path.ends_with("hud.gd"): c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 12 * 60.0
	var T: Vehicle = null
	for v in W.get_tree().get_nodes_in_group("vehicles"):
		if v.kind == "tractor": T = v
	T.global_position = Vector3(40, 0.3, 40)
	T.rotation.y = 0.0
	for i in 30: await physics_frame
	var xf := T.global_transform
	cam = Camera3D.new(); cam.far = 700.0; cam.fov = 45.0; W.add_child(cam)
	cam.make_current()
	await shot("tractor_34", xf * Vector3(-5.0, 2.2, -5.5), xf * Vector3(0, 1.2, -0.3))
	await shot("tractor_side", xf * Vector3(-8.0, 1.6, -0.3), xf * Vector3(0, 1.2, -0.3))
	await shot("tractor_rear", xf * Vector3(2.5, 2.2, 6.5), xf * Vector3(0, 1.2, 0.5))
	cam.global_position = xf * Vector3(0.0, 2.6, 1.05)
	cam.fov = 75.0
	cam.look_at(xf * Vector3(0.0, 1.6, -0.3))
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/tractor_cabin.png" % OS.get_environment("SHOTS"))
	quit()
