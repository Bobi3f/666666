extends SceneTree
## Нагрузка в разных местах мира: вызовы отрисовки, треугольники, объекты,
## время скриптов (_process и _physics_process) — на низкой и высокой
## детализации. Запуск — с экраном (xvfb-run, --rendering-driver opengl3).
var W
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func measure(name: String, pos: Vector3, yaw: float) -> void:
	var P = W.get_node("Player")
	P.global_position = pos; P.rotation.y = yaw
	for i in 40: await process_frame
	var dc := 0.0; var prim := 0.0; var obj := 0.0; var tp := 0.0; var tph := 0.0
	var n := 30
	for i in n:
		await process_frame
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		obj += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		tp += Performance.get_monitor(Performance.TIME_PROCESS)
		tph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	print("SPOT %-14s вызовов %4d  треуг. %7d  объектов %4d  _process %5.2f мс  _physics %5.2f мс" % [name, dc / n, prim / n, obj / n, tp / n * 1000.0, tph / n * 1000.0])
func _run() -> void:
	for i in 20: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	var SM = root.get_node("SettingsManager")
	root.get_node("TimeManager").minutes = 12 * 60.0
	for d in [0, 2]:
		SM.set_detail(d)
		print("== детализация ", d)
		await measure("деревня", Vector3(-110, 0.2, -40), -PI / 2.0)
		await measure("трасса", Vector3(300, 0.2, 2), -PI / 2.0)
		await measure("въезд в город", Town.w(Vector3(-60, 0.2, 2)), -PI / 2.0)
		await measure("центр города", Town.w(Vector3(97, 0.2, 40)), PI)
		await measure("рынок/школа", Town.w(Vector3(97, 0.2, 120)), PI / 2.0)
		await measure("восток города", Town.w(Vector3(265, 0.2, 60)), 0.0)
		await measure("парк", Town.w(Vector3(20, 0.2, 165)), PI / 2.0)
		await measure("Заречье", Vector3(490, 0.2, 300), 0.0)
	quit()
