extends SceneTree
## Работы в три этапа и заборы: машина клиента на подъёмнике СТО, огороды
## Каменки за забором с калиткой из двора, задний забор в селе, калитки
## городских участков.
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
	W.get_node("Player").global_position = at + Vector3(0, -1.5, 0)
	for i in 3: await physics_frame
	cam.make_current(); cam.global_position = at; cam.look_at(look)
	await save(n)
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 10 * 60.0
	root.get_node("Progress").add_item("mechanic")
	cam = Camera3D.new(); cam.far = 600; cam.fov = 60; W.add_child(cam)
	var east = W.find_child("TownEast", true, false)
	east._shift()
	await shot("j_sto", Town.w(Vector3(249, 2.2, 56)), Town.w(Vector3(253, 0.8, 67)))
	await shot("j_garden", Vector3(-112, 6.0, -78), Vector3(-125, 0.5, -64))
	var c: Vector2 = Region.VILLAGES[0].c
	await shot("j_village", Vector3(c.x - 30, 7.0, c.y - 40), Vector3(c.x - 10, 0.5, c.y - 18))
	await shot("j_plots", Town.w(Vector3(231, 8.0, 140)), Town.w(Vector3(231, 0.5, 175)))
	quit()
