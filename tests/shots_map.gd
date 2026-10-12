extends SceneTree
## Снимки карты: большая (M) и мини-карта в углу. SHOTS — папка для png.
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	for i in 10: await process_frame
	var map
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c.get_script() and c.get_script().resource_path.ends_with("map.gd"): map = c
	root.get_node("TimeManager").minutes = 12 * 60.0
	for i in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/map_mini.png")
	map._canvas.visible = true
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/map_big.png")
	quit()
