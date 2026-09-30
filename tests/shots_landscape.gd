extends SceneTree
## Снимки пейзажа района: холмы, поля, лесополосы, кафе у трассы, АЗС,
## ремонт дороги. LVL — детализация.
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
	var SM = root.get_node("SettingsManager")
	SM.detail = int(OS.get_environment("LVL")) if OS.get_environment("LVL") != "" else 1
	SM.changed.emit()
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c is CanvasLayer: c.visible = false
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 10 * 60.0
	var P = W.get_node("Player"); P.set_physics_process(false); P.global_position = Vector3(0, 0.2, 90)
	cam = Camera3D.new(); W.add_child(cam)
	print("Холмов: %d, полей: %d, прудов: %d" % [Landscape.hills.size(), Landscape.fields.size(), Landscape.ponds.size()])
	await view("l1_road_east", Vector3(600, 1.8, 2.5), Vector3(1100, 0, 0))
	await view("l2_air", Vector3(-600, 90, 200), Vector3(-900, 0, -100))
	var h: Array = Landscape.hills[0]
	var hc: Vector2 = h[0]
	await view("l3_hill", Vector3(hc.x + h[1] * 1.6, 6, hc.y + h[1] * 0.6), Vector3(hc.x, h[2] * 0.5, hc.y))
	await view("l4_cafe", Roadside.CAFE + Vector3(14, 4, 22), Roadside.CAFE + Vector3(0, 2, 4))
	await view("l5_fuel", Roadside.FUEL2 + Vector3(-26, 4, 22), Roadside.FUEL2 + Vector3(-6, 2, 4))
	await view("l6_roadwork", Roadside.ROADWORK + Vector3(-14, 4, 22), Roadside.ROADWORK + Vector3(0, 1, 0))
	await view("l7_fields", Vector3(-380, 30, -150), Vector3(-500, 0, -300))
	quit()
