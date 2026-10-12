extends SceneTree
## Снимки дорог: деревенская улица, полевая и лесная грунтовки, трасса,
## городские улицы, грунтовка к селу района, тропинки, фонари ночью; двор
## с техникой после загрузки.
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
	W.get_node("Player").global_position = at + Vector3(0, 0.3, 0)
	for i in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c is CanvasLayer: c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 13 * 60.0
	var P = W.get_node("Player"); P.set_physics_process(false)
	cam = Camera3D.new(); W.add_child(cam)
	var args := OS.get_cmdline_user_args()
	var pre := "rd_after_" if "--after" in args else "rd_"
	await view(pre + "village", Vector3(-150, 2.2, -40), Vector3(-110, 0.5, -40))
	await view(pre + "field", Vector3(-30, 2.2, -38), Vector3(-6, 0.5, -60))
	await view(pre + "forest", Vector3(-164.5, 2.2, -70), Vector3(-150, 0.5, -86.5))
	await view(pre + "highway", Vector3(120, 2.5, -2), Vector3(180, 0.5, 2))
	await view(pre + "town", Town.w(Vector3(97, 2.5, 20)), Town.w(Vector3(97, 0.5, 60)))
	await view(pre + "townx", Town.w(Vector3(60, 2.5, 58)), Town.w(Vector3(130, 0.5, 58)))
	await view(pre + "region", Vector3(430, 2.2, 20), Vector3(430, 0.5, 90))
	root.get_node("TimeManager").minutes = 22 * 60.0
	await view(pre + "night_village", Vector3(-150, 3.0, -40), Vector3(-100, 0.5, -40))
	await view(pre + "night_town", Town.w(Vector3(97, 3.0, 15)), Town.w(Vector3(97, 0.5, 60)))
	await view(pre + "night_road", Vector3(-20, 3.0, -2), Vector3(60, 0.5, 2))
	quit()
