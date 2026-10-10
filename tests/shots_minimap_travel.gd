extends SceneTree
## Снимок мини-карты после поездки из Каменки в Заречье: подробная карта
## перерисовывается полосами на ходу и должна быть целой, без швов.
var W
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 20: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	var C = W.get_node("Car")
	root.get_node("Progress").buy_car("car"); root.get_node("Progress").license = true
	C.global_position = Vector3(-60, 0.1, 2); C._on_enter(); C.set_physics_process(false)
	for leg in [[Vector3(-60, 0.1, 2), Vector3(430, 0.1, 2)], [Vector3(430, 0.1, 2), Vector3(432, 0.1, 290)]]:
		var a: Vector3 = leg[0]; var b: Vector3 = leg[1]
		var n := int(a.distance_to(b) / 4.0)
		for k in n:
			C.global_position = a.lerp(b, float(k) / n)
			C.rotation.y = atan2(-(b - a).x, -(b - a).z)
			await process_frame
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/minimap_travel.png" % OS.get_environment("SHOTS"))
	quit()
