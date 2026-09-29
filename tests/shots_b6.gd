extends SceneTree
var W
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func snap(n: String) -> void:
	for i in 12: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
var cam: Camera3D
func view(n: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.current = true
	await snap(n)
func _run() -> void:
	for i in 10: await process_frame
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var hud = child("hud.gd"); if hud: hud.visible = false
	var TM = root.get_node("TimeManager"); var WM = root.get_node("WeatherManager")
	WM.set_kind(0, 99999.0)
	TM.minutes = 11 * 60.0
	cam = Camera3D.new(); cam.far = 700.0
	W.add_child(cam)
	# Прохожие на площади
	var sl = child("street_life.gd")
	var w = sl._walkers[0]
	for i in 40: await process_frame
	var wp: Vector3 = w.node.global_position
	var fwd: Vector3 = -w.node.global_transform.basis.z
	await view("a_walker", wp + fwd * 3.0 + Vector3(1.5, 1.4, 0), wp + Vector3(0, 0.9, 0))
	await view("b_pond", Vector3(-170, 3.5, -34), Vector3(-185, 0, -42))
	await view("c_birds", Vector3(-105, 2, -20), Vector3(-105, 30, -60))
	# Пыль за машиной
	var C = W.get_node("Car")
	C.global_position = Vector3(-10, 0.1, -100); C.rotation.y = -PI / 2.0
	C._on_enter(); C.fuel = 30.0
	var e := InputEventKey.new(); e.physical_keycode = KEY_W; e.pressed = true
	Input.parse_input_event(e)
	for i in 150: await physics_frame
	var cp: Vector3 = C.global_position
	await view("d_dust", cp + Vector3(-9, 3, 4), cp + Vector3(2, 0.5, 0))
	e = InputEventKey.new(); e.physical_keycode = KEY_W; e.pressed = false
	Input.parse_input_event(e)
	C.exit_car()
	cam.current = true
	TM.day = 15; WM._on_minutes(900.0); TM.minutes = 11 * 60.0
	await view("e_ice", Vector3(-170, 3.5, -34), Vector3(-185, 0, -42))
	quit()
