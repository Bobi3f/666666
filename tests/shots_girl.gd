extends SceneTree
## Снимки: Оля у калитки, разговор с ней, Оля в машине и на мотоцикле.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(name: String) -> void:
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func shot(name: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	await save(name)
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var TM = root.get_node("TimeManager"); var PR = root.get_node("Progress")
	TM.day = 3; TM.minutes = 15 * 60.0
	PR.buy_car("car"); PR.add_category("B"); PR.add_category("A"); PR.license = true
	var G: Girl = W.get_node("Girl")
	var P = W.get_node("Player")
	for i in 5: await process_frame
	var g := G.doll.global_position
	cam = Camera3D.new(); cam.far = 700.0; W.add_child(cam)
	cam.make_current()
	await shot("girl_gate", g + Vector3(1.2, 1.5, -3.2), g + Vector3(0, 1.1, 0))
	await shot("girl_face", g + Vector3(0.3, 1.45, -1.3), g + Vector3(0, 1.3, 0))
	await shot("girl_far", g + Vector3(6, 3, -9), g + Vector3(0, 1, 2))
	cam.current = false
	P.global_position = g + Vector3(0, 0.1, -1.5)
	for i in 10: await physics_frame
	G.rel = 35
	G.open_talk()
	await save("girl_talk")
	G.panel.close_panel()
	G.invite()
	var C: Vehicle = W.get_node("Car")
	C.global_position = g + Vector3(2.5, 0.3, -5)
	C.rotation.y = PI / 2.0
	for i in 10: await physics_frame
	# Сначала — снаружи: сажаем Олю без водителя, камера своя
	G._board(C)
	G.set_process(false)  # без водителя она бы сразу вышла
	for i in 5: await process_frame
	cam.make_current()
	var cp := C.global_position
	await shot("girl_car", cp + C.global_transform.basis * Vector3(2.4, 1.4, -1.2), cp + C.global_transform.basis * Vector3(0.3, 0.9, 0.3))
	G.set_process(true)
	G._get_out()
	C._on_enter()
	for i in 5: await process_frame
	await save("girl_car_inside")
	C._drop_driver()
	for i in 10: await process_frame
	var M: Vehicle = W.get_node("Moto")
	M.global_position = C.global_position + C.global_transform.basis * Vector3(-4, 0, 0)
	M.rotation.y = PI / 2.0
	for i in 10: await physics_frame
	M._on_enter()
	for i in 5: await process_frame
	cam.make_current()
	var mp := M.global_position
	await shot("girl_moto", mp + M.global_transform.basis * Vector3(2.8, 1.3, 0.8), mp + Vector3(0, 0.9, 0))
	quit()
