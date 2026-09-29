extends SceneTree
var W
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func snap(name: String) -> void:
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func child(e: String) -> Node:
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(e):
			return c
	return null
func _run() -> void:
	for i in 10: await process_frame
	var QM = root.get_node("QuestManager"); var TM = root.get_node("TimeManager")
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	child("pause_menu.gd")._close()
	TM.minutes = 10 * 60.0
	var P = W.get_node("Player")
	P.set_physics_process(false)
	# Трекер на улице у бабы Гали, взяты две просьбы
	QM.event("ate"); QM.event("map")
	for z in ["Почтальонка Оля", "Баба Галя"]:
		QM.talk(z)
	P.global_position = Vector3(-101.5, 0.1, -39.0)
	P.rotation.y = PI * 0.9
	var cam := Camera3D.new()
	W.add_child(cam)
	cam.global_position = Vector3(-96.5, 1.7, -39.5)
	cam.look_at(Vector3(-99, 1.2, -36.5))
	cam.make_current()
	await snap("01_tracker_letters")
	child("journal.gd")._open(false)
	await snap("02_journal")
	child("journal.gd")._close()
	for id in QM.MAIN:
		QM.quests[id].state = 2
	QM.stats.earned = 48210; QM.stats.km = 37.4; QM.stats.fish = 23; QM.stats.shifts = 19; QM.stats.quests = 12; QM.stats.deliveries = 6
	child("journal.gd")._open(true)
	await snap("03_victory")
	quit()
