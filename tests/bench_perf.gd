extends SceneTree
## Замер производительности: в нескольких местах мира — вызовы отрисовки,
## объекты, треугольники, время скриптов и физики на кадр, и кто тратит
## кадр (узлы с _process / _physics_process по скриптам).
var W
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func stat() -> Dictionary:
	return {"draw": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"obj": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"tri": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"proc": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"phys": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0}
func measure(name: String) -> void:
	for i in 60: await process_frame
	var acc := {"draw": 0.0, "obj": 0.0, "tri": 0.0, "proc": 0.0, "phys": 0.0}
	var mx := {"proc": 0.0, "phys": 0.0, "wall": 0.0}
	var n := 90
	var t0 := Time.get_ticks_usec()
	var last := t0
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		mx.wall = maxf(mx.wall, (now - last) / 1000.0)
		last = now
		var s := stat()
		for k in acc: acc[k] += s[k]
		mx.proc = maxf(mx.proc, s.proc); mx.phys = maxf(mx.phys, s.phys)
	var wall := (Time.get_ticks_usec() - t0) / 1000.0 / n
	print("%-10s draw %5.0f  obj %5.0f  tri %7.0fk  proc %5.2f ms (max %5.2f)  phys %5.2f ms (max %5.2f)  wall %6.1f ms (max %6.1f)" % [name,
		acc.draw / n, acc.obj / n, acc.tri / n / 1000.0, acc.proc / n, mx.proc, acc.phys / n, mx.phys, wall, mx.wall])
## Сколько микросекунд стоит один _process / _physics_process каждого узла
## (по скриптам, сумма) — вызываем напрямую и меряем.
func profile(tag: String) -> void:
	var cost := {}
	for n in W.find_children("*", "", true, false) + [W]:
		var sc: Script = n.get_script()
		if sc == null: continue
		for m in ["_process", "_physics_process"]:
			if not n.has_method(m): continue
			if m == "_process" and not n.is_processing(): continue
			if m == "_physics_process" and not n.is_physics_processing(): continue
			var t := Time.get_ticks_usec()
			for i in 20: n.call(m, 1.0 / 60.0)
			var us := (Time.get_ticks_usec() - t) / 20.0
			var key: String = sc.resource_path.get_file() + (" F" if m == "_physics_process" else " P")
			cost[key] = cost.get(key, 0.0) + us
	var keys := cost.keys()
	keys.sort_custom(func(a, b): return cost[a] > cost[b])
	var total := 0.0
	for k in keys: total += cost[k]
	print("== %s: скрипты %.2f ms на кадр" % [tag, total / 1000.0])
	for k in keys.slice(0, 12): print("   %7.0f us  %s" % [cost[k], k])


## Что попадает в кадр: видимые, в пределах дальности и в поле зрения
## камеры меши — по «хозяевам» (оценка вызовов отрисовки).
func breakdown(tag: String) -> void:
	var cam := root.get_viewport().get_camera_3d()
	var counts := {}
	var shadow := 0
	var total := 0
	for n in W.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree(): continue
		var aabb: AABB = g.get_aabb()
		var c: Vector3 = g.global_transform * aabb.get_center()
		var d := cam.global_position.distance_to(c)
		if g.visibility_range_end > 0.0 and d > g.visibility_range_end + aabb.size.length() * 0.5: continue
		if d < g.visibility_range_begin: continue
		if d > cam.far + aabb.size.length(): continue
		var r := aabb.size.length() * 0.5
		if not cam.is_position_in_frustum(c) and d > r: 
			# грубо: центр вне поля зрения и камера не внутри
			var any := false
			for k in 8:
				if cam.is_position_in_frustum(g.global_transform * aabb.get_endpoint(k)): any = true; break
			if not any: continue
		total += 1
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and d < 70.0: shadow += 1
		var p := g.get_parent()
		var key: String = g.name.rstrip("0123456789_").left(18) + " < " + (p.get_script().resource_path.get_file() if p and p.get_script() else (String(p.name).left(14) if p else "?"))
		counts[key] = counts.get(key, 0) + 1
	var ks := counts.keys()
	ks.sort_custom(func(a, b): return counts[a] > counts[b])
	print("== %s: в кадре ~%d мешей, из них отбрасывают тень (до 70 м) ~%d" % [tag, total, shadow])
	for k in ks.slice(0, 14): print("   %5d  %s" % [counts[k], k])


func _run() -> void:
	print("max_fps=", Engine.max_fps, " low_cpu=", OS.low_processor_usage_mode, " vsync=", DisplayServer.window_get_vsync_mode(), " phys=", Engine.physics_ticks_per_second)
	Engine.max_fps = 0
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 12 * 60.0
	var P = W.get_node("Player")
	# Кто обновляется каждый кадр
	var procs := {}
	var nodes := 0
	for n in W.find_children("*", "", true, false):
		nodes += 1
		var key := ""
		if n.is_processing(): key += "P"
		if n.is_physics_processing(): key += "F"
		if key == "": continue
		var sc: Script = n.get_script()
		var nm: String = sc.resource_path.get_file() if sc else n.get_class()
		procs[nm + " " + key] = procs.get(nm + " " + key, 0) + 1
	var keys := procs.keys()
	keys.sort_custom(func(a, b): return procs[a] > procs[b])
	print("узлов: ", nodes, ", обновляются каждый кадр:")
	for k in keys.slice(0, 25): print("   ", procs[k], "  ", k)
	var spots := [["дом", Vector3(-125, 0.3, -40), 0.0], ["сельмаг", Vector3(-55, 0.3, -30), PI / 2],
		["трасса", Vector3(-20, 0.3, 2), -PI / 2], ["город", Town.w(Vector3(110, 0.3, 30)), 0.0],
		["гаражи", Town.w(Vector3(270, 0.3, 150)), 0.0], ["Владик", VladikGarage.w(Vector3(0, 0.3, 3)), PI],
		["Липки", Vector3(-760, 0.3, 1313.5), PI / 2], ["лес-асф", Vector3(-640, 0.3, 790), PI], ["лес-грунт", Vector3(-1130, 0.3, 1000), PI]]
	for s in spots:
		P.global_position = s[1]; P.rotation.y = s[2]
		await measure(s[0])
		if s[0] in ["сельмаг", "город"]: breakdown(s[0])
	# Езда на машине по трассе
	var car: Vehicle = W.get_node("Car")
	car.global_position = Vector3(-200, 0.5, 2.0); car.rotation = Vector3(0, -PI / 2, 0)
	for i in 5: await physics_frame
	car._on_enter()
	car.fuel = 30.0; car.engine_on = true
	var e := InputEventKey.new(); e.physical_keycode = KEY_W; e.keycode = KEY_W; e.pressed = true
	Input.parse_input_event(e)
	await measure("езда")
	breakdown("езда")
	var sun: DirectionalLight3D = W._sun
	sun.shadow_enabled = false
	await measure("езда-тени")
	sun.shadow_enabled = true
	car.chase_view = false
	await measure("езда-салон")
	car.chase_view = true
	var counts := {}
	for n in W.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree(): continue
		var p := g.get_parent()
		var key: String = (p.get_script().resource_path.get_file() if p and p.get_script() else (p.name if p else "?"))
		counts[key] = counts.get(key, 0) + 1
	var ks := counts.keys()
	ks.sort_custom(func(a, b): return counts[a] > counts[b])
	print("== видимые меши по владельцу:")
	for k in ks.slice(0, 15): print("   %5d  %s" % [counts[k], k])
	quit()
