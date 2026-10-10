extends SceneTree
## Ворота во дворы: дом в селе (профнастил, навес для машины) и свой двор в Каменке.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func shot(n: String, at: Vector3, look: Vector3) -> void:
	W.get_node("Player").global_position = Vector3(look.x, 0.3, look.z)
	for i in 4: await physics_frame
	cam.make_current(); cam.global_position = at; cam.look_at(look)
	await save(n)
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 12 * 60.0
	cam = Camera3D.new(); cam.fov = 60; W.add_child(cam)
	for i in [1, 6]:
		var c: Vector2 = Region.VILLAGES[i].c
		var e: int = Region.VILLAGES[i].entry
		var xf := Transform3D(Basis(Vector3.UP, 0.0), Vector3(c.x + Region.HOUSE_X[0] * e, 0, c.y - 16.0))
		await shot("g_village_%d" % i, xf * Vector3(9, 4, 22), xf * Vector3(4, 0.5, 2))
	var car: Vehicle = W.get_node("Car")
	var px: float = W.PLAYER_HOUSE.x + W._home_door_x
	car.global_position = Vector3(px, 0.2, -47.0)
	car.rotation = Vector3(0, 0, 0)
	for i in 10: await physics_frame
	await shot("g_kamenka_own", Vector3(px + 5, 3.5, -34), Vector3(px, 0.5, -48))
	quit()
