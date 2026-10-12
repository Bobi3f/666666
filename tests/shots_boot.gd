extends SceneTree
## Снимки запуска: экран загрузки, главное меню, карточка цели (как на телефоне).
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	root.add_child(load("res://scenes/Boot.tscn").instantiate())
	_run.call_deferred()
func shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 3: await process_frame
	shot("boot_loading")
	while root.get_node_or_null("World") == null: await process_frame
	for i in 30: await process_frame
	shot("boot_menu")
	var W = root.get_node("World")
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
	for i in 20: await process_frame
	shot("boot_goal_card")
	quit()
