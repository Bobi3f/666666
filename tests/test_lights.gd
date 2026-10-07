extends SceneTree
## Свет в машине и на мотоцикле: L — по кругу авто → габариты → ближний →
## выключен, K — дальний (дальше, ярче, лампа на щитке). Габариты — огни
## спереди и задние фонари. Режим сохраняется; на телефоне — кнопки.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func key(code: int) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code; e.keycode = code; e.pressed = down
		Input.parse_input_event(e)
		await frames(2)
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await frames(10)
	var TM = root.get_node("TimeManager"); var WM = root.get_node("WeatherManager")
	WM.set_kind(0, 9999.0)
	TM.minutes = 13 * 60.0
	for kind in ["Car", "Moped"]:
		print("== ", kind)
		var C: Vehicle = W.get_node(kind)
		W.get_node("Player").global_position = C.global_position + Vector3(1.5, 0, 0)
		for i in 5: await physics_frame
		C._on_enter()
		ok(C.driver != null, "сел за руль")
		C.fuel = 5.0; C.condition = 100.0
		if not C.engine_on: C._toggle_ignition()
		await frames(3)
		ok(C.light_mode == Vehicle.Light.AUTO and not C.headlights_on() and not C.markers_on(), "днём в авто — свет не горит")
		var lamp: StandardMaterial3D = C._marker_mat
		var dim := lamp.albedo_color
		await key(KEY_L)
		ok(C.light_mode == Vehicle.Light.PARKING and C.markers_on() and not C.headlights_on(), "L — габариты")
		ok(lamp.albedo_color != dim and C._brake_mat.albedo_color.r > 0.5, "горят огни спереди и задние фонари")
		await key(KEY_L)
		ok(C.light_mode == Vehicle.Light.LOW and C.headlights_on() and not C.high_beam_on(), "L — ближний")
		var near: float = C._headlights[0].spot_range
		await key(KEY_K)
		ok(C.high_beam_on() and C._headlights[0].spot_range > near * 1.5, "K — дальний светит дальше: %.0f м" % C._headlights[0].spot_range)
		await key(KEY_K)
		ok(not C.high_beam_on() and C.headlights_on(), "K ещё раз — снова ближний")
		await key(KEY_L)
		ok(C.light_mode == Vehicle.Light.OFF and not C.headlights_on() and not C.markers_on(), "L — выключен")
		TM.minutes = 23 * 60.0
		await frames(3)
		ok(not C.headlights_on(), "выключен — и ночью не загорается")
		await key(KEY_K)
		ok(C.light_mode == Vehicle.Light.LOW and C.high_beam_on(), "K при выключенных — включает ближний с дальним")
		await key(KEY_L)
		await key(KEY_L)
		ok(C.light_mode == Vehicle.Light.AUTO and C.headlights_on() and not C.high_beam_on(), "по кругу — снова авто: ночью ближний сам")
		await key(KEY_L)
		var st: Dictionary = C.save_state()
		st.erase("driver")
		C.load_state({})
		ok(C.light_mode == Vehicle.Light.AUTO, "старое сохранение — авто")
		C.load_state(st)
		ok(C.light_mode == Vehicle.Light.PARKING, "режим света сохраняется")
		C.light_mode = Vehicle.Light.AUTO
		TM.minutes = 13 * 60.0
		C.engine_on = false; C.speed = 0.0
		C._drop_driver()
		await frames(10)
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
