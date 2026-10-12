extends SceneTree
## Замер тяжести кадра в разных местах: вызовы отрисовки, треугольники,
## объекты и время кадра. DETAIL=0/1/2 — детализация. Для поиска, что
## тормозит на телефоне (рендер Compatibility, как в браузере).
var W
func _initialize() -> void:
	root.size = Vector2i(960, 540)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	var SM = root.get_node("SettingsManager")
	SM.detail = int(OS.get_environment("DETAIL")) if OS.get_environment("DETAIL") != "" else 0
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	# NIGHT=1 — ночью: горят фонари и окна
	root.get_node("TimeManager").minutes = (23.0 if OS.get_environment("NIGHT") == "1" else 12.0) * 60.0
	var P: Node3D = W.get_node("Player")
	var spots := [
		["дом игрока", Vector3(-125, 0.3, -42), PI],
		["улица Каменки", Vector3(-100, 0.3, -40), -PI / 2],
		["у сельмага", Vector3(-50, 0.3, -20), PI],
		["трасса у фермы", Vector3(18, 0.3, 10), PI],
		["в коровнике", Vector3(Farm.BARN.position.x + 2, 0.3, Farm.BARN.get_center().y), -PI / 2],
		["город, площадь", Town.w(Vector3(120, 0.3, 20)), 0.0],
		["город, восток", Town.w(Vector3(255, 0.3, 50)), 0.0],
		["село Озерцово", Vector3(-440, 0.3, -300), 0.0],
		["свалка", Landmarks.junk_center() + Vector3(0, 0.3, 25), PI],
	]
	var VP := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(VP, true)
	print("Детализация %d" % SM.detail)
	for s in spots:
		P.global_position = s[1]
		P.rotation.y = s[2]
		for i in 40: await process_frame
		var dc := 0.0; var prim := 0.0; var obj := 0.0; var cpu := 0.0; var gpu := 0.0
		var n := 20
		for i in n:
			await RenderingServer.frame_post_draw
			dc += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			prim += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			obj += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(VP) + RenderingServer.get_frame_setup_time_cpu()
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(VP)
		print("%-18s вызовов %5d  треуг. %7d тыс.  объектов %5d  кадр CPU %.1f мс  GPU %.1f мс" % [s[0], int(dc / n), int(prim / n / 1000), int(obj / n), cpu / n, gpu / n])
	quit()
