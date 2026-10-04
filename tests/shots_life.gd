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
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var TM = root.get_node("TimeManager")
	TM.minutes = 12 * 60.0
	var P = W.get_node("Player"); P.set_physics_process(false); P.global_position = Vector3(0, 0.2, 60)
	cam = Camera3D.new(); W.add_child(cam)
	var L = W.get_node("StreetLife")
	# Красный: трафик собирается у стоп-линии
	L.get_script().highway = "red"
	for i in 60 * 12:
		L._t = 0.0
		await physics_frame
	await view("01_light", Town.w(Vector3(80, 4, 11)), Town.w(Vector3(95, 1.5, 0)))
	for i in 60 * 4: await physics_frame
	await view("02_walkers", Town.w(Vector3(112, 3, 36)), Town.w(Vector3(122, 0.5, 18)))
	# Коровы переходят улицу
	TM.minutes = 6 * 60.0 + 59.0
	for i in 3: await physics_frame
	TM.minutes = 7 * 60.0 + 0.5
	for i in 60 * 36: await physics_frame
	var cows: Array = L.cows_positions()
	await view("03_cows", cows[0] + Vector3(8, 3.5, 7), cows[0] + Vector3(0, 0.5, -2))
	quit()
