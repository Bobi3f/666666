extends SceneTree
## Таблички вблизи: номер дома, название улицы, остановки, указатель —
## по-русски и по-английски.
var W
var cam: Camera3D
func _initialize() -> void:
	root.size = Vector2i(1000, 560)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func save(n: String) -> void:
	for i in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
## Встать перед надписью на dist метров и посмотреть на неё.
func look_at_label(n: String, text: String, dist: float, side := 0.0, skip := 0) -> void:
	for l in W.find_children("*", "Label3D", true, false):
		# skip > 0 — только крупные надписи (табличка на столбе, не у двери)
		if (l as Label3D).text == text and (skip == 0 or (l as Label3D).pixel_size > 0.002):
			var t := (l as Label3D).global_transform
			W.get_node("Player").global_position = t.origin + t.basis.z * 3.0 + Vector3(0, -1.5, 0)
			for i in 3: await physics_frame
			cam.make_current()
			cam.global_position = t.origin + t.basis.z * dist + t.basis.x * side + Vector3(0, 0.1, 0)
			cam.look_at(t.origin)
			await save(n)
			return
	print("нет надписи: ", text)
func _run() -> void:
	for i in 10: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 12 * 60.0
	cam = Camera3D.new(); cam.far = 600; cam.fov = 60; W.add_child(cam)
	for lang in ["ru", "en"]:
		root.get_node("SettingsManager").set_lang(lang)
		await look_at_label("sign_house_" + lang, "3", 2.2, 0.6)
		await look_at_label("sign_street_" + lang, "ул. Садовая", 4.0, 1.0, 1)
		await look_at_label("sign_stop_" + lang, "Каменка", 5.0, 1.0)
		await look_at_label("sign_turn_" + lang, "Озерцово, поворот", 6.0, 2.0)
		await look_at_label("sign_town_" + lang, "пр. Мира", 7.0, 2.5)
	root.get_node("SettingsManager").set_lang("ru")
	quit()
