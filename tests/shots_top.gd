extends SceneTree
## Вид сверху на центр карты (Каменка и город) — для планировки.
var W
func _initialize() -> void:
	root.size = Vector2i(1200, 1200)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c is CanvasLayer: c.visible = false
	root.get_node("TimeManager").minutes = 12 * 60.0
	var P = W.get_node("Player"); P.set_physics_process(false)
	var cam := Camera3D.new(); W.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var cx := float(OS.get_environment("CX")); var cz := float(OS.get_environment("CZ")); var sz := float(OS.get_environment("SZ"))
	P.global_position = Vector3(cx, 0.2, cz)
	cam.size = sz
	cam.far = 800
	cam.global_position = Vector3(cx, 45, cz)
	cam.rotation = Vector3(-PI / 2.0, 0, 0)
	cam.make_current()
	for i in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/top.png" % OS.get_environment("SHOTS"))
	quit()
