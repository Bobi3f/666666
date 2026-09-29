extends SceneTree
## Снимки клубов: сельский клуб снаружи вечером, танцпол изнутри, «Метелица».
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
	for i in 25: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c is CanvasLayer: c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var TM = root.get_node("TimeManager")
	TM.day = 5; TM.minutes = 20.5 * 60.0
	var P = W.get_node("Player"); P.set_physics_process(false)
	cam = Camera3D.new(); cam.far = 700.0; W.add_child(cam)
	var V = W.get_node("ClubVillage")
	P.global_position = V.center + Vector3(0, 0.1, 12)
	await view("club_village", V.center + Vector3(-9, 3, 16), V.center + Vector3(0, 2.5, 5))
	P.global_position = V.center + Vector3(0, 0.1, 3)
	await view("club_inside", V.center + Vector3(5.5, 2.4, 4.5), V.center + Vector3(-1, 0.8, -1.5))
	var T = W.get_node("ClubTown")
	TM.minutes = 22 * 60.0
	P.global_position = T.center + Vector3(0, 0.1, -12)
	await view("club_town", T.center + Vector3(14, 4, -22), T.center + Vector3(0, 3, -6))
	quit()
