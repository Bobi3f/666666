extends SceneTree
## Долгая игра: 30 дней подряд — работа, еда, грибы, покупки, сон,
## сохранения и загрузки. Смотрим, не растёт ли число узлов и не сыпятся ли ошибки.
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
func nodes() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager"); var NM = root.get_node("NeedsManager")
	var PR = root.get_node("Progress"); var SM = root.get_node("SaveManager"); var DL = root.get_node("Daily")
	var AC = root.get_node("Achievements"); var WM = root.get_node("WeatherManager")
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var MS = W.get_node("Mushrooms")
	var P = W.get_node("Player")
	await frames(30)
	var n0 := nodes()
	var orphans0 := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var t0 := Time.get_ticks_msec()
	var min_money := 1 << 30
	for day in 30:
		TM.minutes = 7.2 * 60.0
		await frames(20)
		# Утро: поесть, грибы, работа
		if NM.snacks > 0: NM.eat_snack()
		for i in mini(3, MS._spots.size()): MS._pick(i)
		NM.energy = 100.0
		W.warehouse_job.simulate_all()
		await frames(10)
		W.kolkhoz_job.simulate_all()
		await frames(10)
		# Днём погуляли по деревне, посмотрели жизнь
		P.global_position = Vector3(-100, 0.2, -40)
		TM.minutes = 13 * 60.0
		await frames(40)
		TM.minutes = 19.5 * 60.0
		await frames(40)
		# Покупки по ходу игры
		if day == 5: GM.money += 12000; PR.upgrade_house()
		if day == 8: PR.add_item("tv"); PR.add_item("dog")
		if day == 12: GM.money += 30000; PR.upgrade_house()
		if day == 14: GM.money += 20000; DL.buy("kiosk")
		if day == 16: PR.add_item("greenhouse")
		# Вечером в кровать
		NM.energy = 30.0
		W._sleep()
		await frames(10)
		min_money = mini(min_money, GM.money)
		if day % 3 == 2:
			SM.load_game()
			await frames(10)
		if day % 10 == 9:
			print("  день %d: узлов %d, денег %d, сезон %s, достижений %d" % [TM.day, nodes(), GM.money, WM.season_text(), AC.got.size()])
	var n1 := nodes()
	var orphans1 := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	print("  30 дней за %.1f с, узлов было %d, стало %d, сирот %d → %d" % [(Time.get_ticks_msec() - t0) / 1000.0, n0, n1, orphans0, orphans1])
	ok(TM.day >= 31, "прожили 30 дней: день %d" % TM.day)
	ok(n1 < n0 * 1.05 + 50, "узлы не копятся: %d → %d" % [n0, n1])
	ok(orphans1 - orphans0 < 20, "потерянных узлов нет: %d" % (orphans1 - orphans0))
	ok(min_money >= 0, "деньги не уходили в минус: минимум %d" % min_money)
	ok(PR.house_level == 2 and DL.owns("kiosk") and PR.has_item("greenhouse"), "кирпичный дом, ларёк и теплица на месте")
	ok(AC.got.has("year"), "достижение «Четыре сезона»")
	ok(W.get_node("HomeItems").get_child_count() >= 3, "покупки стоят дома после перестроек и загрузок")
	# Не оставляем сохранение другим тестам
	if FileAccess.file_exists(SM.PATH): DirAccess.remove_absolute(SM.PATH)
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
