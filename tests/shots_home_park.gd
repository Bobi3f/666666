extends SceneTree
## Снимок: после загрузки вся своя техника — дома, во дворе и у калитки.
var W
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c is CanvasLayer: c.visible = false
	root.get_node("TimeManager").minutes = 12 * 60.0
	for k in ["car", "moto", "vaz2107", "izh", "niva", "truck"]:
		root.get_node("Progress").buy_car(k)
	for n in ["Car", "Moto", "Vaz2107", "Izh", "Niva", "Truck"]:
		W.get_node(n).global_position = Vector3(300, 0.1, 2)
	W.park_home()
	for i in 10: await physics_frame
	var cam := Camera3D.new(); W.add_child(cam)
	var h := Vector3(W.PLAYER_HOUSE.x, 0, W.PLAYER_HOUSE.y)
	cam.global_position = h + Vector3(-2, 9, 26)
	cam.look_at(h + Vector3(0, 0, 12))
	cam.make_current()
	for i in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/home_park.png" % OS.get_environment("SHOTS"))
	quit()
