extends SceneTree
## Плавность движения: машина едет ровно, кадров больше, чем шагов физики
## (как на экране 144 Гц). Смотрим, на сколько сдвигается нарисованная
## машина от кадра к кадру: при сглаживании — ровно, без — рывками.
var W
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 20: await process_frame
	OS.low_processor_usage_mode = false
	Engine.max_fps = 144
	var C = W.get_node("Car")
	root.get_node("Progress").buy_car("car")
	C.global_position = Vector3(-150, 0.1, 2.0); C.rotation.y = -PI / 2.0
	C._on_enter(); C.fuel = 30
	var e := InputEventKey.new(); e.physical_keycode = KEY_W; e.keycode = KEY_W; e.pressed = true
	Input.parse_input_event(e)
	for i in 200: await process_frame
	var steps := []
	var last: float = C.get_global_transform_interpolated().origin.x
	for i in 120:
		await process_frame
		var x: float = C.get_global_transform_interpolated().origin.x
		steps.append(x - last)
		last = x
	var mean := 0.0
	for s in steps: mean += s
	mean /= steps.size()
	var dev := 0.0
	for s in steps: dev += absf(s - mean)
	dev /= steps.size()
	print("SMOOTH шаг в кадр %.3f м, разброс %.3f м (%.0f%%), нулевых кадров %d" % [mean, dev, dev / maxf(absf(mean), 0.0001) * 100.0, steps.filter(func(s): return absf(s) < 0.0001).size()])
	quit()
