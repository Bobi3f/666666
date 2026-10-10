extends SceneTree
## Снимки: оглядеться за рулём — из салона влево и сзади облётом сбоку.
var W
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func shot(name: String) -> void:
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("Progress").buy_car("car")
	var C = W.get_node("Car"); var P = W.get_node("Player")
	C.global_position = Vector3(-30, 0.1, 2.0); C.rotation.y = -PI / 2.0
	C._on_enter()
	P._look(1.2, 0.05)
	await shot("look_cabin_left")
	C.look_yaw = 0.0; C.look_pitch = 0.0
	Vehicle.chase_view = true
	C._active_camera().current = true
	P._look(2.0, 0.25)
	await shot("look_chase_side")
	quit()
