extends SceneTree
## Своё управление: на телефоне кнопки и руль можно переставить и поменять
## размер (сохраняется), на компьютере — назначить свои клавиши.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await process_frame
## Точка игры → точка окна (экран растянут — касания приходят в точках окна)
func wp(p: Vector2) -> Vector2:
	return root.get_final_transform() * p
func touch(i: int, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i; e.position = wp(pos); e.pressed = down
	Input.parse_input_event(e)
func drag(i: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i; e.position = wp(pos); e.relative = rel
	Input.parse_input_event(e)
func key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code; e.keycode = code; e.pressed = down
	Input.parse_input_event(e)
func _initialize() -> void:
	root.size = Vector2i(900, 420)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null

func _run() -> void:
	for i in 10: await process_frame
	var SM = root.get_node("SettingsManager")
	SM.set_touch_layout({})
	SM.reset_keys()
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tc = child("touch_controls.gd")
	await frames(3)

	print("== Кнопки на телефоне")
	var eb = null
	for e in tc._buttons:
		if e.text == "Прыжок": eb = e
	var c0: Vector2 = eb.center
	tc.start_edit()
	await frames(2)
	ok(tc.editing and paused and tc._edit_bar.visible, "редактор открыт, игра на паузе")
	touch(0, c0, true); await frames(2)
	ok(tc._sel == "Прыжок|walk", "нажал на «Прыжок» — выбрана")
	drag(0, c0 + Vector2(-150, -60), Vector2(-150, -60)); await frames(2)
	touch(0, c0 + Vector2(-150, -60), false); await frames(2)
	ok((eb.center as Vector2).distance_to(c0 + Vector2(-150, -60)) < 2.0, "перетащил пальцем: %s → %s" % [str(c0.round()), str((eb.center as Vector2).round())])
	tc.resize_selected(0.1); tc.resize_selected(0.1)
	ok(absf((eb.node as TouchScreenButton).scale.x - 1.2) < 0.01, "«+» дважды — кнопка крупнее (×1.2)")
	ok(not GameManager_moved(eb), "в редакторе нажатие не жмёт клавишу E")
	tc._edit_mode_btn.pressed.emit()
	await frames(2)
	ok(tc._edit_drive and tc.button("Газ").visible, "переключил на кнопки в машине")
	var w0: Vector2 = tc._wheel_center
	touch(1, w0 + Vector2(30, 0), true); await frames(2)
	ok(tc._sel == "wheel", "нажал на руль — выбран")
	drag(1, w0 + Vector2(110, -40), Vector2(80, -40)); await frames(2)
	touch(1, w0 + Vector2(110, -40), false); await frames(2)
	tc.resize_selected(-0.2)
	ok(tc._wheel_center.distance_to(w0 + Vector2(80, -40)) < 2.0 and absf(tc._wheel_k - 0.8) < 0.01, "руль передвинул и уменьшил")
	tc._edit_bar.get_child(0).get_child(1).get_child(4).pressed.emit()  # «Готово»
	await frames(2)
	ok(not tc.editing and not paused, "«Готово» — обратно в игру")
	ok(SM.touch_layout.has("Прыжок|walk") and SM.touch_layout.has("wheel"), "раскладка сохранена в настройках")
	tc._layout()
	ok((eb.center as Vector2).distance_to(c0 + Vector2(-150, -60)) < 2.0, "после перестройки кнопка на своём месте")
	tc.start_edit(); tc.reset_layout(); tc.finish_edit(true)
	await frames(2)
	ok((eb.center as Vector2).distance_to(c0) < 2.0 and SM.touch_layout.is_empty(), "«Сбросить» — как было")

	print("== Свои клавиши")
	SM.bind_key(KEY_E, KEY_F)
	await frames(2)
	key(KEY_F, true); await frames(2)
	ok(Input.is_physical_key_pressed(KEY_E), "назначил F на «Действие»: F жмёт E")
	key(KEY_F, false); await frames(2)
	key(KEY_E, true); await frames(2)
	ok(not Input.is_physical_key_pressed(KEY_E), "сама E больше ничего не делает")
	key(KEY_E, false); await frames(2)
	SM.bind_key(KEY_Z, KEY_F)
	ok(KeyRemap.key_for(KEY_Z) == KEY_F and KeyRemap.key_for(KEY_E) == KEY_Z, "F занята — поменялись: поворотник на F, действие на Z")
	SM.reset_keys()
	ok(SM.key_map.is_empty() and KeyRemap.key_for(KEY_E) == KEY_E, "«Вернуть клавиши» — всё как было")

	print("== Время суток")
	var TM = root.get_node("TimeManager")
	TM.set_hour(23.0)
	ok(absf(TM.hour() - 23.0) < 0.01, "ночь — 23:00")
	TM.set_hour(7.0)
	ok(absf(TM.hour() - 7.0) < 0.01, "утро — 7:00, тот же день")

	print("\nИТОГО: " + ("всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ, провалов: %d" % fails))
	quit(1 if fails else 0)

func GameManager_moved(_e) -> bool:
	return Input.is_physical_key_pressed(KEY_E)
