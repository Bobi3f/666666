extends SceneTree
## GEARCOIN: окно с пакетами (цены в гривнах, рублях, долларах; оплата —
## «скоро»), эксклюзив за монеты — техника, клубы, жильё — и сохранение.
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
	var PR = root.get_node("Progress"); var DM = root.get_node("Daily"); var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager")
	var shop: GearShop = W.get_node("GearShop")
	print("== Окно")
	shop.open()
	await frames(2)
	ok(shop.visible and paused, "окно GEARCOIN открылось, игра на паузе")
	ok(GearShop.PACKS.size() == 6 and GearShop.price_text(0, "грн") == "49 грн" and GearShop.price_text(5, "грн") == "3 999 грн", "шесть пакетов: от 49 до 3 999 грн")
	ok(GearShop.price_text(0, "₽").ends_with("₽") and GearShop.price_text(0, "$").begins_with("$"), "цены в рублях и долларах: %s, %s" % [GearShop.price_text(0, "₽"), GearShop.price_text(0, "$")])
	PR.gearcoins = 0
	ok(not shop.buy_pack(2) and shop._status.text.contains("скоро") and PR.gearcoins == 0, "оплаты пока нет — «скоро»")
	ok(not shop.redeem("ABCD-1234") and PR.gearcoins == 0 and shop._status.text.contains("нет"), "чужой код не проходит")
	# Подарочный код: проверочный, добавлен только на время теста
	GearShop.CODES["TEST-CODE".sha256_text()] = [1000000, 1000000]
	var m0: int = GM.money
	ok(GearShop.normalize(" su9k 27na-lcrт ") == "SU9K-27NA-LCRT" and GearShop.normalize("su9k27nalcrt") == "SU9K-27NA-LCRT", "код понимается без дефисов, с пробелами и русскими буквами")
	ok(shop.redeem(" test-code ") and PR.gearcoins == 1000000 and GM.money == m0 + 1000000, "код: +1 000 000 GEARCOIN и +1 000 000 грн")
	ok(shop._balance.text.contains("1 000 000"), "баланс с пробелами: " + shop._balance.text)
	ok(not shop.redeem("TEST-CODE") and PR.gearcoins == 1000000, "второй раз тот же код не проходит")
	var cst: Dictionary = PR.save_state()
	PR.codes = []
	PR.load_state(cst)
	ok(PR.codes.size() == 1, "активированный код сохраняется")
	ok(GearShop.CODES.size() == 2, "в игре есть личный код владельца")
	GearShop.CODES.erase("TEST-CODE".sha256_text())
	PR.codes = []
	GM.money = m0
	print("== Профиль и экран")
	var SM = root.get_node("SettingsManager")
	var keep: Array = [SM.first_name, SM.last_name]
	SM.set_player_name("  Богдан ", "Тестовый")
	ok(SM.full_name() == "Богдан Тестовый", "профиль: " + SM.full_name())
	shop._refresh()
	ok(shop._balance.text.begins_with("Богдан Тестовый"), "имя в окне GEARCOIN")
	var hud: Node = null
	for n in W.get_children():
		if n.get_script() and String(n.get_script().resource_path).ends_with("hud.gd"): hud = n
	hud._slow_update()
	ok(hud._top.text.contains("1 000 000 GC"), "GEARCOIN на экране: " + hud._top.text)
	var menu: Node = null
	for n in W.get_children():
		if n.get_script() and String(n.get_script().resource_path).ends_with("pause_menu.gd"): menu = n
	menu._refresh()
	ok(menu._profile.text == "Профиль: Богдан Тестовый", "кнопка профиля в меню: " + menu._profile.text)
	menu._show("profile")
	menu._name_edits[0].text = "Иван"
	menu._name_edits[1].text = "Петренко"
	menu.save_profile()
	ok(SM.full_name() == "Иван Петренко" and menu._page == "main", "имя сохранено из меню")
	SM.set_player_name(keep[0], keep[1])
	PR.gearcoins = 0
	print("== Эксклюзив")
	ok(not shop.buy("club_v") and shop._status.text.contains("Не хватает"), "без монет не купишь")
	PR.gearcoins = 10000
	ok(shop.buy("club_v") and DM.owns("club_v") and PR.gearcoins == 8500, "клуб «Каменка» — твой")
	ok(not DM.buy("club_t"), "клуб за гривны не продаётся")
	var club = W.get_node("ClubVillage")
	ok(club.biz == "club_v", "клуб знает, что он твой — вход бесплатный")
	ok(shop.buy("volga:black") and PR.owns("volga:black"), "«Волга» Чёрная куплена")
	shop.close_panel()
	await create_timer(1.5).timeout
	var v: Vehicle = W.get_node_or_null("Exclusive_volga_black")
	ok(v != null and v.owned() and v.spec.title == "«Волга» Чёрная" and int(v.parts.get("rims", -1)) == 3, "стоит у дома: %s" % (v.spec.title if v else "нет"))
	ok(shop.buy("penthouse") and PR.has_item("penthouse"), "квартира на 9-м этаже")
	await frames(2)
	var bed: InteractZone = W.find_child("HomeSleep_penthouse", true, false)
	ok(bed != null and bed.text().begins_with("E — домой"), "у подъезда девятиэтажки: " + (bed.text() if bed else "нет"))
	ok(shop.buy("mansion") and PR.has_item("mansion"), "особняк")
	var door: InteractZone = W.find_child("MansionDoor", true, false)
	ok(door != null and door.text().begins_with("E — домой"), "у двери особняка: " + (door.text() if door else "нет"))
	print("== Сохранение")
	var st: Dictionary = PR.save_state()
	PR.load_state({})
	ok(PR.gearcoins == 0, "старое сохранение — монет нет")
	PR.load_state(st)
	ok(PR.gearcoins == 10000 - 1500 - 800 - 900 - 2500, "монеты сохраняются: %d" % PR.gearcoins)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
