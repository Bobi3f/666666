extends SceneTree
## Каменка-Северная, разные сёла района и задворки у бурсы — с высоты и с земли.
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
	var TM = root.get_node("TimeManager")
	TM.minutes = 12 * 60.0
	cam = Camera3D.new(); cam.fov = 60; cam.far = 1500; W.add_child(cam)
	var n := 0
	for i in Region.VILLAGES.size(): n += Region.plan(i).houses.size()
	print("новых домов в сёлах: ", n)
	await shot("v_kn_air", Vector3(-20, 70, -60), Vector3(-62, 0, -170))
	await shot("v_kn_street", Vector3(-62, 1.8, -95), Vector3(-62, 1.5, -150))
	await shot("v_kn_ring", Vector3(-62, 12, -196), Vector3(-62, 0, -228))
	for i in [0, 3, 4, 6, 7]:
		var c: Vector2 = Region.VILLAGES[i].c
		var e := float(Region.VILLAGES[i].entry)
		await shot("v_vil_%d_%s" % [i, Region.PLANS[i]], Vector3(c.x + 40 * e, 90, c.y + 90), Vector3(c.x - 60 * e, 0, c.y))
	TM.minutes = 21.5 * 60.0
	await shot("v_backlot_eve", Town.w(Vector3(284, 2.0, 117)), Town.w(Vector3(310, 1.5, 140)))
	TM.minutes = 13 * 60.0
	await shot("v_backlot_day", Town.w(Vector3(300, 6, 105)), Town.w(Vector3(312, 1.0, 145)))
	quit()
