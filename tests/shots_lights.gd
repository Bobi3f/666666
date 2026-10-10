extends SceneTree
## Свет ночью: «Жигули» и «Карпаты» с габаритами, ближним и дальним.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 23 * 60.0
	cam = Camera3D.new(); cam.fov = 55; W.add_child(cam)
	var spot := Vector3(-60, 0.1, 60)
	for kind in ["Car", "Moped"]:
		var v: Vehicle = W.get_node(kind)
		v.global_position = spot
		v.rotation = Vector3.ZERO
		W.get_node("Player").global_position = spot + Vector3(0, 0, 30)
		if v._sale:
			v._sale.queue_free(); v._sale = null
		v.engine_on = true
		for i in 10: await physics_frame
		cam.make_current()
		for m in [["parking", Vehicle.Light.PARKING, false], ["low", Vehicle.Light.LOW, false], ["high", Vehicle.Light.LOW, true]]:
			v.light_mode = m[1]; v.high_beam = m[2]
			v._update_lights()
			# Спереди — видно огни; сзади-сбоку — как светит на дорогу
			cam.global_position = spot + Vector3(2.2, 1.1, -4.2)
			cam.look_at(spot + Vector3(0, 0.6, 0))
			await save("lights_%s_%s" % [kind.to_lower(), m[0]])
			cam.global_position = spot + Vector3(0.6, 3.2, 5.5)
			cam.look_at(spot + Vector3(0, 0.0, -12.0))
			await save("lights_%s_%s_road" % [kind.to_lower(), m[0]])
		v.engine_on = false
		spot.x += 14.0
	quit()
