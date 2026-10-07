extends SceneTree
## Работа без перемотки часов: на экране «Дою коров — ещё N мин»;
## в настройках — «Ход времени».
var W
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func child(end: String) -> Node:
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(end): return c
	return null
func _run() -> void:
	for i in 10: await process_frame
	var menu = child("pause_menu.gd")
	menu._close()
	var tut = child("tutorial.gd")
	if tut: tut._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	var TM = root.get_node("TimeManager")
	TM.minutes = 10 * 60.0
	TM.work(45.0, "Дою коров")
	for i in 60: await process_frame
	child("hud.gd")._slow_update()
	await save("work_hud")
	TM.finish_work()
	menu._open(true)
	menu._show("settings")
	for i in 5: await process_frame
	for l in menu.find_children("*", "Label", true, false):
		if (l as Label).text == "Ход времени":
			var sc := l.get_parent()
			while sc and not sc is ScrollContainer: sc = sc.get_parent()
			if sc: (sc as ScrollContainer).scroll_vertical += 200
	await save("work_settings")
	quit()
