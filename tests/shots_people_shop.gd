extends SceneTree
## Люди смотрят на игрока (продавщица, бабки на лавочке) и меню сельмага.
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
	var P: Node3D = W.get_node("Player")
	cam = Camera3D.new(); cam.fov = 60; W.add_child(cam)
	var seller: MeshInstance3D
	var bd := INF
	for n in get_nodes_in_group("people"):
		var d: float = (n as Node3D).global_position.distance_to(W.SHOP_POS)
		if d < bd: bd = d; seller = n
	# Игрок у правого края прилавка, камера — у левого: продавщица
	# поворачивается к игроку, мимо камеры
	var zone: Node3D = W.find_child("ShopZone", true, false)
	var side: Vector3 = zone.global_transform.basis.x
	var spot: Vector3 = zone.global_position + side * 2.0
	for i in 60:
		P.global_position = spot
		await physics_frame
	cam.make_current()
	cam.global_position = zone.global_position - side * 1.5 + Vector3(0, 1.3, 0)
	cam.look_at(seller.global_position + Vector3(0, 1.45, 0))
	await save("ps_seller_looks")
	# Бабки на лавочке: игрок слева на улице
	spot = Vector3(-98.0, 0.1, -40.0)
	for i in 90:
		P.global_position = spot
		await physics_frame
	cam.global_position = Vector3(-101.5, 1.5, -40.5)
	cam.look_at(Vector3(-101.8, 1.0, -36.4))
	await save("ps_bench_looks")
	cam.current = false
	W.open_shop()
	await save("ps_shop_menu")
	quit()
