extends SceneTree
## Ферма у Каменки: участок за забором с воротами, в коровник, гараж и
## ангар можно зайти, коровы в стойлах, техника на площадке; покупка,
## доход по утрам, дойка раз в день, сохранение.
var fails := 0
var W
func ok(c: bool, w: String) -> void:
	print(("  OK   " if c else "  FAIL ") + w)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func _initialize() -> void:
	W = load("res://scenes/World.tscn").instantiate()
	root.add_child(W)
	_run.call_deferred()
func _run() -> void:
	await frames(10)
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager"); var DM = root.get_node("Daily")
	var farm: Farm = W.get_node("Farm")
	ok(farm != null, "ферма есть")
	var space: PhysicsDirectSpaceState3D = W.get_world_3d().direct_space_state
	var hit := func(a: Vector3, b: Vector3) -> bool:
		return not space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b)).is_empty()

	print("== Участок и вход")
	var A := Farm.AREA
	ok(not hit.call(Vector3(Farm.GATE_X, 1.0, A.position.y - 3.0), Vector3(Farm.GATE_X, 1.0, A.position.y + 3.0)), "ворота открыты")
	ok(hit.call(Vector3(A.position.x + 5.0, 1.0, A.position.y - 3.0), Vector3(A.position.x + 5.0, 1.0, A.position.y + 3.0)), "сбоку от ворот — забор")
	ok(hit.call(Vector3(A.end.x + 3.0, 1.0, A.get_center().y), Vector3(A.end.x - 3.0, 1.0, A.get_center().y)), "забор и сбоку участка")
	var B := Farm.BARN
	ok(not hit.call(Vector3(B.position.x - 3.0, 1.0, B.get_center().y), Vector3(B.position.x + 4.0, 1.0, B.get_center().y)), "в коровник заходишь через ворота в торце")
	ok(hit.call(Vector3(B.get_center().x, 1.0, B.position.y - 2.0), Vector3(B.get_center().x, 1.0, B.position.y + 2.0)), "длинная стена коровника глухая")
	var G := Farm.GARAGE
	ok(not hit.call(Vector3(G.position.x - 3.0, 1.0, G.get_center().y), Vector3(G.position.x + 3.0, 1.0, G.get_center().y)), "в гараж можно заехать")
	var H := Farm.HANGAR
	ok(not hit.call(Vector3(H.get_center().x, 1.0, H.position.y - 3.0), Vector3(H.get_center().x, 1.0, H.position.y + 6.0)), "в ангар можно заехать")
	# Деревья луга обходят ферму
	var trees := 0
	var veg = W.get_node_or_null("Vegetation")
	if veg:
		for kind in veg._trees:
			for xf in veg._trees[kind]:
				var o: Vector3 = (xf as Transform3D).origin
				if A.has_point(Vector2(o.x, o.z)): trees += 1
	ok(trees == 0, "на участке фермы деревьев нет: %d" % trees)
	var cows: MeshInstance3D = farm.get_node("FarmCows")
	ok(cows != null and cows.mesh.get_aabb().size.x > 20.0, "коровы в стойлах коровника")

	print("== Покупка")
	TM.minutes = 10 * 60.0
	GM.money = 1000
	ok(not farm.milk_cows(), "чужих коров не подоишь")
	ok(not DM.buy("farm") and not DM.owns("farm"), "денег мало — не продают")
	GM.money = 25000
	ok(DM.buy("farm") and DM.owns("farm"), "купил ферму за %d грн" % int(DM.BUSINESSES.farm.price))
	ok(farm._sign.text == "ТВОЯ ФЕРМА", "на воротах — «ТВОЯ ФЕРМА»")
	var m0: int = GM.money
	ok(farm.milk_cows() and GM.money == m0 + Farm.MILK_PAY, "подоил коров: +%d грн" % Farm.MILK_PAY)
	ok(not farm.milk_cows(), "второй раз за день — нет")
	var m1: int = GM.money
	GM.in_game = true
	DM.paid_day = TM.day
	TM.minutes = 23.9 * 60.0
	TM.advance(8.0 * 60.0)
	await frames(2)
	var net: int = DM.income("farm") - DM.tax_of(DM.income("farm"))
	ok(GM.money >= m1 + net, "утром — доход фермы +%d грн после налога" % net)
	ok(farm.milk_prompt().begins_with("E — подоить"), "новый день — снова доить")

	print("== Сохранение")
	farm.milk_cows()
	var st: Dictionary = farm.save_state()
	farm.load_state({})
	ok(farm.milk_day == -1, "старое сохранение — ферма как новая")
	farm.load_state(st)
	ok(farm.milk_day == TM.day, "день дойки сохраняется")

	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
