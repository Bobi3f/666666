extends SceneTree
## Снимки погонь: милиция за машиной игрока и лихач на трассе.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func shot(name: String) -> void:
	for i in 3: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 18.5 * 60.0
	root.get_node("Progress").buy_car("car")
	root.get_node("Progress").add_category("B")
	var C = W.get_node("Car")
	C.global_position = Vector3(-60.0, 0.3, 2.0)
	C.rotation.y = -PI / 2.0
	C._on_enter()
	C.engine_on = true
	var CH = W.get_node("Chase")
	CH.start(Vector3(-100.0, 0.05, -8.4), "110 км/ч мимо поста ГАИ")
	# Едем по трассе на восток, милиция догоняет
	var I := Input
	var e := InputEventKey.new(); e.physical_keycode = KEY_W; e.keycode = KEY_W; e.pressed = true
	Input.parse_input_event(e)
	for i in 60 * 5: await physics_frame
	# Снаружи: сбоку-сзади милиции, видно и её, и «Жигули» впереди
	cam = Camera3D.new(); cam.far = 700.0; W.add_child(cam)
	var pc: Vector3 = CH.car.global_position
	var cp: Vector3 = C.global_position
	cam.global_position = pc + (pc - cp).normalized() * 9.0 + Vector3(0, 3.5, 6.0)
	cam.look_at((pc + cp) * 0.5 + Vector3(0, 0.8, 0))
	cam.make_current()
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("hud.gd"): c.visible = false
	await shot("chase_player")
	var e2 := InputEventKey.new(); e2.physical_keycode = KEY_W; e2.keycode = KEY_W; e2.pressed = false
	Input.parse_input_event(e2)
	CH._end("lost")
	for i in 60 * 9: await physics_frame
	C.speed = 0.0
	C.exit_car()
	CH._show_cool = 9999.0
	CH.start_show()
	CH._show_t = 14.0
	for i in 30: await physics_frame
	var bad: Vector3 = CH.show_cars[0].global_position
	var cop: Vector3 = CH.show_cars[1].global_position
	var mid := (bad + cop) * 0.5
	cam.global_position = mid + Vector3(-CH._show_dir * 6.0, 3.0, 12.0)
	cam.look_at(mid + Vector3(0, 0.8, 0))
	cam.make_current()
	await shot("chase_show")
	quit()
