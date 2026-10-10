extends SceneTree
## Оля: распорядок, разговор и подарки, гулять и кататься вместе,
## дискотека, проводить домой, сохранение.
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

func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager"); var PR = root.get_node("Progress")
	var NM = root.get_node("NeedsManager"); var QM = root.get_node("QuestManager")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	PR.buy_car("car")
	PR.add_category("B")
	PR.license = true
	var G: Girl = W.get_node("Girl")
	var P = W.get_node("Player")
	var C: Vehicle = W.get_node("Car")
	TM.day = 3  # среда
	TM.minutes = 8 * 60.0
	P.global_position = Vector3(-100, 0.1, -42)
	await frames(3)

	print("== Распорядок")
	ok(G.doll.visible and G.doll.global_position.distance_to(G.HOME) < 1.0, "утром стоит у своей калитки")
	TM.minutes = 10 * 60.0
	await frames(2)
	ok(G._path.size() > 0, "в десять идёт в сельмаг (игрок рядом — пешком)")
	for i in 60 * 70:
		await physics_frame
		if G._path.is_empty(): break
	ok(G.doll.global_position.distance_to(G.SHOP) < 0.5, "дошла до сельмага")
	TM.minutes = 3 * 60.0
	P.global_position = Vector3(300, 0.1, 300)
	await frames(2)
	ok(not G.doll.visible, "ночью спит — не видно")
	TM.minutes = 21 * 60.0
	TM.day = 5  # пятница
	P.global_position = Vector3(300, 0.1, 300)
	# Под нагрузкой несколько шагов физики проходят за один кадр — ждём кадры
	for i in 30:
		await process_frame
		if G.doll.global_position.distance_to(G.CLUB) < 0.5: break
	ok(G.doll.global_position.distance_to(G.CLUB) < 0.5, "в пятницу вечером — у клуба")
	TM.day = 3
	TM.minutes = 14 * 60.0
	await frames(2)
	ok(G.doll.global_position.distance_to(G.HOME) < 0.5, "днём опять у калитки")

	print("== Разговор и подарки")
	P.global_position = G.doll.global_position + Vector3(0, 0.1, -1.0)
	await frames(4)
	ok(G._prompt().contains("девушкой"), "подсказка: " + G._prompt())
	G.open_talk()
	ok(G.panel.visible and paused, "окно разговора, игра на паузе")
	G.panel._refresh()
	var t: String = G.talk()
	ok(G.rel == G.TALK_GAIN, "поболтали: +%d (%s)" % [G.TALK_GAIN, t])
	G.talk()
	ok(G.rel == G.TALK_GAIN, "второй раз за день симпатия не растёт")
	GM.money = 1000
	ok(G.gift("candy").contains("Спасибо") and G.rel == G.TALK_GAIN + 12 and GM.money == 900, "конфеты: +12, −100 грн")
	ok(G.gift("flowers").contains("уже") and GM.money == 900, "второй подарок за день не берёт")
	G.panel.close_panel()
	ok(not paused, "окно закрыто")

	print("== Гулять и кататься")
	ok(G.invite() != "" and G.state == Girl.State.FOLLOW, "позвал гулять — идёт")
	P.global_position += Vector3(8, 0, 0)
	await frames(240)
	ok(G.doll.global_position.distance_to(P.global_position) < 3.0, "идёт следом")
	C.global_position = P.global_position + Vector3(3, 0.3, 0)
	C.rotation.y = 0.0
	await frames(5)
	C._on_enter()
	await frames(3)
	ok(G.state == Girl.State.RIDE and G.doll.get_parent() == C._body and G._sit.visible, "села в машину рядом с водителем")
	ok(G.doll.position.x > 0.2, "справа от водителя")
	var r0 := G.rel
	G._ride_t = 59.9
	for i in 30:
		C.speed = 10.0
		await process_frame
		if G.rel > r0: break
	ok(G.rel == r0 + G.RIDE_GAIN, "минута катания: +%d" % G.RIDE_GAIN)
	C.speed = 0.0
	ok(W.get_node("Girl").get_path() == G.get_path() and G.save_state().has("rel"), "сохраняется по прежнему пути")
	C._drop_driver()
	await frames(3)
	ok(G.state == Girl.State.FOLLOW and G.doll.get_parent() == G and G._walk.visible, "вышел — вышла и она")

	print("== Дискотека")
	r0 = G.rel
	QM.event("dance")
	ok(G.rel == r0 + G.DANCE_GAIN and last().contains("танцевал с Олей"), "танцевал с ней: +%d" % G.DANCE_GAIN)
	QM.event("dance")
	ok(G.rel == r0 + G.DANCE_GAIN, "за ночь — один раз")

	print("== Проводить домой")
	TM.minutes = 22.8 * 60.0
	P.global_position = G.HOME + Vector3(0, 0.1, -3)
	await frames(240)
	ok(G.state == Girl.State.LIFE and last().contains("проводил"), "поздно, довёл до калитки — спасибо: " + last())
	G.invite()
	ok(G.state == Girl.State.LIFE, "ночью гулять не идёт")
	TM.minutes = 15 * 60.0
	G.invite()
	TM.minutes = 1.2 * 60.0
	P.global_position = Vector3(-60, 0.1, -40)
	G.doll.global_position = Vector3(-61, 0, -40)
	r0 = G.rel
	await frames(3)
	ok(G.state == Girl.State.LIFE and G.rel == r0 - G.LEFT_ALONE, "не проводил до часу ночи — обиделась")

	print("== Уровни")
	G.rel = 68
	TM.minutes = 12 * 60.0
	TM.day = 9
	var sn: int = NM.snacks
	G.talk()
	ok(G.level() == "твоя девушка" and root.get_node("Achievements").got.has("girl"), "стала твоей девушкой, достижение «Первая любовь»")
	ok(NM.snacks == sn + 2, "девушка угощает пирожками")
	var d := G.save_state()
	G.rel = 0
	G.load_state(d)
	ok(G.rel == 72 and G.met, "симпатия из сохранения")

	print("\nИТОГО: " + ("всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ, провалов: %d" % fails))
	quit(1 if fails else 0)
