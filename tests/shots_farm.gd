extends SceneTree
## Ферма у Каменки: общий вид, ворота, внутри коровника, гараж и ангар.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 560)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func shot(n: String, at: Vector3, look: Vector3) -> void:
	W.get_node("Player").global_position = Vector3(at.x, 0.2, at.z)
	for i in 3: await physics_frame
	cam.make_current(); cam.global_position = at; cam.look_at(look)
	await save(n)
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 11 * 60.0
	cam = Camera3D.new(); cam.far = 600; cam.fov = 60; W.add_child(cam)
	var A := Farm.AREA
	var c := A.get_center()
	await shot("f_overview", Vector3(c.x - 40, 30, A.position.y - 30), Vector3(c.x, 0, c.y))
	await shot("f_gate", Vector3(Farm.GATE_X - 4, 1.7, A.position.y - 14), Vector3(Farm.GATE_X, 2.5, A.position.y + 10))
	var B := Farm.BARN
	await shot("f_barn_in", Vector3(B.position.x + 1.5, 1.7, B.get_center().y), Vector3(B.end.x, 1.0, B.get_center().y))
	var G := Farm.GARAGE
	await shot("f_garage", Vector3(G.position.x - 6, 1.7, G.get_center().y + 2), Vector3(G.end.x, 1.0, G.get_center().y))
	var H := Farm.HANGAR
	await shot("f_hangar", Vector3(H.get_center().x - 2, 1.8, H.position.y - 8), Vector3(H.get_center().x, 2.0, H.end.y))
	quit()
