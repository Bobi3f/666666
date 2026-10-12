extends SceneTree
## Уличный музыкант у сельмага: сидит на лавке с гитарой, днём играет
## песни (рука бьёт по струнам), в дождь молчит, ночью уходит; в кепке
## деньги, по E кидаешь 10 грн — купюр прибавляется, сохраняется.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await frames(10)
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager"); var WM = root.get_node("WeatherManager")
	var SL = root.get_node("SoundLibrary")
	var bk: Busker = W.get_node("Busker")
	ok(bk != null, "музыкант есть")
	ok(bk.global_position.distance_to(W.SHOP_POS) < 10.0, "сидит у сельмага: %s" % str(bk.global_position))
	for n in ["busker_0", "busker_1"]:
		var s: AudioStream = SL.stream(n)
		ok(s != null and s.get_length() > 15.0, "песня %s — %.0f с" % [n, s.get_length() if s else 0.0])
	var body: MeshInstance3D = bk.get_node("Body")
	ok(body.is_in_group("people") and body.get_meta("sit", false), "смотрит на игрока, сидя")
	var cap: MeshInstance3D = bk.get_node("Cap")
	ok(cap.mesh != null and cap.mesh.get_faces().size() > 300, "кепка на земле с деньгами")
	# Лавка — с опорой: в неё не провалиться
	var space: PhysicsDirectSpaceState3D = W.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(bk.global_position + Vector3(0, 2, 0), bk.global_position + Vector3(0, -1, 0))
	var hit: Dictionary = space.intersect_ray(q)
	ok(not hit.is_empty() and hit.position.y > 0.35, "у лавки есть сиденье: %s" % str(hit.get("position", "")))
	# Днём, без дождя — играет, рука ходит
	WM.set_kind(0, 9999.0)
	TM.minutes = 13 * 60.0
	var cam := Camera3D.new(); W.add_child(cam); cam.make_current()
	cam.global_position = bk.global_position + Vector3(0, 2, -5)
	bk._pause = 0.0
	await frames(5)
	ok(bk.visible and bk.playing, "днём играет")
	var b0: Basis = bk.get_node("StrumArm").basis
	await frames(8)
	ok(not bk.get_node("StrumArm").basis.is_equal_approx(b0), "рука бьёт по струнам")
	# Дождь — молчит
	WM.set_kind(3, 9999.0)
	await frames(3)
	ok(not bk.playing, "в дождь не играет")
	WM.set_kind(0, 9999.0)
	# Ночью — ушёл домой
	TM.minutes = 23 * 60.0 + 30.0
	await frames(3)
	ok(not bk.visible and not bk._zone.monitoring, "ночью его нет")
	TM.minutes = 12 * 60.0
	await frames(3)
	# Кинуть в кепку
	ok(bk._zone.text().contains("10 грн"), "подсказка: " + bk._zone.text())
	GM.money = 100
	var faces0: int = bk.get_node("Cap").mesh.get_faces().size()
	bk._player.stop()
	bk._zone.activate()
	await frames(2)
	ok(GM.money == 90 and bk.tips == 1, "кинул 10 грн: осталось %d" % GM.money)
	ok(bk.get_node("Cap").mesh.get_faces().size() > faces0, "купюр в кепке прибавилось")
	ok(bk._player.playing, "после монеты сразу заиграл")
	GM.money = 5
	bk._zone.activate()
	ok(bk.tips == 1 and GM.money == 5, "без денег — не кинуть")
	var st: Dictionary = bk.save_state()
	bk.load_state({})
	ok(bk.tips == 0, "старое сохранение — кепка как была")
	bk.load_state(st)
	ok(bk.tips == 1, "сколько кинул — сохраняется")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
