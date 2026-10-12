extends SceneTree

var msgs: Array[String] = []
var fails := 0
var W: Node
var held := {}

func ok(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)

func tap(code: int) -> void:
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(2)

func release_all() -> void:
	for k in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_SPACE, KEY_SHIFT]:
		key(k, false)
	await frames(2)

func child(script_end: String) -> Node:
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(script_end):
			return c
	return null

func place(v, pos: Vector3, yaw: float) -> void:
	v.global_position = pos
	v.rotation.y = yaw
	v.speed = 0.0
	v.lateral = 0.0
	v.velocity = Vector3.ZERO

func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	current_scene = W
	_run.call_deferred()

func _run() -> void:
	await frames(5)
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager"); var ST = root.get_node("SettingsManager")
	var WM = root.get_node("WeatherManager"); var SM = root.get_node("SaveManager")
	GM.message.connect(func(t): msgs.append(t))
	child("pause_menu.gd")._close()
	WM.set_kind(0, 99999.0); WM.wetness = 0.0
	TM.minutes = 12 * 60.0
	var P = W.get_node("Player"); var C = W.get_node("Car"); var M = W.get_node("Moto")
	# Поток на трассе убираем, чтобы не мешал замерам; вернём для своей проверки
	var tr = child("traffic.gd")
	tr.set_physics_process(false)
	for v in tr.vehicles():
		v.body.global_position.y = -50.0
	ST.auto_gearbox = true
	# Пост ГАИ и погоню выключаем: на разгоне мимо поста быстрее 100 км/ч
	# милиция встаёт сзади и мешает проверить задний ход
	for n in ["GaiPost", "Chase"]:
		var node := W.get_node_or_null(n)
		if node: node.process_mode = Node.PROCESS_MODE_DISABLED
	# Машину — на трассу, носом на +X
	place(C, Vector3(-150, 0.1, 2.0), -PI / 2.0)
	C.fuel = 40.0
	await frames(5)

	print("== Автомат: машина")
	C._on_enter()
	await frames(2)
	ok(GM.vehicle == C and P.car == C, "сел в Жигули")
	key(KEY_W, true)
	await frames(30)
	ok(C.engine_on and C.gear >= 1, "W завёл мотор сам и включил D (%s)" % C.gear_name())
	var gears := {}
	var t := 0
	while t < 60 * 12:
		await physics_frame
		gears[C.gear] = true
		t += 1
	key(KEY_W, false)
	ok(C.speed_kmh() > 90.0 and C.speed_kmh() < 160.0, "за 12 с разогнался до %d км/ч" % int(C.speed_kmh()))
	ok(gears.size() >= 4, "передачи переключались сами: %s" % str(gears.keys()))
	ok(C.rpm < C.spec.redline * 0.99, "не упирается в отсечку: %d об/мин" % int(C.rpm))
	key(KEY_S, true)
	var stopped_at := -1
	for i in 60 * 8:
		await physics_frame
		if C.speed < 0.2 and stopped_at < 0:
			stopped_at = i
	ok(stopped_at > 0 and C.engine_on, "затормозил до нуля, мотор не заглох")
	ok(C.gear == -1 and C.speed < -0.5 and C.speed > -7.0, "держим S на месте — поехал назад (%s, %.1f км/ч)" % [C.gear_name(), C.speed * 3.6])
	ok(C._brake_mat.albedo_color.g < 0.2 and C.braking == false, "задним ходом S — это газ, стопы не горят")
	key(KEY_S, false)
	key(KEY_W, true)
	await frames(120)
	ok(C.gear >= 1 and C.speed > 0.0, "W — остановился и поехал вперёд (%s)" % C.gear_name())
	key(KEY_W, false)
	await release_all()
	key(KEY_S, true); await frames(10)
	ok(C.braking and C._brake_mat.albedo_color.r > 0.9, "при торможении горят стоп-сигналы")
	for i in 200:
		await physics_frame
		if C.speed <= 0.05:
			break
	key(KEY_S, false)
	# Ползёт на холостых в D
	place(C, Vector3(-150, 0.1, 2.0), -PI / 2.0)
	C.gear = 1
	await frames(180)
	ok(C.speed_kmh() > 1.0 and C.speed_kmh() < 12.0, "в D без газа ползёт: %.1f км/ч" % C.speed_kmh())

	print("== Занос и сцепление с дорогой")
	place(C, Vector3(-150, 0.1, 2.0), -PI / 2.0)
	C.speed = 70.0 / 3.6
	C.velocity = -C.global_transform.basis.z * C.speed
	C.gear = 3
	var max_lat := 0.0
	key(KEY_A, true)
	for i in 50:
		await physics_frame
		max_lat = maxf(max_lat, absf(C.lateral))
	key(KEY_A, false)
	ok(max_lat < 2.0, "на асфальте в повороте держит дорогу: занос %.2f м/с" % max_lat)
	await frames(30)
	place(C, Vector3(-150, 0.1, 2.0), -PI / 2.0)
	C.speed = 70.0 / 3.6
	C.velocity = -C.global_transform.basis.z * C.speed
	max_lat = 0.0
	var y0: float = C.rotation.y
	key(KEY_A, true); key(KEY_SPACE, true)
	for i in 50:
		await physics_frame
		max_lat = maxf(max_lat, absf(C.lateral))
	key(KEY_A, false); key(KEY_SPACE, false)
	ok(max_lat > 3.0, "с ручником — занос: %.1f м/с боком" % max_lat)
	await frames(60)
	# Ограничение поворота на скорости: ω ≤ μg/v
	place(C, Vector3(-150, 0.1, 2.0), -PI / 2.0)
	C.speed = 100.0 / 3.6
	C.velocity = -C.global_transform.basis.z * C.speed
	key(KEY_D, true)
	await frames(40)
	var lim: float = 1.15 * 9.8 / absf(C.speed) * 1.01
	ok(absf(C._yaw_rate) <= lim, "на 100 км/ч руль ограничен сцеплением: %.3f ≤ %.3f рад/с" % [absf(C._yaw_rate), lim])
	key(KEY_D, false)
	await frames(10)
	# Трава против асфальта
	var res := []
	for spot in [Vector3(-150, 0.1, 2.0), Vector3(40, 0.1, -105)]:  # луг между пшеницей и пашней
		place(C, spot, -PI / 2.0)
		C.gear = 1
		key(KEY_W, true)
		await frames(60 * 5)
		key(KEY_W, false)
		res.append(C.speed_kmh())
		await release_all()
	ok(res[1] < res[0] - 1.5, "по траве медленнее: асфальт %d, трава %d км/ч за 5 с" % [int(res[0]), int(res[1])])
	C.speed = 0.0; C.velocity = Vector3.ZERO
	await frames(5)

	print("== Механика")
	await tap(KEY_T)
	ok(not ST.auto_gearbox and msgs[-1].contains("МЕХАНИКА"), "T — переключил на механику")
	place(C, Vector3(-150, 0.1, 2.0), -PI / 2.0)
	C.engine_on = false; C.gear = 0; C.clutch = 1.0
	await tap(KEY_W)
	ok(not C.engine_on, "в механике W мотор не заводит")
	await tap(KEY_R)
	ok(C.engine_on, "R — завёл на нейтрали")
	C.clutch = 1.0
	C._shift(1)
	ok(C.gear == 0 and msgs[-1].contains("Скрежет"), "без сцепления — скрежет")
	C.clutch = 0.0
	C._shift(3)
	C.clutch = 1.0
	for i in 120:
		C._update(1.0 / 60.0, 0.0, false, false, false, 0.0)
	ok(not C.engine_on, "бросил сцепление на третьей с места — заглох")
	await tap(KEY_T)
	ok(ST.auto_gearbox, "T — обратно автомат")
	C.exit_car()
	await frames(3)
	ok(GM.vehicle == null and P.car == null, "вышел из машины")

	print("== Мотоцикл Ява")
	place(M, Vector3(-150, 0.1, 2.0), -PI / 2.0)
	M.fuel = 14.0
	C.global_position = Vector3(-121, 0.1, -39.5)
	await frames(3)
	M._on_enter()
	await frames(2)
	ok(GM.vehicle == M, "сел на Яву")
	key(KEY_W, true)
	var t60 := -1.0
	for i in 60 * 10:
		await physics_frame
		if M.speed_kmh() >= 60.0 and t60 < 0.0:
			t60 = i / 60.0
	key(KEY_W, false)
	ok(t60 > 0.0 and t60 < 7.0, "0–60 км/ч за %.1f с" % t60)
	ok(M.speed_kmh() < 140.0, "за 10 с: %d км/ч" % int(M.speed_kmh()))
	key(KEY_D, true)
	await frames(30)
	ok(absf(M._body.rotation.z) > 0.15, "в повороте ложится: крен %.0f°" % rad_to_deg(M._body.rotation.z))
	key(KEY_D, false)
	await frames(60)
	ok(absf(M._body.rotation.z) < 0.1, "на прямой выпрямился")
	key(KEY_S, true)
	await frames(60 * 6)
	await frames(60)
	ok(M.speed > -M.rev_max() - 0.3, "Ява тормозом встала, назад — только шагом (%s, %.1f км/ч)" % [M.gear_name(), M.speed * 3.6])
	key(KEY_S, false)
	M.speed = 0.0
	M.gear = 1
	key(KEY_S, false)
	# Вид сзади. После разгона Ява улетает с трассы к площади и может
	# влететь в клумбу — для проверки вида сажаем заново на дороге
	place(M, Vector3(-150, 0.1, 2.0), -PI / 2.0)
	if GM.vehicle != M:
		M._on_enter()
	await frames(3)
	await tap(KEY_V)
	ok(M._chase.current and M._rider.visible, "V — вид сзади, мотоциклист виден")
	await tap(KEY_V)
	ok(M._camera.current, "V — снова от первого лица")
	# Падение: на скорости в стену СТО
	place(M, Vector3(-86, 0.1, 30.0), 0.0)  # к задней стене гаража (z=20)
	M.speed = 50.0 / 3.6
	M.velocity = -M.global_transform.basis.z * M.speed
	M.engine_on = true
	var fell := false
	for i in 120:
		await physics_frame
		if M.driver == null:
			fell = true
			break
	ok(fell and GM.vehicle == null and msgs[-1].contains("Упал"), "врезался на 50 км/ч — вылетел из седла: %s" % msgs[-1])
	ok(M.condition < 100.0, "Ява побита: %d%%" % int(M.condition))

	print("== АЗС и СТО для мотоцикла")
	C.global_position = Vector3(-121, 0.1, -39.5)
	place(M, Vector3(-110, 0.1, 9.0), 0.0)
	M.fuel = 2.0
	GM.money = 5000
	await frames(3)
	var pump: InteractZone = null
	var garage: InteractZone = null
	for z in _zones(W):
		if z.text().contains("заправить"):
			pump = z
	ok(pump != null and pump.text().contains("в баке"), "колонка видит Яву: " + (pump.text() if pump else "-"))
	pump.activate()
	ok(absf(M.fuel - 14.0) < 0.01, "залил полный бак Явы (14 л)")
	place(M, Vector3(-86, 0.1, 16.0), 0.0)
	await frames(3)
	for z in _zones(W):
		if z.text().contains("починить"):
			garage = z
	ok(garage != null and garage.text().contains("Влтава"), "СТО чинит Яву: " + (garage.text() if garage else "-"))
	garage.activate()
	ok(M.condition == 100.0, "Ява как новая")

	print("== Трасса уступает мотоциклу")
	tr.set_physics_process(true)
	var v0: Dictionary = tr.vehicles()[0]
	place(M, Vector3(v0.body.global_position.x + v0.dir * 25.0, 0.1, v0.dir * 2.0), 0.0)
	await frames(240)
	var gap: float = (M.global_position.x - v0.body.global_position.x) * v0.dir
	ok(v0.speed < 0.5 and gap > 2.0, "машина встала перед Явой: %.1f м" % gap)
	ok((v0.tail as StandardMaterial3D).albedo_color.r > 0.9, "у неё горят стоп-сигналы")
	TM.minutes = 23 * 60.0
	await frames(3)
	ok((v0.head as StandardMaterial3D).albedo_color.r > 0.95, "ночью у трафика горят фары")
	TM.minutes = 12 * 60.0
	place(M, Vector3(-130, 0.1, -41.6), -PI / 2.0)

	print("== Задний ход на мотоцикле и мопеде — шагом, ногами")
	for bike in [M, W.get_node("Moped")]:
		# Каждый на своём месте — мопед не упрётся задом в Яву
		var p0 := Vector3(-130.0 if bike == M else -112.0, 0.1, -41.6)
		place(bike, p0, -PI / 2.0)
		if root.get_node("GameManager").vehicle != bike:
			if root.get_node("GameManager").vehicle: root.get_node("GameManager").vehicle.speed = 0.0; root.get_node("GameManager").vehicle.exit_car()
			await frames(3)
			bike._on_enter()
		bike.engine_on = true
		bike.fuel = 5.0
		bike.gear = 1
		await frames(3)
		key(KEY_S, true)
		await frames(150)
		var back: float = bike.speed
		var moved: float = (bike.global_position - p0).dot(bike.global_transform.basis.z)
		key(KEY_S, false)
		await frames(30)
		ok(bike.gear == -1 and back < -0.6 and back > -bike.rev_max() - 0.3 and moved > 0.8,
			"%s: назад %.1f км/ч, откатился на %.1f м" % [bike.spec.title, -back * 3.6, moved])
		key(KEY_W, true)
		await frames(40)
		key(KEY_W, false)
		await frames(5)
		ok(bike.gear >= 1, "%s: W — снова вперёд (%s)" % [bike.spec.title, bike.gear_name()])
		bike.speed = 0.0
		bike.exit_car()
		await frames(3)
	place(M, Vector3(-130, 0.1, -41.6), -PI / 2.0)

	print("== Сохранение")
	M.fuel = 7.0; M.condition = 55.0
	SM.save_game()
	M.fuel = 14.0; M.condition = 100.0
	SM.load_game()
	await frames(3)
	ok(absf(M.fuel - 7.0) < 0.01 and absf(M.condition - 55.0) < 0.01, "Ява сохраняется: бензин и состояние")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()

func _zones(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is InteractZone:
			out.append(c)
		out.append_array(_zones(c))
	return out
