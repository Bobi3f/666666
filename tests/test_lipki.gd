extends SceneTree
## Карта: дорогой район «Липки» и две дороги к нему (быстрый асфальт из
## города и красивая грунтовка из Заречья — обе через лес), восемь домов,
## купить можно только №1; в лесах — поляны, тропы, поваленные деревья;
## посадки разные (берёзы, тополя, сосны).
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
	var GM = root.get_node("GameManager"); var PR = root.get_node("Progress")
	print("== Дороги в Липки")
	ok(Region.ROADS.has(EliteDistrict.ROAD_FAST) and Region.ROADS.has(EliteDistrict.ROAD_SCENIC), "обе дороги — в дорогах района (карта, переезды, трафик)")
	var f0: Vector2 = EliteDistrict.ROAD_FAST[0]
	ok(Roads.on_asphalt(f0.x, f0.y - 2.0), "быстрая начинается с трассы у Каменки")
	var s0: Vector2 = EliteDistrict.ROAD_SCENIC[0]
	ok(s0.distance_to(Region.VILLAGES[6].c) < 80.0, "красивая — от Берёзовки")
	var fast_ok := true
	for i in EliteDistrict.ROAD_FAST.size() - 1:
		var m: Vector2 = (EliteDistrict.ROAD_FAST[i] + EliteDistrict.ROAD_FAST[i + 1]) * 0.5
		if not Roads.on_asphalt(m.x, m.y): fast_ok = false
	ok(fast_ok, "быстрая — асфальт на всём пути")
	var mid: Vector2 = EliteDistrict.ROAD_SCENIC[5]
	ok(not Roads.on_asphalt(mid.x, mid.y) and Region.on_road(mid.x, mid.y), "красивая — грунтовка")
	var crosses := false
	for c in Railway.road_crossings():
		if absf((c as Vector2).x - f0.x) < 25.0 and absf((c as Vector2).y - 205.0) < 10.0: crosses = true
	ok(crosses, "через железную дорогу — переезд")
	var through := [0, 0]
	for k in 2:
		var road: Array = [EliteDistrict.ROAD_FAST, EliteDistrict.ROAD_SCENIC][k]
		for i in road.size() - 1:
			for t in 10:
				var p: Vector2 = (road[i] as Vector2).lerp(road[i + 1], t / 10.0)
				for f in Region.FORESTS + EliteDistrict.FORESTS:
					if (f as Rect2).has_point(p): through[k] += 1
	ok(through[0] > 5 and through[1] > 5, "обе идут через лес (точек в лесу: %d и %d)" % through)
	var end_f: Vector2 = EliteDistrict.ROAD_FAST[-1]
	var end_s: Vector2 = EliteDistrict.ROAD_SCENIC[-1]
	ok(EliteDistrict.AREA.has_point(end_f) and EliteDistrict.AREA.has_point(end_s), "обе приводят в Липки")
	print("== Район")
	ok(Roads.on_asphalt(EliteDistrict.BOULEVARD.get_center().x, EliteDistrict.BOULEVARD.get_center().y) and Roads.on_asphalt(EliteDistrict.RING_C.x, EliteDistrict.RING_C.y), "бульвар и кольцо — асфальт")
	ok(not Region.tree_ok(-900, 1270) and not Region.tree_ok(-900, 1360), "на участках лес не растёт")
	var signs := 0
	for i in 8:
		if W.find_child("LipkiSign%d" % (i + 1), true, false): signs += 1
	ok(signs == 8, "восемь домов с номерами: %d" % signs)
	var priv: InteractZone = W.find_child("LipkiPrivate3", true, false)
	ok(priv and priv.text().contains("не продаётся"), "чужой дом: " + (priv.text() if priv else ""))
	var house: InteractZone = W.find_child("LipkiHouse1", true, false)
	ok(house and house.text().contains("купить") and house.text().contains(str(EliteDistrict.HOUSE_PRICE)), "дом №1: " + (house.text() if house else ""))
	GM.money = 1000
	ok(not EliteDistrict.buy_house() and not PR.has_item("lipki_house"), "без денег — не купить")
	GM.money = EliteDistrict.HOUSE_PRICE + 500
	ok(EliteDistrict.buy_house() and PR.has_item("lipki_house") and GM.money == 500, "купил дом №1 за %d грн" % EliteDistrict.HOUSE_PRICE)
	ok(house.text().contains("спать"), "теперь у двери: " + house.text())
	var sign: Label3D = W.find_child("LipkiSign1", true, false)
	ok(sign.text.contains("ТВОЙ ДОМ"), "на воротах: " + sign.text.replace("\n", " "))
	ok(not EliteDistrict.buy_house(), "второй раз не продаётся")
	print("== Лес")
	var gl: Array = ForestLife.glades()
	ok(gl.size() == Region.FORESTS.size() + EliteDistrict.FORESTS.size(), "в каждом лесу поляна: %d" % gl.size())
	var c: Vector2 = gl[0][0]
	ok(not Region.tree_ok(c.x, c.y), "на поляне деревьев нет")
	var veg: Vegetation = W.get_node("Vegetation")
	ok(int(veg.counts.get("tree_%d" % Vegetation.TreeKind.POPLAR, 0)) > 100, "в посадках и вдоль трассы — тополя: %d" % int(veg.counts.get("tree_4", 0)))
	print("== План района: полоса леса и дорогой район")
	var zsigns := 0
	for l in W.find_children("*", "Label3D", true, false):
		if (l as Label3D).text.begins_with("ДОРОГОЙ РАЙОН"): zsigns += 1
	ok(zsigns == 2, "таблички на въездах в дорогой район: %d" % zsigns)
	ok(EliteDistrict.ZONE.encloses(EliteDistrict.AREA), "Липки внутри дорогого района")
	var in_band := 0
	var vg = W.get_node("Vegetation")
	for kind in vg._trees:
		for xf in vg._trees[kind]:
			var o: Vector3 = (xf as Transform3D).origin
			if Rect2(-2000, 420, 2100, 480).has_point(Vector2(o.x, o.z)): in_band += 1
	ok(in_band > 900, "полоса леса к югу от трассы: %d деревьев" % in_band)
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
