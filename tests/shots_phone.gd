extends SceneTree
## Телефон и инвентарь: главный экран, приложения, инвентарь; SIZE=ширина×высота.
var W
func _initialize() -> void:
	var sz := OS.get_environment("SIZE").split("x")
	root.size = Vector2i(int(sz[0]), int(sz[1])) if sz.size() == 2 else Vector2i(1000, 560)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 6: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("TimeManager").minutes = 12 * 60.0 + 34.0
	var pre := OS.get_environment("PRE")
	await save(pre + "game")
	var ph: PhoneUI = W.get_node("Phone")
	ph.open()
	await save(pre + "phone_home")
	for a in ["calls", "taxi", "weather", "music"]:
		ph.show_app(a)
		await save(pre + "phone_" + a)
	ph.close_phone()
	var inv: InventoryPanel = W.get_node("Inventory")
	inv.open()
	await save(pre + "inventory")
	quit()
