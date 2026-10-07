extends SceneTree
## Дядя Владик: все позы в ряд — спереди, сбоку и сзади; и в рабочей куртке.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
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
	for c in W.find_children("*", "CanvasLayer", true, false): c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 12 * 60.0
	var base := Vector3(-60, 0, 60)
	W.get_node("Player").global_position = base + Vector3(0, 0.3, 30)
	var x := 0.0
	for outfit in ["summer", "work"]:
		for pose in VladikModel.POSES:
			var b := MeshBuilder.new()
			b.ground_shade = false
			VladikModel.build(b, pose, outfit)
			var mi := b.build_mesh()
			mi.remove_from_group("people")
			W.add_child(mi)
			mi.global_position = base + Vector3(x, 0, 0)
			var pts := VladikModel.tool_arm_points(pose)
			if not pts.is_empty():
				var ab := MeshBuilder.new()
				VladikModel.tool_arm(ab, pts.hand - pts.elbow, outfit)
				var am := ab.build_mesh()
				W.add_child(am)
				am.global_position = mi.global_position + pts.elbow
			x += 1.1
		x += 1.0
	cam = Camera3D.new(); cam.fov = 40; W.add_child(cam); cam.make_current()
	cam.global_position = base + Vector3(2.75, 1.3, -7.5); cam.look_at(base + Vector3(2.75, 0.9, 0))
	await save("vladik_front")
	cam.global_position = base + Vector3(0.3, 1.55, -1.4); cam.look_at(base + Vector3(0, 1.55, 0))
	await save("vladik_face")
	cam.global_position = base + Vector3(-2.2, 1.0, 0.3); cam.look_at(base + Vector3(0, 0.9, 0))
	await save("vladik_side")
	cam.global_position = base + Vector3(2.75, 1.3, 7.5); cam.look_at(base + Vector3(2.75, 0.9, 0))
	await save("vladik_back")
	cam.global_position = base + Vector3(10.6, 1.3, -6.5); cam.look_at(base + Vector3(10.6, 0.9, 0))
	await save("vladik_work_outfit")
	quit()
