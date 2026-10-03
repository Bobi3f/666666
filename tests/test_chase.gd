extends SceneTree
## Погони: милиция с поста ГАИ гонится за игроком (поймали — штраф,
## оторвался — повезло), а на трассе иногда гоняется за лихачом.
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
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	TM.day = 3
	TM.minutes = 12 * 60.0
	PR.buy_car("car")
	PR.add_category("B")
	var CH: Chase = W.get_node("Chase")
	var gai = W.get_node("GaiPost")
	var C = W.get_node("Car")
	C.global_position = Vector3(-40.0, 0.3, 2.0)
	C.rotation.y = -PI / 2.0
	C._on_enter()
	C.engine_on = true
	await frames(5)

	print("== Погоня: превысил у поста")
	C.global_position = Vector3(-100.0, 0.3, 2.0)
	C.speed = 31.0
	gai._cool = 0.0
	await frames(2)
	ok(CH.state == "chase" and CH.car != null, "110 км/ч мимо поста — погоня: " + last())
	ok(CH.car.get_node("Siren").playing, "воет сирена, мигалка мигает")
	C.speed = 0.0
	C.global_position = Vector3(-40.0, 0.3, 2.0)
	var d0: float = CH.car.global_position.distance_to(C.global_position)
	GM.money = 1000
	for i in 600:
		await physics_frame
		if CH.state != "chase": break
	ok(CH.state == "caught", "стоял — догнали (было %d м)" % int(d0))
	ok(GM.money == 1000 - CH.FINE_CAUGHT and last().contains("Догнали"), "штраф %d грн: %s" % [CH.FINE_CAUGHT, last()])
	ok(GM.challenge_line == "", "строка погони погасла")
	await frames(60 * 9)
	ok(CH.car == null, "милиция уехала")
	ok(not CH.start(gai.BOOTH, "ещё раз"), "второй раз за день не гоняются")

	print("== Погоня: оторвался")
	TM.day = 4
	ok(CH.start(gai.BOOTH + Vector3(6.5, 0.05, 0.8), "Уехал от проверки"), "на следующий день — снова погоня")
	C.global_position = Vector3(520.0, 0.3, 2.0)
	GM.money = 1000
	for i in 60 * 14:
		await physics_frame
		if CH.state != "chase": break
	ok(CH.state == "lost" and GM.money == 1000, "далеко уехал — оторвался, без штрафа: " + last())
	await frames(60 * 9)

	print("== Погоня: уехал от проверки на посту")
	TM.day = 5
	C.global_position = Vector3(-100.0, 0.3, 2.0)
	C.speed = 0.0
	gai.request_stop()
	C.global_position = Vector3(-30.0, 0.3, 2.0)
	await frames(3)
	ok(CH.state == "chase" and CH.reason.contains("проверки"), "уехал от инспектора — погоня: " + CH.reason)
	CH._end("lost")
	await frames(60 * 9)

	print("== Погоня на трассе со стороны")
	var cam := Camera3D.new(); W.add_child(cam)
	cam.global_position = Vector3(0, 3, 15); cam.make_current()
	ok(CH.start_show() and CH.show_cars.size() == 2, "лихач и милиция на трассе")
	var bad: Node3D = CH.show_cars[0]
	var cop: Node3D = CH.show_cars[1]
	var x0 := bad.global_position.x
	await frames(60)
	ok(absf(bad.global_position.x - x0) > 25.0 and absf(cop.global_position.z) < 0.5, "мчатся по разделительной: %d м за секунду" % int(absf(bad.global_position.x - x0)))
	ok((bad.global_position.x - cop.global_position.x) * CH._show_dir > 5.0, "милиция сзади, догоняет")
	CH._show_t = 20.5
	await frames(60 * 5)
	ok(CH.show_state == "stop" and absf(bad.global_position.z) > 4.0, "прижали к обочине: z=%.1f" % bad.global_position.z)
	CH._show_t = 14.5
	await frames(5)
	ok(CH.show_state == "leave", "постояли — уезжают")
	CH._show_t = 26.0
	await frames(5)
	ok(CH.show_cars.is_empty() and CH.show_state == "", "уехали — убраны")
	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)
