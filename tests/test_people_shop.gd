extends SceneTree
## Люди смотрят на игрока: подошёл — повернули голову (стоящие и телом),
## отошёл — отвернулись. В сельмаге — меню у прилавка: хлеб и молоко,
## бургер, вода, ремнабор.
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
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager"); var NM = root.get_node("NeedsManager")
	var PR = root.get_node("Progress")
	var P: Node3D = W.get_node("Player")
	TM.minutes = 12 * 60.0

	print("== Смотрят на игрока")
	var people := get_nodes_in_group("people")
	ok(people.size() > 20, "людей, что умеют смотреть: %d" % people.size())
	var own := false
	for n in people:
		if P.is_ancestor_of(n): own = true
	ok(not own, "сам игрок в их число не входит")
	var seller: MeshInstance3D
	var bd := INF
	for n in people:
		var d: float = (n as Node3D).global_position.distance_to(W.SHOP_POS)
		if d < bd: bd = d; seller = n
	ok(seller != null and bd < 6.0, "продавщица в сельмаге")
	var LK = W.get_node("PeopleLook")
	var spot: Vector3 = seller.global_transform * Vector3(2.0, 0, -2.0)
	P.global_position = spot
	await frames(2)
	for i in 90:
		P.global_position = spot
		await physics_frame
	var local: Vector3 = seller.global_transform.affine_inverse() * (spot + Vector3(0, 1.6, 0))
	var want := atan2(-local.x, -local.z)
	var got: float = LK.angle_of(seller)
	ok(absf(got - want) < 0.15 and absf(want) > 0.5, "подошёл сбоку — смотрит на меня: %.2f рад (нужно %.2f)" % [got, want])
	spot = seller.global_transform * Vector3(-1.0, 0, 3.0)
	P.global_position = spot
	for i in 120:
		P.global_position = spot
		await physics_frame
	local = seller.global_transform.affine_inverse() * (spot + Vector3(0, 1.6, 0))
	want = atan2(-local.x, -local.z)
	got = LK.angle_of(seller)
	ok(absf(got - clampf(want, -2.6, 2.6)) < 0.2, "зашёл почти за спину — развернулась: %.2f рад (нужно %.2f)" % [got, want])
	var far := Vector3(-300, 0.5, 200)
	for i in 120:
		P.global_position = far
		await physics_frame
	ok(absf(LK.angle_of(seller)) < 0.01, "ушёл — смотрит прямо, как раньше")
	# Сидящий поворачивает только голову
	var sit: MeshInstance3D
	for n in people:
		if n.get_meta("sit", false) and n.is_visible_in_tree(): sit = n
	if sit:
		spot = sit.global_transform * Vector3(0.0, 0, 3.0)
		for i in 120:
			P.global_position = spot
			await physics_frame
		var m := sit.material_override as ShaderMaterial
		ok(absf(float(m.get_shader_parameter("turn"))) < 0.01 and absf(float(m.get_shader_parameter("look"))) > 0.9, "сидящий оборачивается только головой")

	print("== Меню сельмага")
	ok(W.find_child("ShopZone", true, false) != null and W.find_child("KitZone", true, false) == null, "у прилавка одно место — меню")
	GM.money = 1000
	W.open_shop()
	await frames(2)
	var panel: MarketPanel = W.get_node("ShopPanel")
	ok(panel.visible and panel.mode == "shop", "меню открылось: " + panel._title.text)
	var rows := []
	for l in panel._goods.find_children("*", "Label", true, false):
		rows.append(l.text.get_slice(" — ", 0))
	ok(rows.has("Хлеб и молоко") and rows.has("Бургер с котлетой") and rows.has("Бутылка воды") and rows.has("Ремнабор"), "в меню: %s" % ", ".join(rows))
	NM.food = 20.0
	ok(panel.buy("burger") and GM.money == 940 and NM.food >= 79.0, "бургер: −60 грн, сытость %d%%" % int(NM.food))
	NM.water = 10.0
	ok(panel.buy("water") and NM.water >= 79.0, "вода: %d%%" % int(NM.water))
	var sn: int = NM.snacks
	ok(panel.buy("bread") and NM.snacks == sn + 1, "хлеб — в запас")
	var kits: int = PR.repair_kits
	ok(panel.buy("repair_kit") and PR.repair_kits == kits + 1, "ремнабор — в запас")
	ok(panel._status.text.contains("Сытость"), "внизу видно, что у меня есть: " + panel._status.text)
	GM.money = 5
	ok(not panel.buy("burger") and panel._status.text.contains("Не хватает"), "без денег не купишь")
	panel.close_panel()
	ok(not paused, "закрыл — игра идёт")
	TM.minutes = 22 * 60.0
	W.open_shop()
	await frames(2)
	ok(not panel.visible, "в 10 вечера закрыто")

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
