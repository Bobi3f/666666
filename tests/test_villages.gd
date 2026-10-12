extends SceneTree
## Каменка-Северная по образцу (Центральная улица, кольцо-тупик, магазин
## «24 часа», трёхэтажка, грузовой двор) и все сёла района разные:
## своя планировка, свои дома, ничего не стоит на дорогах, полях и в воде.
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
	var TM = root.get_node("TimeManager")
	print("== Каменка-Северная")
	var kn := KamenkaNorth.houses()
	ok(kn.size() >= 10, "домов: %d" % kn.size())
	ok(Roads.on_gravel(-62, -150) and Roads.on_gravel(-62, -233) and Roads.on_gravel(-77, -221), "Центральная улица и кольцо — гравий")
	var trees: Array[Vector2] = []
	var veg = W.get_node("Vegetation")
	for kind in veg._trees:
		for xf in veg._trees[kind]:
			var o: Vector3 = (xf as Transform3D).origin
			trees.append(Vector2(o.x, o.z))
	var on_street := 0
	for t in trees:
		if KamenkaNorth.AREA.has_point(t) and Roads.on_gravel(t.x, t.y): on_street += 1
	ok(on_street == 0, "на улицах деревьев нет: %d" % on_street)
	var zone: InteractZone = W.find_child("Shop24Zone", true, false)
	ok(zone != null, "магазин «24 часа»")
	TM.minutes = 3 * 60.0
	if zone: zone.activate()
	await frames(2)
	var panel = W.find_child("ShopPanel", true, false)
	ok(panel != null and panel.visible, "в 3 ночи открыт")
	if panel: panel.close_panel()
	TM.minutes = 12 * 60.0
	var labels := []
	for l in W.find_children("*", "Label3D", true, false): labels.append(l.text)
	ok(labels.has("ГРУЗОВОЙ ДВОР") and labels.has("ул. Центральная"), "грузовой двор и указатель улицы")
	print("== Сёла района разные")
	var plans := {}
	var styles := {}
	for i in Region.VILLAGES.size():
		plans[Region.PLANS[i]] = true
		styles[Region.STYLES[i]] = true
	ok(plans.size() >= 6 and styles.size() >= 6, "планировок %d, видов домов %d" % [plans.size(), styles.size()])
	var kinds := {}
	for i in Region.VILLAGES.size():
		var k := {}
		for j in 8: k[Region.house_kind(i * 8 + j, Region.STYLES[i])] = true
		kinds[Region.STYLES[i]] = k.keys()
	ok(kinds.mazanka.has("mazanka") and kinds.dacha.has("dacha"), "есть мазанки и дачи")
	# Ничего не стоит на дорогах района, полях, в реке и на местах-достопримечательностях
	var bad := []
	var all_h: Array = Region.houses()
	for h in all_h:
		var p: Vector2 = h[0]
		var fr := Region.world_rect(Transform3D(Basis(Vector3.UP, h[1]), Vector3(p.x, 0, p.y)), Rect2(-4.5, -3.5, 9, 7))
		for f in Region.FIELDS:
			if (f[0] as Rect2).intersects(fr): bad.append("%s поле" % p)
		if Region.river_dist(p.x, p.y) < Region.RIVER_HALF + 6.0: bad.append("%s река" % p)
		for st in Landmarks.sites():
			if (st[0] as Vector2).distance_to(p) < float(st[3]) + 4.0: bad.append("%s место %s" % [p, st[2]])
		var rd := Region.road_dist(p.x, p.y)
		if rd < 5.0: bad.append("%s дорога %.1f" % [p, rd])
		if Railway.dist(p.x, p.y) < 10.0: bad.append("%s ж/д" % p)
	ok(bad.is_empty(), "дома не на дорогах, полях, в реке и не на особых местах: %s" % str(bad.slice(0, 8)))
	var close := 0
	for a in all_h.size():
		for b in range(a + 1, all_h.size()):
			if (all_h[a][0] as Vector2).distance_to(all_h[b][0]) < 14.0: close += 1
	ok(close == 0, "дома не налезают друг на друга: %d" % close)
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
