extends SceneTree
## Снимки работ: сено в телегу у колхозного сарая, мешки в грузовик у склада.
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
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 10 * 60.0
	var P = W.get_node("Player")
	cam = Camera3D.new(); cam.far = 700.0; W.add_child(cam)
	var K = W.kolkhoz_job
	K.start()
	for i in 3: K.pick(); K.put_down()
	P.global_position = K.pickup + Vector3(0, 0.1, 1.5)
	K.pick()
	for i in 5: await process_frame
	await view("job_hay", K.pickup + Vector3(-7, 3.5, 5), K.pickup + Vector3(-2, 0.8, 5))
	K.stop()
	var S = W.warehouse_job
	S.start()
	for i in 4: S.pick(); S.put_down()
	P.global_position = S.drop + Vector3(0.5, 0.1, 1.2)
	S.pick()
	for i in 5: await process_frame
	await view("job_sacks", S.drop + Vector3(5, 3.5, 6), S.drop + Vector3(-3, 0.8, 0))
	quit()
