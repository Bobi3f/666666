extends SceneTree
## Снимки: окошко ГАИ «номера» у милиции, окно выбора номера на низком
## экране телефона, мопед во дворе, Ява у соседа.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func shot(name: String) -> void:
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func view(name: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	await shot(name)
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 10 * 60.0
	root.get_node("GameManager").money = 1500
	root.get_node("Progress").buy_car("car")
	cam = Camera3D.new(); cam.far = 700.0; W.add_child(cam)
	var P = W.get_node("Player")
	var H := Vector3(W.PLAYER_HOUSE.x, 0, W.PLAYER_HOUSE.y)
	await view("yard_moped", H + Vector3(3.0, 2.6, 15.0), W.MOPED_SPOT + Vector3(0, 0.6, 0))
	await view("yard_moto", W.MOTO_SPOT + Vector3(4.0, 2.2, 7.0), W.MOTO_SPOT + Vector3(0, 0.6, 0))
	var pol = W.get_node("Police")
	P.global_position = pol.get_node("PlateDesk").global_position + Vector3(-1.0, 0.1, 0)
	P.rotation.y = -PI / 2.0
	await view("gai_desk", Town.w(Police.STATION) + Vector3(-15.0, 2.2, -5.0), Town.w(Police.STATION) + Vector3(-7.0, 1.5, -2.0))
	pol.open_plates()
	await shot("gai_panel")
	quit()
