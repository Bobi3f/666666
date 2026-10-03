extends SceneTree
## Снимки изнутри: сельмаг, почта в сельсовете, дежурная часть милиции.
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
		if c.get_script() and c.get_script().resource_path.ends_with("hud.gd"): c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 11 * 60.0
	cam = Camera3D.new(); cam.far = 700.0; cam.fov = 75.0; W.add_child(cam)
	W.get_node("Player").global_position = Vector3(0, -50, 0)
	# Сельмаг: фасад смотрит к -X (поворот -90°), вход с -X
	var s: Vector3 = W.SHOP_POS
	var sx := Transform3D(Basis(Vector3.UP, -PI / 2.0), s)
	await view("in_shop", sx * Vector3(1.5, 2.0, 2.6), sx * Vector3(-0.8, 1.2, -1.8))
	await view("in_shop_door", sx * Vector3(0, 1.8, 9.0), sx * Vector3(0, 1.4, 0))
	var c: Vector3 = Civic.COUNCIL
	await view("in_post", c + Vector3(-0.5, 2.0, 2.8), c + Vector3(-3.0, 1.3, -1.5))
	await view("in_council", c + Vector3(0.8, 2.0, 2.8), c + Vector3(3.2, 1.2, -2.0))
	var p: Vector3 = Police.STATION
	await view("in_police", p + Vector3(-6.4, 2.0, 0.0), p + Vector3(-2.5, 1.4, 0))
	await view("in_police_cell", p + Vector3(0.0, 2.2, -1.0), p + Vector3(5.0, 1.0, 2.5))
	quit()
