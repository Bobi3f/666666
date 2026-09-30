extends SceneTree
var fails := 0
var W
var held := {}
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func key(k: int, down: bool) -> void:
	if bool(held.get(k, false)) == down: return
	held[k] = down
	var e := InputEventKey.new()
	e.physical_keycode = k; e.keycode = k; e.pressed = down
	Input.parse_input_event(e)
func last() -> String:
	return W.get_node("/root/GameManager").get_meta("last", "")
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager")
	GM.message.connect(func(t: String) -> void:
		GM.set_meta("last", t)
		GM.set_meta("log", str(GM.get_meta("log", "")) + "\n" + t))
	var traffic
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c.get_script() and c.get_script().resource_path.ends_with("traffic.gd"): traffic = c
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	TM.minutes = 12 * 60.0
	var L = W.get_node("StreetLife")
	var P = W.get_node("Player"); var C = W.get_node("Car")

	print("== Светофор")
	ok(L.get_script().highway == "green", "сначала зелёный для трассы")
	L._t = L.GREEN + 0.1; await frames(2)
	ok(L.get_script().highway == "yellow", "потом жёлтый")
	L._t = L.YELLOW + 0.1; await frames(2)
	ok(L.get_script().highway == "red", "потом красный")
	var lamp: Dictionary = L._lamps[0]
	ok((lamp.red as StandardMaterial3D).emission_energy_multiplier > 1.0 and (lamp.green as StandardMaterial3D).emission_energy_multiplier == 0.0, "горит красная лампа")
	# Трафик стоит на красный
	var v0: Dictionary
	for v in traffic._vehicles:
		if v.dir == 1 and not v.bus: v0 = v; break
	for v in traffic._vehicles:
		if v != v0: (v.body as Node3D).global_position.x = -150.0 + randf() * 20.0 * v.dir
	(v0.body as Node3D).global_position = Vector3(55, 0.05, 2.0); v0.speed = 15.0
	for i in 60 * 10:
		L._t = 0.0
		await physics_frame
	var vx: float = (v0.body as Node3D).global_position.x
	ok(v0.speed < 0.5 and vx < L.STOP_EAST and vx > L.STOP_EAST - 8.0, "машина трафика стоит у стоп-линии: x=%.1f" % vx)
	L._t = L.RED + 0.1
	await frames(60 * 3)
	ok(v0.speed > 3.0, "зелёный — поехала: %.0f км/ч" % (v0.speed * 3.6))
	# Игрок проскочил на красный
	L.get_script().highway = "red"; L._t = 0.0
	GM.money = 1000
	C.global_position = Vector3(70, 0.1, -2.0); C.rotation.y = -PI / 2.0; C.speed = 14.0; C.velocity = Vector3.ZERO
	C._on_enter(); C.fuel = 30.0
	for i in 60 * 3:
		L._t = 0.0
		C.speed = maxf(C.speed, 12.0)
		await physics_frame
		if last().contains("красный"): break
	ok(last().contains("Штраф") and GM.money == 900, "на красный — штраф 100: %s" % last())
	C.speed = 0.0; C.velocity = Vector3.ZERO
	C.exit_car(); await frames(3)
	L._t = L.RED + 0.1; await frames(2)

	print("== Прохожие")
	ok(L._walkers.size() >= 8, "прохожих в городе: %d" % L._walkers.size())
	var w: Dictionary = L._walkers[2]
	var n: Node3D = w.node
	var p0 := n.global_position
	await frames(60)
	ok(n.global_position.distance_to(p0) > 0.8, "прохожий идёт: %.1f м за секунду" % n.global_position.distance_to(p0))
	# Машина рядом — останавливается и ругается
	GM.set_meta("last", "")
	C.global_position = n.global_position + Vector3(-2.5, 0.1, 0); C.rotation.y = -PI / 2.0
	C._on_enter(); C.speed = 4.0
	L._shout_cool = 0.0
	var p1 := n.global_position
	await frames(3)
	C.speed = 4.0
	await frames(2)
	ok(last().contains("«") and n.global_position.distance_to(p1) < 2.0, "машина вплотную — прохожий встал и ругается: " + last())
	C.speed = 0.0; C.velocity = Vector3.ZERO
	C.exit_car(); await frames(3)

	print("== Коровы")
	TM.minutes = 6 * 60.0 + 58.0
	await frames(3)
	var home: Array = L.cows_positions()
	ok(home[0].z < -60.0, "ночью коровы во дворе пастуха: z=%.0f" % home[0].z)
	TM.minutes = 7 * 60.0 + 1.0
	await frames(3)
	ok(L._cows_going == 1 and last().contains("коров"), "в 7:00 пастух гонит на луг: " + last())
	for i in 60 * 8: await physics_frame
	var mid: Array = L.cows_positions()
	ok(mid[0].z > home[0].z + 4.0, "идут: %.0f → %.0f" % [home[0].z, mid[0].z])
	var cow: Node3D = L._cows[0].body
	ok(cow is AnimatableBody3D, "корова твёрдая — в неё можно врезаться")
	TM.advance(300.0)
	await frames(3)
	var past: Array = L.cows_positions()
	ok(past[0].x < -150.0 and absf(past[0].z + 11.0) < 1.0, "перемотал время — стадо уже на лугу у трассы: %s" % str(past[0].round()))
	print("== Такси")
	var T = W.get_node("Taxi")
	var PR = root.get_node("Progress")
	TM.minutes = 12 * 60.0
	await frames(3)
	ok(T.state == 0 and T.at == 0 and T._passenger.visible, "пассажир ждёт на стоянке такси")
	var spot: Vector3 = T.place_pos(0)
	C.global_position = spot + Vector3(-5.0, 0.1, 0); C.rotation.y = 0.0; C.speed = 0.0; C.velocity = Vector3.ZERO
	C._on_enter(); C.fuel = 40.0
	PR.license = false
	T._nag = 0.0
	await frames(5)
	ok(T.state == 0 and last().contains("права"), "без прав не садится: " + last())
	PR.license = true
	await frames(5)
	ok(T.state == 1 and last().contains("Мне "), "с правами сел: " + last())
	ok(GM.challenge_line.contains("Такси"), "в строке задания: " + GM.challenge_line)
	var d: Vector3 = T.place_pos(T.dest)
	GM.money = 1000
	GM.set_meta("log", "")
	C.global_position = d + Vector3(0, 0.1, 2.0); C.speed = 0.0; C.velocity = Vector3.ZERO
	await frames(5)
	# Рядом может всплыть «Село такое-то» — ищем «Приехали» среди всех сообщений
	ok(T.state == 0 and GM.money > 1000 and str(GM.get_meta("log", "")).contains("Приехали"), "довёз: +%d грн — %s" % [GM.money - 1000, last()])
	ok(GM.challenge_line == "", "строка задания очистилась")
	C.exit_car(); await frames(3)
	TM.minutes = 23 * 60.0
	await frames(3)
	ok(not T._passenger.visible, "ночью такси не работает")
	print("== Музыка")
	var SL = root.get_node("SoundLibrary")
	var tk := Time.get_ticks_msec()
	while not SL.music_ready() and Time.get_ticks_msec() - tk < 20000:
		await process_frame
	ok(SL.music_ready() and SL.music_player.playing, "музыка собралась и играет")
	var SM = root.get_node("SettingsManager")
	SM.set_music(0.0)
	ok(SL.music_player.stream_paused, "ползунок «Музыка» на ноль — тишина")
	SM.set_music(0.5)
	ok(not SL.music_player.stream_paused, "вернул — играет")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
