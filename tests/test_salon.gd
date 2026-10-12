extends SceneTree
var fails := 0
var W
var held := {}
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func key(k: int, down: bool) -> void:
	if bool(held.get(k, false)) == down: return
	held[k] = down
	var e := InputEventKey.new()
	e.physical_keycode = k; e.keycode = k; e.pressed = down
	Input.parse_input_event(e)
func last() -> String:
	return W.get_node("/root/GameManager").get_meta("last", "")
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func accel(V, pos: Vector3, secs: float) -> float:
	V.global_position = pos; V.rotation.y = -PI / 2.0; V.speed = 0.0; V.velocity = Vector3.ZERO
	V.condition = 100.0
	if W.get_node("/root/GameManager").vehicle != V: V._on_enter()
	V.fuel = 30.0
	await frames(3)
	key(KEY_W, true)
	await frames(int(60 * secs))
	key(KEY_W, false)
	var v: float = V.speed_kmh()
	V.speed = 0.0; V.velocity = Vector3.ZERO
	V.exit_car()
	await frames(3)
	# Отгоняем в сторону, чтобы следующая машина в неё не врезалась
	V.global_position = Vector3(185, 0.1, -15.0 - 12.0 * ["car", "niva", "volga", "truck"].find(V.kind))
	await frames(2)
	return v
func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress"); var TM = root.get_node("TimeManager")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("traffic.gd"): c.queue_free()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c.get_script() and c.get_script().resource_path.ends_with("street_life.gd"): c.set_physics_process(false)
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	TM.minutes = 11 * 60.0
	var P = W.get_node("Player"); var C = W.get_node("Car")
	var N = W.get_node("Niva"); var V = W.get_node("Volga"); var T = W.get_node("Truck")

	print("== Автосалон")
	ok(not N.owned() and not V.owned() and not T.owned() and not C.owned() and W.get_node("Moped").owned(), "в салоне три машины, «Жигули» у дома продаются, свой — мопед")
	root.get_node("Progress").buy_car("car"); root.get_node("Progress").license = true
	ok(N._zone.text().contains("22000") and T._zone.text().contains("грузовик"), "подсказка с ценой: " + N._zone.text())
	GM.money = 1000
	P.global_position = N.global_position + Vector3(2.2, 0.2, 0)
	await frames(3)
	N._zone.activated.emit()
	await frames(2)
	ok(not N.owned() and GM.vehicle == null and last().contains("Не хватает"), "без денег не купить и не сесть: " + last())
	GM.money = 100000
	for car in [N, V, T]:
		car._zone.activated.emit()
	await frames(2)
	ok(N.owned() and V.owned() and T.owned() and GM.money == 100000 - 22000 - 36000 - 28000, "купил все три, осталось %d" % GM.money)
	ok(N._zone.text().contains("сесть за руль"), "купленная — садись: " + N._zone.text())

	print("== Характер машин")
	var a_z: float = await accel(C, Vector3(-150, 0.1, 2.0), 6.0)
	var a_v: float = await accel(V, Vector3(-150, 0.1, 2.0), 6.0)
	var a_t: float = await accel(T, Vector3(-150, 0.1, -2.0), 6.0)
	print("       за 6 с по трассе: Жигули %d, Волга %d, ГМЗ-53 %d км/ч" % [int(a_z), int(a_v), int(a_t)])
	ok(a_v > a_z and a_t < a_z, "Волга быстрее Жигулей, грузовик медленнее")
	var g_z: float = await accel(C, Vector3(2, 0.1, -100), 5.0)
	var g_n: float = await accel(N, Vector3(2, 0.1, -100), 5.0)
	print("       за 5 с по пашне: Жигули %d, Нива %d км/ч" % [int(g_z), int(g_n)])
	ok(g_n > g_z + 3.0, "Нива по бездорожью быстрее Жигулей")

	print("== Развоз на грузовике")
	GM.money = 0
	PR.delivery_active = false
	T.global_position = Town.w(Vector3(27, 0.1, 22)); T.rotation.y = 0.0; T.speed = 0.0; T.velocity = Vector3.ZERO
	T._on_enter(); await frames(3)
	for z in W.get_children():
		if z is InteractZone and z.text().contains("развоз"): z.activate(); break
	ok(PR.delivery_active and GM.delivery_vehicle == T and PR.delivery_mult == 2.0, "хлеб в кузове ГМЗ-53, плата вдвое")
	T.global_position = Vector3(-51, 0.1, -24); await frames(5)
	ok(GM.money >= 1000, "развоз на грузовике: +%d грн" % GM.money)
	T.exit_car(); await frames(3)

	print("== Сохранение")
	var st: Dictionary = PR.save_state()
	var vs: Dictionary = N.save_state()
	PR.load_state({})
	ok(not N.owned(), "новая игра — машины снова в салоне")
	PR.load_state(st)
	N.load_state(vs)
	ok(N.owned() and V.owned() and T.owned(), "после загрузки машины твои")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
