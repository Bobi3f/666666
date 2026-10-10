extends SceneTree
## Двор бурсы (ПТУ): сверху и с улицы — утром, днём и после уроков.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func shot(name: String, at: Vector3, look: Vector3, n := 12) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in n: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 12: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c.get_script() and c.get_script().resource_path.ends_with("hud.gd"): c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var TM = root.get_node("TimeManager")
	var times := OS.get_environment("TIMES").split(",") if OS.get_environment("TIMES") != "" else PackedStringArray(["12"])
	var P: Node3D = root.get_node("GameManager").player
	P.global_position = Town.w(Vector3(258, 0.1, 150))
	cam = Camera3D.new(); cam.fov = 55; cam.far = 700; W.add_child(cam); cam.make_current()
	for t in times:
		TM.minutes = float(t) * 60.0
		for i in 30: await process_frame
		var cl = W.get_tree().get_first_node_in_group("college_life")
		if cl:
			cl.settle()
		for i in 5: await process_frame
		await shot("college_top_%s" % t, Town.w(Vector3(262, 38, 121)), Town.w(Vector3(254, 0, 120.5)))
		await shot("college_street_%s" % t, Town.w(Vector3(270, 2.4, 96)), Town.w(Vector3(252, 1.0, 118)))
		await shot("college_yard_%s" % t, Town.w(Vector3(261.5, 1.7, 139.0)), Town.w(Vector3(254.0, 0.8, 120.0)))
	quit()
