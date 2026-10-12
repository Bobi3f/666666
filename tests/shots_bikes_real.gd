extends SceneTree
## Мотоциклы крупно: «Ява», ИЖ, «Карпаты» — сбоку, спереди-сбоку, сзади, вблизи (круглые шины, бак-капля, седло, цепь).
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 560)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 12 * 60.0
	cam = Camera3D.new(); cam.fov = 45; W.add_child(cam); cam.make_current()
	var bikes := {}
	for v in W.find_children("*", "Vehicle", true, false):
		if v.kind in ["moped", "moto", "izh"] and not bikes.has(v.kind): bikes[v.kind] = v
	var spot := Vector3(-60, 0.1, 60)
	for k in bikes:
		var v: Vehicle = bikes[k]
		v.global_position = spot
		v.rotation = Vector3.ZERO
		W.get_node("Player").global_position = spot + Vector3(0, 0, 40)
		for i in 10: await physics_frame
		var c := v.global_position + Vector3(0, 0.7, 0)
		for view in [["side", Vector3(2.6, 0.9, 0)], ["front", Vector3(1.6, 1.1, -2.0)], ["rear", Vector3(-1.5, 1.2, 2.2)], ["close", Vector3(1.1, 1.0, -0.3)]]:
			cam.global_position = c + view[1]
			cam.look_at(c)
			await save("bike_%s_%s" % [k, view[0]])
		spot.x += 12.0
	quit()
