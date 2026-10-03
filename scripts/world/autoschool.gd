class_name AutoSchool
extends Node3D
## Автошкола: кроме прав категории B (у инструктора, world.gd) здесь сдают
## A — на своём мотоцикле, C — на учебном ГАЗ-53, D — на учебном ПАЗе.
## Для любого экзамена нужны паспорт (сельсовет) и медсправка (больница).
##
## С категорией D и трудовой книжкой берут водителем рейсового автобуса:
## смена у городской остановки.
##
## Стоит к югу от трассы, между Дубравой и школой: кирпичный дом с классом
## (внутрь можно зайти — парты, плакаты со знаками, стол инструктора, стенд
## категорий), рядом автодром и стоянка учебных машин.

## Дом автошколы (центр) — дверью к трассе (локальный +Z смотрит на −Z мира).
const HOUSE := Vector3(-8.0, 0, 21.0)
const HOUSE_SIZE := Vector3(10.0, 3.4, 7.5)
const FLOOR := 0.4
## Автодром (x, z, ширина, длина): въезд с трассы у старта, разворот в конце.
const AUTODROME := Rect2(-40, 14, 22, 57)
const ENTRY := Rect2(-32, 1.5, 6, 12.5)
## Экзамен для любой категории: старт, змейка между конусами, разворот,
## в конце — встать в разметку «P».
const EXAM_START := Vector3(-29, 0, 18.5)
const EXAM_POINTS := [Vector3(-25.5, 0, 24), Vector3(-32.5, 0, 31), Vector3(-25.5, 0, 38), Vector3(-32.5, 0, 45), Vector3(-29, 0, 62)]
const EXAM_CONES := [Vector3(-29, 0, 24), Vector3(-29, 0, 31), Vector3(-29, 0, 38), Vector3(-29, 0, 45)]
const PARK := Vector3(-36.5, 0, 36)
## Где стоят учебные машины — на стоянке за домом автошколы
const TRUCK_SPOT := Vector3(-9.5, 0.1, 42.0)
const BUS_SPOT := Vector3(-9.5, 0.1, 57.0)
## Учебные «Жигули» — экзамен на права (категория B) сдают на них.
const CAR_SPOT := Vector3(-9.5, 0.1, 31.0)
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


## Перевод из координат дома (фасад +Z, пол класса на FLOOR) в мир.
static func xf() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), HOUSE)


func _ready() -> void:
	_build_house()
	var c := xf()
	for i in CATS.size():
		var cat: Array = CATS[i]
		# Таблички категорий на стенде у задней стены класса
		var l := Label3D.new()
		l.text = "%s\n%s" % [cat[0], cat[1]]
		l.font_size = 96
		l.pixel_size = 0.0018
		l.outline_size = 0
		l.position = c * Vector3(1.6 + i * 1.1, FLOOR + 1.75, -3.47)
		l.rotation.y = PI
		add_child(l)
		var z := InteractZone.create("", Vector3(1.0, 2.2, 1.4))
		z.name = "Cat" + String(cat[0])
		z.position = c * Vector3(1.6 + i * 1.1, FLOOR, -2.6)
		var ci := i
		z.prompt_fn = func() -> String: return _prompt(ci)
		z.activated.connect(func() -> void: _start(ci))
		add_child(z)
		# Экзамен — тот же маршрут, что на B: змейка, разворот, стоянка
		var ex := DrivingChallenge.new()
		ex.name = "Exam" + String(cat[0])
		ex.title = "Экзамен на %s" % cat[0]
		ex.only_kind = cat[3]
		ex.start_pos = EXAM_START
		ex.points.assign(EXAM_POINTS)
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


## Дом автошколы: кирпич, крыльцо, вывеска; внутри класс — парты рядами
## лицом к доске, плакаты со знаками, стол инструктора, стенд категорий.
func _build_house() -> void:
	var c := xf()
	var b := MeshBuilder.new()
	b.xf = c
	var lamps := MeshBuilder.new()
	lamps.ground_shade = false
	lamps.xf = c
	var hs := HOUSE_SIZE
	var hx := hs.x * 0.5
	var hz := hs.z * 0.5
	var h := hs.y
	var f := FLOOR
	var brick := Color(0.72, 0.62, 0.48)
	WalkIn.shell(b, hs, f, brick, Color(0.85, 0.88, 0.8), Color(0.5, 0.42, 0.34), -2.0, 1.3, 2.3, lamps)
	# Цоколь — чуть ниже пола класса, иначе их верх рябит
	b.box(Vector3(-hx - 0.1, 0, -hz - 0.1), Vector3(hx + 0.1, f - 0.08, hz + 0.1), Color(0.5, 0.5, 0.48))
	b.box(Vector3(-hx - 0.2, h, -hz - 0.2), Vector3(hx + 0.2, h + 0.25, hz + 0.2), Color(0.35, 0.4, 0.5))
	# Крыльцо с козырьком, вывеска над дверью, окна по фасаду
	b.box(Vector3(-3.4, 0, hz), Vector3(-0.6, f, hz + 1.4), Color(0.58, 0.58, 0.56), true)
	b.box(Vector3(-3.6, 2.85, hz), Vector3(-0.4, 2.97, hz + 1.5), Color(0.45, 0.48, 0.52))
	b.box(Vector3(-1.2, f, hz), Vector3(-1.15, 2.7, hz + 1.1), Color(0.25, 0.35, 0.55))
	b.box(Vector3(0.2, 2.75, hz), Vector3(hx - 0.3, 3.3, hz + 0.08), Color(0.2, 0.35, 0.65))
	for x in [0.8, 3.0]:
		b.box(Vector3(x, 1.2, hz), Vector3(x + 1.4, 2.4, hz + 0.05), Color(0.6, 0.75, 0.85))
	for z in [-2.0, 0.5]:
		b.box(Vector3(hx, 1.2, z), Vector3(hx + 0.05, 2.4, z + 1.4), Color(0.6, 0.75, 0.85))
		b.box(Vector3(-hx - 0.05, 1.2, z), Vector3(-hx, 2.4, z + 1.4), Color(0.6, 0.75, 0.85))
	# Доска и стол инструктора у задней стены (слева), парты рядами к ним
	var wood := Color(0.55, 0.4, 0.26)
	b.box(Vector3(-4.2, f + 0.9, -3.53), Vector3(-0.8, f + 2.1, -3.5), Color(0.15, 0.3, 0.22))
	b.box(Vector3(-4.2, f + 0.85, -3.55), Vector3(-0.8, f + 0.9, -3.42), wood)
	WalkIn.counter(b, Vector3(-3.6, f, -2.7), Vector3(-1.6, f + 0.78, -1.9), wood, wood.lightened(0.2))
	b.box(Vector3(-3.2, f + 0.78, -2.5), Vector3(-2.8, f + 0.8, -2.2), Color(0.95, 0.95, 0.9))
	for row in 3:
		for col in 2:
			# Парты правее прохода от двери к столу инструктора
			var x := -0.7 + col * 1.9
			var z := -0.6 + row * 1.3
			b.box(Vector3(x, f + 0.7, z), Vector3(x + 1.2, f + 0.75, z + 0.5), wood, true)
			b.box(Vector3(x + 0.05, f, z + 0.05), Vector3(x + 0.1, f + 0.7, z + 0.45), wood.darkened(0.3))
			b.box(Vector3(x + 1.1, f, z + 0.05), Vector3(x + 1.15, f + 0.7, z + 0.45), wood.darkened(0.3))
			b.box(Vector3(x + 0.1, f + 0.42, z + 0.6), Vector3(x + 1.1, f + 0.47, z + 0.95), wood.darkened(0.15))
	# Стенд категорий у задней стены справа
	b.box(Vector3(1.0, f + 1.1, -3.52), Vector3(4.4, f + 2.4, -3.48), Color(0.15, 0.3, 0.6))
	# Плакаты со знаками на боковой стене: «STOP», «уступи», «кирпич»
	var signs := [Color(0.8, 0.12, 0.1), Color(0.95, 0.95, 0.9), Color(0.85, 0.15, 0.12)]
	for i in 3:
		var z := -2.5 + i * 1.6
		b.box(Vector3(hx - 0.22, f + 1.2, z), Vector3(hx - 0.2, f + 2.1, z + 0.8), Color(0.92, 0.9, 0.82))
		b.box(Vector3(hx - 0.23, f + 1.35, z + 0.15), Vector3(hx - 0.22, f + 1.95, z + 0.65), signs[i])
		if i == 1:
			b.box(Vector3(hx - 0.235, f + 1.5, z + 0.25), Vector3(hx - 0.23, f + 1.8, z + 0.55), Color(0.85, 0.15, 0.12))
		if i == 2:
			b.box(Vector3(hx - 0.235, f + 1.6, z + 0.2), Vector3(hx - 0.23, f + 1.7, z + 0.6), Color(0.95, 0.95, 0.95))
	# Учебный руль и педали на тумбе в углу
	b.box(Vector3(-4.6, f, 2.3), Vector3(-3.8, f + 0.8, 3.3), Color(0.35, 0.35, 0.38), true)
	b.box(Vector3(-4.3, f + 0.8, 2.6), Vector3(-4.25, f + 1.2, 3.0), Color(0.1, 0.1, 0.1))
	for x in [-1.8, 1.8]:
		WalkIn.lamp(lamps, Vector3(x, h - 0.13, 0.0))
	add_child(b.build_mesh())
	add_child(b.build_body())
	var lm := lamps.build_mesh(true)
	lm.name = "SchoolLamps"
	lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lm)
	var sign := Label3D.new()
	sign.text = "АВТОШКОЛА"
	sign.font_size = 96
	sign.pixel_size = 0.0045
	sign.outline_size = 0
	sign.position = c * Vector3(2.5, 3.02, hz + 0.1)
	sign.rotation.y = PI
	add_child(sign)
	var board := Label3D.new()
	board.text = "ЭКЗАМЕНЫ НА КАТЕГОРИИ"
	board.font_size = 64
	board.pixel_size = 0.0025
	board.outline_size = 0
	board.position = c * Vector3(2.7, f + 2.25, -3.46)
	board.rotation.y = PI
	add_child(board)
	var pdd := Label3D.new()
	pdd.text = "ПДД"
	pdd.font_size = 96
	pdd.pixel_size = 0.004
	pdd.outline_size = 0
	pdd.position = c * Vector3(-1.5, f + 1.85, -3.49)
	pdd.rotation.y = PI
	add_child(pdd)


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
