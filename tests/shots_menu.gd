extends SceneTree
var W
func _initialize() -> void:
	root.size = Vector2i(int(OS.get_environment("SW")), int(OS.get_environment("SH")))
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func snap(name: String) -> void:
	for i in 12:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10:
		await process_frame
	var menu
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): menu = c
	var p: String = OS.get_environment("PFX")
	await snap(p + "1_main")
	menu._close()
	await process_frame
	menu._open(false)
	await snap(p + "2_pause")
	menu._show("settings")
	await snap(p + "3_settings")
	menu._show("controls")
	await snap(p + "4_controls")
	menu._show("confirm")
	await snap(p + "5_confirm")
	quit()
