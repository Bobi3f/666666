extends SceneTree
## Снимки работ «по точкам»: подсветка взаимодействия, стрелка-навигатор, почта и посылки,
## попутчик на мопеде, заправщик на АЗС, колонка с водой (экран телефона).
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func view(name: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	for i in 20: await process_frame
	shot(name)
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var TM = root.get_node("TimeManager")
	TM.minutes = 10 * 60.0
	var P = W.get_node("Player")
	var M = W.get_node("Moped")
	# С HUD: игрок у почты, подсказка и кольцо
	P.global_position = W.POST_POS + Vector3(0.6, 0.1, 3.0)
	P.rotation.y = 0.0
	for i in 30: await physics_frame
	for i in 10: await process_frame
	shot("job_post_hud")
	# Взял посылки — навигатор
	W.post_job.start()
	for i in 20: await process_frame
	shot("job_post_nav")
	# Без HUD — вид сверху на столб света у первой точки
	for c in W.get_children():
		if c is CanvasLayer: c.visible = false
	cam = Camera3D.new(); W.add_child(cam)
	var p0: Vector3 = W.post_job.stops[0][1]
	await view("job_beacon", p0 + Vector3(-18, 9, 18), p0 + Vector3(0, 3, 0))
	W.post_job.cancel()
	# Попутчик на мопеде
	P.global_position = W.HITCH_POS + Vector3(0, 0.1, 0.5)
	await view("job_hitcher", W.HITCH_POS + Vector3(-5, 2.2, -5), W.HITCH_POS + Vector3(0.6, 1.0, 0))
	W.hitch_job.start()
	M.global_position = W.HITCH_POS + Vector3(2, 0.1, 0)
	M.rotation.y = -PI / 2.0
	M._on_enter()
	for i in 10: await process_frame
	var mp: Vector3 = M.global_position
	await view("job_hitch_ride", mp + Vector3(1.5, 1.6, 3.2), mp + Vector3(0, 0.9, 0))
	M.exit_car()
	W.hitch_job.cancel()
	# Заправщик
	P.global_position = W.pump_job.giver + Vector3(0, 0.1, 0)
	W.pump_job.start()
	for i in 5: await process_frame
	await view("job_pump", W.FUEL_POS + Vector3(-10, 4, -9), W.FUEL_POS + Vector3(0, 1, -2))
	W.pump_job.cancel()
	await view("water_pump", W.PUMP_POS + Vector3(-3, 1.8, 3), W.PUMP_POS + Vector3(0, 0.8, 0))
	quit()
