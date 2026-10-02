class_name AutoSchool
extends Node3D
## Автошкола: кроме прав категории B (у инструктора, world.gd) здесь сдают
## A — на своём мотоцикле, C — на учебном ГАЗ-53, D — на учебном ПАЗе.
## Для любого экзамена нужны паспорт (сельсовет) и медсправка (больница).
##
## С категорией D и трудовой книжкой берут водителем рейсового автобуса:
## смена у городской остановки.

## Стенд с категориями у будки автошколы
const BOARD := Vector3(-11.0, 0, -17.5)
## Где стоят учебные машины — за полевой дорогой, в стороне от автодрома
const TRUCK_SPOT := Vector3(-15.0, 0.1, -50.0)
const BUS_SPOT := Vector3(-15.0, 0.1, -65.0)
## Учебные «Жигули» — экзамен на права (категория B) сдают на них.
const CAR_SPOT := Vector3(-15.0, 0.1, -29.0)
## [категория, на чём, цена, kind машины]
const CATS := [
	["A", "мотоцикл", 200, "moto"],
	["C", "грузовик", 500, "truck"],
	["D", "автобус", 700, "bus"],
]
const BUS_SHIFT_PAY := 900
const BUS_STOP := Vector3(32.0, 0, 13.0)

var truck: Vehicle
var bus: Vehicle
var car: Vehicle
## Какая категория сейчас сдаётся ("" — никакая)
var exam_cat := ""
var _exams := {}
var _bus_day := -1


func _ready() -> void:
	var b := MeshBuilder.new()
	var c := BOARD
	# Стенд: два столба и щит с тремя табличками
	for x in [-2.4, 2.3]:
		b.box(c + Vector3(x, 0, -0.05), c + Vector3(x + 0.1, 2.3, 0.05), Color(0.4, 0.4, 0.42), true)
	b.box(c + Vector3(-2.5, 1.2, -0.04), c + Vector3(2.5, 2.3, 0.04), Color(0.15, 0.3, 0.6))
	add_child(b.build_mesh())
	add_child(b.build_body())
	for i in CATS.size():
		var cat: Array = CATS[i]
		var l := Label3D.new()
		l.text = "%s\n%s" % [cat[0], cat[1]]
		l.font_size = 96
		l.pixel_size = 0.0028
		l.outline_size = 0
		l.position = c + Vector3(-1.6 + i * 1.6, 1.75, 0.06)
		add_child(l)
		var z := InteractZone.create("", Vector3(1.5, 2.2, 1.8))
		z.position = c + Vector3(-1.6 + i * 1.6, 0, 1.0)
		var ci := i
		z.prompt_fn = func() -> String: return _prompt(ci)
		z.activated.connect(func() -> void: _start(ci))
		add_child(z)
		# Экзамен — тот же маршрут, что на B: змейка, разворот, стоянка
		var ex := DrivingChallenge.new()
		ex.name = "Exam" + String(cat[0])
		ex.title = "Экзамен на %s" % cat[0]
		ex.only_kind = cat[3]
		ex.start_pos = Vector3(9, 0, -22.5)
		ex.points = [Vector3(5.5, 0, -28), Vector3(12.5, 0, -35), Vector3(5.5, 0, -42), Vector3(12.5, 0, -49), Vector3(9, 0, -66)]
		ex.stage_names = {0: "змейка между конусами", 4: "разворот в конце площадки"}
		ex.point_radius = 3.5 if cat[0] == "A" else 4.5
		ex.max_cones = 1 if cat[0] == "A" else 3
		ex.time_limit = 110.0 if cat[0] == "A" else 180.0
		ex.finished.connect(func(r: Dictionary) -> void: _result(ci, r))
		add_child(ex)
		_exams[cat[0]] = ex
	truck = _school_vehicle("truck", TRUCK_SPOT, "SchoolTruck")
	bus = _school_vehicle("bus", BUS_SPOT, "SchoolBus")
	car = _school_vehicle("car", CAR_SPOT, "SchoolCar")
	# На учебных «Жигулях» — только экзамен на права (он в world.gd)
	car.allowed = func() -> bool:
		var ex = get_parent().get("_exam")
		return ex != null and (ex as DrivingChallenge).active()
	var shift := InteractZone.create("", Vector3(3.0, 2.2, 2.0))
	shift.position = BUS_STOP + Vector3(-5.0, 0, 0)
	shift.prompt_fn = _bus_prompt
	shift.activated.connect(_bus_shift)
	add_child(shift)


func _school_vehicle(kind: String, at: Vector3, node_name: String) -> Vehicle:
	var v := Vehicle.new()
	v.kind = kind
	v.name = node_name
	v.school = true
	v.allowed = func() -> bool: return exam_cat != "" and (_exams[exam_cat] as DrivingChallenge).only_kind == kind
	add_child(v)
	v.global_position = at
	v.rotation.y = 0.0
	return v


func _missing_docs() -> String:
	var need: Array = []
	if not Progress.has_doc("passport"):
		need.append("паспорт (сельсовет)")
	if not Progress.has_doc("med"):
		need.append("медсправка (больница)")
	return ", ".join(need)


func _prompt(i: int) -> String:
	var cat: Array = CATS[i]
	if exam_cat != "":
		return "Идёт экзамен на %s — садись и заезжай на старт" % exam_cat if exam_cat == cat[0] else ""
	if Progress.has_category(cat[0]):
		return "Категория %s (%s) у тебя уже есть" % [cat[0], cat[1]]
	var miss := _missing_docs()
	if miss != "":
		return "Категория %s: нужны %s" % [cat[0], miss]
	return "E — экзамен на категорию %s: %s (%d грн)" % [cat[0], cat[1], cat[2]]


func _start(i: int) -> void:
	var cat: Array = CATS[i]
	if exam_cat != "" or Progress.has_category(cat[0]) or _missing_docs() != "":
		return
	if not GameManager.spend(int(cat[2])):
		return
	exam_cat = cat[0]
	Vehicle.exam_category = exam_cat
	(_exams[exam_cat] as DrivingChallenge).arm()
	var on := "на своей «Яве»" if cat[3] == "moto" else "на учебном «%s» у края автодрома" % Vehicle.SPECS[cat[3]].title
	GameManager.notify("Инструктор: «Категория %s. Заезжай %s на старт — жёлтый круг. Конусы не сбивай»" % [cat[0], on])


func _result(i: int, r: Dictionary) -> void:
	var cat: Array = CATS[i]
	exam_cat = ""
	Vehicle.exam_category = ""
	if r.ok:
		Progress.add_category(cat[0])
		SoundLibrary.play("quest")
		QuestManager.event("license_" + String(cat[0]).to_lower())
		GameManager.notify("Сдал на категорию %s за %d с! В правах теперь: %s" % [cat[0], int(r.time), Progress.categories_text()])
	else:
		GameManager.notify("Категория %s не сдана: %s. Пересдача — у стенда автошколы" % [cat[0], r.why])
	# Учебную машину — на место
	var v: Vehicle = truck if cat[3] == "truck" else (bus if cat[3] == "bus" else null)
	if v:
		get_tree().create_timer(4.0).timeout.connect(func() -> void: _park(v))


## Учебные «Жигули» — на место после экзамена на права.
func park_school_car() -> void:
	get_tree().create_timer(4.0).timeout.connect(func() -> void: _park(car))


## Вернуть учебную машину на её место (если из неё вышли).
func _park(v: Vehicle) -> void:
	if v.driver != null:
		if exam_cat == "":
			v.exit_car()
		else:
			return
	v.speed = 0.0
	v.velocity = Vector3.ZERO
	v.global_position = TRUCK_SPOT if v == truck else (BUS_SPOT if v == bus else CAR_SPOT)
	v.rotation = Vector3.ZERO
	v.condition = 100.0
	v.fuel = float(v.spec.tank)


func _process(_delta: float) -> void:
	# Без экзамена на учебной машине не покатаешься — инструктор высадит
	for v in [truck, bus, car]:
		var veh: Vehicle = v
		if veh.driver != null and not (veh.allowed.call() as bool):
			GameManager.notify("Инструктор: «Учебная машина — только на экзамене!»")
			_park(veh)


# --- Рейсовый автобус --------------------------------------------------------

func _bus_prompt() -> String:
	var h := TimeManager.hour()
	if not Progress.has_category("D"):
		return "Автопарк: «Водителем автобуса — с категорией D и трудовой книжкой»"
	if not Progress.has_doc("work_book"):
		return "Автопарк: «Категория D есть — неси трудовую книжку из сельсовета»"
	if _bus_day == TimeManager.day:
		return "Автопарк: «Сегодня ты уже отъездил смену»"
	if h < 6.0 or h > 14.0:
		return "Автопарк: «Смены водителей — с 6:00 до 14:00»"
	return "E — смена водителем рейсового автобуса: 6 часов, +%d грн" % BUS_SHIFT_PAY


func _bus_shift() -> void:
	var h := TimeManager.hour()
	if not Progress.has_category("D") or not Progress.has_doc("work_book") or _bus_day == TimeManager.day or h < 6.0 or h > 14.0:
		return
	if NeedsManager.energy < 30.0:
		GameManager.notify("Автопарк: «Сонный водитель автобуса — беда. Выспись»")
		return
	_bus_day = TimeManager.day
	TimeManager.advance(360.0)
	NeedsManager.rest(-25.0)
	GameManager.add_money(BUS_SHIFT_PAY)
	SoundLibrary.play("cash")
	QuestManager.event("bus_shift")
	GameManager.notify("Отъездил смену на рейсовом: Каменка — город — Каменка. +%d грн. %s" % [BUS_SHIFT_PAY, TimeManager.clock_text()])
