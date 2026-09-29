extends SceneTree
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
## Координаты интерфейса → координаты окна: настоящий экран присылает оконные,
## а интерфейс на телефоне масштабирован (content_scale_factor)
func win(p: Vector2) -> Vector2:
	return p * root.content_scale_factor

func touch(idx: int, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx; e.position = win(pos); e.pressed = down
	Input.parse_input_event(e)
func drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx; e.position = win(pos); e.relative = win(rel)
	Input.parse_input_event(e)
func btn(tc, text: String) -> Vector2:
	for e in tc._buttons:
		if e.text == text:
			return (e.rect as Rect2).get_center()
	return Vector2(-100, -100)
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await frames(5)
	var GM = root.get_node("GameManager")
	var tc
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("touch_controls.gd"): tc = c
		if c.get_script() and c.get_script().resource_path.ends_with("traffic.gd"): c.set_physics_process(false)
	ok(tc != null and GM.touch_mode, "сенсорное управление включено")
	var P = W.get_node("Player"); var C = W.get_node("Car")
	P.global_position = Vector3(-110, 0.2, -40); P.rotation.y = PI / 2.0
	await frames(20)
	var c0: Vector2 = tc._stick_center
	var a: Vector3 = P.global_position
	touch(0, c0, true)
	await frames(2)
	drag(0, c0 + Vector2(0, -80), Vector2(0, -80))
	await frames(60)
	ok(GM.move_axis.y < -0.8 and P.global_position.distance_to(a) > 2.0, "джойстик вверх — идёт: %.1f м" % P.global_position.distance_to(a))
	# Чуть отклонил — идёт медленнее
	drag(0, c0 + Vector2(0, -35), Vector2(0, 45))
	await process_frame; await process_frame
	await frames(40)
	var slow: float = Vector2(P.velocity.x, P.velocity.z).length()
	ok(GM.move_axis.length() > 0.1 and GM.move_axis.length() < 0.5 and slow > 0.3 and slow < 3.0, "чуть отклонил — медленно: %.1f м/с" % slow)
	# Вбок по диагонали — идёт по диагонали, а не рывками по 8 направлениям
	drag(0, c0 + Vector2(40, -70), Vector2(75, -35))
	await process_frame; await process_frame
	await frames(20)
	var ang: float = rad_to_deg(GM.move_axis.angle())
	ok(absf(ang - rad_to_deg(Vector2(40, -70).angle())) < 3.0, "джойстик в любую сторону плавно: %.0f°" % ang)
	drag(0, c0 + Vector2(0, -95), Vector2(0, -15))
	await frames(40)
	ok(Input.is_physical_key_pressed(KEY_SHIFT), "у края — бег")
	touch(0, c0 + Vector2(0, -95), false)
	await frames(30)
	ok(GM.move_axis == Vector2.ZERO and Vector2(P.velocity.x, P.velocity.z).length() < 0.5, "отпустил — остановился")
	var yaw: float = P.rotation.y
	touch(1, Vector2(900, 300), true)
	await frames(2)
	drag(1, Vector2(800, 300), Vector2(-100, 0))
	# Событие касания доходит до игры на ближайшем кадре отрисовки,
	# а физических кадров до него может пройти несколько
	await process_frame
	await process_frame
	touch(1, Vector2(800, 300), false)
	ok(absf(P.rotation.y - yaw) > 0.2, "палец справа — поворот камеры: %.2f рад" % (P.rotation.y - yaw))
	# Экран пополам: левее середины — ходьба, правее — камера
	var sx: float = tc.split_x()
	var vh: float = tc.get_viewport().get_visible_rect().size.y
	ok(tc._split_hint.visible and tc._split_left > 0.0, "в начале игры подписаны половины: ходить | камера")
	touch(5, Vector2(sx - 30, vh * 0.35), true); await process_frame; await process_frame
	ok(tc._stick_index == 5 and tc._stick_center.x < sx, "чуть левее середины — джойстик ходьбы: центр %.0f" % tc._stick_center.x)
	touch(5, Vector2(sx - 30, vh * 0.35), false); await process_frame; await process_frame
	touch(6, Vector2(sx + 30, vh * 0.35), true); await process_frame; await process_frame
	ok(tc._look_index == 6 and tc._stick_index < 0, "чуть правее середины — камера")
	touch(6, Vector2(sx + 30, vh * 0.35), false); await process_frame; await process_frame
	tc._split_left = 0.0
	await process_frame
	# Кнопка E у машины
	P.global_position = Vector3(-121, 0.2, -37.6)
	await frames(15)
	var center: Vector2 = btn(tc, "E")
	touch(2, center, true); await frames(3); touch(2, center, false)
	for i in 30:
		await physics_frame
		if GM.vehicle == C: break
	ok(GM.vehicle == C, "кнопка E — сел в машину")
	for i in 3: await process_frame
	ok(tc.button("Газ").visible and tc._wheel.visible and tc.button("D").visible and not tc.button("E").visible and not tc._base.visible,
		"в машине: руль, педали и рычаг D/R вместо джойстика")
	C.fuel = 30.0
	var gas: Vector2 = btn(tc, "Газ")
	touch(0, gas, true)
	await frames(180)
	ok(C.engine_on and C.speed_kmh() > 10.0, "кнопка «Газ» — едем: %d км/ч" % int(C.speed_kmh()))
	var yaw0: float = C.rotation.y
	# Крутим руль против часовой: палец по ободу сверху влево и вниз
	var wc: Vector2 = tc._wheel_center
	var R := 90.0
	touch(1, wc + Vector2(0, -R), true)
	await process_frame; await process_frame
	var prev := wc + Vector2(0, -R)
	for i in 12:
		var wa := -PI / 2.0 - (i + 1) * 0.2
		var p := wc + Vector2(cos(wa), sin(wa)) * R
		drag(1, p, p - prev); prev = p
		await process_frame
	await process_frame
	var steer: float = GM.steer_axis
	ok(steer > 0.5, "руль против часовой — влево: %.2f" % steer)
	await frames(60)
	var turned: float = angle_difference(yaw0, C.rotation.y)
	ok(Input.is_physical_key_pressed(KEY_W) and turned > 0.1, "газ и руль вместе — поворачивает влево: %.2f рад" % turned)
	touch(1, prev, false)
	touch(0, gas, false)
	for i in 30: await process_frame
	ok(not Input.is_physical_key_pressed(KEY_W) and absf(GM.steer_axis) < 0.05 and tc._wheel_rot == 0.0, "отпустил — педаль отпущена, руль вернулся: %.2f" % GM.steer_axis)
	# Рычаг на R: газ сперва тормозит, потом едем назад
	var lever: Vector2 = btn(tc, "D")
	touch(2, lever, true); await process_frame; await process_frame; touch(2, lever, false)
	await process_frame
	ok(GM.pedal_reverse and tc.button("D").get_child(0).text == "R", "рычаг — R")
	touch(0, gas, true)
	for i in 400:
		await physics_frame
		if C.speed < -1.5: break
	ok(C.speed < -1.5 and C.gear == -1, "на R газ — назад: %.1f км/ч" % (C.speed * 3.6))
	touch(0, gas, false)
	touch(2, lever, true); await process_frame; await process_frame; touch(2, lever, false)
	await process_frame
	ok(not GM.pedal_reverse, "рычаг снова D")
	# Сигнал — центр руля
	touch(4, wc, true); await process_frame; await process_frame
	ok(Input.is_physical_key_pressed(KEY_H), "центр руля — сигнал")
	touch(4, wc, false); await process_frame; await process_frame
	# «Меню» — управление прячется и отпускает зажатый тормоз
	var brake: Vector2 = btn(tc, "Тормоз")
	touch(0, brake, true); await process_frame; await process_frame; await frames(2)
	ok(Input.is_physical_key_pressed(KEY_S), "«Тормоз» зажат")
	var mc: Vector2 = btn(tc, "Меню")
	touch(3, mc, true); await frames(3); touch(3, mc, false)
	for i in 4: await process_frame
	ok(paused and not tc.visible, "«Меню» открыло меню, кнопки спрятались")
	ok(not Input.is_physical_key_pressed(KEY_S), "зажатые клавиши отпущены")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
