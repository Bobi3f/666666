extends SceneTree
var W
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
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
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	await snap("01_start")
	var P = W.get_node("Player")
	var FG = W.get_node("FishingGame")
	var TM = root.get_node("TimeManager")
	TM.minutes = 7 * 60.0
	P.global_position = FG.spot + Vector3(0.5, 0.1, 0)
	P.rotation.y = PI / 2.0
	P._head.rotation.x = -0.35
	await snap("02_pier")
	for z in W.get_children():
		if z is InteractZone and z.text().contains("порыбачить"):
			z.activate()
	await snap("03_float")
	var t0 := Time.get_ticks_msec()
	while FG.state != 2 and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
		if FG.state == 0:
			for z in W.get_children():
				if z is InteractZone and z.text().contains("порыбачить"): z.activate()
	await snap("04_bite")
	var C = W.get_node("Car")
	P.global_position = C.global_position + Vector3(0, 0.2, 2.0)
	C._on_enter()
	await snap("05_drive")
	quit()
