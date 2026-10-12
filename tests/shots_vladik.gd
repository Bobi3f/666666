extends SceneTree
## Гараж Дяди Владика: снаружи с трассы, внутри, Владик за работой, вблизи,
## окно разговора и двор с битой «копейкой».
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func shot(n: String, at: Vector3, look: Vector3) -> void:
	cam.make_current(); cam.global_position = at; cam.look_at(look)
	await save(n)
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 11 * 60.0
	var P = W.get_node("Player")
	P.global_position = VladikGarage.w(Vector3(0, 0.3, 14))
	cam = Camera3D.new(); cam.fov = 60; W.add_child(cam)
	var vl: Vladik = W.get_node("Vladik")
	await shot("vg_outside", VladikGarage.w(Vector3(-4, 3.0, 13)), VladikGarage.w(Vector3(0, 1.2, 0)))
	await shot("vg_yard", VladikGarage.w(Vector3(3, 2.6, 9)), VladikGarage.w(Vector3(7, 0.5, 2)))
	await shot("vg_inside", VladikGarage.w(Vector3(1.0, 1.9, 3.8)), VladikGarage.w(Vector3(-1.0, 0.8, -2.5)))
	# Владик за верстаком, у мотора, на табурете
	for st in [["bench", Vladik.State.WORK_AT_BENCH], ["engine", Vladik.State.REPAIR], ["chair", Vladik.State.SIT]]:
		var sp: Array = VladikGarage.SPOTS[st[0]]
		vl._body.position = sp[0]; vl._body.rotation.y = sp[1]
		vl._set_state(st[1]); vl._timer = 100.0
		for i in 20: await process_frame
		var at: Vector3 = sp[0] + Basis(Vector3.UP, sp[1]) * Vector3(1.7, 1.5, -0.9)
		await shot("vg_" + st[0], VladikGarage.w(at), VladikGarage.w(sp[0] + Vector3(0, 0.9, 0)))
	# Игрок подошёл — смотрит на него
	vl._body.position = VladikGarage.SPOTS.bench[0]
	vl._set_state(Vladik.State.IDLE)
	P.global_position = VladikGarage.w(VladikGarage.SPOTS.bench[0] + Vector3(2.0, 0.1, 1.0))
	for i in 40: await process_frame
	var face: Vector3 = VladikGarage.w(VladikGarage.SPOTS.bench[0] + Vector3(1.6, 1.6, 1.0))
	await shot("vg_talk", face, VladikGarage.w(VladikGarage.SPOTS.bench[0] + Vector3(0, 1.45, 0)))
	vl.open_talk()
	await save("vg_panel")
	vl.panel.close_panel()
	quit()
