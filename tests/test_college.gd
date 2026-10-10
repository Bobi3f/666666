extends SceneTree
## Ученики бурсы: в будни приходят и приезжают к 8:00, днём их мотоциклы и
## машины стоят во дворе, после уроков разъезжаются; ночью и в выходные
## двор пуст. Всё — по часам: после перемотки времени все на местах.
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


func count(cl: CollegeLife, what: String) -> int:
	var n := 0
	for s in cl.students:
		if what == "people" and (s.man as Node3D).visible: n += 1
		if what == "veh" and s.has("veh") and (s.veh as Node3D).visible: n += 1
	return n


func at(cl: CollegeLife, TM, h: float) -> void:
	TM.minutes = h * 60.0
	cl.settle()


func _run() -> void:
	await frames(5)
	var TM = root.get_node("TimeManager")
	var cl: CollegeLife = get_first_node_in_group("college_life")
	ok(cl != null and cl.students.size() == 10, "у бурсы 10 учеников")
	var bikes := 0
	var cars := 0
	for s in cl.students:
		if s.kind == "moto": bikes += 1
		if s.kind == "car": cars += 1
	ok(bikes == 2 and cars == 2, "двое на мотоциклах, двое на машинах, остальные пешком")
	TM.day = 8
	ok(CollegeLife.school_day(), "понедельник — учебный день")
	at(cl, TM, 6.0)
	ok(count(cl, "people") == 0 and count(cl, "veh") == 0, "в 6:00 во дворе никого")
	at(cl, TM, 7.5)
	ok(count(cl, "people") + count(cl, "veh") >= 3, "в 7:30 сходятся: %d в пути" % (count(cl, "people") + count(cl, "veh")))
	at(cl, TM, 7.6)
	var moving := false
	for s in cl.students:
		if s.kind == "car" and (s.veh as Node3D).visible and (s.veh as Node3D).position.distance_to(s.spot) > 2.0:
			moving = true
	ok(moving, "машина едет к бурсе")
	at(cl, TM, 12.0)
	ok(count(cl, "people") == 0, "днём все на уроках")
	ok(count(cl, "veh") == 4, "во дворе два мотоцикла и две машины")
	var parked := true
	for s in cl.students:
		if s.has("veh"):
			parked = parked and (s.veh as Node3D).position.distance_to(Vector3(s.spot.x, 0.05, s.spot.z)) < 0.1
			if s.veh.has_meta("rider"):
				parked = parked and not (s.veh.get_meta("rider") as Node3D).visible
	ok(parked, "стоят на своих местах, седоков на мотоциклах нет")
	var car: Node3D
	for s in cl.students:
		if s.kind == "car": car = s.veh
	ok(not (car.get_meta("shape") as CollisionShape3D).disabled, "в машину во дворе не проехать насквозь")
	var idle := get_nodes_in_group("college_idle")
	ok(idle.size() == 3 and (idle[0] as Node3D).visible, "у входа днём стоят трое")
	at(cl, TM, 15.3)
	ok(count(cl, "people") >= 2, "после уроков выходят: %d" % count(cl, "people"))
	var riding := false
	for s in cl.students:
		if s.kind == "moto" and s.veh.get_meta("rider").visible: riding = true
	ok(riding, "мотоциклист завёлся и уезжает")
	at(cl, TM, 17.0)
	ok(count(cl, "people") == 0 and count(cl, "veh") == 0, "к 17:00 разъехались")
	ok(car.get_meta("shape").disabled, "уехавшая машина не мешает")
	ok(not (idle[0] as Node3D).visible, "у входа никого")
	TM.day = 13
	at(cl, TM, 12.0)
	ok(not CollegeLife.school_day() and count(cl, "veh") == 0 and not (idle[0] as Node3D).visible, "в субботу двор пуст")
	print("\nИТОГО: %s, провалов: %d" % ["всё работает" if fails == 0 else "ЕСТЬ ОШИБКИ", fails])
	quit()
