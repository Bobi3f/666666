extends SceneTree
## Автошкола на новом месте (к югу от трассы): в дом можно войти, внутри —
## инструктор (права B) и стенд категорий, автодром и учебные машины рядом.
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
func frames(n: int) -> void:
	for i in n: await physics_frame
func key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)
func ray(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	return not (W as Node3D).get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _run() -> void:
	for i in 5: await process_frame
	child("pause_menu.gd")._close()
	child("tutorial.gd")._finish()
	for i in 3: await physics_frame
	var PR = root.get_node("Progress")
	var TM = root.get_node("TimeManager")
	var AS: AutoSchool = W.get_node("AutoSchool")
	var xf: Transform3D = AutoSchool.xf()
	var a: Rect2 = AutoSchool.AUTODROME
	var y := AutoSchool.FLOOR + 1.0

	print("== Место")
	ok(AutoSchool.HOUSE.z > 10.0 and a.position.y > 5.0, "к югу от трассы")
	ok(not a.has_point(Vector2(AutoSchool.HOUSE.x, AutoSchool.HOUSE.z)), "дом рядом с автодромом, не на нём")
	ok(a.has_point(Vector2(AutoSchool.EXAM_START.x, AutoSchool.EXAM_START.z)), "старт экзамена на автодроме")
	var inside := true
	for p in AutoSchool.EXAM_POINTS + AutoSchool.EXAM_CONES + [AutoSchool.PARK]:
		inside = inside and a.has_point(Vector2(p.x, p.z))
	ok(inside, "все точки, конусы и стоянка — на автодроме")
	var school_rect: Rect2 = TownSouth.SCHOOL
	ok(not school_rect.intersects(a) and not school_rect.has_point(Vector2(AutoSchool.BUS_SPOT.x, AutoSchool.BUS_SPOT.z + 5.0)), "со школой не пересекается")
	ok(not ray(Vector3(-29, 1, 8), Vector3(-29, 1, 70)), "автодром от въезда до конца свободен")
	ok(not ray(Vector3(-9.5, 1.2, 27), Vector3(-9.5, 1.2, 25.5)) and W.get_node("AutoSchool/SchoolCar").global_position.distance_to(AutoSchool.CAR_SPOT) < 1.0, "учебные машины на стоянке за домом")

	print("== Дом")
	ok(ray(xf * Vector3(3.0, y, 6.0), xf * Vector3(3.0, y, 0.0)), "фасад — стена")
	ok(not ray(xf * Vector3(-2.0, y, 6.0), xf * Vector3(-2.0, y, 0.5)), "в дверь можно войти")
	ok(ray(xf * Vector3(0.0, y, 0.0), xf * Vector3(0.0, y, -6.0)), "задняя стена держит")
	var room := Rect2(AutoSchool.HOUSE.x - 5, AutoSchool.HOUSE.z - 3.75, 10, 7.5)
	var iz: Node3D = W.get_node("InstructorZone")
	ok(room.has_point(Vector2(iz.global_position.x, iz.global_position.z)), "инструктор — внутри, у стола")
	PR.add_doc("passport")
	PR.add_doc("med")
	var cats := 0
	for c in ["CatA", "CatC", "CatD"]:
		var z: Node3D = AS.get_node(c)
		if room.has_point(Vector2(z.global_position.x, z.global_position.z)): cats += 1
	ok(cats == 3, "стенд категорий A, C, D — внутри")

	print("== Игрок заходит")
	var P = W.get_node("Player")
	var from: Vector3 = xf * Vector3(-2.0, 0.0, 7.5)
	var to: Vector3 = xf * Vector3(-2.2, AutoSchool.FLOOR, -1.0)
	P.global_position = from + Vector3(0, 0.15, 0)
	P.velocity = Vector3.ZERO
	var d := to - from
	P.rotation.y = atan2(-d.x, -d.z)
	await frames(3)
	key(KEY_W, true)
	for i in 300:
		await physics_frame
		if Vector2(P.global_position.x - to.x, P.global_position.z - to.z).length() < 0.6: break
	key(KEY_W, false)
	await frames(10)
	ok(Vector2(P.global_position.x - to.x, P.global_position.z - to.z).length() < 1.0, "с улицы через крыльцо и дверь — в класс")
	ok(P.global_position.y > AutoSchool.FLOOR - 0.1, "стоит на полу класса")
	ok(P._zones.has(iz) and iz.text().contains("сдать на права"), "у стола инструктора: " + iz.text())
	# К стенду категорий — вдоль задней стены
	var cz: Node3D = AS.get_node("CatC")
	P.global_position = cz.global_position + Vector3(0, 0.15, 0)
	await frames(5)
	ok(P._zones.has(cz) and cz.text().contains("категорию C"), "у стенда: " + cz.text())

	print("== Учебная машина и права")
	var SC: Vehicle = AS.car
	ok(SC.paint_name() == "синий" and SC._body.has_node("SchoolMarks"), "учебная — синяя, с полосой и знаком «У»")
	ok(not W.get_node("Car")._body.has_node("SchoolMarks"), "у своих машин знака нет")
	var card: LicenseCard = W.get_node("LicenseCard")
	ok(not card._any(), "прав ещё нет")
	TM.day = 4
	PR.add_category("B")
	TM.day = 6
	PR.add_category("C")
	ok(card._has("B") and card._has("C") and not card._has("A") and int(PR.category_days["B"]) == 4 and int(PR.category_days["C"]) == 6, "в карточке: B с 4-го дня, C с 6-го")
	ok(PR.license_no.begins_with("ВХХ №"), "номер удостоверения: " + PR.license_no)
	var J = child("journal.gd")
	J._open(false)
	J._license_btn.pressed.emit()
	ok(card.visible and paused, "журнал → «Водительское удостоверение» — карточка")
	card.close_card()
	ok(not card.visible and paused, "закрыл — снова журнал (пауза)")
	J._close()
	var sd: Dictionary = PR.save_state()
	PR.category_days = {}
	PR.load_state(sd)
	ok(int(PR.category_days.get("C", 0)) == 6, "дни категорий сохраняются")

	print("\nИТОГО: " + ("всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ, провалов: %d" % fails))
	quit(1 if fails else 0)
