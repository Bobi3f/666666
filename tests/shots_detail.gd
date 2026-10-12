extends SceneTree
var W
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 10: await process_frame
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 13 * 60.0
	W.get_node("Player").set_physics_process(false)
	var cam := Camera3D.new()
	cam.far = 800
	W.add_child(cam)
	cam.make_current()
	var shots := [
		["a_street", Vector3(-100, 1.7, -39), Vector3(-135, 1.2, -41)],
		["b_meadow", Vector3(-45, 1.7, -52), Vector3(-20, 1.0, -75)],
		["c_forest", Vector3(-60, 2.0, -70), Vector3(-80, 3.0, -100)],
		["d_wheat", Vector3(20, 2.0, -105), Vector3(45, 0.8, -130)],
		["e_yard", Vector3(-112, 2.2, -38.5), Vector3(-125, 1.5, -52)],
		["f_town", Vector3(55, 2.0, 25), Vector3(80, 4, 45)],
		["g_car", Vector3(-117, 1.6, -36.5), Vector3(-121, 0.7, -39.5)],
		["h_overview", Vector3(-60, 45, 10), Vector3(-110, 0, -40)],
		["i_people", Vector3(-100.5, 1.5, -39.2), Vector3(-102, 1.0, -36.5)],
		["j_house", Vector3(-146, 2.0, -40.5), Vector3(-150, 2.0, -52)],
		["k_court", Vector3(80, 2.2, 57), Vector3(100, 2.5, 68)],
		["l_sign", Vector3(-35, 1.8, -4), Vector3(-40, 2.0, -6.6)],
	]
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2])
		for i in 14: await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), s[0]])
	quit()
