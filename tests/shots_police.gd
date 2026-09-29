extends SceneTree
## Снимки: пост ГАИ «стакан» с машиной и отделение милиции в городе.
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
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c is CanvasLayer: c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 11 * 60.0
	var P = W.get_node("Player"); P.set_physics_process(false); P.global_position = Vector3(0, 0.2, 90)
	cam = Camera3D.new(); cam.far = 700.0; W.add_child(cam)
	W.get_node("GaiPost").request_stop()
	await view("gai_post", Vector3(-84, 3, 6), Vector3(-98, 2.5, -8))
	var s: Vector3 = Police.STATION
	await view("police", s + Vector3(-21, 3.5, 8), s + Vector3(-5, 2.5, -1))
	root.get_node("TimeManager").minutes = 22 * 60.0
	await view("police_night", s + Vector3(-21, 3.5, 8), s + Vector3(-5, 2.5, -1))
	quit()
