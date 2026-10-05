extends SceneTree
## Меню: «Удалить сохранение» и вопрос «точно?»; сельмаг — ремнабор у прилавка.
var W
func _initialize() -> void:
	root.size = Vector2i(1000, 560)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 10: await process_frame
	var menu
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): menu = c
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("SaveManager").save_game(true)
	menu._show("main")
	await save("k_menu")
	menu._show("delete")
	await save("k_delete")
	root.get_node("SaveManager").delete_slot(root.get_node("SettingsManager").slot)
	menu._close()
	var kit: Node3D = W.find_child("KitZone", true, false)
	var p: Node3D = W.get_node("Player")
	p.global_position = kit.global_position + kit.global_transform.basis.z * 1.2
	for i in 10: await physics_frame
	await save("k_shop")
	quit()
