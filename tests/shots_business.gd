extends SceneTree
## Снимки своего дела: ларёк Жоры в Озерцово, табличка автопарка у гаражей.
var W
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func view(name: String, from: Vector3, at: Vector3) -> void:
	var cam := Camera3D.new(); W.add_child(cam)
	cam.global_position = from; cam.look_at(at); cam.make_current()
	W.get_node("Player").global_position = at + Vector3(2, 0.3, 2)
	for i in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
	cam.queue_free()
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c is CanvasLayer: c.visible = false
	root.get_node("TimeManager").minutes = 12 * 60.0
	var DL = root.get_node("Daily")
	DL.rival = DL.Rival.ACTIVE; DL.changed.emit()
	await view("biz_rival", Vector3(-402, 3, -298), Vector3(-409, 1.2, -308))
	await view("biz_fleet", Town.w(Vector3(262, 3, 164)), Town.w(Vector3(272, 1.2, 172)))
	quit()
