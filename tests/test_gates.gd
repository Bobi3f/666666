extends SceneTree
## Во двор можно заехать: ворота 4,4 м у домов Каменки, ворота 4,4 м и
## навес для машины у домов сёл; «Жигули» заезжают в свой двор и под навес.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
## Свободно ли от a до b для машины: лучи на высоте 0,5 и 1,2 м, слева и справа.
func clear(a: Vector3, b: Vector3, half := 0.8) -> bool:
	var space: PhysicsDirectSpaceState3D = W.get_world_3d().direct_space_state
	var side := (b - a).cross(Vector3.UP).normalized() * half
	for y in [0.5, 1.2]:
		for s in [-1.0, 0.0, 1.0]:
			var q := PhysicsRayQueryParameters3D.create(a + side * s + Vector3(0, y, 0), b + side * s + Vector3(0, y, 0))
			q.exclude = [W.get_node("Player").get_rid()]
			for v in W.find_children("*", "Vehicle", true, false): q.exclude.append(v.get_rid())
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				print("    упёрлось в ", hit.collider, " у ", hit.position)
				return false
	return true
func _run() -> void:
	await frames(10)
	print("== Каменка")
	# Свой двор: от улицы через ворота к дому
	var px: float = W.PLAYER_HOUSE.x + W._home_door_x
	ok(clear(Vector3(px, 0, -40.0), Vector3(px, 0, -49.5)), "в свой двор — проезд свободен")
	ok(clear(Vector3(-100.0 - 1.6 * -1.0, 0, -40.0), Vector3(-100.0 + 1.6, 0, -31.0)), "и в соседний через улицу")
	print("== Сёла")
	var bad := 0
	var tried := 0
	for i in Region.VILLAGES.size():
		var c: Vector2 = Region.VILLAGES[i].c
		var e: int = Region.VILLAGES[i].entry
		for hx in [Region.HOUSE_X[0], Region.HOUSE_X[2]]:
			for side in [-1, 1]:
				var idx: int = i * 8 + (0 if side < 0 else 4) + (0 if hx == Region.HOUSE_X[0] else 2)
				if Region.house_kind(idx, Region.STYLES[i]) == "abandoned": continue
				var yaw := 0.0 if side < 0 else PI
				var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x + hx * e, 0, c.y + side * 16.0))
				tried += 1
				if not clear(xf * Vector3(6.0, 0, 13.0), xf * Vector3(6.0, 0, -5.5)): bad += 1
	ok(tried > 20 and bad == 0, "во дворы сёл через ворота под навес — свободно: %d из %d" % [tried - bad, tried])
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
