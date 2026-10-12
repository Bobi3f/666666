extends SceneTree
## Роща «Берёзки» с тропинками и полянкой, лесополосы вдоль трассы.
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
	root.get_node("TimeManager").minutes = 11 * 60.0
	cam = Camera3D.new(); cam.far = 600; cam.fov = 60; W.add_child(cam)
	await shot("g_road_east", Vector3(150, 2.2, 3.5), Vector3(400, 2.0, 0))
	await shot("g_road_west", Vector3(-300, 2.2, -3.5), Vector3(-700, 2.0, 0))
	await shot("g_grove_air", Vector3(60, 45, 20), Vector3(118, 0, 110))
	await shot("g_grove_entry", Vector3(70, 1.7, 22), Vector3(90, 1.5, 55))
	await shot("g_path", Vector3(100, 1.7, 68), Vector3(118, 1.3, 95))
	await shot("g_clearing", Vector3(132, 1.8, 120), Vector3(124, 0.5, 112))
	quit()
