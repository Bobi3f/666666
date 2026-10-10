extends SceneTree
## Развлечения: в ПТУ — настольный теннис и армрестлинг, в школе — кикер и
## викторина «Умники и умницы». Победа — приз раз в день.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
## Сыграть в теннис/кикер: попасть в hits подач из 10.
func play_ping(g: FunGame, hits: int) -> void:
	g.press()
	for s in FunGame.SERVES:
		g._t = s * FunGame.PERIOD + FunGame.PERIOD - 0.05
		if s < hits: g.press()
	g._t = FunGame.SERVES * FunGame.PERIOD + 0.01
	g._process(0.0)
func _run() -> void:
	await frames(12)
	var GM = root.get_node("GameManager"); var NM = root.get_node("NeedsManager")
	var P: Node3D = GM.player
	NM.energy = 100.0
	print("== ПТУ: настольный теннис")
	W.interiors.enter("college")
	await frames(2)
	var ping: FunGame = W.interiors.ping
	P.global_position = ping.global_position + Vector3(2.0, 0.1, 0)
	ok(ping.prompt().contains("теннис") and ping.prompt().contains("приз 25"), ping.prompt())
	var m0: int = GM.money
	play_ping(ping, 8)
	ok(not ping.active and GM.money == m0 + 25, "отбил 8 из 10 — победа, +25 грн")
	play_ping(ping, 9)
	ok(GM.money == m0 + 25, "второй раз за день — без приза")
	play_ping(ping, 3)
	ok(not ping.active, "отбил 3 — проигрыш, игра кончилась")
	print("== ПТУ: армрестлинг")
	var arm: FunGame = W.interiors.arm
	P.global_position = arm.global_position + Vector3(1.5, 0.1, 0)
	m0 = GM.money
	arm.press()
	for i in 20:
		if not arm.active: break
		arm.press()
	ok(not arm.active and GM.money == m0 + 40, "дожал руку — +40 грн")
	arm.press()
	arm._process(5.0)
	arm._process(5.0)
	ok(not arm.active, "не жал — проиграл")
	W.interiors.leave()
	print("== Школа: кикер и викторина")
	var school = W.find_child("School", true, false)
	var k: FunGame = school.kicker
	P.global_position = k.global_position + Vector3(1.4, 0.1, 0)
	m0 = GM.money
	play_ping(k, 7)
	ok(GM.money == m0 + 20, "кикер: 7 из 10 — +20 грн")
	var lessons: int = school.lessons_today
	school.start_fun_quiz()
	ok(school.panel.visible, "викторина открылась")
	school.panel.done.emit(5, "5 из 5")
	ok(GM.money == m0 + 60 and school.lessons_today == lessons, "викторина: +40 грн, не урок")
	school.panel.visible = false

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit(1 if fails else 0)
