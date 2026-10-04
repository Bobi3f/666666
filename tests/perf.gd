extends SceneTree
## Замер: время сборки мира, узлы, треугольники, вызовы отрисовки, время
## скриптов и физики за кадр (llvmpipe — только для сравнения «до/после»).
func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	var t1 := Time.get_ticks_msec()
	print("PERF build_ms=", t1 - t0)
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"):
			c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"):
			c._finish()
	for i in 30: await process_frame
	print("PERF nodes=%d meshes=%d labels=%d bodies=%d shapes=%d lights=%d" % _count(W))
	var cam := Camera3D.new()
	cam.far = 700.0
	W.add_child(cam)
	var views := [[Vector3(-100, 2, -40), Vector3(-130, 1, -40)], [Vector3(-60, 45, 10), Vector3(-110, 0, -40)], [Vector3(60, 3, 20), Vector3(100, 5, 60)],
		[Vector3(90, 2, 21), Vector3(130, 2, 21)], [Vector3(-60, 2, -30), Vector3(-45, 1, -24)], [Vector3(-110, 2, 20), Vector3(-80, 1, 10)]]
	var lvl := int(OS.get_environment("LVL")) if OS.get_environment("LVL") != "" else 2
	root.get_node("SettingsManager").detail = lvl
	root.get_node("SettingsManager").changed.emit()
	var sum_proc := 0.0
	var sum_phys := 0.0
	for v in views:
		cam.global_position = v[0]
		cam.look_at(v[1])
		cam.make_current()
		for i in 20: await process_frame
		var t := Time.get_ticks_usec()
		var proc := 0.0
		var phys := 0.0
		for i in 30:
			await process_frame
			proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var ms := (Time.get_ticks_usec() - t) / 30000.0
		sum_proc += proc / 30.0
		sum_phys += phys / 30.0
		print("PERF view %s frame_ms=%.1f process_ms=%.2f physics_ms=%.2f draw_calls=%d prims=%d" % [v[0], ms, proc / 30.0, phys / 30.0,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	print("PERF avg process_ms=%.2f physics_ms=%.2f" % [sum_proc / views.size(), sum_phys / views.size()])
	quit()

func _count(n: Node) -> Array:
	var r := [0, 0, 0, 0, 0, 0]
	var st: Array[Node] = [n]
	while not st.is_empty():
		var c: Node = st.pop_back()
		r[0] += 1
		if c is MeshInstance3D or c is MultiMeshInstance3D: r[1] += 1
		if c is Label3D: r[2] += 1
		if c is CollisionObject3D: r[3] += 1
		if c is CollisionShape3D: r[4] += 1
		if c is Light3D: r[5] += 1
		st.append_array(c.get_children())
	return r
