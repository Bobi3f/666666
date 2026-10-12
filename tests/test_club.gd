extends SceneTree
## Клубы: сельский (пт, сб) и городская дискотека (каждый вечер) —
## часы работы, билет, дверь, танец в такт, приз, лимонад, музыка.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func last() -> String:
	return root.get_node("GameManager").get_meta("last", "")
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func zone(club, fragment: String) -> InteractZone:
	for c in club.get_children():
		if c is InteractZone and c.text().contains(fragment): return c
	return null

func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager")
	var NM = root.get_node("NeedsManager")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	var P = W.get_node("Player")
	var V: Club = W.get_node("ClubVillage")
	var T: Club = W.get_node("ClubTown")

	print("== Сельский клуб")
	TM.day = 3; TM.minutes = 21 * 60.0   # среда
	ok(not V.is_open(), "в среду дискотеки нет")
	var door := zone(V, "закрыто")
	ok(door != null and door.text().contains("пт, сб"), "на двери расписание: " + (door.text() if door else "—"))
	TM.day = 5   # пятница
	ok(V.is_open(), "в пятницу вечером — дискотека")
	TM.day = 6; TM.minutes = 0.5 * 60.0
	ok(V.is_open(), "в субботу в половине первого ночи ещё танцуют (пятничная)")
	TM.minutes = 2 * 60.0
	ok(not V.is_open(), "в два ночи закрыто")
	TM.day = 5; TM.minutes = 21 * 60.0
	await frames(3)
	ok(not V._door_block.disabled, "без билета дверь не пускает")
	GM.money = 100
	zone(V, "билет").activate()
	await frames(3)
	ok(GM.money == 80 and V._door_block.disabled, "билет 20 грн — дверь открыта")
	P.global_position = V.center + Vector3(0, 0.1, 1.0)
	await frames(10)
	ok(V._light.visible and V._music.playing, "внутри свет и музыка")
	ok(V._dancers[0].visible and V._dj.visible, "танцуют, диджей за пультом")

	print("== Танец в такт")
	NM.energy = 100.0
	var floor_zone := zone(V, "танцевать")
	floor_zone.activate()
	ok(V.dancing, "начал танцевать")
	var period := 60.0 / Club.BPM
	for k in 10:
		V._beat_t = k * period + 0.03
		floor_zone.activate()
		floor_zone.activate()  # второй раз на тот же удар не считается
	ok(V._hits == 10, "10 попаданий в такт, двойные не считаются: %d" % V._hits)
	V._beat_t = Club.DANCE_BEATS * period + 0.01
	await process_frame; await process_frame
	ok(not V.dancing and last().contains("зажёг"), "зажёг танцпол: " + last())
	floor_zone.activate()
	for k in 3:
		V._beat_t = k * period + period * 0.5   # мимо такта
		floor_zone.activate()
	ok(V._hits == 0, "мимо такта — не засчитано")
	V.dancing = false
	GM.challenge_line = ""

	print("== «Метелица»")
	TM.day = 3; TM.minutes = 22 * 60.0
	ok(T.is_open(), "городская дискотека каждый вечер")
	TM.minutes = 12 * 60.0
	ok(not T.is_open(), "днём закрыто")
	TM.minutes = 23 * 60.0
	GM.money = 500
	zone(T, "билет").activate()
	ok(GM.money == 450, "билет 50 грн")
	P.global_position = T.center + Vector3(0, 0.1, 0)
	await frames(5)
	var tf := zone(T, "танцевать")
	tf.activate()
	for k in 11:
		T._beat_t = k * period + 0.02
		tf.activate()
	T._beat_t = Club.DANCE_BEATS * period + 0.01
	await process_frame; await process_frame
	ok(GM.money == 600 and last().contains("приз"), "лучший танец — приз 150 грн: " + last())
	tf.activate()
	for k in 11:
		T._beat_t = k * period + 0.02
		tf.activate()
	T._beat_t = Club.DANCE_BEATS * period + 0.01
	await process_frame; await process_frame
	ok(GM.money == 600, "приз — раз за вечер")
	var drink := zone(T, "лимонад")
	var food: float = NM.food
	drink.activate()
	ok(GM.money == 580 and NM.food > food, "лимонад в баре")
	var st: Dictionary = T.save_state()
	T.load_state({})
	ok(T._paid_day < 0, "старое сохранение — без билета")
	T.load_state(st)
	ok(T._paid_day == T._night(), "билет на вечер сохраняется")
	P.global_position = Vector3(0, 0.2, 60)
	await frames(5)
	ok(not T._music.playing, "ушёл далеко — музыки не слышно")
	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)
