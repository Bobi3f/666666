extends SceneTree
## Школа № 1: в дверь можно войти, внутри класс и столовая; уроки по
## расписанию — вопрос и три ответа, оценки, аттестат после десяти уроков.
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
	var P = W.get_node("Player")
	q.exclude = [P.get_rid()]
	return W.get_world_3d().direct_space_state.intersect_ray(q)

func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager")
	var NM = root.get_node("NeedsManager"); var PR = root.get_node("Progress")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	var S = W.get_node("TownSouth/School")
	var P = W.get_node("Player")
	await frames(3)

	print("== Здание")
	var dz: float = S.Z0
	ok(ray(Vector3(S.DOOR_X, 1.0, dz - 2.0), Vector3(S.DOOR_X, 1.0, dz + 3.0)).is_empty(), "дверь открыта — внутрь проходим")
	ok(not ray(Vector3(S.DOOR_X - 5.0, 1.0, dz - 2.0), Vector3(S.DOOR_X - 5.0, 1.0, dz + 3.0)).is_empty(), "стены сплошные")
	ok(ray(Vector3(S.DOOR_X, 1.0, dz + 1.7), Vector3(S.CLASS_WALL_X - 3.0, 1.0, dz + 1.7)).is_empty(), "из вестибюля — проём в класс")
	ok(ray(Vector3(S.DOOR_X, 1.0, dz + 1.7), Vector3(S.CANTEEN_WALL_X + 3.0, 1.0, dz + 1.7)).is_empty(), "и в столовую")
	# Игрок заходит: ставим у двери и идём внутрь
	P.global_position = Vector3(S.DOOR_X, 0.1, dz + 1.5)
	await frames(30)
	ok(P.global_position.z > dz and P.global_position.y > -0.3 and P.global_position.y < 0.5, "игрок стоит внутри на полу: %s" % str(P.global_position.round()))
	var desk: InteractZone = S.get_node("Desk")
	ok(desk != null, "парта для игрока")

	print("== Уроки")
	TM.day = 1  # понедельник
	TM.minutes = 6 * 60.0
	ok(desk.text().contains("Уроков сейчас нет"), "утром до восьми уроков нет: " + desk.text())
	TM.minutes = 9 * 60.0
	ok(desk.text().contains("сесть за парту"), "в 9:00 — урок: " + desk.text())
	S.start_lesson()
	ok(S._panel.visible and paused, "вопрос на экране, игра на паузе")
	var right: int = S._answers.find(S._q[2])
	S.answer(right)
	ok(not paused and not S._panel.visible, "ответил — игра идёт дальше")
	ok(S.grades == [5] and S.lessons == 1, "верный ответ — пять")
	ok(absf(TM.minutes - (9 * 60.0 + 45.0)) < 1.0, "урок идёт 45 минут")
	S.start_lesson()
	S.answer((S._answers.find(S._q[2]) + 1) % 3)
	ok(S.grades == [5, 2] and GM.get_meta("last", "").contains("Два"), "неверный — два и правильный ответ: " + GM.get_meta("last", ""))
	S.start_lesson(); S.answer(S._answers.find(S._q[2]))
	S.start_lesson(); S.answer(S._answers.find(S._q[2]))
	S.start_lesson()
	ok(not S._panel.visible and GM.get_meta("last", "").contains("хватит"), "больше четырёх уроков в день — нельзя")
	TM.day = 6; TM.minutes = 10 * 60.0
	ok(S.lesson_time() == "", "в субботу уроков нет")
	TM.day = 2; TM.minutes = 19 * 60.0
	ok(S.lesson_time() == "evening", "вечерняя школа в 19:00")
	for i in 5: await process_frame
	ok(not S._kids[0].visible and S._teacher.visible, "вечером ребят нет, учительница есть")
	TM.minutes = 10 * 60.0
	for i in 5: await process_frame
	ok(S._kids[0].visible, "днём в классе ребята")

	print("== Аттестат")
	S.lessons = 9
	S.grades = [5, 5, 4, 5, 2, 5, 5, 5, 5]
	S._today = TM.day; S.lessons_today = 0
	GM.money = 100
	S.start_lesson(); S.answer(S._answers.find(S._q[2]))
	ok(PR.has_doc("school_cert") and GM.money == 100 + S.CERT_BONUS, "десятый урок — выпускной, аттестат и премия: " + GM.get_meta("last", ""))
	ok(PR.DOC_NAMES.has("school_cert"), "аттестат в списке документов")

	print("== Буфет и сохранение")
	GM.money = 100
	var sn: int = NM.snacks
	S.buy_buffet()
	ok(NM.snacks == sn + 1 and GM.money == 100 - S.BUFFET_PRICE, "в буфете пирожок и компот")
	var st: Dictionary = S.save_state()
	S.lessons = 0; S.grades = []
	S.load_state(st)
	ok(S.lessons == 10 and S.grades.size() == 10, "оценки сохраняются")
	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)
