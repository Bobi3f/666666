extends SceneTree
## Из чего складываются вызовы отрисовки: видимые с места игрока объекты
## (в пределах их дальности видимости), по видам и именам.
var W
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func spot(name: String, pos: Vector3) -> void:
	var P = W.get_node("Player")
	P.global_position = pos
	for i in 20: await process_frame
	var camera: Camera3D = W.get_viewport().get_camera_3d()
	var cam := camera.global_position
	var planes := camera.get_frustum()
	var far: float = root.get_node("SettingsManager").view_range()
	var groups := {}
	var total := 0
	var stack: Array[Node] = [W]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(): stack.append(c)
		var g := n as GeometryInstance3D
		if g == null or not g.is_visible_in_tree(): continue
		var aabb := (g as VisualInstance3D).get_aabb()
		var center: Vector3 = g.global_transform * aabb.get_center()
		var d := center.distance_to(cam)
		var r_end: float = g.visibility_range_end if g.visibility_range_end > 0.0 else far
		if d - aabb.size.length() * 0.5 > minf(r_end, far): continue
		var rad := aabb.size.length() * 0.5
		var inside := true
		for pl in planes:
			if pl.distance_to(center) > rad: inside = false
		if not inside: continue
		var key := g.get_class() + " " + String(n.get_parent().name).left(18)
		if g is MultiMeshInstance3D: key = "MultiMesh " + String(g.name).get_slice("_", 0)
		groups[key] = int(groups.get(key, 0)) + 1
		total += 1
	var arr := []
	for k in groups: arr.append([groups[k], k])
	arr.sort_custom(func(a, b): return a[0] > b[0])
	print("== %s: видимых %d" % [name, total])
	for k in mini(18, arr.size()): print("   %4d  %s" % arr[k])
func _run() -> void:
	for i in 20: await process_frame
	root.get_node("SettingsManager").set_detail(0)
	await spot("деревня", Vector3(-110, 0.2, -40))
	await spot("центр города", Town.w(Vector3(97, 0.2, 40)))
	quit()
