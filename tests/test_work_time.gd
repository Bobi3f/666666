extends SceneTree
## Работа не перематывает часы: время идёт своим ходом, пока игрок занят
## (стоит на месте, E не нажимается, на экране — сколько осталось);
## смена с переноской — без прыжка часов; настройка «Ход времени».
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func child(script_end: String) -> Node:
	for n in W.get_children():
		if n.get_script() and String(n.get_script().resource_path).ends_with(script_end):
			return n
	for n in W.find_children("*", "", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with(script_end):
			return n
	return null
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await frames(10)
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager")
	var PR = root.get_node("Progress"); var SM = root.get_node("SettingsManager")
	var P = GM.player
	SM.set_time_speed(0)

	print("== Огород: работа идёт, часы не прыгают")
	TM.minutes = 10 * 60.0
	GM.money = 1000
	PR.planted = false
	var t0: float = TM.minutes
	PR.use_garden()
	ok(PR.planted and TM.busy() and absf(TM.work_left - 90.0) < 0.01, "посадил: работа на 90 мин")
	ok(TM.minutes - t0 < 1.0, "часы не перемотаны: +%.2f мин" % (TM.minutes - t0))
	await frames(12)
	var hud = child("hud.gd")
	hud._slow_update()
	ok(hud._goal.text.contains("Сажаю картошку — ещё"), "на экране: " + hud._goal.text.split("\n")[0])
	var l0: float = TM.work_left
	await frames(30)
	ok(TM.work_left < l0 and TM.minutes > t0, "время идёт обычным ходом: осталось %.1f мин" % TM.work_left)

	print("== За работой игрок стоит")
	var a: Vector3 = P.global_position
	GM.move_axis = Vector2(0, -1)
	await frames(30)
	GM.move_axis = Vector2.ZERO
	ok(Vector2(P.global_position.x - a.x, P.global_position.z - a.z).length() < 0.3, "джойстик не двигает: %.2f м" % P.global_position.distance_to(a))
	P._use()
	ok(TM.busy(), "E за работой не отвлекает")

	print("== Работа кончилась — снова свободен")
	TM.speed = 400.0
	var guard := 0
	while TM.busy() and guard < 600:
		await frames(1)
		guard += 1
	TM.speed = 1.0
	ok(not TM.busy() and TM.minutes - t0 >= 89.0 and TM.minutes - t0 < 110.0, "доработал: прошло %.0f мин" % (TM.minutes - t0))
	a = P.global_position
	GM.move_axis = Vector2(0, -1)
	await frames(30)
	GM.move_axis = Vector2.ZERO
	ok(P.global_position.distance_to(a) > 0.5, "снова ходит: %.1f м" % P.global_position.distance_to(a))

	print("== Ход времени")
	var m0: float = TM.minutes
	var w0 := Time.get_ticks_msec()
	await frames(60)
	var normal: float = (TM.minutes - m0) / maxf((Time.get_ticks_msec() - w0) / 1000.0, 0.001)
	SM.set_time_speed(2)
	ok(is_equal_approx(SM.time_rate(), 0.25), "очень медленный: ×0.25")
	m0 = TM.minutes
	w0 = Time.get_ticks_msec()
	await frames(60)
	var slow: float = (TM.minutes - m0) / maxf((Time.get_ticks_msec() - w0) / 1000.0, 0.001)
	ok(slow < normal * 0.5, "часы идут медленнее: %.2f против %.2f мин/с" % [slow, normal])
	SM.set_time_speed(0)

	print("== Сохранение и обморок")
	TM.work(45.0, "Дою коров")
	var st: Dictionary = TM.save_state()
	TM.work_left = 0.0
	TM.load_state(st)
	ok(TM.busy() and absf(TM.work_left - 45.0) < 0.5 and TM.work_what == "Дою коров", "недоделанная работа сохраняется")
	W._faint("Тест.")
	ok(not TM.busy(), "обморок обрывает работу")

	print("== Смена грузчика — без прыжка часов")
	var K = W.kolkhoz_job
	ok(not K.start_prompt().contains("мин"), "подсказка без «по N мин»: " + K.start_prompt())
	TM.minutes = 10 * 60.0
	root.get_node("NeedsManager").energy = 100.0
	K.start()
	t0 = TM.minutes
	K.pick(); K.put_down()
	ok(K.done == 1 and TM.minutes - t0 < 1.0 and not TM.busy(), "положил тюк: часы не перемотаны (done %d, active %s, +%.1f мин)" % [K.done, K.active, TM.minutes - t0])
	K.stop()

	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails else 0)
