extends SceneTree
## Снимки: «ИЖ Юпитер-5» в автосалоне — сбоку (как на плакате), спереди,
## сзади и с мотоциклистом.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func shot(name: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c.get_script() and c.get_script().resource_path.ends_with("hud.gd"): c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var TM = root.get_node("TimeManager")
	TM.day = 2; TM.minutes = 12 * 60.0
	var I: Vehicle = W.get_node("Izh")
	I.global_position = Vector3(40, 0.3, 40)
	I.rotation.y = PI / 2.0
	for i in 20: await physics_frame
	var p := I.global_position
	cam = Camera3D.new(); cam.far = 700.0; cam.fov = 40.0; W.add_child(cam)
	cam.make_current()
	# Сбоку слева, перед — влево (как на плакате)
	var xf := I.global_transform
	await shot("izh_side", xf * Vector3(-3.4, 0.75, -0.05), xf * Vector3(0, 0.62, -0.05))
	await shot("izh_front", xf * Vector3(-1.8, 1.2, -2.8), xf * Vector3(0, 0.7, 0))
	await shot("izh_rear", xf * Vector3(1.8, 1.3, 2.8), xf * Vector3(0, 0.7, 0))
	quit()
