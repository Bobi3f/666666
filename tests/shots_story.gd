extends SceneTree
## Снимки новых глав: урок в бурсе, горожане и житель села с просьбой.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(name: String) -> void:
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func shot(name: String, at: Vector3, look: Vector3) -> void:
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
	await save(name)
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var TM = root.get_node("TimeManager"); var PR = root.get_node("Progress"); var QM = root.get_node("QuestManager")
	TM.day = 3; TM.minutes = 11 * 60.0
	var P = W.get_node("Player")
	cam = Camera3D.new(); cam.far = 700.0; W.add_child(cam)
	# Горожане
	var east = W.get_node("TownEast")
	var sto := Town.w(Vector3(east.STO.end.x + 2.2, 0, east.STO.position.y + 8.0))
	await shot("story_nikolaich", sto + Vector3(4.0, 1.7, 2.5), sto + Vector3(0, 1.1, 0))
	var zoya := Town.w(Vector3(88.5, 0, 137.5))
	await shot("story_zoya", zoya + Vector3(4.0, 1.8, -2.0), zoya + Vector3(0, 1.1, 1.0))
	# Житель села у магазина
	var region = W.get_node("Region")
	var v0: Node3D = region.get_node("Villager_0")
	var vp := v0.global_position
	await shot("story_villager", vp + Vector3(2.5, 1.6, 3.5), vp + Vector3(0, 1.1, 0))
	cam.current = false
	P.global_position = vp + Vector3(0, 0.1, 1.5)
	for i in 10: await physics_frame
	await save("story_villager_prompt")
	# Урок в бурсе
	cam.current = false
	TM.minutes = 10 * 60.0
	PR.home_items.erase("mechanic")
	root.get_node("GameManager").money = 1000
	east.take_course()
	await save("story_lesson")
	east.lesson_panel.visible = false
	root.paused = false
	quit()
