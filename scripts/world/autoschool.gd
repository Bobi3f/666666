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
## Весь асфальт автошколы: автодром, въезд, дорожка к крыльцу, стоянка
## учебных машин и проезд к ней (Roads.on_asphalt — по нему сцепление).
const ASPHALT := [Rect2(-40, 14, 22, 57), Rect2(-32, 1.5, 6, 12.5), Rect2(-26, 13, 16, 2),
	Rect2(-13, 26, 7, 37), Rect2(-18, 26, 5, 4)]
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
		# Экзамен следит за машиной в мире: точки — со сдвигом города
		ex.top_level = true
		ex.start_pos = Town.w(EXAM_START)
		for p in EXAM_POINTS:
			ex.points.append(Town.w(p))
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
	# Учебная легковая — синяя, как в настоящей автошколе
	if kind == "car":
		v.paint = 2
	v.allowed = func() -> bool: return exam_cat != "" and (_exams[exam_cat] as DrivingChallenge).only_kind == kind
	add_child(v)
	v.global_position = Town.w(at)
	v.rotation.y = 0.0
	return v


## Дом автошколы: кирпич, крыльцо, вывеска. Внутри класс как в настоящей
## автошколе: серые стены в плакатах ПДД, светлая плитка, стулья с
## откидными столиками, стол инструктора с креслом, окно с цветами,
## тренажёр с рулём и педалями, стенд экзаменов на категории.
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	WalkIn.shell(b, hs, f, brick, Color(0.5, 0.51, 0.49), Color(0.84, 0.84, 0.82), -2.0, 1.3, 2.3, lamps)
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
	# Плитка: швы на светлом полу
	var x0 := -hx + 0.2
	while x0 < hx - 0.2:
		b.box(Vector3(x0, f, -hz + 0.2), Vector3(x0 + 0.015, f + 0.003, hz - 0.2), Color(0.7, 0.7, 0.68))
		x0 += 0.6
	var z0 := -hz + 0.2
	while z0 < hz - 0.2:
		b.box(Vector3(-hx + 0.2, f, z0), Vector3(hx - 0.2, f + 0.003, z0 + 0.015), Color(0.7, 0.7, 0.68))
		z0 += 0.6
	# Окно в задней стене: рама, стекло (изнутри и снаружи), подоконник с цветами
	var wx0 := -1.3
	var wx1 := 0.4
	b.box(Vector3(wx0 - 0.08, f + 0.95, -hz + 0.2), Vector3(wx1 + 0.08, f + 2.35, -hz + 0.23), Color(0.95, 0.95, 0.95))
	b.box(Vector3(wx0, f + 1.02, -hz + 0.2), Vector3(wx1, f + 2.28, -hz + 0.235), Color(0.72, 0.85, 0.92))
	b.box(Vector3((wx0 + wx1) * 0.5 - 0.03, f + 1.02, -hz + 0.2), Vector3((wx0 + wx1) * 0.5 + 0.03, f + 2.28, -hz + 0.24), Color(0.95, 0.95, 0.95))
	b.box(Vector3(wx0, f + 1.02, -hz - 0.05), Vector3(wx1, f + 2.28, -hz), Color(0.6, 0.75, 0.85))
	b.box(Vector3(wx0 - 0.15, f + 0.9, -hz + 0.2), Vector3(wx1 + 0.15, f + 0.95, -hz + 0.45), Color(0.95, 0.95, 0.93))
	for px in [wx0 + 0.25, wx1 - 0.35]:
		b.box(Vector3(px, f + 0.95, -hz + 0.25), Vector3(px + 0.2, f + 1.12, -hz + 0.42), Color(0.92, 0.92, 0.9))
		for k in 5:
			var lx: float = px + 0.1 + rng.randf_range(-0.12, 0.12)
			var lz := -hz + 0.33 + rng.randf_range(-0.08, 0.08)
			b.box(Vector3(lx - 0.015, f + 1.1, lz - 0.015), Vector3(lx + 0.015, f + 1.1 + rng.randf_range(0.25, 0.5), lz + 0.015), Color(0.3, 0.55, 0.25))
	# Плакаты «Правила дорожного движения» на левой стене — два ряда
	var px0 := -hx + 0.21
	for row in 2:
		for i in 6:
			var z := -hz + 0.3 + i * 1.12
			var y := f + 1.25 + row * 0.78
			b.box(Vector3(px0, y, z), Vector3(px0 + 0.012, y + 0.72, z + 1.04), Color(0.95, 0.95, 0.93))
			b.box(Vector3(px0 + 0.012, y + 0.62, z + 0.02), Vector3(px0 + 0.016, y + 0.7, z + 1.02), Color(0.15, 0.3, 0.65))
			for k in 6:
				var cz := z + 0.06 + (k % 3) * 0.33
				var cy := y + 0.06 + (k / 3) * 0.28
				var col: Color = [Color(0.35, 0.55, 0.3), Color(0.85, 0.75, 0.4), Color(0.4, 0.5, 0.7), Color(0.8, 0.35, 0.3), Color(0.6, 0.6, 0.62)][rng.randi() % 5]
				b.box(Vector3(px0 + 0.012, cy, cz), Vector3(px0 + 0.016, cy + 0.22, cz + 0.28), col)
	# Таблица дорожных знаков на правой стене: синие, запрещающие, треугольники
	var sx := hx - 0.21
	b.box(Vector3(sx - 0.012, f + 1.0, -1.4), Vector3(sx, f + 2.6, 1.8), Color(0.96, 0.96, 0.95))
	b.box(Vector3(sx - 0.016, f + 2.45, -1.35), Vector3(sx - 0.012, f + 2.56, 1.75), Color(0.15, 0.3, 0.65))
	for r in 4:
		for k in 7:
			var z := -1.25 + k * 0.42
			var y := f + 1.1 + r * 0.33
			var kind := (r + k * 3) % 4
			var at := Vector3(sx - 0.014, y, z)
			match kind:
				0:
					b.box(at + Vector3(-0.004, 0, 0), at + Vector3(0, 0.24, 0.24), Color(0.15, 0.35, 0.75))
					b.box(at + Vector3(-0.008, 0.08, 0.06), at + Vector3(-0.004, 0.16, 0.18), Color(0.95, 0.95, 0.95))
				1:
					b.box(at + Vector3(-0.004, 0, 0), at + Vector3(0, 0.24, 0.24), Color(0.85, 0.12, 0.1))
					b.box(at + Vector3(-0.008, 0.04, 0.04), at + Vector3(-0.004, 0.2, 0.2), Color(0.97, 0.97, 0.97))
				2:
					b.tri(at + Vector3(-0.006, 0, 0), at + Vector3(-0.006, 0.24, 0.12), at + Vector3(-0.006, 0, 0.24), Color(0.85, 0.12, 0.1))
					b.tri(at + Vector3(-0.01, 0.04, 0.045), at + Vector3(-0.01, 0.17, 0.12), at + Vector3(-0.01, 0.04, 0.195), Color(0.97, 0.97, 0.97))
				_:
					b.box(at + Vector3(-0.004, 0, 0), at + Vector3(0, 0.24, 0.24), Color(0.95, 0.8, 0.15))
					b.box(at + Vector3(-0.008, 0.1, 0.03), at + Vector3(-0.004, 0.14, 0.21), Color(0.1, 0.1, 0.1))
	# Стол инструктора, кресло за ним, стул для ученика сбоку, бумаги и цветок
	var wood := Color(0.78, 0.6, 0.38)
	WalkIn.counter(b, Vector3(-3.6, f, -2.7), Vector3(-1.6, f + 0.76, -1.9), wood, wood.lightened(0.1))
	b.box(Vector3(-3.3, f + 0.76, -2.5), Vector3(-2.9, f + 0.8, -2.2), Color(0.95, 0.95, 0.9))
	b.box(Vector3(-2.2, f + 0.76, -2.55), Vector3(-2.05, f + 0.9, -2.4), Color(0.2, 0.3, 0.6))
	b.box(Vector3(-1.95, f + 0.76, -2.6), Vector3(-1.75, f + 0.92, -2.4), Color(0.9, 0.9, 0.88))
	for k in 6:
		var lx := -1.85 + rng.randf_range(-0.12, 0.12)
		b.box(Vector3(lx - 0.015, f + 0.92, -2.52), Vector3(lx + 0.015, f + 0.92 + rng.randf_range(0.2, 0.4), -2.48), Color(0.3, 0.55, 0.25))
	_office_chair(b, Vector3(-2.6, f, -3.15))
	_tablet_chair(b, Vector3(-3.9, f, -1.4), 0.6)
	# Стулья с откидными столиками — лицом к столу инструктора, вразнобой
	for row in 3:
		for col in 3:
			var p := Vector3(-0.2 + col * 1.35 + rng.randf_range(-0.15, 0.15), f, -0.9 + row * 1.25 + rng.randf_range(-0.1, 0.1))
			_tablet_chair(b, p, 0.35 + rng.randf_range(-0.25, 0.25))
	# Стенд категорий у задней стены справа
	b.box(Vector3(1.0, f + 1.1, -3.52), Vector3(4.4, f + 2.4, -3.48), Color(0.15, 0.3, 0.6))
	# Тренажёр: рама, сиденье, рулевая колонка с рулём, педали
	var dark := Color(0.12, 0.12, 0.13)
	b.box(Vector3(-4.6, f, 2.0), Vector3(-3.6, f + 0.08, 3.2), dark, true)
	b.box(Vector3(-4.45, f + 0.08, 2.75), Vector3(-3.75, f + 0.45, 3.15), Color(0.25, 0.25, 0.28))
	b.box(Vector3(-4.45, f + 0.45, 3.0), Vector3(-3.75, f + 0.95, 3.12), Color(0.25, 0.25, 0.28))
	b.box(Vector3(-4.15, f + 0.08, 2.15), Vector3(-4.05, f + 0.85, 2.25), Color(0.9, 0.75, 0.15))
	var saved := b.xf
	for a in [0.0, PI / 4.0, PI / 2.0, 3.0 * PI / 4.0]:
		b.xf = saved * Transform3D(Basis(Vector3(0, 0.45, -0.89).normalized(), a), Vector3(-4.1, f + 0.95, 2.35))
		b.box(Vector3(-0.19, -0.015, -0.015), Vector3(0.19, 0.015, 0.015), dark)
	b.xf = saved
	for x in [-4.35, -4.15, -3.95]:
		b.box(Vector3(x, f + 0.08, 2.05), Vector3(x + 0.1, f + 0.2, 2.12), Color(0.5, 0.5, 0.52))
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
	pdd.text = "ПРАВИЛА ДОРОЖНОГО ДВИЖЕНИЯ"
	pdd.font_size = 64
	pdd.pixel_size = 0.003
	pdd.outline_size = 0
	pdd.modulate = Color(0.15, 0.3, 0.65)
	pdd.position = c * Vector3(-hx + 0.24, f + 2.92, 0.0)
	pdd.rotation.y = PI + PI / 2.0
	add_child(pdd)


## Стул с откидным столиком справа: чёрный каркас, серая обивка.
## Сидящий смотрит на −Z (в координатах дома), yaw поворачивает.
func _tablet_chair(b: MeshBuilder, p: Vector3, yaw: float) -> void:
	var saved := b.xf
	b.xf = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	var frame := Color(0.08, 0.08, 0.09)
	var cloth := Color(0.25, 0.25, 0.27)
	for lx in [-0.22, 0.2]:
		for lz in [-0.2, 0.2]:
			b.box(Vector3(lx, 0, lz), Vector3(lx + 0.025, 0.45, lz + 0.025), frame)
	b.box(Vector3(-0.23, 0.42, -0.22), Vector3(0.23, 0.5, 0.23), cloth, true)
	b.box(Vector3(-0.22, 0.5, 0.2), Vector3(0.22, 0.95, 0.26), cloth)
	b.box(Vector3(-0.25, 0.6, -0.15), Vector3(-0.22, 0.64, 0.2), frame)
	b.box(Vector3(0.22, 0.6, -0.15), Vector3(0.25, 0.64, 0.2), frame)
	b.box(Vector3(0.18, 0.66, -0.38), Vector3(0.42, 0.69, 0.05), frame)
	b.xf = saved


## Офисное кресло: крестовина на колёсиках, сиденье, высокая спинка.
func _office_chair(b: MeshBuilder, p: Vector3) -> void:
	var black := Color(0.06, 0.06, 0.07)
	b.box(p + Vector3(-0.32, 0.03, -0.03), p + Vector3(0.32, 0.07, 0.03), black)
	b.box(p + Vector3(-0.03, 0.03, -0.32), p + Vector3(0.03, 0.07, 0.32), black)
	b.box(p + Vector3(-0.03, 0.07, -0.03), p + Vector3(0.03, 0.42, 0.03), Color(0.3, 0.3, 0.32))
	b.box(p + Vector3(-0.26, 0.42, -0.24), p + Vector3(0.26, 0.52, 0.26), black, true)
	b.box(p + Vector3(-0.25, 0.52, -0.32), p + Vector3(0.25, 1.25, -0.22), black)


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
	var on := "на своём мотоцикле" if cat[3] == "moto" else "на учебном «%s» у края автодрома" % Vehicle.SPECS[cat[3]].title
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
	v.global_position = Town.w(TRUCK_SPOT if v == truck else (BUS_SPOT if v == bus else CAR_SPOT))
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
