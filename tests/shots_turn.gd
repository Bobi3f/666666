extends SceneTree
## Снимки: мигает левый поворотник у «Жигулей» (сзади и спереди), стрелки
## на спидометре и кнопки ◀ ▶ на телефоне.
var W
func _initialize() -> void:
	root.size = Vector2i(int(OS.get_environment("SW")), int(OS.get_environment("SH")))
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c.get_script() and c.get_script().resource_path.ends_with("traffic.gd"): c.queue_free()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 19.5 * 60.0
	var PR = root.get_node("Progress")
	PR.buy_car("car"); PR.add_category("B")
	var C: Vehicle = W.get_node("Car")
	C.global_position = Vector3(-150, 0.3, 2.0); C.rotation.y = -PI / 2.0
	for i in 5: await physics_frame
	C._on_enter()
	C.chase_view = true
	C._update_camera(1.0)
	C.set_turn(-1)
	for i in 6: await process_frame
	C._turn_t = 0.1
	for i in 3: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/turn_%s.png" % [OS.get_environment("SHOTS"), OS.get_environment("PFX")])
	# Снаружи сзади-слева: горит левый поворотник (мигание на миг остановлено)
	C._show_turn(true)
	C.set_process(false)
	var cam := Camera3D.new(); cam.far = 500.0; W.add_child(cam)
	var xf := C.global_transform
	cam.global_position = xf * Vector3(-3.0, 1.6, 6.5)
	cam.look_at(xf * Vector3(0, 0.7, 0))
	cam.make_current()
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/turn_%s_rear.png" % [OS.get_environment("SHOTS"), OS.get_environment("PFX")])
	cam.global_position = xf * Vector3(-3.0, 1.4, -6.0)
	cam.look_at(xf * Vector3(0, 0.7, 0))
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/turn_%s_front.png" % [OS.get_environment("SHOTS"), OS.get_environment("PFX")])
	quit()
