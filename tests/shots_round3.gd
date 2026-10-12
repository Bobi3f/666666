extends SceneTree
var W
func _initialize() -> void:
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
	var TM = root.get_node("TimeManager"); var PR = root.get_node("Progress")
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var P = W.get_node("Player")
	var C = W.get_node("Car")
	# Карта: игрок на улице
	P.global_position = Vector3(-110, 0.1, -40)
	TM.minutes = 12 * 60.0
	for i in 5: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("map.gd"):
			c._canvas.visible = true
			await snap("01_map")
			c._canvas.visible = false
	# Огород поспевший
	PR.planted = true
	PR.planted_at = PR.now() - PR.GROW_TIME - 10.0
	PR.garden_changed.emit()
	P.set_physics_process(false)
	var cam := Camera3D.new()
	W.add_child(cam)
	cam.make_current()
	cam.global_position = Vector3(-118, 3.0, -73)
	cam.look_at(Vector3(-125, 0.3, -66))
	TM.minutes = 13 * 60.0
	await snap("02_garden_ripe")
	# Фары ночью: смотрим из машины
	C.global_position = Vector3(-150, 0.1, -40)
	C.rotation.y = -PI / 2.0
	C._on_enter()
	C.fuel = 30.0
	C._toggle_ignition()
	TM.minutes = 23 * 60.0
	await snap("03_headlights")
	C.engine_on = false
	C.exit_car()
	# Улица ночью: теперь фонари светят по-настоящему
	cam.make_current()
	cam.global_position = Vector3(-120, 2.0, -40)
	cam.look_at(Vector3(-137.5, 0.5, -39))
	await snap("04_lamps_night")
	quit()
