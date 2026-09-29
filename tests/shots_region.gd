extends SceneTree
## Снимки района: сёла, мосты через реку, озеро, карта района. SHOTS — папка.
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
	var map
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c.get_script() and c.get_script().resource_path.ends_with("map.gd"): map = c
		if c is CanvasLayer: c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 11 * 60.0
	var P = W.get_node("Player"); P.set_physics_process(false)
	cam = Camera3D.new(); cam.far = 700.0; W.add_child(cam)
	var v0: Vector2 = Region.VILLAGES[0].c
	P.global_position = Vector3(v0.x, 0.1, v0.y)
	await view("01_village", Vector3(v0.x + 70, 6, v0.y + 6), Vector3(v0.x, 1.5, v0.y - 4))
	await view("02_bridge_highway", Vector3(275, 7, 22), Vector3(315, 0, 0))
	var br: Vector2 = Vector2.ZERO
	for b in W.region._bridges:
		if absf((b[0] as Vector2).y) > 50.0: br = b[0]
	await view("03_bridge_wood", Vector3(br.x - 22, 5, br.y + 16), Vector3(br.x, 0, br.y))
	await view("04_lake", Vector3(Region.LAKE.x + 55, 8, Region.LAKE.y + 20), Vector3(Region.LAKE.x, 0, Region.LAKE.y))
	var v3: Vector2 = Region.VILLAGES[3].c
	await view("05_zarechye", Vector3(v3.x - 90, 25, v3.y - 60), Vector3(v3.x, 0, v3.y))
	await view("06_air", Vector3(-150, 120, 150), Vector3(-380, 0, 300))
	# Карта района и мини-карта у села
	map.visible = true
	root.size = Vector2i(1280, 720)
	cam.clear_current()
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/07_minimap.png")
	map.mode = 2; map._canvas.visible = true
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/08_map_region.png")
	map.mode = 1
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/09_map_local.png")
	quit()
