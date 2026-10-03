extends SceneTree
## Снимки: автошкола на новом месте (к югу от трассы) — дом, автодром,
## учебные машины; класс внутри — парты, доска, инструктор, стенд категорий.
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
	var TM = root.get_node("TimeManager")
	TM.day = 2; TM.minutes = 12 * 60.0
	cam = Camera3D.new(); cam.far = 700.0; W.add_child(cam)
	cam.make_current()
	var h: Vector3 = AutoSchool.HOUSE
	await shot("autoschool_top", Vector3(-20, 45, -14), Vector3(-22, 0, 30))
	await shot("autoschool_front", h + Vector3(-6, 3, -13), h + Vector3(0, 1.5, 0))
	var xf: Transform3D = AutoSchool.xf()
	await shot("autoschool_class", xf * Vector3(3.8, 2.3, 3.2), xf * Vector3(-2.0, 0.8, -3.0))
	await shot("autoschool_board", xf * Vector3(-0.5, 2.0, 1.5), xf * Vector3(2.7, 1.6, -3.5))
	var SC: Vehicle = W.get_node("AutoSchool").car
	var cp := SC.global_position
	await shot("autoschool_car", cp + Vector3(-3.6, 1.6, -3.4), cp + Vector3(0, 0.8, 0.2))
	await shot("autoschool_car_side", cp + Vector3(4.2, 1.3, 1.0), cp + Vector3(0, 0.7, 0.3))
	var PR = root.get_node("Progress")
	TM.day = 5
	PR.add_category("B")
	TM.day = 9
	PR.add_category("A")
	var card: LicenseCard = W.get_node("LicenseCard")
	card.open()
	for i in 6: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/autoschool_license.png" % OS.get_environment("SHOTS"))
	quit()
