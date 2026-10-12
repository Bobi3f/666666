extends SceneTree
## Человек (1,8 м) рядом с домами, машинами, автобусом, пятиэтажкой,
## магазином, деревом и забором — проверка пропорций.
var W
var cam: Camera3D
var V
func _initialize() -> void:
	root.size = Vector2i(1000, 560)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func man(p: Vector3, yaw := 0.0) -> void:
	var b := MeshBuilder.new(); b.ground_shade = false
	V.person_model(b, Color(0.9, 0.2, 0.2), Color(0.2, 0.2, 0.2), false, false)
	var mi := b.build_mesh(); mi.position = p; mi.rotation.y = yaw
	W.add_child(mi)
func shot(n: String, at: Vector3, look: Vector3) -> void:
	cam.make_current(); cam.global_position = at; cam.look_at(look)
	await save(n)
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 12 * 60.0
	V = load("res://scripts/world/villagers.gd")
	cam = Camera3D.new(); cam.far = 600; cam.fov = 60; W.add_child(cam)
	W.get_node("Player").global_position = Vector3(0, 0, 300)
	# Свой дом и соседский через улицу
	man(Vector3(-125, 0, -47)); man(Vector3(-100, 0, -33), PI)
	await shot("s_house", Vector3(-118, 1.6, -36), Vector3(-125, 2.0, -52))
	await shot("s_street", Vector3(-112, 1.6, -40), Vector3(-80, 2.0, -40))
	# Жигули у дома
	var car: Node3D = W.get_node("Car")
	man(car.global_position + Vector3(1.3, -0.1, 1.5))
	await shot("s_car", car.global_position + Vector3(6, 1.5, 4), car.global_position + Vector3(0, 0.8, 0))
	# Автобус автошколы
	var bus: Node3D = W.find_child("SchoolBus", true, false)
	bus.global_position = Vector3(30, 0.1, 300); bus.rotation = Vector3.ZERO
	for i in 20: await physics_frame
	man(bus.global_position + Vector3(1.8, -0.1, -1.0))
	await shot("s_bus", bus.global_position + Vector3(9, 1.6, 2), bus.global_position + Vector3(0, 1.4, 0))
	quit()
	return
	# Пятиэтажка, кафе, больница
	man(Town.w(Vector3(65, 0, 54))); man(Town.w(Vector3(92, 0, 18)))
	await shot("s_flats", Town.w(Vector3(60, 1.6, 66)), Town.w(Vector3(66, 6, 48)))
	await shot("s_shop", Town.w(Vector3(100, 1.6, 22)), Town.w(Vector3(88, 2, 17)))
	# Сельсовет и колхоз
	man(Civic.COUNCIL + Vector3(1.5, 0.4, 6.5))
	await shot("s_council", Civic.COUNCIL + Vector3(6, 1.6, 16), Civic.COUNCIL + Vector3(0, 2, 0))
	# Трактор, ГАЗ-53
	var tr: Node3D = W.find_child("Tractor", true, false)
	if tr:
		man(tr.global_position + Vector3(2.2, -0.1, 0))
		await shot("s_tractor", tr.global_position + Vector3(7, 1.6, 5), tr.global_position + Vector3(0, 1.2, 0))
	quit()
