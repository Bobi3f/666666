extends SceneTree

var msgs: Array[String] = []
var fails := 0
var W: Node

func ok(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)

func zone_with(text: String) -> InteractZone:
	for z in _all(W):
		if z.text().contains(text):
			return z
	return null

func _all(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is InteractZone:
			out.append(c)
		out.append_array(_all(c))
	return out

func child(script_end: String) -> Node:
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(script_end):
			return c
	return null

func last() -> String:
	return msgs[-1] if msgs.size() else ""

func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()

func _run() -> void:
	await frames(5)
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager"); var NM = root.get_node("NeedsManager")
	var WM = root.get_node("WeatherManager"); var PR = root.get_node("Progress"); var SM = root.get_node("SaveManager")
	GM.message.connect(func(t): msgs.append(t))
	var P = W.get_node("Player"); var C = W.get_node("Car")
	child("pause_menu.gd")._close()
	# «Жигули» свои (за руль тест сажает сам, без проверки прав)
	root.get_node("Progress").buy_car("car")
	WM.set_kind(0, 9999.0)

	print("== Огород")
	var g := zone_with("посадить картошку")
	ok(g != null, "грядки за домом: " + (g.text() if g else "-"))
	TM.minutes = 9 * 60.0
	GM.money = 500
	g.activate()
	ok(PR.garden_stage() == 1 and GM.money == 400, "посадил за 100 грн, стадия 1")
	var garden = child("garden.gd")
	await frames(2)
	ok(garden._plants != null, "ростки видны")
	ok(g.text().contains("копать через"), "подсказка: " + g.text())
	TM.advance(1440.0 * 1.5)
	NM.energy = 100.0; NM.food = 100.0
	await frames(2)
	ok(PR.garden_stage() == 2 and garden._stage == 2, "через полтора дня — ботва")
	TM.advance(1440.0 * 1.6)
	NM.energy = 100.0; NM.food = 100.0
	await frames(2)
	ok(PR.garden_stage() == 3 and msgs.any(func(m): return m.contains("поспела")), "через три дня поспела, пришло сообщение")
	var sn: int = NM.snacks
	g.activate()
	ok(NM.snacks == sn + 6 and PR.garden_stage() == 0, "выкопал: +6 еды, грядки пустые")
	await frames(2)
	ok(garden._plants == null, "ботва убрана")

	print("== Рыбалка и сельмаг")
	var f := zone_with("порыбачить")
	ok(f != null, "мостки на пруду")
	TM.minutes = 6 * 60.0
	NM.energy = 100.0
	var FG = W.get_node("FishingGame")
	P.global_position = FG.spot + Vector3(0, 0.1, 0)
	await frames(3)
	# Рано дёрнул — рыба ушла
	f.activate()
	ok(FG.state == 1 and f.text().contains("жди"), "закинул удочку: " + f.text())
	f.activate()
	ok(FG.state == 0 and NM.fish == 0 and last().contains("Рано"), "рано подсёк — ушла")
	# Ждём поклёвку и подсекаем
	var caught := 0
	var missed := 0
	for i in 12:
		TM.minutes = 6 * 60.0
		f.activate()
		var t0 := Time.get_ticks_msec()
		while FG.state == 1 and Time.get_ticks_msec() - t0 < 8000:
			await process_frame
		if FG.state == 2:
			if caught == 0:
				ok(f.text().contains("КЛЮЁТ"), "поклёвка: " + f.text())
			var n: int = NM.fish
			f.activate()
			caught += NM.fish - n
		else:
			missed += 1
	ok(caught > 0, "за 12 забросов поймал %d рыб (не клюнуло %d)" % [caught, missed])
	# Прозевал поклёвку — сорвалась
	var lost := false
	for i in 12:
		f.activate()
		var t0 := Time.get_ticks_msec()
		while FG.state != 0 and Time.get_ticks_msec() - t0 < 10000:
			await process_frame
		if last().contains("Сорвалась"):
			lost = true
			break
	ok(lost, "прозевал поклёвку — сорвалась")
	NM.fish = 0
	TM.minutes = 23 * 60.0
	var fi: int = NM.fish
	f.activate()
	ok(NM.fish == fi and last().contains("Ночью"), "ночью не клюёт")
	NM.fish = 3
	GM.money = 0
	var sell := zone_with("сдать рыбу")
	ok(sell != null, "сельмаг принимает рыбу: " + (sell.text() if sell else "-"))
	sell.activate()
	ok(GM.money == 180 and NM.fish == 0, "сдал 3 рыбы за 180 грн")
	# На мостки можно зайти
	P.global_position = Vector3(-167, 0.1, -40)
	P.rotation.y = -PI / 2.0 * -1.0  # лицом к -X, к пруду
	P.rotation.y = PI / 2.0
	await frames(10)
	key(KEY_W, true)
	var ymax := 0.0
	for i in 180:
		await physics_frame
		ymax = maxf(ymax, P.global_position.y)
	key(KEY_W, false)
	ok(ymax > 0.3, "зашёл на мостки: высота %.2f, x=%.1f" % [ymax, P.global_position.x])
	P.global_position = f.global_position + Vector3(0, 0.1, 0)
	await frames(10)
	ok(P.global_position.y > 0.3 and P.current_prompt().contains("порыбачить"), "стоя на мостках (y=%.2f): %s" % [P.global_position.y, P.current_prompt()])

	print("== Сон и автосохранение")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	NM.energy = 20.0
	var bed := zone_with("лечь спать")
	bed.activate()
	ok(SM.has_save() and last().contains("сохранена"), "после сна игра сохранена: " + last())

	print("== Фары")
	NM.energy = 100.0; NM.food = 100.0
	C.global_position = Vector3(-121, 0.1, -39.5)
	C._on_enter()
	C.fuel = 30.0; C.condition = 100.0
	TM.minutes = 13 * 60.0
	C._toggle_ignition()
	await frames(3)
	ok(not C.headlights_on(), "днём фары выключены")
	TM.minutes = 22 * 60.0
	await frames(3)
	ok(C.headlights_on(), "ночью включились сами")
	TM.minutes = 13 * 60.0
	key(KEY_L, true); await frames(2); key(KEY_L, false); await frames(2)
	ok(C.headlights_on(), "L включает фары днём")
	C.engine_on = false
	await frames(2)
	ok(not C.headlights_on(), "мотор заглушен — фары погасли")
	C.exit_car()
	await frames(2)

	print("== Карта")
	var map = child("map.gd")
	ok(not map._canvas.visible, "карта скрыта")
	key(KEY_M, true); await frames(2); key(KEY_M, false); await frames(3)
	ok(map._canvas.visible, "M открывает карту")
	ok(map.mode == 1, "сначала — окрестности")
	key(KEY_M, true); await frames(2); key(KEY_M, false); await frames(2)
	ok(map._canvas.visible and map.mode == 2 and map._view.size.x > 1000.0, "второе M — весь район")
	key(KEY_M, true); await frames(2); key(KEY_M, false); await frames(2)
	ok(not map._canvas.visible, "третье M закрывает")

	print("== Повтор прошлых проверок")
	NM.energy = 100.0; NM.food = 100.0
	GM.money = 12000
	TM.minutes = 10 * 60.0
	zone_with("прораб").activate()
	await frames(3)
	var house = W.get_node_or_null("House_-125_-56")
	ok(PR.house_level == 1 and house and house.wealth == 1, "перестройка дома")
	ok(zone_with("посадить картошку") != null, "огород на месте после перестройки")
	GM.money = 0; NM.energy = 90.0
	W.kolkhoz_job.simulate_all()
	ok(GM.money == 400, "колхоз платит")
	C.global_position = Vector3(27, 0.1, 22); await frames(2)
	zone_with("развоз").activate()
	ok(PR.bread == 100.0, "хлеб целый")
	PR.damage_bread(30.0)
	ok(PR.bread == 70.0 and last().contains("бьётся"), "удар — хлеб бьётся: " + last())
	C._on_enter(); C.global_position = Vector3(-51, 0.1, -24); await frames(4)
	ok(GM.money == 400 + 350 + 150 and last().contains("премией"), "развоз: 70%% хлеба + премия за скорость = %d, %s" % [GM.money - 400, last()])
	C.exit_car(); await frames(2)
	var tr = child("traffic.gd")
	var x0: float = tr.vehicles()[0].body.global_position.x
	await frames(30)
	ok(absf(tr.vehicles()[0].body.global_position.x - x0) > 3.0, "трасса едет")

	print("== Сохранение огорода и рыбы")
	PR.planted = true
	PR.planted_at = PR.now() - 100.0
	NM.fish = 4
	SM.save_game()
	PR.planted = false; NM.fish = 0
	SM.load_game()
	await frames(2)
	ok(PR.garden_stage() == 1 and NM.fish == 4, "огород и рыба восстановлены")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
