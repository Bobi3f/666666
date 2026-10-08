extends SceneTree
## Картинка для магазина (Google Play — 1024×500): село Каменка летом,
## без интерфейса и мини-карты. Надпись кладёт tools/store_art.gd.
var W
func _initialize() -> void:
	root.size = Vector2i(1024, 500)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func _run() -> void:
	for i in 10: await process_frame
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	root.get_node("SettingsManager").set_minimap(false)
	for c in W.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	root.get_node("WeatherManager").set_kind(0, 99999.0)
	root.get_node("TimeManager").minutes = 10 * 60.0
	var cam := Camera3D.new(); cam.far = 700.0; cam.fov = 60.0
	W.add_child(cam)
	cam.global_position = Vector3(-95, 7, -30)
	cam.look_at(Vector3(-128, 1, -46))
	cam.current = true
	W._update_daylight()
	for i in 14: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
	quit()
