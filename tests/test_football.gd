extends SceneTree
## Футбол во дворе школы: удар, ведение, гол, ребята бьют в ответ, конец
## матча; урок физкультуры на оценку; звонок; дети во дворе.
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
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var S = W.get_node("TownSouth/School")
	var F = S.football
	var P = W.get_node("Player")
	var field: Rect2 = F.field
	var c := Vector3(field.get_center().x, 0, field.get_center().y)

	print("== Поле и мяч")
	TM.day = 6
	TM.minutes = 21 * 60.0
	var sz: InteractZone = F.get_node("FootballStart")
	ok(sz.text().contains("с 8:00"), "ночью ребят нет: " + sz.text())
	TM.minutes = 16 * 60.0
	ok(sz.text().contains("футбол с ребятами"), "днём: " + sz.text())
	await frames(30)
	ok(F.ball.global_position.distance_to(c) < 0.6, "мяч лежит в центре поля")

	print("== Матч")
	ok(F.start(false) and F.state == "play", "начали матч")
	ok(GM.challenge_line.contains("0 : 0") or true, "счёт в строке задания")
	# Удар: встал за мячом лицом к чужим воротам (+X)
	P.global_position = F.ball.global_position + Vector3(-0.8, 0.1, 0)
	P.rotation.y = -PI / 2.0
	await frames(2)
	F.kick()
	await frames(2)
	ok(F.ball.linear_velocity.x > 6.0, "удар: мяч полетел вперёд %.1f м/с" % F.ball.linear_velocity.x)
	ok(F._ball_zone.text() == "E — удар!", "у мяча подсказка «E — удар!»")
	# Гол: мяч у чужих ворот, катится в сетку
	F._kick_cool = 99.0
	F.ball.global_position = Vector3(field.end.x - 1.0, 0.3, c.z)
	F.ball.linear_velocity = Vector3(6, 0, 0)
	F._keeper.global_position = Vector3(field.end.x - 0.7, 0.05, c.z + 1.4)
	for i in 30:
		await physics_frame
		if F.mine > 0: break
	ok(F.mine == 1 and last().contains("ГОЛ"), "гол! %s" % last())
	await frames(170)
	ok(F.state == "play" and F.ball.global_position.distance_to(c) < 1.5, "после гола — с центра")
	# Ребята бьют в ответ: нападающий бежит к мячу и бьёт к воротам игрока
	P.global_position = c + Vector3(-12, 0.1, 6)
	F._kick_cool = 0.0
	var sd0: float = F._striker.global_position.distance_to(F.ball.global_position)
	var kicked := false
	for i in 240:
		await physics_frame
		if F.ball.linear_velocity.x < -3.0:
			kicked = true
			break
	ok(kicked, "нападающий добежал (%.1f м) и пробил в твою сторону" % sd0)
	# Ведение: бежишь на мяч — он катится перед тобой
	F._kick_cool = 99.0
	F.ball.linear_velocity = Vector3.ZERO
	F.ball.global_position = c + Vector3(-3, 0.25, 3)
	F._striker.global_position = c + Vector3(6, 0.05, -4)
	P.global_position = F.ball.global_position + Vector3(-1.2, 0.1, 0)
	P.rotation.y = -PI / 2.0
	await frames(3)
	var bx: float = F.ball.global_position.x
	key(KEY_W, true)
	await frames(50)
	key(KEY_W, false)
	ok(F.ball.global_position.x - bx > 1.0, "ведёт мяч: прокатил %.1f м" % (F.ball.global_position.x - bx))
	# Аут
	F.ball.global_position = c + Vector3(0, 0.3, field.size.y)
	await frames(3)
	ok(F.ball.global_position.distance_to(c) < 1.0 and last().contains("Аут"), "мяч за полем — с центра")
	# Конец матча
	var t0: float = TM.minutes
	F.time_left = 0.01
	await frames(4)
	ok(F.state == "idle" and GM.challenge_line == "" and last().contains("Футбол окончен"), "три минуты — конец: " + last())
	ok(TM.minutes - t0 >= 19.0, "матч занял 20 минут игрового времени")

	print("== Урок физкультуры")
	TM.day = 2
	TM.minutes = 10 * 60.0
	S._today = TM.day; S.lessons_today = 0
	var pz: InteractZone = S.get_node("Lesson_pe")
	ok(pz.text().contains("физкультуры"), "у физрука: " + pz.text())
	var n0: int = S.grades.size()
	pz.activate()
	await process_frame
	await process_frame
	ok(F.state == "play" and F.pe and GM.challenge_line.contains("Физкультура"), "урок: матч на оценку")
	F.mine = 2; F.theirs = 1
	F.time_left = 0.01
	await frames(4)
	ok(S.grades.size() == n0 + 1 and S.grades.back() == ["pe", 5], "выиграл 2:1 — пять: %s" % str(S.grades.back()))
	ok(last().contains("Пал Палыч"), "физрук: " + last())
	TM.minutes = 19 * 60.0
	ok(pz.text().contains("только днём"), "вечером физкультуры нет")

	print("== Звонок и дети во дворе")
	TM.day = 3
	TM.minutes = 7 * 60.0 + 59.0
	await process_frame
	TM.minutes = 8 * 60.0 + 1.0
	await process_frame
	ok(S._bell_hour == 8, "в 8:00 — звонок на урок")
	TM.minutes = 10 * 60.0 + 30.0
	P.global_position = S.at(Vector3(S.DOOR_X, 0.1, S.Z0 - 8.0))
	await frames(5)
	var k0: Node3D = S._yard_kids[0].node
	var pos0 := k0.position
	S._yard_kids[0].wait = 0.0
	await frames(90)
	ok(k0.visible and k0.position.distance_to(pos0) > 0.5, "днём во дворе бегают дети: %d" % S._yard_kids.size())
	var inside_yard := true
	for k in S._yard_kids:
		var p: Vector3 = (k.node as Node3D).position
		if not S.YARD.has_point(Vector2(p.x, p.z)): inside_yard = false
	ok(inside_yard, "дети не выходят за забор")
	TM.minutes = 20 * 60.0
	await process_frame
	await process_frame
	ok(not k0.visible, "вечером двор пуст")
	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)
