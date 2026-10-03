extends SceneTree
## «ИЖ Юпитер-5» в автосалоне: купить, нужна категория A, едет быстрее
## «Явы», экзамен на A принимают и на нём.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)
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
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	var PR = root.get_node("Progress"); var GM = root.get_node("GameManager")
	var I: Vehicle = W.get_node("Izh")

	print("== В салоне")
	ok(I.spec.title == "ИЖ Юпитер-5" and I.price == 3500 and not I.owned(), "продаётся за 3500")
	ok(I.spec.two_wheels and I.category() == "A", "мотоцикл, категория A")
	var labels := []
	for c in I._paint_mesh.get_children():
		if c is Label3D: labels.append(c.text)
	ok(labels.has("ИЖ") and labels.has("ЮПИТЕР 5"), "надписи на баке и ящике: " + str(labels))
	ok((I.spec.torque as float) > (W.get_node("Moto").spec.torque as float) and I.tank() > W.get_node("Moto").tank(), "мощнее и с баком больше, чем «Ява»")

	print("== Купил и поехал")
	PR.buy_car("izh")
	ok(I.owned() and not I.may_drive(), "купил, но без категории A не поедет")
	PR.add_category("A")
	ok(I.may_drive(), "с категорией A — можно")
	I.global_position = Vector3(60, 0.3, 2.0)
	I.rotation.y = -PI / 2.0
	await frames(5)
	I._on_enter()
	I.engine_on = true
	I.gear = 1
	key(KEY_W, true)
	await frames(60 * 6)
	key(KEY_W, false)
	ok(I.speed_kmh() > 25.0, "разгоняется: %d км/ч" % int(I.speed_kmh()))
	I.speed = 0.0
	I.exit_car()
	await frames(3)

	print("== Экзамен на A")
	var ex: DrivingChallenge = W.get_node("AutoSchool/ExamA")
	I.global_position = ex.start_pos + Vector3(0, 0.3, -3)
	await frames(3)
	I._on_enter()
	await frames(2)
	ok(ex._vehicle() == I, "экзамен на A засчитывают и на «ИЖе»")

	print("\nИТОГО: " + ("всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ, провалов: %d" % fails))
	quit(1 if fails else 0)
