extends SceneTree
## Удалить сохранение из меню (с вопросом «точно?») и ремнабор: купить в
## сельмаге или на базаре, починить свою машину или мотоцикл из инвентаря.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await frames(10)
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress"); var SM = root.get_node("SettingsManager")
	var SV = root.get_node("SaveManager"); var TM = root.get_node("TimeManager")
	var menu = child("pause_menu.gd")
	var slot0: int = SM.slot

	print("== Удалить сохранение")
	SM.set_slot(2)
	SV.delete_slot(2)
	ok(SV.save_game(true) and FileAccess.file_exists(SV.path_for(2)), "сохранил игру в ячейку 2")
	menu._show("main")
	await frames(2)
	ok(menu._delete.visible and menu._delete.text == "Удалить сохранение 2", "в меню кнопка: " + menu._delete.text)
	menu._delete.pressed.emit()
	await frames(2)
	ok(menu._page == "delete" and menu._delete_q.text.contains("ячейке 2"), "спрашивает: " + menu._delete_q.text.replace("\n", " "))
	ok(FileAccess.file_exists(SV.path_for(2)), "пока не согласился — сохранение на месте")
	for b in menu._pages.delete.find_children("*", "Button", true, false):
		if b.text == "Да, удалить": b.pressed.emit()
	await frames(2)
	ok(not FileAccess.file_exists(SV.path_for(2)) and SV.slot_info(2) == "пусто", "ячейка 2 пуста")
	ok(menu._page == "main" and not menu._delete.visible, "кнопки удаления больше нет")
	SM.set_slot(slot0)

	print("== Ремнабор")
	menu._close()
	TM.minutes = 12 * 60.0
	GM.money = 1000
	PR.repair_kits = 0
	ok(W.buy_repair_kit() and PR.repair_kits == 1 and GM.money == 850, "купил ремнабор в сельмаге за 150")
	var kz: InteractZone = W.find_child("ShopZone", true, false)
	ok(kz != null, "в сельмаге место с ремнабором у прилавка")
	var pl = W.get_node("Player")
	pl.global_position = kz.global_position + kz.global_transform.basis.z * 0.5 + Vector3(0, 0.5, 0)
	for i in 6: await physics_frame
	var near = pl._nearest_zone()
	ok(near == kz and kz.text().contains("ремнабор"), "подошёл к прилавку — «%s»" % (near.text() if near else "нет подсказки"))
	var mp := MarketPanel.new()
	W.add_child(mp)
	await frames(1)
	var moped: Vehicle = W.get_node("Moped")
	mp.open("parts", [moped])
	ok(mp.buy("repair_kit") and PR.repair_kits == 2, "и на базаре в «Автозапчастях»")
	ok(mp.buy("repair_kit") and PR.repair_kits == 3, "можно брать сколько нужно")
	mp.close_panel()
	moped.condition = 30.0
	var inv: InventoryPanel = W.get_node("Inventory")
	W.get_node("Player").global_position = moped.global_position + Vector3(1.5, 0, 0)
	await frames(2)
	inv.open()
	await frames(2)
	var fix: Button
	for b in inv.find_children("*", "Button", true, false):
		if b.text == "Починить": fix = b
	ok(fix != null, "в инвентаре — «Починить»")
	if fix: fix.pressed.emit()
	await frames(2)
	ok(is_equal_approx(moped.condition, 70.0) and PR.repair_kits == 2, "мопед подлатан: 30%% → %d%%, ремнаборов осталось %d" % [int(moped.condition), PR.repair_kits])
	moped.condition = 100.0
	ok(not PR.use_repair_kit(moped) and PR.repair_kits == 2, "целую технику не чинит — ремнабор цел")
	var st: Dictionary = PR.save_state()
	PR.load_state({})
	ok(PR.repair_kits == 0, "старое сохранение — ремнаборов нет")
	PR.load_state(st)
	ok(PR.repair_kits == 2, "ремнаборы сохраняются")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
