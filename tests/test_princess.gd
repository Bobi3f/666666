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
	PR.walk()
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
	PR.walk()
	ok(not PR.following, "отпустил — идёт домой")
	print("== Брелочки и настроение")
	PR.set_mood(70.0)
	ok(PR.kind() and PR.price(0) == 96, "добрая: брелок-коронка со скидкой — %d грн" % PR.price(0))
	GM.money = 1000
	ok(PR.buy(0) and PR.keychains.has("crown") and GM.money == 904, "купил брелок-коронку")
	ok(not PR.buy(0), "второй такой же не продаёт")
	PR.seen_day = TM.day
	TM.day += 5
	PR.catch_up()
	ok(not PR.kind() and PR.price(3) == 90, "5 дней не приходил — злая, сердечко втридорога: %d грн" % PR.price(3))
	ok(PR.girl.mesh == PR._poses[1] and PR._poses[0] != PR._poses[1], "злая — другая поза: руки скрещены, брови сдвинуты")
	ok(PR._charms.mesh != null, "брелок-коронка висит у неё на сумочке")
	PR.walk()
	ok(not PR.following, "злая гулять не идёт")
	PR.buy(3)
	PR.buy(4)
	ok(PR.kind(), "купил два брелочка — помирились (%d)" % int(PR.mood))
	ok(PR.girl.mesh == PR._poses[0], "добрая — снова улыбается")
	PR._update_leashes()
	var hand: Vector3 = PR.girl.to_global(PrincessModel.LEASH_HAND)
	var leash_ok := PR._leashes.size() == 2
	for i in 2:
		var lm: MeshInstance3D = PR._leashes[i]
		var col: Vector3 = PR.pets[i].to_global(Princess.COLLAR)
		if lm.visible:
			leash_ok = leash_ok and absf(lm.global_transform.basis.y.length() - hand.distance_to(col)) < 0.01
	ok(leash_ok, "поводки — от её руки до ошейников собак")
	var st: Dictionary = PR.save_state()
	PR.keychains = []
	PR.load_state(st)
	ok(PR.keychains.size() == 3, "коллекция брелоков сохраняется")
	print("== Окошко")
	PR.talk()
	var panel: PrincessPanel = W.get_tree().get_first_node_in_group("princess_panel")
	ok(panel.visible and paused and panel._list.get_child_count() == 7, "окошко: настроение, гулять и 6 брелоков")
	panel.close_panel()
	TM.minutes = 23 * 60.0
	await frames(2)
	ok(not PR.visible, "ночью дома")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit(1 if fails else 0)
