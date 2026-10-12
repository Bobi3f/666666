extends SceneTree
## Снимки трафика: все модели попуток рядом, трасса с машинами, автобус
## на остановке, районный автобус на грунтовке.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func view(name: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c is CanvasLayer: c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 11 * 60.0
	var P = W.get_node("Player"); P.set_physics_process(false); P.global_position = Vector3(-600, 0.2, 60)
	cam = Camera3D.new(); W.add_child(cam)
	var TR
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("traffic.gd"): TR = c
	TR.set_physics_process(false)
	# Выставка: по одной машине каждого вида в ряд на трассе
	var seen := {}
	var x := -640.0
	for v in TR._vehicles:
		if seen.has(v.kind): continue
		seen[v.kind] = true
		TR._place(v.body, x, 1)
		x += float(v.len) + 3.0
	await view("traffic_lineup", Vector3(-640 + (x + 640) * 0.5 - 10, 5, 22), Vector3(-640 + (x + 640) * 0.5 - 10, 1, 2))
	await view("traffic_lineup_front", Vector3(x + 8, 3, 8), Vector3(-640, 1, 2))
	TR.set_physics_process(true)
	for i in 120: await physics_frame
	# Автобус на остановке у Каменки
	var bus: Dictionary
	for v in TR._vehicles:
		if v.bus and v.dir == -1: bus = v
	TR.set_physics_process(false)
	TR._place(bus.body, -68.5, -1)
	await view("traffic_bus_stop", Vector3(-80, 4, -18), Vector3(-68, 1.5, -2))
	TR.set_physics_process(true)
	var RL = W.get_node("RuralLife")
	for m in RL.movers:
		if m.kind == "bus" and m.wait <= 0.0:
			var p: Vector3 = m.body.global_position
			cam.global_position = p + Vector3(12, 5, 12)
			cam.make_current()
			for i in 3: await process_frame
			p = m.body.global_position
			await view("traffic_district_bus", p + Vector3(12, 5, 12), p + Vector3(0, 1.5, 0))
			break
	quit()
