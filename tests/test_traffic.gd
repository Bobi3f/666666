extends SceneTree
## Трафик: машины на трассе и грунтовках едут носом вперёд, моделей много,
## рейсовые автобусы ходят в обе стороны и не застревают на остановках,
## районные автобусы ездят к сёлам.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null

## Нос машины (−Z модели) в мире.
func nose(n: Node3D) -> Vector3:
	return -n.global_transform.basis.z.normalized()

func _run() -> void:
	for i in 5: await process_frame
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	var TR = child("traffic.gd")
	var RL = W.get_node("RuralLife")
	for i in 30: await physics_frame

	print("== Трасса")
	var kinds := {}
	var sideways := 0
	for v in TR._vehicles:
		kinds[v.kind] = true
		var n := nose(v.body)
		if n.dot(Vector3(float(v.dir), 0, 0)) < 0.95: sideways += 1
	ok(sideways == 0, "все машины на трассе едут носом вперёд (боком: %d)" % sideways)
	ok(kinds.size() >= 8, "моделей на трассе: %d — %s" % [kinds.size(), ", ".join(kinds.keys())])
	for k in ["moskvich", "zaz", "uaz", "kamaz", "volga"]:
		ok(kinds.has(k), "есть " + k)
	var buses: Array = TR._vehicles.filter(func(v: Dictionary) -> bool: return v.bus)
	ok(buses.size() == 2 and buses[0].dir != buses[1].dir, "рейсовых автобусов два, в обе стороны")
	ok((TR.stops[1] as Array).size() >= 3 and (TR.stops[-1] as Array).size() >= 3, "остановок по сторонам: %d и %d" % [(TR.stops[1] as Array).size(), (TR.stops[-1] as Array).size()])

	# Автобус подходит к остановке, стоит и едет дальше
	TR.set_physics_process(false)
	var bus: Dictionary = buses[0]
	var dir: int = bus.dir
	var stop_x: float = TR.stops[dir][0]
	for v in TR._vehicles:
		if not is_same(v, bus): TR._place(v.body, -1500.0 * v.dir, v.dir)
	TR._place(bus.body, stop_x - dir * 40.0, dir)
	bus.speed = TrafficSpeed.bus(TR)
	bus.left_stop = INF
	var stood := false
	var min_x := INF
	for i in 600:
		TR._physics_process(0.1)
		if bus.wait > 0.0 and absf((bus.body as Node3D).global_position.x - stop_x) < 1.5: stood = true
		if stood and ((bus.body as Node3D).global_position.x - stop_x) * dir > 40.0: break
	var bx: float = (bus.body as Node3D).global_position.x
	ok(stood, "автобус встал на остановке")
	ok((bx - stop_x) * dir > 40.0, "постоял и поехал дальше: %.0f м за остановкой" % ((bx - stop_x) * dir))
	# Целый круг: проходит все остановки своей стороны
	var visited := {}
	for i in 6000:
		TR._physics_process(0.1)
		if bus.wait > 0.0: visited[bus.at_stop] = true
	ok(visited.size() >= (TR.stops[dir] as Array).size() - 1, "за рейс стоял на %d из %d остановок" % [visited.size(), (TR.stops[dir] as Array).size()])
	TR.set_physics_process(true)

	print("== Грунтовки")
	var rk := {}
	var rbus := 0
	for m in RL.movers:
		rk[m.kind] = true
		if m.kind == "bus": rbus += 1
	ok(rbus >= 2, "районных автобусов на дорогах к сёлам: %d" % rbus)
	ok(rk.size() >= 9, "видов транспорта на грунтовках: %d" % rk.size())
	var P = W.get_node("Player")
	var bad := 0
	for m in RL.movers:
		if float(m.wait) > 0.0: continue
		P.global_position = (m.body as Node3D).global_position + Vector3(0, 0, 200)
		var at: Array = RL._at(m.pts, float(m.s))
		var d: Vector2 = at[1] * float(m.dir)
		var n := nose(m.body)
		if Vector2(n.x, n.z).dot(d) < 0.95 and (m.body as Node3D).visible:
			bad += 1
			print("    ", m.kind, " s=", m.s, " d=", d, " nose=", n, " vis=", m.body.visible)
	ok(bad == 0, "на грунтовках все едут носом вперёд (боком: %d)" % bad)
	print("ИТОГО: %s" % ("всё работает" if fails == 0 else "%d ошибок" % fails))
	quit(1 if fails > 0 else 0)


class TrafficSpeed:
	static func bus(tr) -> float:
		return tr.BUS_CRUISE
