extends SceneTree
## Снимки: редактор кнопок на телефоне — пешком и в машине (руль сдвинут).
var W
func _initialize() -> void:
	root.size = Vector2i(900, 420)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func snap(n: String) -> void:
	for i in 6: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_environment("SHOTS"), n])
func _run() -> void:
	for i in 10: await process_frame
	var tc = null
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c.get_script() and c.get_script().resource_path.ends_with("touch_controls.gd"): tc = c
	root.get_node("SettingsManager").set_touch_layout({})
	for i in 5: await process_frame
	tc.start_edit()
	tc._sel = "Прыжок|walk"
	tc.move_selected(Vector2(620, 260))
	tc.resize_selected(0.3)
	tc._update_edit_label()
	await snap("layout_walk")
	tc._edit_mode_btn.pressed.emit()
	tc._sel = "wheel"
	tc.move_selected(Vector2(230, 300))
	tc.resize_selected(-0.2)
	tc._update_edit_label()
	await snap("layout_drive")
	tc.finish_edit(false)
	root.get_node("SettingsManager").set_touch_layout({})
	quit()
