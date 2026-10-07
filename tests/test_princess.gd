extends SceneTree
## Принцесса — девушка игрока: корона, две собачки и кот рядом; позвать
## гулять — идёт рядом с игроком, отпустить — уходит на свою прогулку.
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
	await frames(12)
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager"); var NM = root.get_node("NeedsManager")
	var PR: Princess = W.princess
	TM.minutes = 12 * 60.0
	await frames(3)
	ok(PR != null and PR.visible and PR.pets.size() == 3, "Принцесса гуляет с тремя питомцами")
	ok(PR.girl.get_child_count() >= 2 and PR.girl.mesh.get_aabb().size.y > 1.5, "взрослая девушка, корона на голове")
	var P: Node3D = GM.player
	P.global_position = PR.girl.global_position + Vector3(1.5, 0.1, 0)
	NM.energy = 50.0
	PR.talk()
	ok(PR.following and NM.energy > 55.0, "позвал гулять — обняла, сил прибавилось")
	P.global_position += Vector3(20, 0, 0)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 10000:
		await process_frame
		if PR.girl.global_position.distance_to(P.global_position) < 3.0: break
	ok(PR.girl.global_position.distance_to(P.global_position) < 3.0, "идёт за игроком: %.1f м" % PR.girl.global_position.distance_to(P.global_position))
	var pet_d := 0.0
	await create_timer(2.0).timeout
	for p in PR.pets: pet_d = maxf(pet_d, (p as Node3D).global_position.distance_to(PR.girl.global_position))
	ok(pet_d < 3.5, "собачки и кот рядом: до %.1f м" % pet_d)
	PR.talk()
	ok(not PR.following, "отпустил — идёт домой")
	TM.minutes = 23 * 60.0
	await frames(2)
	ok(not PR.visible, "ночью дома")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit(1 if fails else 0)
