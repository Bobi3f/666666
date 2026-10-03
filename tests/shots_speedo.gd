extends SceneTree
var W
func key(k: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k; e.keycode = k; e.pressed = down
	Input.parse_input_event(e)
func _initialize() -> void:
	root.size = Vector2i(int(OS.get_environment("SW")), int(OS.get_environment("SH")))
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func snap(n: String) -> void:
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c.get_script() and c.get_script().resource_path.ends_with("traffic.gd"): c.queue_free()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var hud
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("hud.gd"): hud = c
	var sp = null
	for c in hud.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("speedometer.gd"): sp = c
	print("пешком спидометр виден: ", sp.visible)
	var p: String = OS.get_environment("PFX")
	root.get_node("Progress").add_category("A"); root.get_node("Progress").buy_car("moto")
	for kind in ["Car", "Moto"]:
		var V = W.get_node(kind)
		V.global_position = Vector3(-150, 0.1, 2.0 if kind == "Car" else -2.0); V.rotation.y = -PI / 2.0
		V._on_enter(); V.fuel = 25.0
		V.chase_view = true
		V._update_camera(1.0)
		key(KEY_W, true)
		for i in 60 * 5: await physics_frame
		print(kind, ": спидометр виден ", sp.visible, ", стрелка %d км/ч, машина %d км/ч" % [int(sp._shown), int(V.speed_kmh())])
		await snap(p + "_" + kind)
		key(KEY_W, false)
		V.speed = 0.0; V.velocity = Vector3.ZERO
		V.exit_car()
		for i in 5: await physics_frame
	print("вышел — спидометр виден: ", sp.visible)
	quit()
