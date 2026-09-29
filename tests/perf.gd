extends SceneTree
## Замер: время сборки мира, треугольники, вызовы отрисовки и FPS (llvmpipe — только сравнение).
func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	var t1 := Time.get_ticks_msec()
	print("PERF build_ms=", t1 - t0)
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"):
			c._close()
	for i in 30: await process_frame
	var cam := Camera3D.new()
	W.add_child(cam)
	var views := [[Vector3(-100, 2, -40), Vector3(-130, 1, -40)], [Vector3(-60, 45, 10), Vector3(-110, 0, -40)], [Vector3(60, 3, 20), Vector3(100, 5, 60)],
		[Vector3(90, 2, 21), Vector3(130, 2, 21)], [Vector3(-60, 2, -30), Vector3(-45, 1, -24)], [Vector3(-110, 2, 20), Vector3(-80, 1, 10)]]
	var lvl := int(OS.get_environment("LVL")) if OS.get_environment("LVL") != "" else 2
	root.get_node("SettingsManager").detail = lvl
	root.get_node("SettingsManager").changed.emit()
	for v in views:
		cam.global_position = v[0]
		cam.look_at(v[1])
		cam.make_current()
		for i in 20: await process_frame
		var t := Time.get_ticks_usec()
		for i in 30: await process_frame
		var ms := (Time.get_ticks_usec() - t) / 30000.0
		print("PERF view %s frame_ms=%.1f draw_calls=%d prims=%d" % [v[0], ms,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	quit()
