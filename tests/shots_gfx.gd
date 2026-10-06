extends SceneTree
## Графика: полдень с тенями облаков, закат с тёплой дымкой, блеск «Жигулей».
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("SettingsManager").set_detail(2)
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var TM = root.get_node("TimeManager")
	cam = Camera3D.new(); cam.fov = 65; cam.far = 1500; W.add_child(cam); cam.make_current()
	W.get_node("Player").global_position = Vector3(20, 0.2, 60)
	TM.minutes = 12.5 * 60.0
	cam.global_position = Vector3(0, 14, 30)
	cam.look_at(Vector3(150, 0, 120))
	await save("g_noon_fields")
	var car: Node3D = W.get_node("Car")
	W.get_node("Player").global_position = car.global_position + Vector3(0, 0.2, 8)
	cam.global_position = car.global_position + Vector3(3.2, 1.4, 2.4)
	cam.look_at(car.global_position + Vector3(0, 0.7, 0))
	await save("g_car_gloss")
	TM.minutes = 19.6 * 60.0
	cam.global_position = Vector3(-60, 3, -8)
	cam.look_at(Vector3(-300, 10, -10))
	await save("g_sunset")
	cam.global_position = Vector3(-60, 3, -8)
	cam.look_at(Vector3(200, 5, 0))
	await save("g_sunset_lit")
	root.get_node("SettingsManager").set_detail(1)
	quit()
