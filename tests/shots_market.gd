extends SceneTree
## Снимки: базар с забором, лавка запчастей, машина и мопед с запчастями,
## вещи с базара дома, спидометр с подсветкой.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func shot(name: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var TM = root.get_node("TimeManager"); var PR = root.get_node("Progress")
	TM.day = 2; TM.minutes = 11 * 60.0
	var S = W.get_node("TownSouth")
	var r: Rect2 = S.MARKET
	for id in ["rug", "tape", "fridge", "chair", "tv"]: PR.add_item(id)
	PR.buy_car("car")
	var C: Vehicle = W.get_node("Car")
	var M: Vehicle = W.get_node("Moped")
	for p in ["exhaust", "wheels", "rims", "rims", "rims", "speedo"]: C.fit_part(p)
	for p in ["exhaust", "wheels", "rims", "rims"]: M.fit_part(p)
	var hud = null
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("hud.gd"): hud = c
	cam = Camera3D.new(); cam.far = 700.0; W.add_child(cam)
	cam.make_current()
	await shot("market_gate", Vector3(r.end.x + 14, 7, r.position.y + 2), Vector3(r.get_center().x + 6, 1, r.get_center().y))
	await shot("market_fence", Vector3(r.position.x - 6, 3.5, r.end.y + 6), Vector3(r.get_center().x, 1, r.get_center().y))
	var pz = null
	for c in S.get_children():
		if c is InteractZone and String(c.name).ends_with("parts"): pz = c; break
	await shot("market_parts", pz.global_position + Vector3(-1.5, 1.7, -3.2), pz.global_position + Vector3(0, 1.0, 1.2))
	C.global_position = Vector3(r.end.x + 6, 0.3, r.position.y + 25)
	C.rotation.y = 0.0
	M.global_position = Vector3(r.end.x + 8.5, 0.3, r.position.y + 25)
	M.rotation.y = 0.0
	for i in 30: await physics_frame
	await shot("market_car", C.global_position + Vector3(-3.5, 1.4, 5.0), C.global_position + Vector3(1.0, 0.5, 0))
	var HI = W.get_node("HomeItems")
	var h = HI._house()
	var rr: Rect2 = h._room_rect()
	var xf: Transform3D = h.global_transform
	await shot("market_home", xf * Vector3(rr.end.x - 0.4, 1.9, rr.end.y - 0.4), xf * Vector3(rr.position.x + 0.8, 0.4, rr.position.y + 0.8))
	var k: Rect2 = h._kitchen_rect()
	await shot("market_fridge", xf * Vector3(k.position.x + 0.6, 1.7, k.end.y - 0.5), xf * Vector3(k.end.x - 0.4, 0.8, k.position.y + 0.3))
	# Спидометр с подсветкой — за рулём, вид сзади
	C._on_enter()
	C.engine_on = true
	C.speed = 15.0
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/market_speedo.png" % OS.get_environment("SHOTS"))
	quit()
