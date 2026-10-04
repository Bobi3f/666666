extends SceneTree
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
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	TM.minutes = 12 * 60.0
	var gai = W.get_node("GaiPost")
	gai.check_chance = 0.0
	var C = W.get_node("Car")
	print("== ГАИ")
	C.global_position = Vector3(-100, 0.1, 2.0); C.rotation.y = -PI / 2.0
	C._on_enter(); C.fuel = 30.0
	GM.money = 1000
	C.speed = 15.0  # 54 км/ч
	await process_frame; await process_frame
	ok(GM.money == 1000, "54 км/ч — не штрафуют")
	C.speed = 22.0  # 79 км/ч
	await process_frame; await process_frame
	ok(GM.money == 800 and last().contains("Штраф"), "79 км/ч — штраф: " + last())
	await process_frame
	ok(GM.money == 800, "второй раз сразу не штрафуют")
	gai._cool = 0.0
	W._race.state = 2
	C.speed = 30.0
	await process_frame; await process_frame
	ok(GM.money == 800, "в споре с Колькой не штрафуют")
	W._race.state = 0
	# Спор кончился — останавливаемся, иначе 108 км/ч у поста — уже погоня
	C.speed = 0.0
	print("== Дым и приветствие")
	C.condition = 20.0; C.engine_on = true
	await frames(3)
	ok(C._smoke.emitting and last().contains("дымит"), "побитая машина дымит: " + last())
	C.condition = 90.0
	await frames(3)
	ok(not C._smoke.emitting and C._dust_mat != null, "починили — не дымит")
	C.exit_car()
	TM.minutes = 8 * 60.0
	var vil = child("villagers.gd")
	ok(vil._greeting() == "Доброе утро!", "утром здороваются: " + vil._greeting())
	TM.minutes = 19 * 60.0
	ok(vil._greeting() == "Добрый вечер!", "вечером: " + vil._greeting())
	print("== Грибы")
	var MS = W.get_node("Mushrooms"); var NM = root.get_node("NeedsManager"); var SM = root.get_node("SaveManager")
	TM.day = 2; TM.minutes = 7 * 60.0
	await process_frame
	ok(MS._spots.size() == 12, "летом утром в лесу грибов: %d" % MS._spots.size())
	var good := -1
	for i in MS._spots.size():
		if MS.KINDS[int(MS._spots[i][1])][0] != "мухомор": good = i; break
	var sn: int = NM.snacks
	MS._pick(good)
	ok(NM.snacks > sn and last().contains("еды") and not MS._nodes[good].visible, "срезал гриб: " + last())
	MS._pick(good)
	ok(MS._picked.size() == 1, "второй раз тот же не сорвать")
	SM.save_game(true)
	MS._picked.clear(); MS._update_nodes()
	SM.load_game()
	ok(MS._picked.size() == 1 and not MS._nodes[good].visible, "сорванные сохраняются")
	TM.day = 3; TM.minutes = 7 * 60.0
	await process_frame
	ok(MS._picked.is_empty() and MS._spots.size() == 12, "назавтра выросли новые")
	TM.day = 9; TM.minutes = 7 * 60.0
	await process_frame
	ok(MS._spots.size() == 26, "осенью грибов вдвое больше: %d" % MS._spots.size())
	TM.day = 16; TM.minutes = 7 * 60.0
	await process_frame
	ok(MS._spots.size() == 0 and not MS._nodes[0].visible, "зимой грибов нет")
	print("== Очередь сообщений")
	var hud = child("hud.gd")
	hud._queue.clear(); hud._msg.text = ""; hud._msg_time = 0.0
	hud.show_message("первое")
	hud.show_message("второе")
	hud.show_message("второе")
	ok(hud._msg.text == "первое" and hud._queue.size() == 1, "второе ждёт, дубль не добавился")
	await frames(150)
	ok(hud._msg.text == "второе" and hud._queue.is_empty(), "через пару секунд — второе")
	print("== Животные и радио")
	var sl = child("street_life.gd")
	TM.day = 20; TM.minutes = 6.9 * 60.0
	await frames(3)
	TM.minutes = 7.02 * 60.0
	await frames(30)
	var cow: Dictionary = sl._cows[0]
	var cm: ShaderMaterial = cow.mesh.material_override
	ok(float(cm.get_shader_parameter("amount")) > 0.9 and float(cm.get_shader_parameter("wag")) > 0.1, "корова идёт на луг — ноги шагают, хвост машет")
	var P = W.get_node("Player")
	if GM.vehicle:
		GM.vehicle.speed = 0.0; GM.vehicle.velocity = Vector3.ZERO
		GM.vehicle.exit_car()
		await frames(3)
	var dog: Dictionary = vil._dogs[0]
	P.global_position = (dog.node as Node3D).global_position + Vector3(2, 0.2, 0)
	await frames(90)
	var dm: ShaderMaterial = (dog.node.get_child(0) as MeshInstance3D).material_override
	ok(float(dm.get_shader_parameter("wag")) > 0.4, "подошёл к собаке — виляет хвостом")
	var radio = W.get_node("Radio")
	TM.day = 13
	var news := ""
	for i in 4:
		var n: String = radio._news()
		if n.contains("Завтра воскресенье"): news = n
	ok(news != "", "по радио в субботу: " + news)
	print("== Карта")
	var map = child("map.gd")
	ok(map._tex_vp != null and map._tex_vp.size.x >= 1000, "местность карты — готовая текстура")
	map._canvas.visible = true
	await process_frame; await process_frame
	ok(not map._mini.visible, "открыта большая карта — мини-карта прячется")
	map._canvas.visible = false
	await process_frame; await process_frame
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
