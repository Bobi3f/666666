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

	# Надписи не выходят за рамки: ширина и высота текста — не больше рамки
	var font := ThemeDB.fallback_font
	var worst := 0.0
	var checked := 0
	for v in W.get_tree().get_nodes_in_group("vehicles"):
		for l in (v as Node).find_children("*", "Label3D", true, false):
			var lb := l as Label3D
			if lb == (v as Vehicle)._sale or lb.text == "":
				continue
			var w := 0.0
			for line in lb.text.split("\n"):
				w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, lb.font_size).x * lb.pixel_size)
			worst = maxf(worst, w)
			checked += 1
	var ij: Label3D = null
	var ju: Label3D = null
	for c in I._paint_mesh.get_children():
		if c is Label3D and c.text == "ИЖ": ij = c
		if c is Label3D and c.text == "ЮПИТЕР 5": ju = c
	var wij := font.get_string_size("ИЖ", HORIZONTAL_ALIGNMENT_LEFT, -1, ij.font_size).x * ij.pixel_size
	var wju := font.get_string_size("ЮПИТЕР 5", HORIZONTAL_ALIGNMENT_LEFT, -1, ju.font_size).x * ju.pixel_size
	ok(wij <= 0.171 and wju <= 0.201, "эмблемы в рамках: «ИЖ» %.2f ≤ 0.17 м, «ЮПИТЕР 5» %.2f ≤ 0.2 м" % [wij, wju])
	ok(checked > 10 and worst <= 1.31, "все надписи на технике (%d) не шире своих рамок: самая широкая %.2f м" % [checked, worst])

	# «Жигули» — по чертежу ВАЗ-2106: база 2424, длина 4166, высота 1440 мм
	var C: Vehicle = W.get_node("Car")
	var box: AABB = C._paint_mesh.get_aabb()
	var wb: float = absf(C._wheels[2].position.z - C._wheels[0].position.z)
	ok(absf(wb - 2.42) < 0.03 and box.size.z > 4.1 and box.size.z < 4.26 and box.end.y > 1.4 and box.end.y < 1.5, "«Жигули» по чертежу: база %.2f, длина %.2f, высота %.2f м" % [wb, box.size.z, box.end.y])

	# «Ява 350»: надписи «JAWA» и «350», два прибора на руле
	var JV: Vehicle = W.get_node("Moto")
	var jl := []
	for c in JV._paint_mesh.get_children():
		if c is Label3D: jl.append(c.text)
	ok(jl.count("JAWA") == 3 and jl.count("350") == 2 and JV._dash_vp != null and JV._gauge_spots().is_empty(), "«Ява 350»: JAWA на баке и брызговике, 350 на крышках, живой щиток на руле")

	ok(I._dash_vp != null and I._dash_quad != null and I._gauge_spots().is_empty(), "у «ИЖа» на руле — живой щиток (лампочки и спидометр)")

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
