extends SceneTree
## Школа № 1: вход, коридор и пять кабинетов; уроки математики, литературы,
## рисования и лепки — у каждого своё задание; оценки, аттестат, буфет;
## школа лёгкая для телефона.
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
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [W.get_node("Player").get_rid()]
	return W.get_world_3d().direct_space_state.intersect_ray(q)
func last() -> String:
	return root.get_node("GameManager").get_meta("last", "")

func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager")
	var NM = root.get_node("NeedsManager"); var PR = root.get_node("Progress")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	var S = W.get_node("TownSouth/School")
	var LP = S.panel
	var P = W.get_node("Player")
	await frames(3)

	print("== Здание")
	ok(ray(Vector3(S.DOOR_X, 1.0, S.Z0 - 2.0), Vector3(S.DOOR_X, 1.0, S.Z0 + 3.0)).is_empty(), "входная дверь открыта")
	ok(not ray(Vector3(S.DOOR_X - 6.0, 1.0, S.Z0 - 2.0), Vector3(S.DOOR_X - 6.0, 1.0, S.Z0 + 3.0)).is_empty(), "стены сплошные")
	ok(ray(Vector3(S.DOOR_X, 1.0, S.Z0 + 1.0), Vector3(S.DOOR_X, 1.0, (S.ZN + S.ZS) * 0.5)).is_empty(), "из вестибюля — в коридор")
	for r in S.ROOMS:
		var dx: float = r[6]
		var inside := (float(r[4]) + float(r[5])) * 0.5
		ok(ray(Vector3(dx, 1.0, (S.ZN + S.ZS) * 0.5), Vector3(dx, 1.0, inside)).is_empty(), "из коридора — в кабинет «%s»" % r[1])
	P.global_position = Vector3(S.DOOR_X, 0.1, S.Z0 + 2.0)
	await frames(30)
	ok(P.global_position.z > S.Z0 and absf(P.global_position.y) < 0.5, "игрок внутри на полу: %s" % str(P.global_position.round()))
	for id in ["math", "lit", "art", "clay"]:
		ok(S.has_node("Lesson_" + id), "место для урока: " + S.SUBJECTS[id])
	ok(S.has_node("Buffet"), "буфет в столовой")
	# Лёгкость для телефона: без настоящих ламп, внутренности — только вблизи
	var meshes := 0
	var lights := 0
	for c in S.get_children():
		if c is MeshInstance3D:
			meshes += 1
			ok((c as MeshInstance3D).visibility_range_end > 0.0 and (c as MeshInstance3D).visibility_range_end <= 50.0, "%s рисуется только вблизи" % c.name)
		if c is Light3D: lights += 1
	ok(meshes <= 4 and lights == 0, "мешей в школе: %d, ламп-источников: %d" % [meshes, lights])

	print("== Уроки")
	TM.day = 1; TM.minutes = 6 * 60.0
	var mz: InteractZone = S.get_node("Lesson_math")
	ok(mz.text().contains("уроков сейчас нет"), "до восьми уроков нет: " + mz.text())
	TM.minutes = 9 * 60.0
	ok(mz.text().contains("сесть за парту") and mz.text().contains("Мат 0/2"), "в 9:00 — математика: " + mz.text())
	ok((S.get_node("Lesson_art") as InteractZone).text().contains("мольберт"), "в ИЗО — к мольберту")
	ok((S.get_node("Lesson_clay") as InteractZone).text().contains("гончарный круг"), "в лепке — за гончарный круг")
	# Математика: четыре примера, все верно — пять
	S.start_lesson("math")
	ok(LP.visible and paused and LP.mode == "quiz" and LP._items.size() == 4, "математика: четыре примера, игра на паузе")
	var item: Array = LP._items[0]
	ok(item[1] != item[2] and item[1] != item[3] and item[2] != item[3], "ответы разные: %s" % str(item))
	for i in 4: LP.answer(LP.right_index())
	ok(not LP.visible and not paused, "урок кончился — игра идёт")
	ok(S.grades.back() == ["math", 5] and last().contains("пять"), "все примеры верно — пять: " + last())
	ok(absf(TM.minutes - (9 * 60.0 + 45.0)) < 1.0, "урок идёт 45 минут")
	# Литература: всё неверно — два
	S.start_lesson("lit")
	ok(LP._items.size() == 3 and LP._question.text.length() > 12, "литература: три вопроса — " + LP._question.text)
	for i in 3: LP.answer((LP.right_index() + 1) % 3)
	ok(S.grades.back() == ["lit", 2], "ни одного верно — два")
	# Рисование: провести по контуру — пять, каракули — два
	S.start_lesson("art")
	ok(LP.mode == "draw" and LP.canvas().target.size() > 20, "рисование: контур из %d точек" % LP.canvas().target.size())
	var line := PackedVector2Array()
	for p in LP.canvas().target: line.append(p)
	LP.canvas().strokes = [line]
	LP.finish_art()
	ok(S.grades.back() == ["art", 5], "обвёл контур — пять: " + last())
	# Лепка: повторил силуэт — пять
	S.start_lesson("clay")
	var cv = LP.canvas()
	ok(LP.mode == "clay" and cv.goal.size() == cv.SLICES, "лепка: силуэт на круге")
	var s0: float = cv.score()
	for i in cv.SLICES:
		var y: float = 0.92 - float(i) / (cv.SLICES - 1) * 0.84
		for k in 4: cv.touch(Vector2(0.5 + cv.goal[i] * 0.4, y))
	ok(cv.score() > s0 and cv.score() > 0.8, "ведёт пальцем по пунктиру — глина принимает форму: %.2f → %.2f" % [s0, cv.score()])
	LP.finish_art()
	ok(S.grades.back()[0] == "clay" and int(S.grades.back()[1]) >= 4, "лепка — %s" % str(S.grades.back()))
	S.start_lesson("math")
	ok(not LP.visible and last().contains("хватит"), "пятый урок за день — нельзя")
	# Рисование каракулями
	TM.day = 2; TM.minutes = 10 * 60.0
	S.start_lesson("art")
	LP.canvas().strokes = [PackedVector2Array([Vector2(0.02, 0.02), Vector2(0.05, 0.98), Vector2(0.98, 0.03)])]
	LP.finish_art()
	ok(S.grades.back() == ["art", 2], "каракули — два")
	TM.day = 6
	ok(S.lesson_time() == "", "в субботу уроков нет")
	TM.day = 2; TM.minutes = 19 * 60.0
	for i in 5: await process_frame
	ok(S.lesson_time() == "evening" and not S._kids.visible and S._teachers.visible, "вечерняя школа: ребят нет, учителя есть")
	TM.minutes = 10 * 60.0
	for i in 5: await process_frame
	ok(S._kids.visible, "днём в классах ребята")

	print("== Аттестат")
	S.grades = [["math", 5], ["math", 4], ["lit", 5], ["lit", 4], ["art", 5], ["clay", 5], ["clay", 4]]
	S._today = TM.day; S.lessons_today = 0
	GM.money = 100
	ok(not PR.has_doc("school_cert"), "пока не все предметы — аттестата нет")
	S.start_lesson("art")
	var line2 := PackedVector2Array()
	for p in LP.canvas().target: line2.append(p)
	LP.canvas().strokes = [line2]
	LP.finish_art()
	ok(PR.has_doc("school_cert") and GM.money == 100 + S.CERT_BONUS, "по два урока каждого предмета — выпускной: " + last())

	print("== Буфет и сохранение")
	GM.money = 100
	var sn: int = NM.snacks
	S.buy_buffet()
	ok(NM.snacks == sn + 1 and GM.money == 100 - S.BUFFET_PRICE, "в буфете пирожок и компот")
	var st: Dictionary = S.save_state()
	S.grades = []
	S.load_state(st)
	ok(S.grades.size() == 8 and S.count("art") == 2, "оценки сохраняются")
	S.load_state({"lessons": 3, "grades": [5, 4, 2]})
	ok(S.grades.size() == 3 and S.count("math") == 3, "старое сохранение читается")
	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)
