extends SceneTree
## Снимки дальности обзора: с дороги вдаль, с холма над Каменкой, край района.
## LVL — детализация (0, 1, 2), SUFFIX — к имени файла.
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
	for i in 25: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [OS.get_environment("SHOTS"), name, OS.get_environment("SUFFIX")])
func _run() -> void:
	for i in 10: await process_frame
	var SM = root.get_node("SettingsManager")
	SM.detail = int(OS.get_environment("LVL")) if OS.get_environment("LVL") != "" else 2
	SM.changed.emit()
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c is CanvasLayer: c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 10 * 60.0
	var P = W.get_node("Player"); P.set_physics_process(false); P.global_position = Vector3(0, 0.2, 90)
	cam = Camera3D.new(); W.add_child(cam)
	await view("v1_road", Vector3(-200, 1.6, 2.5), Vector3(-600, 0, 0))
	await view("v2_hill", Vector3(-100, 40, 20), Vector3(-400, 0, -300))
	await view("v3_edge", Vector3(1900, 3, 0), Vector3(2100, 5, 100))
	quit()
