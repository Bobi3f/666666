extends SceneTree
## Кто съедает время кадра: средний кадр без рендера (headless), потом —
## с выключенным по очереди каждым узлом мира. Разница — цена узла.
var W
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func frame_ms(n: int) -> float:
	await process_frame
	var t0 := Time.get_ticks_usec()
	for i in n: await process_frame
	return (Time.get_ticks_usec() - t0) / 1000.0 / n
func spot(name: String, pos: Vector3) -> void:
	var P = W.get_node("Player")
	P.global_position = pos
	for i in 30: await process_frame
	var base: float = await frame_ms(60)
	print("== %s: кадр %.2f мс" % [name, base])
	var costs := []
	for c in W.get_children():
		if c == P or not (c is Node): continue
		var m: int = c.process_mode
		c.process_mode = Node.PROCESS_MODE_DISABLED
		var t: float = await frame_ms(40)
		c.process_mode = m
		costs.append([base - t, String(c.name)])
	costs.sort_custom(func(a, b): return a[0] > b[0])
	for k in 12:
		print("   %6.2f мс  %s" % costs[k])
func _run() -> void:
	for i in 20: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	print('low_proc=', OS.low_processor_usage_mode, ' sleep=', OS.low_processor_usage_mode_sleep_usec)
	OS.low_processor_usage_mode_sleep_usec = 0
	root.get_node("TimeManager").minutes = 12 * 60.0
	await spot("деревня", Vector3(-110, 0.2, -40))
	await spot("центр города", Town.w(Vector3(97, 0.2, 40)))
	await spot("трасса", Vector3(300, 0.2, 2))
	quit()
