extends SceneTree
## Снимки территории автошколы: забор, ворота, стоянка учебных машин с «У»;
## экзамен на A — игрок на учебной «Яве» на старте.
var W
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func shot(name: String, from: Vector3, at: Vector3) -> void:
	var cam := Camera3D.new(); W.add_child(cam)
	cam.global_position = Town.w(from); cam.look_at(Town.w(at)); cam.make_current()
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
	W.get_node("Player").global_position = Town.w(Vector3(-20, 0.3, 5))
	await shot("as_gate", Vector3(-29, 6, -8), Vector3(-25, 0, 30))
	await shot("as_parking", Vector3(4, 9, 30), Vector3(-10, 0, 50))
	var PR = root.get_node("Progress")
	PR.add_doc("passport"); PR.add_doc("med")
	root.get_node("GameManager").money = 1000
	var AS = W.get_node("AutoSchool")
	AS._start(0)
	for i in 20: await physics_frame
	await shot("as_exam_a", Vector3(-24, 4, 10), Vector3(-29, 0.5, 20))
	quit()
