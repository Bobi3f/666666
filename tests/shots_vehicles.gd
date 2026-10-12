extends SceneTree
var W
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func snap(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)
func _run() -> void:
	for i in 10: await process_frame
	var TM = root.get_node("TimeManager")
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var M = W.get_node("Moto"); var C = W.get_node("Car")
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("traffic.gd"):
			for v in c.vehicles():
				if v.dir == 1:
					v.body.global_position.y = -50.0
	TM.minutes = 12 * 60.0
	# Ява: вид у дома
	var cam := Camera3D.new()
	W.add_child(cam)
	cam.global_position = Vector3(-126, 1.8, -43.5)
	cam.look_at(Vector3(-130, 0.7, -41.6))
	cam.make_current()
	for i in 12: await process_frame
	snap("01_moto_parked")
	# Едем на Яве по трассе, вид сзади, поворот
	M.global_position = Vector3(-160, 0.1, 2.0)
	M.rotation.y = -PI / 2.0
	M.fuel = 14.0
	M._on_enter()
	M.chase_view = true
	M._update_camera(1.0)
	M._chase.current = true
	key(KEY_W, true)
	for i in 150: await physics_frame
	key(KEY_A, true)
	for i in 25: await physics_frame
	snap("02_moto_lean")
	key(KEY_A, false)
	key(KEY_W, false)
	for i in 60: await physics_frame
	# Из седла — вид от первого лица с приборами
	M.chase_view = false
	M._camera.current = true
	key(KEY_W, true)
	for i in 40: await physics_frame
	snap("03_moto_fp")
	key(KEY_W, false)
	key(KEY_S, true)
	for i in 200: await physics_frame
	key(KEY_S, false)
	M.exit_car()
	for i in 5: await physics_frame
	# Жигули в заносе с ручником, вид сзади
	C.global_position = Vector3(-120, 0.1, 2.0)
	C.rotation.y = -PI / 2.0
	C.fuel = 40.0
	C._on_enter()
	C.chase_view = true
	C._update_camera(1.0)
	C._chase.current = true
	key(KEY_W, true)
	for i in 300: await physics_frame
	key(KEY_W, false)
	key(KEY_D, true); key(KEY_SPACE, true)
	for i in 30: await physics_frame
	snap("04_car_drift")
	key(KEY_D, false); key(KEY_SPACE, false)
	key(KEY_S, true)
	for i in 180: await physics_frame
	key(KEY_S, false)
	# Ночь: трасса со стоп-сигналами и фарами
	C.exit_car()
	TM.minutes = 22.5 * 60.0
	cam.global_position = Vector3(-40, 3.0, -9)
	cam.look_at(Vector3(-5, 0.8, 0))
	cam.make_current()
	for i in 20: await process_frame
	snap("05_traffic_night")
	quit()
