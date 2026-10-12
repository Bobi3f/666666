extends SceneTree
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var SM = root.get_node("SaveManager"); var ST = root.get_node("SettingsManager")
	var TM = root.get_node("TimeManager")
	var menu = child("pause_menu.gd")
	menu._close()
	var tc = child("touch_controls.gd")
	ST.set_slot(1); ST.set_text_scale(1.0); ST.set_left_hand(false)

	print("== Ячейки сохранения")
	for s in [2, 3]:
		if FileAccess.file_exists(SM.path_for(s)): DirAccess.remove_absolute(SM.path_for(s))
	GM.money = 1111; TM.day = 3
	ST.set_slot(1); SM.save_game(true)
	ST.set_slot(2)
	ok(not SM.has_save() and SM.slot_info(2) == "пусто", "ячейка 2 пустая")
	GM.money = 2222; TM.day = 9
	SM.save_game(true)
	ok(SM.has_save() and SM.slot_info(2) == "день 9, 2222 грн" and SM.slot_info(1) == "день 3, 1111 грн", "две игры: " + SM.slot_info(1) + " / " + SM.slot_info(2))
	ST.set_slot(1); SM.load_game()
	ok(GM.money == 1111 and TM.day == 3, "загрузил ячейку 1")
	ST.set_slot(2); SM.load_game()
	ok(GM.money == 2222 and TM.day == 9, "загрузил ячейку 2")
	menu._refresh()
	ok(menu._slot_buttons.size() == 3 and menu._slot_buttons[1].text.contains("2222") and menu._slot_buttons[1].button_pressed, "в меню ячейки: " + menu._slot_buttons[1].text)
	ST.set_slot(1)

	print("== Размер текста")
	var win := root.get_window()
	var k0: float = win.content_scale_factor
	ST.set_text_scale(1.4)
	await process_frame
	ok(absf(win.content_scale_factor - k0 * 1.4) < 0.01, "крупный текст: %.2f → %.2f" % [k0, win.content_scale_factor])
	ST.set_text_scale(1.0)
	await process_frame
	ok(absf(win.content_scale_factor - k0) < 0.01, "обычный — обратно")

	print("== Под левую руку")
	if tc:
		var w: float = root.get_viewport().get_visible_rect().size.x
		ok(tc._stick_center.x < w * 0.5, "обычно джойстик слева")
		ST.set_left_hand(true)
		await process_frame
		var gas := Vector2.ZERO
		for e in tc._buttons:
			if e.text == "Газ": gas = (e.rect as Rect2).get_center()
		ok(tc._stick_center.x > w * 0.5 and tc._wheel_center.x > w * 0.5 and gas.x < w * 0.5, "левша: джойстик и руль справа, педали слева")
		ST.set_left_hand(false)
		await process_frame
		ok(tc._stick_center.x < w * 0.5, "обратно")
	else:
		ok(false, "нет сенсорного управления (запусти с --touch)")
	for s in [2, 3]:
		if FileAccess.file_exists(SM.path_for(s)): DirAccess.remove_absolute(SM.path_for(s))
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
