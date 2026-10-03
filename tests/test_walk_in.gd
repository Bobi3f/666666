extends SceneTree
## Здания, в которые можно войти: сельмаг, сельсовет с почтой, дежурная
## часть милиции. Заходим ногами через дверь, внутри — прилавок и окошки.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [W.get_node("Player").get_rid()]
	return W.get_world_3d().direct_space_state.intersect_ray(q)
## Встать в from лицом к to и идти, пока не дойдёт (или 4 с).
func walk(P, from: Vector3, to: Vector3) -> void:
	P.global_position = from + Vector3(0, 0.15, 0)
	P.velocity = Vector3.ZERO
	var d := to - from
	P.rotation.y = atan2(-d.x, -d.z)
	await frames(3)
	key(KEY_W, true)
	for i in 240:
		await physics_frame
		if Vector2(P.global_position.x - to.x, P.global_position.z - to.z).length() < 0.6:
			break
	key(KEY_W, false)
	await frames(10)

func _run() -> void:
	for i in 5: await process_frame
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var tr = child("traffic.gd"); if tr: tr.queue_free()
	var TM = root.get_node("TimeManager")
	TM.day = 2
	TM.minutes = 11 * 60.0
	var P = W.get_node("Player")

	print("== Сельмаг")
	var sx := Transform3D(Basis(Vector3.UP, -PI / 2.0), W.SHOP_POS)
	ok(not ray(sx * Vector3(-3.0, 1.2, 5.0), sx * Vector3(-3.0, 1.2, 0.0)).is_empty(), "стены сельмага держат")
	ok(ray(sx * Vector3(0, 1.4, 5.0), sx * Vector3(0, 1.4, 1.0)).is_empty(), "дверь открыта")
	await walk(P, sx * Vector3(0, 0, 7.0), sx * Vector3(0, 0.4, 0.6))
	var local: Vector3 = sx.affine_inverse() * P.global_position
	ok(local.z < 2.5 and absf(P.global_position.y - 0.4) < 0.3, "зашёл в магазин: %s" % str(local.snapped(Vector3.ONE * 0.1)))
	P.global_position = sx * Vector3(-0.4, 0.5, 0.5)
	await frames(4)
	ok(P.current_prompt().contains("сельмаг"), "у прилавка: " + P.current_prompt())
	P.global_position = sx * Vector3(1.6, 0.5, 0.5)
	await frames(4)
	ok(P.current_prompt().contains("воды"), "у холодильника: " + P.current_prompt())
	ok(W.has_node("ShopLamps"), "в магазине горят лампы")

	print("== Сельсовет и почта")
	var c: Vector3 = Civic.COUNCIL
	ok(not ray(c + Vector3(-3.0, 1.5, 6.0), c + Vector3(-3.0, 1.5, 2.0)).is_empty(), "стены сельсовета держат")
	await walk(P, c + Vector3(0, 0, 8.0), c + Vector3(0, 0.4, 1.0))
	ok(P.global_position.z < c.z + 3.0, "зашёл в сельсовет")
	var post = W.post.offices[0]
	P.global_position = post.home_job.giver + Vector3(0, 0.1, 0.2)
	await frames(4)
	ok(P.current_prompt().contains("по домам"), "почта внутри — окошко «по домам»: " + P.current_prompt())
	P.global_position = post.bag_job.giver + Vector3(0, 0.1, 0.2)
	await frames(4)
	ok(P.current_prompt().contains("мешок"), "окошко «в почту»: " + P.current_prompt())
	P.global_position = c + Vector3(3.0, 0.5, -0.4)
	await frames(4)
	ok(P.current_prompt().contains("оформить") or P.current_prompt().contains("Секретарь"), "стол секретаря: " + P.current_prompt())
	ok((post.road as Vector3).z > c.z + 4.0, "мешок на почту Каменки подвозят к крыльцу, не в стену")

	print("== Милиция")
	var p: Vector3 = Police.STATION
	ok(not ray(p + Vector3(-10.0, 1.5, -3.0), p + Vector3(-4.0, 1.5, -3.0)).is_empty(), "стены милиции держат")
	await walk(P, p + Vector3(-12.0, 0, 0), p + Vector3(-5.0, 0.3, 0))
	ok(P.global_position.x > p.x - 7.0, "зашёл в дежурную часть: x=%.1f" % (P.global_position.x - p.x))
	P.global_position = p + Vector3(-4.3, 0.4, -2.6)
	await frames(4)
	ok(P.current_prompt().contains("Дежурный") or P.current_prompt().contains("дружинник") or P.current_prompt().contains("штраф"), "окошко дежурного: " + P.current_prompt())
	P.global_position = p + Vector3(-4.3, 0.4, 2.7)
	await frames(4)
	ok(P.current_prompt().contains("ГАИ"), "окошко ГАИ: " + P.current_prompt())
	ok(not ray(p + Vector3(-4.0, 1.6, -2.6), p + Vector3(-1.5, 1.6, -2.6)).is_empty(), "за стойку не пролезть")
	ok(not ray(p + Vector3(2.0, 1.0, 2.5), p + Vector3(5.5, 1.0, 2.5)).is_empty(), "камера за решёткой закрыта")
	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)
