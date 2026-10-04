extends SceneTree
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func key(k: int, down: bool) -> void:
	var e := InputEventKey.new(); e.physical_keycode = k; e.keycode = k; e.pressed = down
	Input.parse_input_event(e)
func touch(idx: int, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new(); e.index = idx; e.position = pos * root.content_scale_factor; e.pressed = down
	Input.parse_input_event(e)
func drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new(); e.index = idx; e.position = pos * root.content_scale_factor; e.relative = rel * root.content_scale_factor
	Input.parse_input_event(e)
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
	var ST = root.get_node("SettingsManager")
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tc = child("touch_controls.gd")
	ST.set_third_person(true)
	var P = W.get_node("Player")
	P.global_position = Vector3(-100, 0.2, -40); P.rotation.y = 0.0
	await frames(20)
	print("== Вид со спины")
	ok(P._body.visible and P._arm.spring_length > 3.0, "по умолчанию — со спины, тело видно")
	var back: float = P.camera.global_position.distance_to(P.global_position + Vector3(0, 1.6, 0))
	ok(back > 2.5, "камера позади персонажа: %.1f м" % back)
	# Идём вбок (влево) — тело поворачивается туда, камера остаётся
	var yaw0: float = P.rotation.y
	key(KEY_A, true)
	await frames(40)
	key(KEY_A, false)
	var facing: Vector3 = -P._body.global_transform.basis.z
	var left: Vector3 = -P.global_transform.basis.x
	ok(facing.dot(left) > 0.9 and absf(P.rotation.y - yaw0) < 0.01, "пошёл влево — тело смотрит влево, камера не крутится")
	ok(float((P._body_mesh.material_override as ShaderMaterial).get_shader_parameter("amount")) >= 0.0, "шагает ногами")
	print("== Переключение вида")
	key(KEY_V, true); await process_frame; key(KEY_V, false)
	await frames(3)
	ok(not ST.third_person and not P._body.visible and P._arm.spring_length == 0.0, "V — из глаз")
	key(KEY_V, true); await process_frame; key(KEY_V, false)
	await frames(3)
	ok(ST.third_person and P._body.visible, "V ещё раз — снова со спины")
	if tc:
		print("== Плавающий джойстик")
		var vs: Vector2 = root.get_viewport().get_visible_rect().size
		var c0: Vector2 = tc._stick_center
		var at := Vector2(vs.x * 0.25, vs.y * 0.55)
		touch(0, at, true)
		await process_frame; await process_frame
		ok(tc._stick_center.distance_to(at) < 1.0, "джойстик встал под палец: %s" % str(tc._stick_center))
		drag(0, at + Vector2(0, -80), Vector2(0, -80))
		await frames(20)
		ok(root.get_node("GameManager").move_axis.y < -0.8, "от места касания — вперёд")
		touch(0, at + Vector2(0, -80), false)
		await process_frame; await process_frame
		ok(tc._stick_center.distance_to(c0) < 1.0, "отпустил — вернулся на место")
		ok(tc.button("Вид").visible, "кнопка «Вид» пешком")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
