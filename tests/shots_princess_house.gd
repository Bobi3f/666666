extends SceneTree
## Дом Принцессы: фасад с улицы днём, арка над воротами, вечером на кухне за
## чаем, ночью — комната (собачки на лежанках, кот на кровати), трюмо.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func shot(name: String, at: Vector3, look: Vector3, n := 12) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in n: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 12: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c.get_script() and c.get_script().resource_path.ends_with("hud.gd"): c.visible = false
	var TM = root.get_node("TimeManager")
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	TM.minutes = 13 * 60.0
	var PR = W.princess
	var h: HouseInterior = PR.home
	var o: Vector3 = h.global_position
	var P: Node3D = root.get_node("GameManager").player
	P.global_position = o + Vector3(30, 0.1, 30)
	cam = Camera3D.new(); cam.fov = 55; cam.far = 700; W.add_child(cam); cam.make_current()
	# Днём: фасад с улицы и арка над воротами
	await shot("phouse_street", o + Vector3(-9.0, 2.6, 22.0), o + Vector3(0.0, 2.0, 2.0))
	await shot("phouse_gate", o + Vector3(h.entrance_offset + 1.5, 1.7, 17.5), o + Vector3(h.entrance_offset, 2.2, 12.0))
	await shot("phouse_yard", o + Vector3(-9.5, 2.2, 10.5), o + Vector3(6.5, 0.6, 7.0))
	# Вечер: она на кухне у стола, чай с вареньем
	TM.minutes = 21 * 60.0 + 40.0
	PR._snap(Princess.HOME)
	P.global_position = h.to_global(Vector3(h.entrance_offset, 0.05, 2.0))
	for i in 5: await process_frame
	await shot("phouse_tea", h.to_global(Vector3(-1.4, 1.55, 2.6)), h.to_global(Vector3(-2.4, 0.9, 0.6)))
	# Ночь: комната — лежанки, кот на кровати, трюмо и портрет
	TM.minutes = 1 * 60.0
	PR._snap(Princess.ASLEEP)
	P.global_position = h.to_global(Vector3(1.0, 0.05, 1.0))
	for i in 5: await process_frame
	await shot("phouse_night", h.to_global(Vector3(0.6, 1.6, 2.4)), h.to_global(Vector3(3.2, 0.4, -1.0)))
	await shot("phouse_mirror", h.to_global(Vector3(0.9, 1.5, 0.6)), h.to_global(Vector3(-0.1, 1.3, 2.9)))
	quit()
