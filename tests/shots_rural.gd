extends SceneTree
## Снимки жизни на просёлках: машины и телега на дорогах, стадо, комбайн.
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
	root.get_node("TimeManager").minutes = 10 * 60.0
	var P = W.get_node("Player"); P.set_physics_process(false); P.global_position = Vector3(0, 0.2, 90)
	cam = Camera3D.new(); W.add_child(cam)
	var RL = W.get_node("RuralLife")
	for kind in ["tractor", "cart", "moto", "niva", "truck"]:
		for m in RL.movers:
			if m.kind == kind:
				var p: Vector3 = m.body.global_position
				cam.global_position = p + Vector3(9, 4, 9)
				for i in 3: await process_frame
				p = m.body.global_position
				await view("rural_" + kind, p + Vector3(9, 4, 9), p + Vector3(0, 1, 0))
				break
	var h: Dictionary = RL.herds[0]
	var c: Vector2 = h.center
	await view("rural_herd", Vector3(c.x + 30, 7, c.y + 30), Vector3(c.x, 0.5, c.y))
	var cp: Vector3 = RL._combine.mesh.position
	await view("rural_combine", cp + Vector3(16, 8, 16), cp + Vector3(0, 1.5, 0))
	quit()
