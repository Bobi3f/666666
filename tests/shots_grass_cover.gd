extends SceneTree
## Снимки травы кусками вокруг камеры: у дома игрока, на лугу, в соседнем
## селе (камера перелетела — трава построилась вокруг неё).
var W
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
var cam: Camera3D
func view(n: String, from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.current = true
	W._update_daylight()
	# Трава подстраивается под камеру раз в 0,25 с — ждём секунду
	for i in 60: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 10: await process_frame
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var hud = child("hud.gd"); if hud: hud.visible = false
	var TM = root.get_node("TimeManager"); var WM = root.get_node("WeatherManager")
	WM.set_kind(0, 99999.0)
	root.get_node("SettingsManager").set_detail(int(OS.get_environment("DETAIL")) if OS.get_environment("DETAIL") != "" else 1)
	cam = Camera3D.new(); cam.far = 700.0
	W.add_child(cam)
	TM.minutes = 11 * 60.0
	await view("grass_yard", Vector3(-118, 1.7, -36), Vector3(-130, 0.5, -60))
	await view("grass_meadow", Vector3(-60, 1.7, 40), Vector3(-20, 0.3, 80))
	await view("grass_wheat", Vector3(20, 2.0, -110), Vector3(60, 0.5, -150))
	quit()
