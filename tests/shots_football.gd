extends SceneTree
## Снимки: футбол во дворе школы и физрук, дети во дворе.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var TM = root.get_node("TimeManager")
	TM.day = 2; TM.minutes = 11 * 60.0
	var S = W.get_node("TownSouth/School")
	var F = S.football
	var P = W.get_node("Player")
	var c := Vector3(F.field.get_center().x, 0, F.field.get_center().y)
	F.start(false)
	P.global_position = c + Vector3(-2.0, 0.1, 1.0)
	P.rotation.y = -PI / 2.0
	for i in 70: await physics_frame
	F.ball.global_position = P.global_position + Vector3(0.7, 0.2, 0)
	F.kick()
	for i in 12: await physics_frame
	cam = Camera3D.new(); cam.far = 700.0; W.add_child(cam)
	cam.global_position = c + Vector3(-1.0, 4.5, 11.0)
	cam.look_at(c + Vector3(1.5, 0.5, 0))
	cam.make_current()
	for i in 6: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/football.png" % OS.get_environment("SHOTS"))
	quit()
