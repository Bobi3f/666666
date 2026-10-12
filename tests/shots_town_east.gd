extends SceneTree
## Снимки города на новом месте: дорога из Каменки, въезд, восточная часть
## (банк, авторынок, СТО, бурса, дома, участки, гаражи), парк, дворы.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func view(name: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = Town.w(from)
	cam.look_at(Town.w(at))
	cam.make_current()
	var P = W.get_node("Player"); P.global_position = Town.w(at) + Vector3(0, 0.2, 0)
	for i in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c is CanvasLayer: c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 12 * 60.0
	var P = W.get_node("Player"); P.set_physics_process(false)
	cam = Camera3D.new(); W.add_child(cam)
	# Дорога из Каменки: в координатах города Каменка — x около −760
	await view("te_road", Vector3(-640, 4, 3), Vector3(-560, 2, 3))
	await view("te_entry", Vector3(-90, 6, -10), Vector3(40, 3, 30))
	await view("te_bank", Vector3(200, 6, -14), Vector3(205, 3, 20))
	await view("te_market", Vector3(236, 12, -4), Vector3(237, 0, 30))
	await view("te_sto", Vector3(246, 6, 44), Vector3(248, 1, 68))
	await view("te_college", Vector3(285, 10, 120), Vector3(243, 4, 120))
	await view("te_flats", Vector3(240, 14, 95), Vector3(280, 6, 120))
	await view("te_plots", Vector3(232, 18, 132), Vector3(232, 0, 175))
	await view("te_garage", Vector3(258, 5, 185), Vector3(275, 1, 185))
	await view("te_park", Vector3(30, 14, 140), Vector3(-10, 4, 172))
	await view("te_wheel", Vector3(0, 4, 198), Vector3(-14, 8, 176))
	await view("te_yard", Vector3(66, 9, 104), Vector3(66, 0, 90))
	root.get_node("TimeManager").minutes = 22 * 60.0
	await view("te_night", Vector3(285, 10, 100), Vector3(260, 4, 130))
	quit()
