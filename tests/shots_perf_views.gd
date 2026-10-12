extends SceneTree
## Одни и те же виды до и после оптимизаций: улица Каменки вблизи, сельмаг,
## город, трасса — чтобы сравнить картинку попиксельно.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(960, 540)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 12: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func shot(n: String, at: Vector3, look: Vector3) -> void:
	W.get_node("Player").global_position = at + Vector3(0, -1.5, 0)
	cam.make_current(); cam.global_position = at; cam.look_at(look)
	await save(n)
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	for c in W.find_children("*", "CanvasLayer", true, false): c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 12 * 60.0
	cam = Camera3D.new(); cam.fov = 65; W.add_child(cam)
	await shot("pv_street", Vector3(-110, 1.7, -42), Vector3(-80, 1.0, -40))
	await shot("pv_shop", Vector3(-58, 2.0, -30), Vector3(-45, 1.5, -24))
	await shot("pv_town", Town.w(Vector3(100, 2.0, 40)), Town.w(Vector3(125, 3.0, 15)))
	await shot("pv_road", Vector3(-30, 1.6, 3), Vector3(30, 0.5, 2))
	await shot("pv_roofs", Vector3(-140, 9.0, -70), Vector3(-110, 2.0, -45))
	quit()
