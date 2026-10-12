extends SceneTree
## Снимки поворотников: каждая машина и мотоцикл с включённым левым
## поворотником — сзади и спереди. Лампа должна гореть на месте
## поворотника модели, а не висеть в воздухе.
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
	root.get_node("TimeManager").minutes = 18.5 * 60.0
	root.get_node("WeatherManager").set_kind(0, 99999.0)
	var cam := Camera3D.new(); cam.far = 300.0; cam.fov = 40.0
	W.add_child(cam)
	cam.current = true
	var only := OS.get_environment("KINDS")
	var seen := {}
	for v in W.find_children("*", "Vehicle", true, false):
		if seen.has(v.kind) or (only != "" and not only.split(",").has(v.kind)): continue
		seen[v.kind] = true
		v.set_turn(-1)
		v._turn_t = 0.0
		v._show_turn(true)
		var xf: Transform3D = v.global_transform
		var size: float = 2.2 if v.spec.get("two_wheels", false) else 5.5
		for side in [["rear", 1.0], ["front", -1.0]]:
			# Слева сзади (или спереди) и чуть сверху
			cam.global_position = xf * Vector3(-size * 0.55, size * 0.35, side[1] * size)
			cam.look_at(xf * Vector3(0, 0.6, 0))
			W._update_daylight()
			for i in 6: await process_frame
			v._turn_t = 0.0
			v._show_turn(true)
			await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/turn_%s_%s.png" % [OS.get_environment("SHOTS"), v.kind, side[0]])
		v.set_turn(0)
	print("сняты: ", seen.keys())
	quit()
