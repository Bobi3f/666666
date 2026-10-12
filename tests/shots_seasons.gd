extends SceneTree
var W
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func snap(n: String) -> void:
	for i in 12: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
var cam: Camera3D
func view(n: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.current = true
	W._update_daylight()
	await snap(n)
func _run() -> void:
	for i in 10: await process_frame
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var hud = child("hud.gd"); if hud: hud.visible = false
	var TM = root.get_node("TimeManager"); var WM = root.get_node("WeatherManager")
	WM.set_kind(0, 99999.0)
	cam = Camera3D.new(); cam.far = 700.0
	W.add_child(cam)
	TM.minutes = 11 * 60.0
	var village_from := Vector3(-95, 7, -30)
	var village_at := Vector3(-125, 1, -48)
	await view("a_summer", village_from, village_at)
	TM.day = 8; WM._on_minutes(1500.0); TM.minutes = 11 * 60.0
	await view("b_autumn", village_from, village_at)
	TM.day = 15; WM._on_minutes(900.0); TM.minutes = 11 * 60.0
	await view("c_winter", village_from, village_at)
	WM.set_kind(3, 99999.0); WM.rain = 1.0; WM.cloud = 1.0
	await view("d_snowfall", Vector3(-110, 2.0, -40), Vector3(-125, 1.5, -52))
	WM.set_kind(0, 99999.0); WM.rain = 0.0; WM.cloud = 0.0
	TM.day = 29; WM._on_minutes(3000.0)
	TM.minutes = 23.5 * 60.0
	await view("e_night_sky", Vector3(-110, 2, -40), Vector3(-60, 40, -120))
	TM.minutes = 6.0 * 60.0
	await view("f_morning_mist", Vector3(20, 4, -40), Vector3(100, 0, -80))
	TM.minutes = 11 * 60.0
	var job = child("tractor_job.gd")
	await view("g_tractor", job.TRACTOR_POS + Vector3(6, 3, 5), job.TRACTOR_POS)
	var T = job.tractor
	T.global_position = Vector3(70, 0.1, -82); T.rotation.y = -PI / 2.0
	for i in 4: job._add_strip(i)
	await view("h_plough", Vector3(55, 6, -70), Vector3(75, 0, -85))
	TM.day = 7; TM.minutes = 11 * 60.0
	await process_frame
	await view("i_fair", Vector3(116, 3.5, 21), Vector3(106, 1, 21))
	await view("j_business", Vector3(-96, 3, 6), Vector3(-90, 1, 13))
	var C = W.get_node("Car")
	C.global_position = Vector3(-150, 0.1, 2.0); C.rotation.y = -PI / 2.0
	C._on_enter(); C.fuel = 30.0
	C.speed = 16.0
	for i in 30: await process_frame
	C.speed = 16.0
	await snap("k_cockpit")
	C.exit_car()
	T._on_enter()
	for i in 20: await process_frame
	await snap("l_tractor_cab")
	quit()
