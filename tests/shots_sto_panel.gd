extends SceneTree
## Снимок окна мастера СТО «Автосервис»: покраска и замена узлов.
var W
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("TimeManager").minutes = 11 * 60.0
	root.get_node("Progress").buy_car("car")
	var C = W.get_node("Car")
	C.global_position = Town.w(Vector3(248, 0.1, 67))
	C.health = {"brakes": 18.0, "tyres": 46.0, "engine": 71.0}
	W.get_node("Player").global_position = Town.w(Vector3(236, 0.2, 65))
	for i in 5: await process_frame
	W.get_node("TownEast").open_master()
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/sto_panel.png" % OS.get_environment("SHOTS"))
	quit()
