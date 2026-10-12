extends SceneTree
## Игрок виден за рулём: в машине и на мотоцикле сидит он сам (та же
## внешность), руки на руле, на мотоцикле — в шлеме. С вида сзади — виден,
## от первого лица — нет (камера в голове), без водителя — пусто.
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
func _run() -> void:
	await frames(10)
	var P = W.get_node("Player")
	var seen := {}
	for v in W.find_children("*", "Vehicle", true, false):
		if v.kind in ["car", "moto", "izh", "moped", "niva", "truck", "tractor"] and not seen.has(v.kind): seen[v.kind] = v
	for k in seen:
		var v: Vehicle = seen[k]
		var r: Node3D = v._rider
		ok(r != null, "%s: есть водитель-игрок" % v.spec.title)
		if r == null: continue
		var meshes := r.find_children("*", "MeshInstance3D", true, false)
		# Треугольники, а не вершины: у мешей индексы, вершины общие у соседних
		var tris := 0
		for m in meshes:
			var mesh: Mesh = (m as MeshInstance3D).mesh
			var n: int = mesh.surface_get_array_index_len(0)
			tris += (n if n > 0 else mesh.surface_get_array_len(0)) / 3
		ok(tris > 1000, "  человек, а не коробки: %d треугольников" % tris)
		ok((meshes.size() == 2) == v.spec.two_wheels, "  шлем — только на мотоцикле")
		ok(not r.visible, "  без водителя — пусто")
		v.driver = P
		Vehicle.chase_view = true
		await frames(2)
		ok(r.visible, "  сел, вид сзади — виден")
		Vehicle.chase_view = false
		await frames(2)
		ok(not r.visible, "  от первого лица — не мешает")
		v.driver = null
		Vehicle.chase_view = false
		await frames(1)
		var box: AABB = (meshes[-1] as MeshInstance3D).mesh.get_aabb()
		var seat: Vector3 = v.spec.seat
		var head_y: float = r.position.y + box.end.y
		ok(head_y > seat.y - 0.35 and head_y < seat.y + 0.45, "  голова на месте: макушка %.2f, камера %.2f" % [head_y, seat.y])
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
