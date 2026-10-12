extends SceneTree
var W
func _initialize() -> void:
	root.size = Vector2i(1000, 600)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 12: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func _run() -> void:
	for i in 10: await process_frame
	child("pause_menu.gd")._close(); child("tutorial.gd")._finish()
	var map = child("map.gd")
	await save("map_mini")
	map.mode = 1; map._canvas.visible = true; map._canvas.queue_redraw()
	await save("map_kamenka")
	W.get_node("Player").global_position = Town.w(Vector3(120, 0.2, 60))
	for i in 30: await process_frame
	map._canvas.queue_redraw()
	await save("map_town")
	W.get_node("Player").global_position = Vector3(-460, 0.2, -290)
	for i in 30: await process_frame
	map._canvas.queue_redraw()
	await save("map_village")
	quit()
