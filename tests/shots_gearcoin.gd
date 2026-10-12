extends SceneTree
## Окно GEARCOIN: пакеты монет и эксклюзив; «Волга» Чёрная у дома.
var W
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("TimeManager").minutes = 12 * 60.0
	var shop: GearShop = W.get_node("GearShop")
	shop.open()
	await save("gc_coins")
	shop._tab = "shop"
	shop._refresh()
	await save("gc_shop")
	root.get_node("Progress").gearcoins = 5000
	shop.buy("volga:black")
	shop.buy("moto:gold")
	shop.close_panel()
	await create_timer(1.5).timeout
	var cam := Camera3D.new(); W.add_child(cam); cam.make_current()
	cam.global_position = Vector3(-140, 2.2, -33)
	cam.look_at(Vector3(-140, 0.8, -39.5))
	await save("gc_cars")
	quit()
