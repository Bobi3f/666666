extends SceneTree
## Базар: забор вокруг, лавки «Для дома» и «Автозапчасти», покупки
## меняют дом и технику и сохраняются.
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
func child(suffix: String):
	for c in W.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with(suffix): return c
	return null
func stall(S, kind: String):
	for c in S.get_children():
		if c is InteractZone and String(c.name).ends_with(kind): return c
	return null

func _run() -> void:
	for i in 5: await process_frame
	var GM = root.get_node("GameManager"); var TM = root.get_node("TimeManager"); var PR = root.get_node("Progress")
	var NM = root.get_node("NeedsManager"); var SM = root.get_node("SaveManager")
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	TM.day = 3
	TM.minutes = 10 * 60.0
	var S = W.get_node("TownSouth")
	var C: Vehicle = W.get_node("Car")
	var M: Vehicle = W.get_node("Moped")
	PR.buy_car("car")

	print("== Забор и лавки")
	var space := (W as Node3D).get_world_3d().direct_space_state
	var r: Rect2 = Town.wr(S.MARKET)
	var hits := 0
	# Луч поперёк каждой стороны забора упирается в него; в воротах — проход
	for ray in [[Vector3(r.get_center().x, 1.0, r.position.y - 2), Vector3(r.get_center().x, 1.0, r.position.y + 2)],
			[Vector3(r.get_center().x, 1.0, r.end.y + 2), Vector3(r.get_center().x, 1.0, r.end.y - 2)],
			[Vector3(r.position.x - 2, 1.0, r.get_center().y), Vector3(r.position.x + 2, 1.0, r.get_center().y)],
			[Vector3(r.end.x + 2, 1.0, r.position.y + 5), Vector3(r.end.x - 2, 1.0, r.position.y + 5)]]:
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(ray[0], ray[1])).is_empty(): hits += 1
	ok(hits == 4, "забор держит со всех четырёх сторон (%d/4)" % hits)
	var gate := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(r.end.x + 3, 1.0, r.position.y + 16), Vector3(r.end.x - 2.5, 1.0, r.position.y + 16)))
	ok(gate.is_empty(), "в ворота можно пройти")
	var home_z = stall(S, "home"); var parts_z = stall(S, "parts")
	ok(home_z != null and parts_z != null, "есть лавки «Для дома» и «Автозапчасти»")
	ok(home_z.text().contains("ковёр") and parts_z.text().contains("глушак"), "подсказки: " + parts_z.text())
	TM.minutes = 18 * 60.0
	ok(parts_z.text().contains("7:00"), "вечером закрыто")
	TM.minutes = 10 * 60.0

	print("== Для дома")
	GM.money = 2000
	home_z.activate()
	var P: MarketPanel = S.market_panel
	ok(P.visible and paused, "окно открыто, игра на паузе")
	ok(P.buy("fridge") and PR.has_item("fridge") and GM.money == 1400, "купил холодильник за 600")
	ok(not P.buy("fridge"), "второй раз не продают")
	P.buy("rug"); P.buy("tape"); P.buy("chair")
	P.close_panel()
	await frames(3)
	var HI = W.get_node("HomeItems")
	ok(HI.has_node("Fridge") and HI.has_node("Rug") and HI.has_node("Tape") and HI.has_node("Chair"), "дома стоят холодильник, ковёр, магнитофон и кресло")
	HI.toggle_tape()
	ok(HI._tape.playing, "магнитофон играет")
	HI.toggle_tape()
	var sn: int = NM.snacks
	PR.fridge_day = 0
	TM.advance(1.0)
	ok(NM.snacks == sn + 1, "холодильник дал еды утром")
	TM.advance(1.0)
	ok(NM.snacks == sn + 1, "второй раз за день — нет")

	print("== Запчасти")
	GM.money = 5000
	parts_z.activate()
	ok(P.mode == "parts" and P._vehicles.has(C) and P._vehicles.has(M), "в списке своя техника: машина и мопед")
	P.select(C)
	var t0 := C.tank()
	var q0 := C._torque()
	ok(P.buy("tank") and is_equal_approx(C.tank(), t0 * 1.5), "бак: %d → %d л" % [int(t0), int(C.tank())])
	ok(P.buy("exhaust") and C._torque() > q0 and C._body.has_node("Exhaust"), "глушак: тяга больше, труба видна")
	ok(P.buy("speedo") and C.has_part("speedo"), "спидометр с подсветкой")
	var y0: float = C._body.position.y
	ok(P.buy("wheels") and C._body.position.y > y0 and C._wheels[0].scale.x > 1.1, "большие колёса — машина выше")
	ok(P.buy("rims") and int(C.parts["rims"]) == 0, "диски хром")
	ok(P.buy("rims") and int(C.parts["rims"]) == 1, "ещё раз — чёрные")
	P.select(M)
	ok(P.buy("wheels") and M.has_part("wheels") and not C.has_part("tank") == false, "мопеду — свои колёса")
	P.close_panel()
	GM.money = 10
	parts_z.activate()
	P.select(M)
	ok(not P.buy("exhaust") and P._status.text.contains("денег"), "без денег не продают")
	P.close_panel()

	print("== Сохранение")
	var data: Dictionary = C.save_state()
	C.parts = {}
	C._apply_parts()
	ok(not C._body.has_node("Exhaust"), "сбросили")
	C.load_state(data)
	ok(C.has_part("exhaust") and C.has_part("wheels") and int(C.parts["rims"]) == 1 and C._body.has_node("Exhaust"), "запчасти вернулись из сохранения")
	var old := C.save_state()
	old.erase("parts")
	C.load_state(old)
	ok(C.parts.is_empty() and is_equal_approx(C._body.position.y, 0.0), "старое сохранение — без запчастей")
	var pd: Dictionary = PR.save_state()
	ok(int(pd.get("fridge", -1)) == TM.day, "день холодильника сохраняется")

	print("\nИТОГО: " + ("всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ, провалов: %d" % fails))
	quit(1 if fails else 0)
