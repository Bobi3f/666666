extends SceneTree
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func view(name: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c is CanvasLayer: c.visible = false
	var WM = root.get_node("WeatherManager")
	WM.set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 12 * 60.0
	var P = W.get_node("Player"); P.set_physics_process(false); P.global_position = Vector3(0, 0.2, 60)
	cam = Camera3D.new(); W.add_child(cam)
	await view("01_square", Vector3(100, 7, 5), Vector3(122, 0, 22))
	await view("02_shops", Vector3(100, 3, 8), Vector3(88, 1.5, 24))
	await view("03_bridge", Vector3(-102, 3.5, -95), Vector3(-112, 0, -86))
	await view("04_field_road", Vector3(-58, 2.2, -31), Vector3(-20, 0, -38))
	var PR = root.get_node("Progress")
	for id in ["tv", "dog", "greenhouse"]: PR.add_item(id)
	for i in 5: await process_frame
	await view("05_yard", Vector3(-120, 4, -36), Vector3(-127, 0.5, -50))
	await view("06_greenhouse", Vector3(-110, 5, -60), Vector3(-125, 0.5, -68))
	var h = W.get_node("House_-125_-56")
	var r: Rect2 = h._room_rect()
	var c3: Vector3 = h.to_global(Vector3(r.end.x - 0.4, 1.6, r.end.y - 0.4))
	await view("07_tv", c3, h.to_global(Vector3(r.position.x + 0.3, 0.8, r.position.y + 0.6)))
	WM.set_kind(2, 9999.0)
	WM.wetness = 0.9
	root.get_node("TimeManager").minutes = 16 * 60.0
	await view("08_puddles", Vector3(-100, 2.5, -36), Vector3(-80, 0, -40))
	quit()
