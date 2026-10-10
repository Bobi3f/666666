extends SceneTree
## Снимки базара: общий вид, ряд с овощами и фруктами, мясо и мёд, квас,
## окно лавки с торгом.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func shot(name: String, at: Vector3, look: Vector3) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), name])
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	if OS.get_environment("LANG_CODE") != "":
		root.get_node("SettingsManager").set_lang(OS.get_environment("LANG_CODE"))
	var TM = root.get_node("TimeManager")
	TM.day = 2; TM.minutes = 11 * 60.0
	var S = W.get_node("TownSouth")
	var o: Vector3 = S.global_position
	var r: Rect2 = S.MARKET
	root.get_node("GameManager").player.global_position = o + Vector3(r.get_center().x, 1, r.get_center().y)
	var B = S.bazaar
	B._tick = 0.0
	for i in 20: B._process(0.2)
	B._shout.text = "Помидорчики свежие, сладкие!"
	B._shout.position = B.sellers[0].position + Vector3(0, 2.05, 0)
	B._shout.visible = true
	B._shout_t = 100.0
	B.set_process(false)
	cam = Camera3D.new(); cam.far = 700.0; cam.fov = 60; W.add_child(cam)
	cam.make_current()
	var y0 := r.position.y
	await shot("bazaar_overview", o + Vector3(r.end.x - 2, 5.5, y0 + 2), o + Vector3(r.position.x + 15, 0.5, y0 + 16))
	await shot("bazaar_veg", o + Vector3(r.position.x + 7.5, 1.9, y0 + 5.2), o + Vector3(r.position.x + 5.5, 1.0, y0 + 8.6))
	await shot("bazaar_fruit", o + Vector3(r.position.x + 21.5, 1.9, y0 + 5.0), o + Vector3(r.position.x + 19.5, 0.8, y0 + 8.6))
	await shot("bazaar_meat", o + Vector3(r.position.x + 7.5, 1.9, y0 + 19.2), o + Vector3(r.position.x + 5.5, 1.2, y0 + 22.6))
	await shot("bazaar_honey", o + Vector3(r.position.x + 39.0, 1.9, y0 + 19.2), o + Vector3(r.position.x + 35.5, 1.3, y0 + 22.6))
	await shot("bazaar_dairy", o + Vector3(r.position.x + 35.5, 1.9, y0 + 5.2), o + Vector3(r.position.x + 33.5, 1.0, y0 + 8.6))
	await shot("bazaar_kvass", o + Vector3(r.end.x - 7.5, 1.8, y0 + 5.5), o + Vector3(r.end.x - 3.5, 0.9, y0 + 10.0))
	S.open_food("fruit")
	S.bazaar.haggle("fruit", 0.1)
	S.market_panel._status.text = "«Ладно, для тебя — уступлю!» Сегодня здесь на 20% дешевле"
	S.market_panel._refresh()
	for i in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/bazaar_panel.png" % OS.get_environment("SHOTS"))
	quit()
