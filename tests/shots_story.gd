extends SceneTree
## Снимки новых глав: лавка «К свадьбе» на рынке, столик в «Метелице»,
## ЗАГС в сельсовете, жена во дворе, урок в бурсе, горожане и житель села
## с просьбой, предложение в разговоре с Олей.
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
	var G = W.get_tree().get_first_node_in_group("girl")
	var P = W.get_node("Player")
	cam = Camera3D.new(); cam.far = 700.0; W.add_child(cam)
	# Лавка «К свадьбе»: k = 7 — второй ряд, третья лавка
	var st := Town.w(Vector3(62.5, 0, 150.0))
	await shot("story_wedding_stall", st + Vector3(-2.5, 1.9, -4.5), st + Vector3(0, 1.3, 0.8))
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
	# Столик в «Метелице» с Олей
	TM.minutes = 21.5 * 60.0
	G.rel = 80
	var club = W.get_node("ClubTown")
	club._paid_day = club._night()
	var table: Node3D = W.find_child("DateTable", true, false)
	G.invite()
	P.global_position = table.global_position + Vector3(-1.0, 0.1, 0.3)
	G.doll.global_position = table.global_position + Vector3(-1.2, 0, -1.0)
	for i in 10: await physics_frame
	await save("story_table_prompt")
	var tp := table.global_position
	await shot("story_table", tp + Vector3(-3.0, 2.0, 0.8), tp + Vector3(0, 0.6, 0))
	G.send_home()
	# Предложение в разговоре
	TM.minutes = 15 * 60.0
	PR.add_item("ring")
	G.doll.global_position = G.HOME
	P.global_position = G.HOME + Vector3(0, 0.1, -1.5)
	for i in 10: await physics_frame
	cam.current = false
	G.open_talk()
	await save("story_propose")
	G.panel._say(G.propose())
	await save("story_propose_yes")
	G.panel.close_panel()
	# ЗАГС в сельсовете
	TM.minutes = 11 * 60.0
	while TM.weekday() == "вс": TM.day += 1
	PR.add_item("dress")
	var zags: Node3D = W.find_child("ZagsZone", true, false)
	G.invite()
	P.global_position = zags.global_position + Vector3(0, 0.1, 1.0)
	G.doll.global_position = zags.global_position + Vector3(1.0, 0, 1.2)
	for i in 10: await physics_frame
	await save("story_zags_prompt")
	W.get_node("Civic").wedding()
	for i in 5: await physics_frame
	await save("story_wedding_done")
	G.send_home()
	# Жена во дворе
	TM.minutes = 14 * 60.0
	G._spot = ""
	for i in 5: await process_frame
	var g: Vector3 = G.doll.global_position
	await shot("story_wife_yard", g + Vector3(3.0, 1.8, 4.5), g + Vector3(0, 1.0, 0))
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
