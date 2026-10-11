extends SceneTree
## Снимки «Изара 525» по ракурсам чертежа: спереди и сзади в три четверти,
## сбоку, прямо спереди и сзади, сверху (люк, обогрев заднего стекла), салон
## от водителя, за рулём и сзади на трассе.
var W
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func _run() -> void:
	for i in 10: await process_frame
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var hud = child("hud.gd"); if hud: hud.visible = false
	var TM = root.get_node("TimeManager")
	TM.minutes = 12.0 * 60.0
	root.get_node("WeatherManager").set_kind(0, 99999.0)
	var v: Vehicle = W.get_node("Izar")
	var cam := Camera3D.new(); cam.far = 300.0; cam.fov = 32.0
	W.add_child(cam)
	cam.current = true
	var xf: Transform3D = v.global_transform
	var views := [["front34", Vector3(-4.2, 1.7, -5.6), Vector3(0, 0.7, -0.3)], ["rear34", Vector3(4.0, 1.7, 5.8), Vector3(0, 0.7, 0.3)],
		["side", Vector3(-8.5, 1.0, 0.0), Vector3(0, 0.7, 0.0)], ["front", Vector3(0, 1.0, -8.0), Vector3(0, 0.7, 0)],
		["rear", Vector3(0, 1.0, 8.0), Vector3(0, 0.7, 0)], ["wheel", Vector3(-1.8, 0.5, -1.9), Vector3(-0.7, 0.32, -1.52)]]
	for vw in views:
		cam.global_position = xf * (vw[1] as Vector3)
		cam.look_at(xf * (vw[2] as Vector3))
		W._update_daylight()
		for i in 8: await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/izar_%s.png" % [OS.get_environment("SHOTS"), vw[0]])
	# Салон: глазами водителя
	cam.fov = 70.0
	cam.global_position = xf * (v.spec.seat as Vector3)
	cam.look_at(xf * ((v.spec.seat as Vector3) + Vector3(0.1, -0.25, -1.0)))
	v._gauge_holders.map(func(g): g.visible = true)
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/izar_cabin.png" % OS.get_environment("SHOTS"))
	# Сверху — как на чертеже (люк, обогрев заднего стекла); купленная — без
	# надписи «Продаётся»
	var PR = root.get_node("Progress")
	PR.buy_car("bmw"); PR.add_category("B"); PR.license = true
	cam.fov = 32.0
	cam.global_position = xf * Vector3(0.0, 14.0, 0.01)
	cam.look_at(xf * Vector3(0, 0.7, 0), xf.basis * Vector3.FORWARD)
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/izar_top.png" % OS.get_environment("SHOTS"))
	# За рулём на трассе: приборы видно сквозь руль; потом вид сзади
	if hud: hud.visible = true
	cam.current = false
	for sc in ["traffic.gd", "chase.gd", "police.gd", "gai_post.gd"]:
		var n = child(sc)
		if n: n.queue_free()
	v.global_position = Vector3(-150, 0.1, 2.0); v.rotation.y = -PI / 2.0
	v._on_enter()
	v.engine_on = true
	for shot in ["drive", "chase"]:
		Vehicle.chase_view = shot == "chase"
		v._active_camera().current = true
		for i in 40:
			v.speed = 33.0
			await physics_frame
		W._update_daylight()
		root.get_viewport().get_texture().get_image().save_png("%s/izar_%s.png" % [OS.get_environment("SHOTS"), shot])
	print("готово")
	quit()
