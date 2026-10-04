extends SceneTree
## Снимки: «Жигули» ВАЗ-2106 как на чертеже — три четверти спереди,
## сбоку, спереди, сзади; и вид из салона.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func shot(name: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c.get_script() and c.get_script().resource_path.ends_with("hud.gd"): c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var TM = root.get_node("TimeManager")
	TM.day = 2; TM.minutes = 12 * 60.0
	var C: Vehicle = W.get_node("Car")
	C.paint = 1
	C._paint_body()
	C.global_position = Vector3(40, 0.3, 40)
	C.rotation.y = 0.0
	for i in 30: await physics_frame
	var xf := C.global_transform
	cam = Camera3D.new(); cam.far = 700.0; cam.fov = 45.0; W.add_child(cam)
	cam.make_current()
	await shot("zhiguli_34", xf * Vector3(3.6, 1.9, -5.2), xf * Vector3(0, 0.6, 0))
	await shot("zhiguli_side", xf * Vector3(-7.5, 0.9, 0), xf * Vector3(0, 0.7, 0))
	await shot("zhiguli_front", xf * Vector3(0, 0.9, -6.5), xf * Vector3(0, 0.7, 0))
	await shot("zhiguli_rear", xf * Vector3(2.5, 1.5, 6.0), xf * Vector3(0, 0.7, 0))
	cam.current = false
	C._on_enter()
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/zhiguli_inside.png" % OS.get_environment("SHOTS"))
	quit()
