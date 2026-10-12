extends SceneTree
## Коттедж с балконом и беседкой, дом в городе и квартира — таблички «ПРОДАЁТСЯ».
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
func shot(n: String, at: Vector3, look: Vector3) -> void:
	W.get_node("Player").global_position = Vector3(at.x, 0.2, at.z)
	for i in 3: await physics_frame
	cam.make_current(); cam.global_position = at; cam.look_at(look)
	await save(n)
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 12 * 60.0
	cam = Camera3D.new(); cam.far = 600; cam.fov = 60; W.add_child(cam)
	root.get_node("Progress").house_level = 3
	root.get_node("Progress").house_changed.emit(3)
	await process_frame
	await shot("h_cottage", Vector3(-112, 4.5, -32), Vector3(-125, 3.5, -55))
	await shot("h_cottage_side", Vector3(-145, 6, -40), Vector3(-130, 2.5, -56))
	await shot("h_town_house", Town.w(Vector3(213, 2.0, 184)), Town.w(Vector3(213, 1.8, 165)))
	await shot("h_flat", Town.w(Vector3(262, 2.0, 82)), Town.w(Vector3(273, 2.2, 76)))
	quit()
