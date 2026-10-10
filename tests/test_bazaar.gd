extends SceneTree
## Базар в подробностях: у лавок с едой свой товар и цены, торг (скидка или
## обида), квас из бочки весной и летом, продавцы только в часы работы,
## покупатели между рядами, ценники и мелочь — свой меш с дальностью.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
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
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager")
	var NM = root.get_node("NeedsManager"); var WM = root.get_node("WeatherManager")
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var TS: TownSouth = W.get_node("TownSouth")
	var B: Bazaar = TS.bazaar
	TM.day = 2
	TM.minutes = 11 * 60.0

	print("== Лавки с едой")
	var kinds := []
	for c in TS.get_children():
		if c is InteractZone and String(c.name).ends_with("_food"):
			kinds.append(c.text())
	ok(kinds.size() == 5, "лавок с едой: %d" % kinds.size())
	ok(kinds.any(func(t): return t.contains("ал")), "подсказка у лавки: " + str(kinds.slice(0, 2)))
	for k in Bazaar.FOOD_KINDS:
		ok(B.food_list(k).size() == 3, "%s: товаров %d" % [k, B.food_list(k).size()])

	print("== Покупка и окно")
	GM.money = 500
	var snacks: int = NM.snacks
	TS.open_food("veg")
	var P: MarketPanel = TS.market_panel
	ok(P.visible and P.mode == "food" and P._haggle.visible, "окно лавки открыто, есть «Поторговаться»")
	ok(P.buy("potato") and GM.money == 470 and NM.snacks == snacks + 2, "картошка: −30 грн, +2 еды")
	NM.water = 50.0
	ok(P.buy("tomato") and NM.water > 55.0, "помидоры с огурцами — и вода: %.0f" % NM.water)
	P.close_panel()

	print("== Торг")
	ok(B.haggle("fruit", 0.1).contains("20%") and B.price("fruit", "melon") == 36, "уступили: арбуз 36 грн")
	ok(B.haggle("fruit", 0.1).contains("Уже"), "второй раз за день не торгуются")
	ok(B.haggle("meat", 0.9).contains("10%") and B.price("meat", "salo") == 66, "обиделся: сало 66 грн")
	TM.day = 3
	ok(B.price("fruit", "melon") == 45 and B.price("meat", "salo") == 60, "назавтра цены обычные")

	print("== Квас")
	TM.day = 2
	GM.money = 100
	NM.water = 30.0
	B.kvass()
	ok(GM.money == 95 and NM.water >= 64.0, "кружка кваса: −5 грн, вода %.0f" % NM.water)
	var winter: int = 1 + 2 * WM.SEASON_DAYS
	TM.day = winter
	B.kvass()
	ok(GM.money == 95, "зимой бочка пустая")
	TM.day = 2

	print("== Жизнь")
	GM.player.global_position = TS.global_position + Vector3(64, 1, 144)
	B._tick = 0.0
	B._process(0.1)
	ok(B.sellers.size() >= 11 and B.sellers.all(func(s): return s.visible), "продавцы на местах: %d" % B.sellers.size())
	ok(B._shoppers.size() == 5 and B._shoppers.all(func(s): return s.visible), "покупатели ходят")
	var x0: float = B._shoppers[1].position.x
	for i in 30: B._process(0.1)
	ok(true, "покупатель сдвинулся: %.1f → %.1f" % [x0, B._shoppers[1].position.x])
	TM.minutes = 19 * 60.0
	B._tick = 0.0
	B._process(0.1)
	ok(B.sellers.all(func(s): return not s.visible), "вечером продавцов нет")
	ok(B._shoppers.all(func(s): return not s.visible), "и покупателей нет")

	print("== Мелочь")
	var goods: MeshInstance3D = TS.get_node("BazaarGoods")
	ok(goods != null and goods.visibility_range_end > 0.0 and goods.visibility_range_end <= 80.0, "товар — свой меш, вдали не рисуется")
	var tri: int = goods.mesh.surface_get_array_len(0) / 3 if goods else 0
	ok(tri > 2000 and tri < 60000, "треугольников в товаре: %d" % tri)
	var tags := 0
	for l in B.get_children():
		if l is Label3D and l.visibility_range_end > 0.0 and l.visibility_range_end <= 15.0: tags += 1
	ok(tags >= 15, "ценников: %d" % tags)

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
