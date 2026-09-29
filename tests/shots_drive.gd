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
	for i in 15: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 11 * 60.0
	var P = W.get_node("Player"); var C = W.get_node("Car")
	P.set_physics_process(false)
	P.global_position = Vector3(-3, 0.2, -16)
	cam = Camera3D.new(); W.add_child(cam)
	var EX = W.get_node("Exam")
	EX.arm()
	C.global_position = Vector3(9, 0.1, -24); C.rotation.y = 0.0
	C._on_enter()
	for i in 10: await physics_frame
	C.global_position = Vector3(6.5, 0.1, -30); C.rotation.y = 0.35
	await view("01_exam", Vector3(-3, 7, -12), Vector3(10, 0, -40))
	C.exit_car()
	C.global_position = Vector3(-86, 0.1, 13); C.rotation.y = PI * 0.85
	C.repaint()
	await view("02_garage", Vector3(-76, 3.2, 5), Vector3(-85, 0.8, 14))
	W.get_node("Race").arm()
	await view("03_race", Vector3(-70, 4.5, -30), Vector3(-60, 0, -18))
	quit()
