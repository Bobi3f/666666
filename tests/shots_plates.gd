extends SceneTree
## Снимки номерных знаков: «Жигули» сзади и спереди, Ява сзади, попутка.
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
		if c.get_script() and c.get_script().resource_path.ends_with("hud.gd"): c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 11 * 60.0
	cam = Camera3D.new(); cam.far = 700.0; cam.fov = 50.0; W.add_child(cam)
	W.get_node("Player").global_position = Vector3(0, -50, 0)
	var C: Node3D = W.get_node("Car")
	var b := C.global_transform.basis
	await view("plate_car_rear", C.global_position + b * Vector3(0.8, 1.1, 4.3), C.global_position + b * Vector3(0, 0.6, 2.0))
	await view("plate_car_front", C.global_position + b * Vector3(-0.8, 1.1, -4.4), C.global_position + b * Vector3(0, 0.6, -2.0))
	var M: Node3D = W.get_node("Moto")
	b = M.global_transform.basis
	await view("plate_moto", M.global_position + b * Vector3(0.5, 1.0, 2.6), M.global_position + b * Vector3(0, 0.6, 0.8))
	var tr
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("traffic.gd"): tr = c
	tr.process_mode = Node.PROCESS_MODE_DISABLED
	var T: Node3D = tr._vehicles[0].body
	b = T.global_transform.basis
	await view("plate_traffic", T.global_position + b * Vector3(1.2, 1.4, 6.0), T.global_position + b * Vector3(0, 0.7, 2.0))
	quit()
