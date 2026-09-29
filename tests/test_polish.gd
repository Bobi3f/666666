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
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager"); var WM = root.get_node("WeatherManager")
	var QM = root.get_node("QuestManager"); var AC = root.get_node("Achievements"); var SM = root.get_node("SaveManager")
	GM.message.connect(func(t: String) -> void: GM.set_meta("last", t))
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	WM.set_kind(0, 9999.0)
	TM.minutes = 12 * 60.0

	print("== Мир кусками")
	var wm: Node = W.get_node("WorldMesh")
	ok(wm.get_child_count() >= 12, "мир нарезан на %d кусков" % wm.get_child_count())
	var lbl_ok := true
	for n in W.find_children("*", "Label3D", true, false):
		if (n as Label3D).visibility_range_end <= 0.0: lbl_ok = false
	ok(lbl_ok, "надписи издалека не рисуются")

	print("== Люди шагают")
	var sl = child("street_life.gd")
	var w: Dictionary = sl._walkers[0]
	var p0: Vector3 = w.node.global_position
	await frames(30)
	var dirv: Vector3 = w.node.global_position - p0
	dirv.y = 0
	var facing: Vector3 = -w.node.global_transform.basis.z
	ok(dirv.length() > 0.3 and facing.dot(dirv.normalized()) > 0.7, "прохожий идёт лицом вперёд: %.2f" % facing.dot(dirv.normalized()))
	var mat: ShaderMaterial = w.body.material_override
	ok(mat != null and float(mat.get_shader_parameter("amount")) > 0.9, "ноги и руки ходят")

	print("== Пыль, вода, птицы")
	var C = W.get_node("Car")
	C.global_position = Vector3(-10, 0.1, -100); C.rotation.y = -PI / 2.0
	C._on_enter(); C.fuel = 30.0
	await frames(3)
	key(KEY_W, true)
	await frames(120)
	ok(C._dust.emitting, "по полю — пыль из-под колёс: %d км/ч" % int(C.speed_kmh()))
	key(KEY_W, false)
	C.global_position = Vector3(-150, 0.1, 2.0); C.speed = 0.0; C.velocity = Vector3.ZERO
	await frames(5)
	ok(not C._dust.emitting, "на асфальте — без пыли")
	C.exit_car()
	var water: MeshInstance3D = W.get_node("Water")
	ok(water != null and water.material_override is ShaderMaterial, "вода со своим шейдером")
	TM.day = 15; WM._on_minutes(900.0)
	W._update_daylight()
	ok(float(W._water_mat.get_shader_parameter("ice")) > 0.9, "зимой пруд подо льдом")
	TM.day = 29; WM._on_minutes(3000.0)
	W._update_daylight()
	ok(float(W._water_mat.get_shader_parameter("ice")) < 0.05, "летом лёд сошёл")
	var birds = W.get_node("Birds")
	await process_frame
	ok(birds._mi.visible, "днём над деревней птицы")
	TM.minutes = 23 * 60.0
	await process_frame
	ok(not birds._mi.visible, "ночью птиц нет")
	TM.minutes = 12 * 60.0

	print("== Гроза")
	WM.set_kind(4, 9999.0)
	WM._on_minutes(60.0)
	ok(WM.wet() and WM.rain > 0.9 and WM.name_text().begins_with("гроза"), "гроза: " + WM.name_text())
	var amb = child("ambience.gd")
	amb._bolt_in = 0.0
	await process_frame
	ok(WM.flash > 0.5, "сверкнула молния")
	W._update_daylight()
	ok(W._env.ambient_light_energy > 1.5, "всё осветило вспышкой")
	WM.set_kind(0, 9999.0); WM._on_minutes(200.0)

	print("== Достижения")
	AC.load_state({})
	QM.event("fish")
	ok(AC.got.has("fish1") and last().contains("Первая поклёвка"), "первая рыба: " + last())
	QM.event("drive_m", 4000.0)
	ok(absf(AC.progress("km10") - 0.4) < 0.01, "пробег копится: %d%%" % int(AC.progress("km10") * 100))
	QM.event("fair_sold")
	QM.event("lottery_win", 100.0)
	ok(not AC.got.has("lucky"), "100 грн в лотерею — ещё не везунчик")
	QM.event("lottery_win", 500.0)
	ok(AC.got.has("lucky"), "500 — везунчик")
	for i in 20: QM.event("kolkhoz" if i % 2 == 0 else "shift")
	ok(AC.got.has("work20"), "20 смен в колхозе и на складе")
	var j = child("journal.gd")
	var txt: String = j._journal_text()
	ok(txt.contains("ДОСТИЖЕНИЯ — 3 из 19") and txt.contains("40%"), "в журнале достижения")
	SM.save_game(true)
	AC.load_state({})
	SM.load_game()
	ok(AC.got.size() == 3 and absf(AC.progress("km10") - 0.4) < 0.01, "сохраняются")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
