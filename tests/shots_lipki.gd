extends SceneTree
## Липки и дороги к ним: въезд с постом и стелой, бульвар, дома разных видов,
## дом №1, быстрая дорога через лес, грунтовка через лес, поляна, посадка с тополями.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 14: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func shot(n: String, at: Vector3, look: Vector3) -> void:
	W.get_node("Player").global_position = Vector3(look.x, 0.3, look.z)
	for i in 3: await physics_frame
	cam.make_current(); cam.global_position = at; cam.look_at(look)
	await save(n)
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	for c in W.find_children("*", "CanvasLayer", true, false): c.visible = false
	root.get_node("SettingsManager").set_detail(2)
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 15 * 60.0
	cam = Camera3D.new(); cam.fov = 60; W.add_child(cam)
	await shot("lp_entrance", Vector3(1020, 4.0, 1062), Vector3(1080, 1.5, 1080))
	await shot("lp_boulevard", Vector3(1150, 3.0, 1080), Vector3(1260, 2.0, 1080))
	for i in 4:
		var xf := EliteDistrict.plot_xf(i)
		await shot("lp_house_%d" % (i + 1), xf * Vector3(-2, 6.0, 22), xf * Vector3(4, 3.0, -34))
	await shot("lp_ring", Vector3(1320, 8.0, 1060), Vector3(1352, 0.5, 1080))
	var f: Array = EliteDistrict.ROAD_FAST
	await shot("lp_fast_forest", Vector3(f[2].x - 2, 2.0, f[2].y - 25), Vector3(f[3].x, 1.0, f[3].y))
	var sr: Array = EliteDistrict.ROAD_SCENIC
	await shot("lp_scenic_forest", Vector3(sr[7].x - 4, 2.0, sr[7].y - 30), Vector3(sr[8].x, 1.0, sr[8].y))
	var g: Vector2 = ForestLife.glades()[0][0]
	await shot("lp_glade", Vector3(g.x + 10, 3.0, g.y + 10), Vector3(g.x, 0.5, g.y))
	await shot("lp_poplars", Vector3(300, 2.5, 10), Vector3(380, 4.0, 18))
	quit()
