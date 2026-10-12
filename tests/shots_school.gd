extends SceneTree
## Снимки школы: снаружи, коридор, кабинеты и экран каждого урока
## (размер — как у низкого телефона).
var W
var cam: Camera3D
var OFF := Vector3.ZERO
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func view(name: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from + OFF
	cam.look_at(at + OFF)
	cam.make_current()
	for i in 20: await process_frame
	shot(name)
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
	var P = W.get_node("Player"); P.set_physics_process(false); P.global_position = S.at(Vector3(S.DOOR_X, 0.05, S.Z0 + 2.0))
	cam = Camera3D.new(); W.add_child(cam)
	var cz: float = (S.ZN + S.ZS) * 0.5
	# Все точки ниже — в координатах школы: view сдвигает их на место школы
	OFF = S.ORIGIN
	await view("school_yard", Vector3(S.DOOR_X + 22.0, 9.0, S.YARD.position.y - 12.0), Vector3(S.DOOR_X - 4.0, 0.0, S.Z0 - 14.0))
	await view("school_sport", Vector3(S.YARD.position.x + 26.0, 3.0, S.YARD.position.y + 3.0), Vector3(S.YARD.position.x + 8.0, 0.5, S.YARD.position.y + 12.0))
	await view("school_outside", Vector3(S.DOOR_X - 10, 5, S.Z0 - 18), Vector3(S.DOOR_X, 3, S.Z0 + 5))
	await view("school_corridor", Vector3(S.X1 - 1.0, 2.3, cz), Vector3(S.X0, 1.2, cz))
	await view("school_math", Vector3(53.3, 2.6, S.ZN - 0.6), Vector3(S.X0, 1.0, (S.Z0 + S.ZN) * 0.5))
	await view("school_lit", Vector3(52.3, 2.6, S.ZS + 0.8), Vector3(S.X0, 1.0, (S.ZS + S.Z1) * 0.5 + 1.0))
	await view("school_art", Vector3(63.5, 2.7, S.ZS + 0.8), Vector3(56.0, 0.8, S.Z1))
	await view("school_clay", Vector3(65.3, 2.7, S.ZS + 0.8), Vector3(74.0, 0.6, S.Z1 - 1.0))
	await view("school_canteen", Vector3(64.8, 2.5, S.ZN - 0.6), Vector3(S.X1, 1.0, S.Z0 + 2.0))
	cam.global_position = S.at(Vector3(53.3, 2.6, S.ZN - 0.6))
	cam.look_at(S.at(Vector3(S.X0, 1.0, (S.Z0 + S.ZN) * 0.5)))
	var LP = S.panel
	S.start_lesson("math")
	for i in 10: await process_frame
	shot("lesson_math")
	for i in 4: LP.answer(LP.right_index())
	S.start_lesson("lit")
	for i in 10: await process_frame
	shot("lesson_lit")
	for i in 3: LP.answer(0)
	S.start_lesson("art")
	var cv = LP.canvas()
	var line := PackedVector2Array()
	for k in int(cv.target.size() * 0.6): line.append(cv.target[k] + Vector2(0.008, -0.006))
	cv.strokes = [line]
	cv.queue_redraw()
	for i in 10: await process_frame
	shot("lesson_art")
	LP.finish_art()
	TM.day = 2
	S.start_lesson("clay")
	cv = LP.canvas()
	for i in cv.SLICES / 2:
		var y: float = 0.92 - float(i) / (cv.SLICES - 1) * 0.84
		for k in 3: cv.touch(Vector2(0.5 + cv.goal[i] * 0.4, y))
	for i in 10: await process_frame
	shot("lesson_clay")
	LP.finish_art()
	quit()
