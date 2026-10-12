extends SceneTree
## «Изар 525» (как BMW E34): стоит на авторынке за 52 000, нужны права B,
## быстрее «Волжанки», свои поворотники в фарах и фонарях, повторители на
## крыльях, два прибора в щитке, в такси платят больше всех, сохраняется.
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


## Разгон по трассе: [секунд до 100 км/ч (или -1), скорость через secs].
func accel(V: Vehicle, pos: Vector3, secs: float) -> Array:
	V.global_position = pos; V.rotation.y = -PI / 2.0; V.speed = 0.0; V.velocity = Vector3.ZERO
	V.condition = 100.0
	if W.get_node("/root/GameManager").vehicle != V: V._on_enter()
	V.fuel = 40.0
	await frames(3)
	key(KEY_W, true)
	var t100 := -1.0
	for i in int(60 * secs):
		await physics_frame
		if t100 < 0.0 and V.speed_kmh() >= 100.0:
			t100 = i / 60.0
	key(KEY_W, false)
	var v: float = V.speed_kmh()
	V.speed = 0.0; V.velocity = Vector3.ZERO
	V.exit_car()
	await frames(3)
	V.global_position = Vector3(185, 0.1, -15.0 - 12.0 * ["volga", "bmw"].find(V.kind))
	await frames(2)
	return [t100, v]


func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("traffic.gd"): c.queue_free()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
		if c.get_script() and c.get_script().resource_path.ends_with("street_life.gd"): c.set_physics_process(false)
	root.get_node("WeatherManager").set_kind(0, 9999.0)
	root.get_node("TimeManager").minutes = 11 * 60.0
	var P = W.get_node("Player")
	var I: Vehicle = W.get_node("Izar")
	var V: Vehicle = W.get_node("Volga")

	print("== На авторынке")
	ok(I.kind == "bmw" and I.spec.title == "Изар 525" and I.price == 52000, "«Изар 525» за %d грн" % I.price)
	ok(not I.owned() and I.global_position.distance_to(Town.w(Vector3(231, 0.1, 24))) < 1.0, "стоит на авторынке, ничей")
	ok(I._zone.text().contains("52000") and I._zone.text().contains("пятёрка"), "подсказка: " + I._zone.text())
	ok(I.category() == "B", "нужны права B")
	var labels := []
	for n in I.find_children("*", "Label3D", true, false):
		labels.append((n as Label3D).text)
	ok(labels.has("525i"), "на крышке багажника — «525i»: %s" % str(labels))

	print("== Покупка")
	GM.money = 30000
	P.global_position = I.global_position + Vector3(2.4, 0.2, 0)
	await frames(3)
	I._zone.activated.emit()
	await frames(2)
	ok(not I.owned() and GM.vehicle == null and last().contains("Не хватает"), "на 30 000 не купить: " + last())
	GM.money = 60000
	I._zone.activated.emit()
	await frames(2)
	ok(I.owned() and GM.money == 8000, "купил, осталось %d" % GM.money)
	ok(not I.may_drive(), "без прав B за руль нельзя")
	PR.add_category("B"); PR.license = true
	ok(I.may_drive(), "с правами B — можно")

	print("== Быстрее «Волжанки»")
	PR.buy_car("volga")
	var rv: Array = await accel(V, Vector3(-150, 0.1, 2.0), 12.0)
	var ri: Array = await accel(I, Vector3(-150, 0.1, 2.0), 12.0)
	print("       до 100 км/ч: Волжанка %.1f с, Изар %.1f с; за 12 с: %d и %d км/ч" % [rv[0], ri[0], int(rv[1]), int(ri[1])])
	ok(ri[0] > 0.0 and (rv[0] < 0.0 or ri[0] < rv[0] - 0.4), "до сотни быстрее «Волжанки»")
	ok(ri[1] > rv[1] + 5.0, "за 12 с разгоняется сильнее")
	# Наибольшая скорость: где сила мотора на 5-й равна сопротивлению
	var top_i: float = top_speed(I)
	var top_v: float = top_speed(V)
	print("       наибольшая: Волжанка %d, Изар %d км/ч" % [int(top_v), int(top_i)])
	ok(top_i > top_v + 25.0 and top_i < 260.0, "наибольшая скорость выше «Волжанки» и в пределах спидометра до 260")

	print("== Поворотники, приборы, колёса")
	var sides := {-1: 0, 1: 0}
	for l in I._turn_lamps:
		sides[int(l[1])] += 1
	ok(I._model_turns.size() == 6 and sides[-1] == 3 and sides[1] == 3, "по три поворотника: в углу фар, в фонаре, на крыле: %s" % str(sides))
	var fr := 0
	var re := 0
	var wing := 0
	for t in I._model_turns:
		var p: Vector3 = t[0]
		if p.z < -2.0: fr += 1
		elif p.z > 2.0: re += 1
		else: wing += 1
	ok(fr == 2 and re == 2 and wing == 2, "спереди %d, сзади %d, на крыльях %d" % [fr, re, wing])
	ok(I._gauge_spots().size() == 2, "в щитке два больших прибора")
	var dial := []
	for n in I._gauge_holders[0].get_children():
		if n is Label3D: dial.append((n as Label3D).text)
	ok(dial.has("240") and dial.has("120"), "спидометр в салоне до 240: %s" % str(dial))
	var wheels_ok: bool = I._wheels.size() == 4
	for w in I._wheels:
		var aabb: AABB = ((w as Node3D).get_child(0) as MeshInstance3D).mesh.get_aabb()
		wheels_ok = wheels_ok and absf(aabb.size.y - 0.634) < 0.03
	ok(wheels_ok, "четыре литых колеса, радиус 0,317 м")

	print("== Кузов и звук")
	var tris := 0
	var mesh: Mesh = I._paint_mesh.mesh
	for si in mesh.get_surface_count():
		tris += (mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var v_tris := 0
	var vm: Mesh = V._paint_mesh.mesh
	for si in vm.get_surface_count():
		v_tris += (vm.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print("       треугольников: Изар %d, Волжанка %d" % [tris, v_tris])
	ok(tris < 16000, "гладкий кузов, но телефону по силам: %d треугольников" % tris)
	# Борт гладкий: у соседних вершин одной точки борта нормали плавно
	# поворачиваются, а не прыгают на 90°, как у коробки
	var arr: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var slanted := 0
	for i in verts.size():
		var p: Vector3 = verts[i]
		if absf(p.z) < 0.5 and p.y > 0.3 and p.y < 0.9 and absf(p.x) > 0.84:
			var n: Vector3 = norms[i]
			if absf(n.y) > 0.08 and absf(n.y) < 0.9: slanted += 1
	ok(slanted > 20, "у бортов скруглённые нормали (наклонных вершин: %d)" % slanted)
	ok((MeshBuilder.vehicle_material().shader as Shader).code.contains("g = mix(g, 0.93, clamp(paint + chrome"), "краска гладкая — без зерна асфальта, рисунок не плывёт по едущей машине")
	ok(tris > 9000, "кузов детальный: щели дверей по аркам, уплотнители, молдинги, болты колёс (%d треугольников)" % tris)
	var SL = root.get_node("SoundLibrary")
	ok(I._engine_snd.stream == SL.stream("engine_six") and SL.stream("engine_six") != SL.stream("engine_volga"), "свой звук — рядная шестёрка")

	print("== Такси")
	var TX = W.get_node("Taxi")
	var pays := {}
	for car in [V, I]:
		GM.money = 0
		TX._dist = 500.0; TX._t = 9999.0; TX._cond0 = car.condition
		TX._pay(car)
		pays[car.kind] = GM.money
	ok(pays["bmw"] > pays["volga"], "за ту же поездку на «Изаре» %d грн, на «Волжанке» %d" % [pays["bmw"], pays["volga"]])

	print("== Сохранение")
	I.paint = 2; I._paint_body()
	var st: Dictionary = PR.save_state()
	var vs: Dictionary = I.save_state()
	PR.load_state({})
	ok(not I.owned(), "новая игра — снова на авторынке")
	PR.load_state(st)
	I.load_state(vs)
	ok(I.owned() and I.paint == 2, "после загрузки — твой и того же цвета")

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()


## Скорость, на которой на высшей передаче тяга мотора (на любых оборотах до
## отсечки) за вычетом трения уже не больше сопротивления — как в Vehicle.
func top_speed(v: Vehicle) -> float:
	var s: Dictionary = v.spec
	var top_gear: int = 0
	for g in s.ratios:
		top_gear = maxi(top_gear, int(g))
	var best := 0.0
	for i in 400:
		var ms := i * 0.25
		var ratio: float = float(s.ratios[top_gear]) * float(s.final)
		var rpm: float = ms / float(s.wheel_r) * ratio * 60.0 / TAU
		if rpm > float(s.redline):
			break
		var t_fric: float = v._torque() * (0.07 + rpm * 0.000023)
		var force: float = (v._engine_torque(rpm, 1.0) - t_fric) * ratio / float(s.wheel_r)
		var resist: float = 0.012 * float(s.mass) * 9.8 + float(s.drag) * ms * ms
		if force > resist:
			best = ms
	return best * 3.6
