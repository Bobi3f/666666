extends SceneTree
## Снимки поверхностей вблизи: трава, асфальт, доски, кирпич, панели, крыши.
## SHOTS — папка; в имя файла добавляется SUFFIX (сравнить «до» и «после»).
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func view(name: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [OS.get_environment("SHOTS"), name, OS.get_environment("SUFFIX")])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c is CanvasLayer: c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 10 * 60.0
	var P = W.get_node("Player"); P.set_physics_process(false); P.global_position = Vector3(0, 0.2, 90)
	cam = Camera3D.new(); cam.far = 700.0; W.add_child(cam)
	await view("g1_street", Vector3(-112, 1.7, -38), Vector3(-126, 1.5, -52))
	await view("g2_town", Vector3(62, 1.7, 26), Vector3(75, 4, 38))
	await view("g3_road", Vector3(-20, 1.4, 5.5), Vector3(-5, 0, 0))
	await view("g4_barn", Vector3(-33, 1.8, -36), Vector3(-35, 2, -43))
	await view("g5_roofs", Vector3(-140, 7, -30), Vector3(-125, 3, -56))
	quit()
