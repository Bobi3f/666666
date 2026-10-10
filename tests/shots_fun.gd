extends SceneTree
## Развлечения: теннис и армрестлинг в ПТУ, кикер в школе (мяч в полёте).
var W
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 12: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("TimeManager").minutes = 12 * 60.0
	var cam := Camera3D.new(); cam.fov = 70; W.add_child(cam)
	W.interiors.enter("college")
	var ping: FunGame = W.interiors.ping
	GameManagerPos(ping)
	ping.press()
	cam.make_current()
	cam.global_position = ping.global_position + Vector3(3.5, 2.2, 3.0)
	cam.look_at(ping.global_position + Vector3(0.5, 0.6, 0))
	await save("fun_college")
	W.interiors.leave()
	var school = W.find_child("School", true, false)
	var k: FunGame = school.kicker
	GameManagerPos(k)
	k.press()
	cam.global_position = k.global_position + Vector3(2.2, 1.9, 1.8)
	cam.look_at(k.global_position + Vector3(0, 0.7, 0))
	await save("fun_school")
	quit()
func GameManagerPos(g: Node3D) -> void:
	var P: Node3D = root.get_node("GameManager").player
	P.global_position = g.global_position + Vector3(1.6, 0.1, 0)
