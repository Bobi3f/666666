extends SceneTree
## Инвентарь (I) и телефон (P): разделы инвентаря, «Съесть»; в телефоне —
## девять приложений, такси домой, эвакуатор, звонок Оле, музыка пешком,
## сообщения, прогноз погоды, вклад, фото в галерею.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func pf(n: int) -> void:
	for i in n: await process_frame
func key(k: int) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k; e.keycode = k; e.pressed = down
		Input.parse_input_event(e)
		await pf(2)
func labels(n: Node) -> String:
	var out := ""
	for l in n.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree(): out += (l as Label).text + "\n"
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree(): out += (b as Button).text + "\n"
	return out
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await pf(10)
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	await pf(3)
	var GM = root.get_node("GameManager"); var NM = root.get_node("NeedsManager"); var TM = root.get_node("TimeManager")
	var PR = root.get_node("Progress"); var WM = root.get_node("WeatherManager"); var DM = root.get_node("Daily")
	TM.minutes = 12 * 60.0
	var inv: InventoryPanel = W.get_node("Inventory")
	var ph: PhoneUI = W.get_node("Phone")
	var player: Node3D = W.get_node("Player")

	print("== Инвентарь")
	await key(KEY_I)
	ok(inv.is_open() and paused, "I — инвентарь открыт, игра на паузе")
	var t := labels(inv)
	for s in ["ДЕНЬГИ", "ЕДА И ПИТЬЁ", "ДОКУМЕНТЫ", "ТЕХНИКА", "ДОМ И ХОЗЯЙСТВО"]:
		ok(t.contains(s), "раздел «%s»" % s)
	ok(t.contains("Мопед") or t.contains("«Карпаты»") or t.contains("Карпаты"), "свой мопед в технике")
	NM.snacks = 2
	NM.food = 40.0
	inv.refresh()
	await pf(2)
	var eat: Button
	for b in inv.find_children("*", "Button", true, false):
		if b.text == "Съесть": eat = b
	ok(eat != null, "у еды — кнопка «Съесть»")
	if eat:
		eat.pressed.emit()
		await pf(2)
	ok(NM.snacks == 1 and NM.food > 40.0, "съел из запаса: осталось %d, сытость %d%%" % [NM.snacks, int(NM.food)])
	await key(KEY_I)
	ok(not inv.is_open() and not paused, "I ещё раз — закрыт")

	print("== Телефон")
	await key(KEY_P)
	ok(ph.is_open() and paused, "P — телефон открыт, игра на паузе")
	var apps := 0
	for a in PhoneUI.APPS:
		if ph.find_child("App_" + String(a[0]), true, false): apps += 1
	ok(apps == 9, "девять приложений на главном экране: %d" % apps)
	var vp: Vector2 = ph.get_viewport().get_visible_rect().size
	var fr: Control = ph._frame
	ok(fr.position.y >= 0.0 and fr.position.y + fr.size.y <= vp.y + 0.5, "телефон целиком на экране: %s в %s" % [str(fr.size.round()), str(vp)])
	for a in PhoneUI.APPS:
		ph.show_app(a[0])
		await pf(1)
	ok(ph._app == "clock" and labels(ph._content).contains(":"), "все приложения открываются, часы показывают время")

	print("== Сообщения")
	GM.notify("Проверка связи")
	ph.show_app("sms")
	await pf(2)
	ok(labels(ph._content).contains("Проверка связи"), "сообщение есть в телефоне")

	print("== Погода")
	var fc: int = WM.forecast()
	WM._minutes_left = 0.0
	WM._on_minutes(1.0)
	ok(WM.kind == fc, "прогноз сбылся: %s" % WM.NAMES[fc])

	print("== Такси")
	player.global_position = Town.w(Vector3(150, 0.1, 58))
	await pf(2)
	var money0: int = GM.money
	var price: int = ph.taxi_price(ph.taxi_places()[0][1])
	var t0: float = TM.minutes
	ok(ph.taxi("Домой"), "вызвал такси домой за %d грн" % price)
	ok(player.global_position.distance_to(ph.taxi_places()[0][1]) < 1.0, "приехал к своей калитке")
	ok(GM.money == money0 - price and TM.minutes > t0 + 10.0, "заплатил, прошло %d мин" % int(TM.minutes - t0))
	ok(not ph.is_open(), "телефон убран — едем дальше")

	print("== Эвакуатор")
	var car: Vehicle = W.get_node("Car")
	PR.buy_car("car")
	car.global_position = Vector3(400, 0.3, 300)
	car.fuel = 0.0
	GM.money = 5000
	ph.open("tow")
	ok(labels(ph._content).contains("Жигули"), "Жигули в списке эвакуатора")
	ok(ph.tow(car), "эвакуатор вызван за %d грн" % (5000 - GM.money))
	ok(car.global_position.distance_to(ph.tow_spots()[0]) < 12.0 and car.fuel >= 3.0, "Жигули у дома, в баке 3 л")

	print("== Звонок Оле")
	var girl: Girl = W.get_node("Girl")
	ph.show_app("calls")
	ok(not labels(ph._content).contains("Оля"), "незнакомой Оли в контактах нет")
	girl.met = true
	girl.rel = 50
	ph.show_app("calls")
	ok(labels(ph._content).contains("Оля"), "Оля в контактах")
	girl.global_position = player.global_position + Vector3(200, 0, 0)
	var reply: String = ph.call_girl()
	ok(girl.state == Girl.State.FOLLOW and girl.global_position.distance_to(player.global_position) < 6.0, "позвонил — Оля пришла: " + reply)

	print("== Музыка")
	var radio = get_first_node_in_group_safe("radio")
	radio.play_on_phone(0)
	ok(radio.phone and radio.station == 0, "станция «%s» с телефона" % radio.STATIONS[0].name)
	radio.stop_phone()
	ok(not radio.phone and radio.station == -1, "выключил")

	print("== Банк")
	GM.money = 2000
	DM.deposit = 0
	ph.show_app("bank")
	for b in ph._content.find_children("*", "Button", true, false):
		if String(b.text).begins_with("Положить"): b.pressed.emit()
	ok(DM.deposit == 1700 and GM.money == 300, "положил на вклад с телефона: %d" % DM.deposit)

	print("== Фото")
	for f in PhoneUI.photos():
		DirAccess.remove_absolute(PhoneUI.PHOTO_DIR.path_join(f))
	ph.show_app("photo")
	await ph.take_photo()
	await pf(3)
	var files := PhoneUI.photos()
	ok(files.size() == 1, "снимок сохранён: %s" % str(files))
	if files.size() > 0:
		var img := Image.load_from_file(PhoneUI.PHOTO_DIR.path_join(files[0]))
		ok(img != null and img.get_width() > 100, "в галерее картинка %dx%d" % [img.get_width(), img.get_height()])
	ok(ph.is_open() and labels(ph._content).contains("Снимков: 1"), "галерея показывает снимок")
	for f in PhoneUI.photos():
		DirAccess.remove_absolute(PhoneUI.PHOTO_DIR.path_join(f))
	ph.show_app("")
	await key(KEY_P)
	ok(not ph.is_open() and not paused, "P — телефон убран")

	print("== По-английски")
	var tr := LangTranslation.new()
	var miss := []
	for a in PhoneUI.APPS:
		if tr.text(a[1]) == a[1]: miss.append(a[1])
	ok(miss.is_empty(), "названия приложений переведены: " + str(miss))

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
func get_first_node_in_group_safe(g: String) -> Node:
	return get_nodes_in_group(g)[0] if not get_nodes_in_group(g).is_empty() else null
