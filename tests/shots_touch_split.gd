extends SceneTree
## Снимок телефонного экрана в начале игры: подсказка «ходить | камера».
func _initialize() -> void:
	root.size = Vector2i(1600, 740)
	var W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
	for i in 40: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/touch_split.png")
	quit()
