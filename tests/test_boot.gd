extends SceneTree
## Запуск игры как у игрока: экран загрузки → мир → главное меню
## («Новая игра», «Продолжить», «Настройки», «Выход»), инверсия камеры,
## «Продолжить» с сохранения и «Новая игра» снова через экран загрузки.
var fails := 0
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	root.add_child(load("res://scenes/Boot.tscn").instantiate())
	_run.call_deferred()
func find_world() -> Node:
	return root.get_node_or_null("World")
func menu_of(w: Node):
	for c in w.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): return c
	return null
func button(m, text: String) -> Button:
	for b in m.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree(): return b
	return null

func _run() -> void:
	await process_frame
	var boot = root.get_node_or_null("Boot")
	ok(boot != null and boot.screen != null and boot.screen.visible, "при запуске — экран загрузки")
	ok(boot.screen._tip.text.begins_with("Совет:"), "на экране загрузки совет: " + boot.screen._tip.text)
	var t0 := Time.get_ticks_msec()
	while find_world() == null and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	for i in 5: await process_frame
	var W := find_world()
	ok(W != null and current_scene == W, "мир построен и стал текущей сценой")
	ok(root.get_node_or_null("Boot") == null, "экран загрузки убран")
	var M = menu_of(W)
	ok(M != null and M.is_open() and paused, "главное меню поверх мира, игра на паузе")
	# Верх экрана под меню: часы, деньги, за ними кольца — не друг на друге
	var hud: CanvasLayer = null
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("hud.gd"): hud = c
	ok(hud != null and hud._top.text != "" and hud._needs.position.x >= 16.0 + hud._top.get_combined_minimum_size().x,
		"под меню кольца сытости — после часов и денег, не поверх: x=%d" % (hud._needs.position.x if hud else -1))
	var mini := get_first_node_in_group("minimap") as Control
	ok(mini != null and not mini.visible, "под меню мини-карты нет (раньше в углу торчала буква «С»)")
	ok(button(M, "Новая игра") != null, "без сохранения: «Новая игра»")
	ok(button(M, "Настройки") != null, "есть «Настройки»")
	ok(OS.has_feature("web") or button(M, "Выход") != null, "есть «Выход»")
	# Настройки: инверсия камеры
	M._show("settings")
	var inv: CheckButton = null
	for c in M.find_children("*", "CheckButton", true, false):
		if (c as CheckButton).text.contains("Инверсия"): inv = c
	ok(inv != null, "в настройках — инверсия камеры")
	M._show("main")
	button(M, "Новая игра").pressed.emit()
	await process_frame
	ok(not M.is_open() and not paused, "«Новая игра» — играем")
	for i in 2: await process_frame
	ok(mini.visible == root.get_node("SettingsManager").minimap, "в игре мини-карта на месте")
	var P = W.get_node("Player")
	var SM = root.get_node("SettingsManager")
	var was: bool = SM.invert_y
	SM.invert_y = false
	var h0: float = P._head.rotation.x
	P._look(0.0, 0.2)
	var up: float = P._head.rotation.x - h0
	SM.invert_y = true
	h0 = P._head.rotation.x
	P._look(0.0, 0.2)
	var inverted: float = P._head.rotation.x - h0
	SM.invert_y = was
	ok(up > 0.0 and inverted < 0.0, "инверсия переворачивает взгляд по вертикали")
	# Сохранение — и «Продолжить» из главного меню
	root.get_node("GameManager").money = 4321
	root.get_node("SaveManager").save_game()
	root.get_node("GameManager").money = 10
	M._open(true)
	ok(button(M, "Продолжить") != null and button(M, "Новая игра") != null, "с сохранением: «Продолжить» и «Новая игра»")
	button(M, "Продолжить").pressed.emit()
	for i in 10: await process_frame
	ok(root.get_node("GameManager").money == 4321 and not paused, "«Продолжить» загрузило сохранение: %d грн" % root.get_node("GameManager").money)
	# «Новая игра» — снова через экран загрузки
	M._open(true)
	M._new_game()
	await process_frame
	await process_frame
	var b2 = root.get_node_or_null("Boot")
	ok(b2 != null, "«Новая игра» — экран загрузки")
	t0 = Time.get_ticks_msec()
	while (find_world() == null or root.get_node_or_null("Boot") != null) and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	ok(find_world() != null and root.get_node("GameManager").money == root.get_node("GameManager").START_MONEY, "новый мир, деньги с начала")
	ok(not menu_of(find_world()).is_open(), "после «Новой игры» меню не всплывает снова")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)
