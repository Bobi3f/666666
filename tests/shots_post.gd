extends SceneTree
## Снимки почты: киоск в селе и в городе, окошки в Каменке, коробки на
## мопеде и на крыше машины, посылка у калитки.
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
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 10 * 60.0
	cam = Camera3D.new(); cam.far = 700.0; W.add_child(cam)
	var PS = W.post
	var P = W.get_node("Player")
	P.global_position = Vector3(0, -50, 0)
	var k: Dictionary = PS.offices[2]
	var fwd := Basis(Vector3.UP, k.yaw) * Vector3.BACK
	await view("post_village", k.window + fwd * 7.0 + Vector3(3, 1.8, 0), k.window + Vector3(0, 1.4, 0))
	var t: Dictionary = PS.offices[1]
	fwd = Basis(Vector3.UP, t.yaw) * Vector3.BACK
	await view("post_town", t.window + fwd * 8.0 + Vector3(0, 2.0, 4), t.window + Vector3(0, 1.4, 0))
	var h: Dictionary = PS.offices[0]
	await view("post_kamenka", h.window + Vector3(1.5, 1.8, 6.0), h.window + Vector3(0.5, 1.4, 0))
	# Мопед с коробками у калитки, одна уже лежит
	var M = W.get_node("Moped")
	var J = h.home_job
	J.start()
	M._on_enter()
	var s0: Array = J.stops[0]
	M.global_position = s0[1] + Vector3(0, 0.2, 0)
	M.rotation.y = PI / 2.0
	M.speed = 0.0
	for i in 8: await physics_frame
	await view("post_moped", s0[1] + Vector3(3.5, 1.8, 3.0), s0[1] + Vector3(0, 0.6, -1.0))
	J.cancel()
	M.speed = 0.0; M.exit_car()
	for i in 4: await physics_frame
	var C = W.get_node("Niva")
	var B = h.bag_job
	B.start()
	C._on_enter()
	for i in 6: await physics_frame
	await view("post_car", C.global_position + Vector3(4.5, 3.0, 4.5), C.global_position + Vector3(0, 1.2, 0))
	quit()
