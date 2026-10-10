extends SceneTree
## Плавность: машина и игрок рисуются между шагами физики. Кадров больше,
## чем шагов (экран 144 Гц), — нарисованная машина всё равно сдвигается каждый
## кадр ровно; после переноса (телепорта) не «летит» через полкарты.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func _run() -> void:
	for i in 10: await process_frame
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	OS.low_processor_usage_mode = false
	Engine.max_fps = 144
	print("== Сглаживание движения")
	ok(get_root().physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_OFF and ProjectSettings.get_setting("physics/common/physics_interpolation"), "сглаживание включено в проекте")
	var C: Vehicle = W.get_node("Car")
	var P = W.get_node("Player")
	ok(C.is_physics_interpolated() and P.is_physics_interpolated() and W.get_node("StreetLife").is_physics_interpolated(), "машины, игрок и прохожие сглаживаются")
	ok(not C._camera.is_physics_interpolated() and not W.get_node("WorldMesh").is_physics_interpolated(), "камера и неподвижный мир — без сглаживания")
	root.get_node("Progress").buy_car("car")
	C.global_position = Vector3(-150, 0.1, 2.0); C.rotation.y = -PI / 2.0
	C._on_enter(); C.fuel = 30.0
	var e := InputEventKey.new(); e.physical_keycode = KEY_W; e.keycode = KEY_W; e.pressed = true
	Input.parse_input_event(e)
	for i in 200: await process_frame
	var still := 0
	var last: float = C.get_global_transform_interpolated().origin.x
	for i in 120:
		await process_frame
		var x: float = C.get_global_transform_interpolated().origin.x
		if absf(x - last) < 0.0001: still += 1
		last = x
	ok(still < 5, "на 144 кадрах машина сдвигается каждый кадр (стоп-кадров %d из 120)" % still)
	e = e.duplicate(); e.pressed = false
	Input.parse_input_event(e)
	C.speed = 0.0; C.velocity = Vector3.ZERO
	# Перенос — сразу на новом месте, без пролёта
	C.global_position = Vector3(-40, 0.1, 2.0)
	await physics_frame
	await process_frame
	ok(C.get_global_transform_interpolated().origin.distance_to(C.global_position) < 1.0, "после переноса машина сразу на месте")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
