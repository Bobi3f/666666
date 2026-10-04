extends SceneTree
## Замер кадров при поездке между сёлами и через город: печатает кадры,
## что вдвое дольше обычного, и где была середина подробной мини-карты.
## Запуск — с экраном (xvfb-run, --rendering-driver opengl3), как скриншоты.
var W
func _initialize() -> void:
	root.size = Vector2i(1000, 460)
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	for i in 30: await process_frame
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("pause_menu.gd"): c._close()
		if c.get_script() and c.get_script().resource_path.ends_with("tutorial.gd"): c._finish()
	var C = W.get_node("Car")
	root.get_node("Progress").buy_car("car"); root.get_node("Progress").license = true
	C.global_position = Vector3(-60, 0.1, 2); C._on_enter(); C.fuel = 40
	C.set_physics_process(false)
	var route := [Vector3(-60, 0.1, 2), Vector3(430, 0.1, 2), Vector3(430, 0.1, 160), Vector3(435, 0.1, 300), Vector3(430, 0.1, 160), Vector3(430, 0.1, 2), Vector3(1000, 0.1, 2), Vector3(-380, 0.1, 2), Vector3(-380, 0.1, -160), Vector3(-405, 0.1, -300)]
	for i in 30: await process_frame
	var prev := Time.get_ticks_usec()
	var spikes := []
	var times := []
	for s in range(route.size() - 1):
		var a: Vector3 = route[s]; var b: Vector3 = route[s + 1]
		var n := int(a.distance_to(b) / 3.0)
		for k in n:
			C.global_position = a.lerp(b, float(k) / n)
			C.rotation.y = atan2(-(b - a).x, -(b - a).z)
			await process_frame
			var now := Time.get_ticks_usec()
			var ms := (now - prev) / 1000.0
			prev = now
			times.append(ms)
			var med: float = times[max(0, times.size() - 40)]
			var sorted_t := times.slice(max(0, times.size() - 40)); sorted_t.sort()
			med = sorted_t[sorted_t.size() / 2]
			var mp = null
			for c in W.get_children():
				if c.get_script() and c.get_script().resource_path.ends_with("map.gd"): mp = c
			var nc: Vector2 = mp._near_c if mp else Vector2.ZERO
			if ms > med * 2.2 and times.size() > 10:
				spikes.append("%.0f мс (обычно %.0f) у %s карта:%s" % [ms, med, str(C.global_position.round()), str(nc)])
	for sp in spikes: print("SPIKE ", sp)
	print("spikes: ", spikes.size())
	quit()
