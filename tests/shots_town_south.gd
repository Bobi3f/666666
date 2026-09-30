extends SceneTree
## Снимки южной части города и железной дороги.
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
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 17 * 60.0
	var P = W.get_node("Player"); P.set_physics_process(false); P.global_position = Vector3(97, 0.2, 150)
	cam = Camera3D.new(); W.add_child(cam)
	var RW = W.get_node("Region/Railway")
	RW.set_process(false)
	await view("ts_station", Vector3(97, 9, 160), Vector3(97, 2, 195))
	await view("ts_platform", Vector3(60, 3.5, 199), Vector3(110, 2, 204))
	await view("ts_market", Vector3(95, 8, 125), Vector3(64, 1, 144))
	await view("ts_stadium", Vector3(120, 12, 128), Vector3(156, 0, 160))
	await view("ts_school", Vector3(58, 6, 150), Vector3(58, 3, 172))
	await view("ts_garages", Vector3(200, 6, 80), Vector3(222, 1, 80))
	await view("ts_factory", Vector3(150, 12, 190), Vector3(185, 8, 228))
	await view("ts_cross", Vector3(97, 5, 88), Vector3(97, 2, 58))
	var br: Vector2 = Railway.river_crossing()
	await view("ts_bridge", Vector3(br.x - 30, 8, br.y - 25), Vector3(br.x, 2, br.y))
	var c0: Dictionary = Railway.crossings[0]
	var cp: Vector2 = c0.p
	# Поезд на переезде
	RW.s = float(c0.along) + 30.0
	RW.dir = 1.0; RW.v = 20.0; RW.state = "run"; RW.target = -1.0
	RW._process(0.02)
	for i in 60: RW._update_crossings(0.1)
	await view("ts_crossing", Vector3(cp.x + 25, 6, cp.y - 25), Vector3(cp.x, 2, cp.y))
	await view("ts_train", Vector3(cp.x + 20, 5, cp.y + 18), Vector3(cp.x - 20, 2, cp.y))
	root.get_node("TimeManager").minutes = 22 * 60.0
	await view("ts_station_night", Vector3(97, 9, 160), Vector3(97, 2, 195))
	quit()
