extends SceneTree
## Своё дело растёт: три уровня (доход ×1,5 и ×2), налог 15% с дохода каждое
## утро, улучшение из телефона. Дом: четвёртый уровень — коттедж с беседкой;
## купить дом в городе и квартиру — там можно спать.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await frames(10)
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager"); var DM = root.get_node("Daily")
	var PR = root.get_node("Progress"); var NM = root.get_node("NeedsManager")

	print("== Уровни своего дела")
	GM.money = 50000
	ok(DM.buy("kiosk"), "купил ларёк")
	ok(DM.level("kiosk") == 1 and DM.income("kiosk") == 250, "1-й уровень: +250")
	var cost: int = DM.upgrade_cost("kiosk")
	ok(cost == 2500 and DM.upgrade_text("kiosk") != "", "улучшение: %s за %d" % [DM.upgrade_text("kiosk"), cost])
	ok(DM.upgrade("kiosk") and DM.level("kiosk") == 2 and DM.income("kiosk") == 375, "2-й уровень: +375")
	ok(DM.upgrade("kiosk") and DM.level("kiosk") == 3 and DM.income("kiosk") == 500, "3-й уровень: +500")
	ok(not DM.upgrade("kiosk") and DM.upgrade_cost("kiosk") == 0, "дальше некуда")
	ok(not DM.upgrade("sto"), "чужое дело не улучшишь")

	print("== Налог")
	GM.in_game = true
	DM.paid_day = TM.day
	var m0: int = GM.money
	var sum: int = DM.income("kiosk")
	TM.minutes = 23.9 * 60.0
	TM.advance(8.0 * 60.0)
	await frames(2)
	var tax: int = DM.tax_of(sum)
	ok(tax == 75 and GM.money - m0 == sum - tax, "утром: +%d, налог %d, на руки %d" % [sum, tax, GM.money - m0])

	print("== Сохранение уровней")
	var st: Dictionary = DM.save_state()
	DM.load_state({})
	ok(DM.level("kiosk") == 1, "старое сохранение — 1-й уровень")
	DM.load_state(st)
	ok(DM.level("kiosk") == 3 and DM.owns("kiosk"), "уровень сохраняется")

	print("== Телефон: улучшить из «Банка»")
	ok(DM.buy("sto"), "купил СТО")
	var ph: PhoneUI = W.get_node("Phone")
	ph.open("bank")
	var up: Button
	for b in ph._content.find_children("*", "Button", true, false):
		if String(b.text).begins_with("Улучшить"): up = b
	ok(up != null, "в «Банке» кнопка «Улучшить»: " + (up.text if up else "нет"))
	if up:
		up.pressed.emit()
	ok(DM.level("sto") == 2, "СТО улучшено с телефона")
	ph.close_phone()

	print("== Коттедж")
	PR.house_level = 2
	GM.money = 70000
	ok(PR.next_cost() == 60000, "после кирпичного — коттедж за 60000")
	ok(PR.upgrade_house() and PR.house_level == 3 and PR.max_level(), "построил коттедж")
	await frames(3)
	var yard: MeshInstance3D = W.get_node("PlayerYardMesh")
	ok(yard.mesh.get_aabb().size.y > 8.0, "дом в два этажа: высота %.1f м" % yard.mesh.get_aabb().size.y)
	var inv: InventoryPanel = W.get_node("Inventory")
	ok(inv.HOUSE_NAMES[3].contains("коттедж"), "в инвентаре — коттедж")

	print("== Дом в городе и квартира")
	var east = W.find_child("TownEast", true, false)
	GM.money = 30000
	ok(east.buy_home("flat") and PR.has_item("flat") and GM.money == 12000, "купил квартиру за 18000")
	ok(not east.buy_home("town_house"), "на дом в городе денег не хватило")
	GM.money = 25000
	ok(east.buy_home("town_house") and PR.has_item("town_house"), "купил дом в городе")
	var bed: InteractZone = east.find_child("HomeSleep_flat", true, false)
	ok(bed and bed.text().begins_with("E — домой"), "у подъезда: " + (bed.text() if bed else "нет"))
	NM.energy = 30.0
	TM.minutes = 22 * 60.0
	var d0: int = TM.day
	bed.activate()
	ok(TM.day == d0 + 1 and absf(TM.hour() - 7.0) < 0.1 and NM.energy > 90.0, "поспал в квартире до 7 утра")
	ok(inv.item_name("flat").contains("Квартира"), "в инвентаре: " + inv.item_name("flat"))
	# Сон сохраняет игру — не оставляем сохранение другим тестам
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
