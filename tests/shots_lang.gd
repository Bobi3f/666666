extends SceneTree
## Снимки английской версии: главное меню, игра с заданием, журнал, карта,
## настройки, разговор с Олей, лавка на базаре.
var W
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func _run() -> void:
	for i in 10: await process_frame
	var SM = root.get_node("SettingsManager")
	var lang0: String = SM.lang
	SM.set_lang("en")
	var menu = child("pause_menu.gd")
	menu._open(true)
	await save("lang_menu")
	menu._show("settings")
	await save("lang_settings")
	menu._close()
	child("tutorial.gd")._finish()
	root.get_node("TimeManager").minutes = 10 * 60.0
	await save("lang_hud")
	var P = W.get_node("Player")
	var G = W.get_tree().get_first_node_in_group("girl")
	P.global_position = G.doll.global_position + Vector3(0, 0.1, -1.5)
	for i in 10: await physics_frame
	await save("lang_girl_prompt")
	G.open_talk()
	await save("lang_girl")
	G.panel.close_panel()
	var j = child("journal.gd")
	j._open(false)
	await save("lang_journal")
	j._close()
	var map = child("map.gd")
	map.mode = 1
	map._canvas.visible = true
	await save("lang_map")
	SM.set_lang(lang0)
	quit()
