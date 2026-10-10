extends SceneTree
## Игрок за рулём: на «Яве», ИЖе, «Карпатах» и в «Жигулях» — вид сбоку и сзади.
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
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 12 * 60.0
	cam = Camera3D.new(); cam.fov = 50; W.add_child(cam); cam.make_current()
	var P = W.get_node("Player")
	var want := {}
	for v in W.find_children("*", "Vehicle", true, false):
		if v.kind in ["moped", "moto", "izh", "car"] and not want.has(v.kind): want[v.kind] = v
	var spot := Vector3(-60, 0.1, 60)
	for k in want:
		var v: Vehicle = want[k]
		v.global_position = spot
		v.rotation = Vector3.ZERO
		P.global_position = spot + Vector3(0, 0, 40)
		for i in 5: await physics_frame
		v.driver = P
		Vehicle.chase_view = true
		cam.make_current()
		var c := v.global_position + Vector3(0, 0.9, 0)
		cam.global_position = c + Vector3(3.2 if k == "car" else 2.4, 0.5, -0.4)
		cam.look_at(c)
		await save("r_%s_side" % k)
		cam.global_position = c + Vector3(-1.4, 1.0, 3.6)
		cam.look_at(c)
		await save("r_%s_rear" % k)
		v.driver = null
		spot.x += 14.0
	quit()
