extends SceneTree
## Снимки школы: вход, класс с ребятами, вопрос урока, вестибюль, столовая.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func view(name: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c is CanvasLayer: c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var TM = root.get_node("TimeManager")
	TM.day = 1; TM.minutes = 9 * 60.0
	var S = W.get_node("TownSouth/School")
	var P = W.get_node("Player"); P.set_physics_process(false); P.global_position = Vector3(S.DOOR_X, 0.05, S.Z0 - 6.0)
	cam = Camera3D.new(); W.add_child(cam)
	await view("school_outside", Vector3(S.DOOR_X - 8, 4, S.Z0 - 16), Vector3(S.DOOR_X, 3, S.Z0))
	await view("school_class", Vector3(S.CLASS_WALL_X - 0.8, 2.6, S.Z0 + 1.2), Vector3(S.X0 + 1.0, 1.0, (S.Z0 + S.Z1) * 0.5))
	await view("school_class_back", Vector3(S.X0 + 1.2, 2.4, S.Z1 - 1.0), Vector3(S.CLASS_WALL_X - 1.0, 0.8, S.Z0 + 3.0))
	await view("school_hall", Vector3(S.DOOR_X, 2.2, S.Z0 + 1.0), Vector3(S.DOOR_X, 1.5, S.Z1))
	await view("school_canteen", Vector3(S.CANTEEN_WALL_X + 0.8, 2.5, S.Z0 + 1.2), Vector3(S.X1, 1.0, (S.Z0 + S.Z1) * 0.5))
	TM.minutes = 19.5 * 60.0
	await view("school_evening", Vector3(S.CLASS_WALL_X - 0.8, 2.6, S.Z0 + 1.2), Vector3(S.X0 + 1.0, 1.0, (S.Z0 + S.Z1) * 0.5))
	# Урок: вопрос на экране (как на телефоне)
	TM.minutes = 10 * 60.0
	cam.global_position = Vector3(S.CLASS_WALL_X - 0.8, 2.6, S.Z0 + 1.2)
	cam.look_at(Vector3(S.X0 + 1.0, 1.0, (S.Z0 + S.Z1) * 0.5))
	for i in 5: await process_frame
	S.start_lesson()
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/school_lesson.png" % OS.get_environment("SHOTS"))
	S.answer(0)
	quit()
