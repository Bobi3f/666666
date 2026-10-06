class_name TownEast
extends Node3D
## Восточная часть города и дворы: бурса (ПТУ), банк, авторынок, городское
## СТО, гаражи на продажу, новые кирпичные дома, частные участки, парк
## культуры с колесом обозрения и эстрадой, детские площадки во дворах
## пятиэтажек.
##
## Всё — в координатах города: узел стоит на Town.SHIFT, общий меш строится
## со сдвигом (MeshBuilder.shift). Где логика сравнивает с машинами в мире —
## точки переводятся через Town.w.

const Villagers := preload("res://scripts/world/villagers.gd")
## Восточная улица (вдоль Z) и проезд к ней от гаражной дороги (вдоль X).
const EAST_STREET := Rect2(262, 4, 6, 196)
const EAST_ROAD := Rect2(206, 52, 56, 6)
const BANK := Rect2(190, 12, 22, 14)
const CAR_MARKET := Rect2(216, 12, 42, 36)
const STO := Rect2(238, 61, 20, 13)
const COLLEGE := Rect2(236, 100, 14, 40)
const FLATS := [Rect2(274, 70, 13, 40), Rect2(274, 124, 13, 40)]
const PLOTS := Rect2(204, 148, 54, 50)
const PARK := Rect2(-40, 132, 76, 66)
const MY_GARAGES := Rect2(274, 172, 8, 26)
## Колесо обозрения: центр, радиус.
const WHEEL := Vector3(-14.0, 0, 176.0)
const WHEEL_R := 10.0
const WHEEL_PRICE := 20
const COURSE_PRICE := 600
## Курсы: три урока (по одному в день, 2 часа), потом экзамен.
const COURSE_LESSONS := 3
const LESSON_MIN := 120.0
## Вопросы автослесаря: [вопрос, верный, неверный, неверный].
const MECHANIC_QUIZ := [
	["Что смазывает мотор изнутри?", "Моторное масло", "Тосол", "Тормозная жидкость"],
	["Мотор перегрелся, стрелка в красной зоне — что сделать первым?", "Остановиться и дать остыть", "Долить холодной воды в горячий радиатор", "Газовать сильнее"],
	["Педаль тормоза проваливается — что проверить?", "Тормозную жидкость и колодки", "Масло в моторе", "Давление в шинах"],
	["Зачем нужно сцепление?", "Отсоединить мотор от коробки при переключении", "Чтобы машина светила фарами", "Охлаждать мотор"],
	["Свечи зажигания нужны, чтобы…", "Поджигать смесь в цилиндрах", "Светить в салоне", "Заряжать аккумулятор"],
	["Машина плохо заводится в мороз. Что виновато чаще всего?", "Слабый аккумулятор", "Грязные стёкла", "Новые колодки"],
	["Карбюратор…", "Готовит смесь бензина с воздухом", "Охлаждает тормоза", "Крутит колёса"],
	["Стук в подвеске на кочках — это обычно…", "Изношенные амортизаторы", "Пустой бак", "Громкое радио"],
	["Какое давление в шинах «Жигулей»?", "Около двух атмосфер", "Десять атмосфер", "Полатмосферы"],
	["Ремень генератора свистит — значит…", "Ослаб или изношен", "Мотор новый", "Бензин хороший"],
	["Масло в моторе меняют примерно каждые…", "10 тысяч километров", "100 километров", "Никогда"],
	["Синий дым из выхлопной трубы — признак того, что…", "Мотор ест масло", "Бак полный", "Колёса накачаны"],
]
const SHIFT_PAY := 250
## Смена на СТО: премия, если поломку нашёл с первого раза; где машина
## клиента (на подъёмнике); жалобы клиентов: [жалоба, верный узел, два неверных].
const STO_BONUS := 50
const STO_CAR := Vector3(252.95, 0, 67.0)
const STO_FAULTS := [
	["Клиент: «Скрипит и плохо тормозит»", "Тормозные колодки", "Сцепление", "Амортизаторы"],
	["Клиент: «На кочках стучит спереди, машину бросает»", "Амортизаторы", "Тормозные колодки", "Резина"],
	["Клиент: «Газую — обороты растут, а не едет, пахнет горелым»", "Сцепление", "Мотор (капремонт)", "Тормозные колодки"],
	["Клиент: «Дымит сизым и масло ест»", "Мотор (капремонт)", "Сцепление", "Амортизаторы"],
	["Клиент: «Резина лысая, на мокром ведёт»", "Резина", "Амортизаторы", "Тормозные колодки"],
]
const GARAGE_PRICE := 2500
## Своё жильё в городе: [id вещи, название, цена, где купить, где спать,
## поворот таблички] — домик на первом участке и квартира в шестиэтажке.
const HOMES := [
	["town_house", "дом в городе", 25000, Vector3(213.0, 0, 174.0), Vector3(213.0, 0, 160.2), 0.0],
	["flat", "квартиру в шестиэтажке", 18000, Vector3(272.0, 0, 76.0), Vector3(272.0, 0, 76.0), -PI / 2.0],
]
## Детские площадки во дворах пятиэтажек.
const PLAYGROUNDS := [Rect2(52, 85, 30, 13), Rect2(126, 85, 20, 13)]

var sto_day := -1
## Смена на СТО: 0 — заказа нет, 1 — машина ждёт ремонта, 2 — починена, сдать
var sto_stage := 0
var sto_fault := 0
var sto_miss := 0
var _client_car: Node3D
var master_panel: StoPanel
## Курсы автослесаря: оплачены ли, сколько уроков пройдено, в какой день был
## последний урок или экзамен.
var course_paid := false
var course_lessons := 0
var course_day := -1
var lesson_panel: LessonPanel
var _rotor: Node3D
var _cabins: Array[MeshInstance3D] = []
var _garage_label: Label3D
var _world: Node3D
var _glow: MeshBuilder


func _ready() -> void:
	add_to_group("persist")
	add_to_group("town_east")


func _process(delta: float) -> void:
	if _rotor == null:
		return
	_rotor.rotation.z += delta * 0.12
	for i in _cabins.size():
		var a := _rotor.rotation.z + i * TAU / _cabins.size()
		_cabins[i].position = WHEEL + Vector3(cos(a) * WHEEL_R, WHEEL_R + 1.5 + sin(a) * WHEEL_R - 1.1, 0)


## b, glow — общий меш мира (со сдвигом на город), veg — деревья и трава.
func build(world: Node3D, b: MeshBuilder, glow: MeshBuilder, veg: Vegetation) -> void:
	_world = world
	_glow = glow
	for r in [EAST_STREET, EAST_ROAD, BANK, CAR_MARKET, STO, COLLEGE, MY_GARAGES, FLATS[0], FLATS[1]]:
		var g := (r as Rect2).grow(1.5)
		veg.block(g.position.x, g.position.y, g.end.x, g.end.y)
	_roads(b)
	_bank(b, glow)
	_car_market(b)
	_sto(b, glow)
	_garages(b)
	_college(b, glow, veg)
	# Задворки у бурсы: девятиэтажки, котельная, теплотрасса, тусовка
	Backlot.build(self, b, glow, veg)
	for f in FLATS:
		_flats(b, glow, f)
	_plots(b, veg)
	_homes()
	_park(b, glow, veg)
	for p in PLAYGROUNDS:
		_playground(b, p)
	_town_people()


## Горожане с просьбами (QuestManager, t_*): мастер у СТО, продавщица
## у рынка, лейтенант у милиции, дворник во дворе, студент у бурсы.
## Точки — в координатах города (узел стоит на Town.SHIFT).
func _town_people() -> void:
	var people := [
		["Мастер Николаич", Vector3(STO.end.x + 2.2, 0, STO.position.y + 8.0), -PI / 2.0, Color(0.55, 0.3, 0.15), false,
			["Машина — она как человек: не лечишь — ломается.", "Покраска полчаса, колодки — минут сорок. Подгоняй к воротам.", "Корочку автослесаря в бурсе получишь — бери смены, мне руки нужны."]],
		["Продавщица Зоя", Vector3(88.5, 0, 137.5), -PI / 2.0, Color(0.7, 0.3, 0.45), true,
			["Свежее сало, молоко с утра! Рынок до четырёх.", "В лавке «К свадьбе» кольца — золото настоящее, не сомневайся.", "Ярмарка у нас по выходным — урожай везут со всего района."]],
		["Лейтенант Сидоренко", Police.STATION + Vector3(-11.0, 0, 1.0), PI / 2.0, Color(0.3, 0.36, 0.3), false,
			["Права при себе? Документы — первое дело.", "В патруль берём с правами. Смена — триста гривен.", "Гоняешь — штрафуем. Ездишь аккуратно — уважаем."]],
		["Дворник Степаныч", Vector3(50.0, 0, 91.5), -PI / 2.0, Color(0.35, 0.4, 0.3), false,
			["Двор мету с шести утра. Чисто, как в Москве!", "Детвора с площадки мячом окна побила — опять.", "В пятиэтажках лифтов нет, а на пятый этаж — пешком."]],
		["Студент Димка", Vector3(COLLEGE.end.x + 6.0, 0, COLLEGE.position.y + 28.0), PI / 2.0, Color(0.2, 0.4, 0.65), false,
			["Бурса — это сила! После курсов — сразу на СТО.", "Экзамен у нас строгий: пять вопросов, надо четыре.", "Колька из Каменки, говорят, на мопеде до моста быстрее всех."]],
	]
	for p in people:
		Villagers.talker(self, p[0], p[1], p[2], p[3], p[4], p[5])


# --- Улицы ----------------------------------------------------------------------

func _roads(b: MeshBuilder) -> void:
	var asphalt := Color(0.3, 0.3, 0.31)
	var curb := Color(0.6, 0.6, 0.58)
	for r in [EAST_STREET, EAST_ROAD]:
		var rr: Rect2 = r
		b.box(Vector3(rr.position.x, 0, rr.position.y), Vector3(rr.end.x, 0.05, rr.end.y), asphalt)
	# Тротуары вдоль восточной улицы
	b.box(Vector3(EAST_STREET.position.x - 2.0, 0, 8.0), Vector3(EAST_STREET.position.x, 0.12, 198.0), curb.darkened(0.15))
	b.box(Vector3(EAST_STREET.end.x, 0, 8.0), Vector3(EAST_STREET.end.x + 2.0, 0.12, 198.0), curb.darkened(0.15))
	RoadDetails.center_line(b, Vector2(265, 58), Vector2(265, 198))
	# Тротуар вдоль трассы дальше на восток
	b.box(Vector3(190, 0, 5), Vector3(262, 0.12, 7.5), Color(0.5, 0.5, 0.49))
	var x := 190.0
	while x < 262.0:
		b.box(Vector3(x, 0, 4.85), Vector3(x + 0.95, 0.19, 5.05), curb)
		x += 1.0
	# Фонари по восточной улице и проезду к ней
	var lz := 20.0
	while lz < 196.0:
		RoadDetails.lamp(b, _glow, Vector3(EAST_STREET.end.x + 1.5, 0, lz), PI / 2.0)
		lz += 30.0
	for lx in [215.0, 245.0]:
		RoadDetails.lamp(b, _glow, Vector3(lx, 0, EAST_ROAD.end.y + 1.0), 0.0)
	RoadDetails.center_line(b, Vector2(265, 8), Vector2(265, 52))
	_label("ул. Заводская", Vector3(EAST_STREET.position.x - 2.2, 2.6, 10.0), -PI / 2.0, 0.004, Color(1, 1, 1))
	b.box(Vector3(EAST_STREET.position.x - 2.25, 0, 9.9), Vector3(EAST_STREET.position.x - 2.15, 2.4, 10.1), Color(0.35, 0.35, 0.37))
	b.box(Vector3(EAST_STREET.position.x - 2.3, 2.4, 9.0), Vector3(EAST_STREET.position.x - 2.25, 2.8, 11.0), Color(0.15, 0.3, 0.6))


# --- Банк ----------------------------------------------------------------------

## Банк: два этажа, колонны у входа со стороны трассы, вывеска. Окошки вклада —
## у входа (business_spots.gd, BANK там — точка у двери).
func _bank(b: MeshBuilder, glow: MeshBuilder) -> void:
	var r := BANK
	var wall := Color(0.88, 0.86, 0.8)
	b.box(Vector3(r.position.x, 0, r.position.y + 2.0), Vector3(r.end.x, 7.2, r.end.y), wall, true)
	b.box(Vector3(r.position.x - 0.3, 7.2, r.position.y + 1.7), Vector3(r.end.x + 0.3, 7.6, r.end.y + 0.3), Color(0.55, 0.55, 0.56))
	# Крыльцо и колонны
	b.box(Vector3(r.position.x + 5.0, 0, r.position.y - 0.5), Vector3(r.end.x - 5.0, 0.35, r.position.y + 2.0), Color(0.7, 0.7, 0.68), true)
	b.box(Vector3(r.position.x + 5.0, 5.6, r.position.y - 0.5), Vector3(r.end.x - 5.0, 6.2, r.position.y + 2.0), wall.darkened(0.05))
	for k in 4:
		var cx := r.position.x + 6.0 + k * 3.3
		b.box(Vector3(cx - 0.3, 0.35, r.position.y - 0.2), Vector3(cx + 0.3, 5.6, r.position.y + 0.4), Color(0.95, 0.94, 0.9), true)
	var cx0 := r.get_center().x
	b.box(Vector3(cx0 - 1.2, 0.35, r.position.y + 1.95), Vector3(cx0 + 1.2, 3.0, r.position.y + 2.0), Color(0.35, 0.45, 0.5))
	glow.box(Vector3(cx0 - 1.1, 0.4, r.position.y + 1.93), Vector3(cx0 + 1.1, 2.9, r.position.y + 1.94), Color(1.0, 0.92, 0.75))
	for fl in 2:
		var y := 1.2 + fl * 3.3
		var x := r.position.x + 1.5
		while x < r.end.x - 1.5:
			if absf(x + 0.8 - cx0) > 2.0 or fl == 1:
				b.box(Vector3(x, y, r.position.y + 1.95), Vector3(x + 1.6, y + 1.8, r.position.y + 2.0), Color(0.3, 0.4, 0.48))
				if (int(x) + fl) % 3 != 0:
					glow.box(Vector3(x + 0.1, y + 0.1, r.position.y + 1.93), Vector3(x + 1.5, y + 1.7, r.position.y + 1.94), Color(1.0, 0.9, 0.7))
			x += 2.6
	b.box(Vector3(cx0 - 5.0, 6.25, r.position.y - 0.55), Vector3(cx0 + 5.0, 7.1, r.position.y - 0.5), Color(0.12, 0.35, 0.25))
	_label("БАНК", Vector3(cx0, 6.68, r.position.y - 0.58), PI, 0.01, Color(1.0, 0.9, 0.55))


# --- Авторынок -------------------------------------------------------------------

## Авторынок: площадка за сеткой, ряды подержанных машин с ценниками,
## будка продавца. «Нива» и ГАЗ-53 здесь продаются (world.gd, SALON_CARS),
## остальные уже сторговали.
func _car_market(b: MeshBuilder) -> void:
	var r := CAR_MARKET
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0.04, r.end.y), Color(0.42, 0.4, 0.37))
	for side in [[r.position.x, r.position.y + 3.0, r.position.x + 0.1, r.end.y], [r.end.x - 0.1, r.position.y + 3.0, r.end.x, r.end.y],
			[r.position.x, r.end.y - 0.1, r.end.x, r.end.y]]:
		b.box(Vector3(side[0], 0, side[1]), Vector3(side[2], 1.8, side[3]), Color(0.55, 0.6, 0.55), true)
	# Ворота-арка с вывеской со стороны трассы
	for gx in [r.position.x + 12.0, r.position.x + 30.0]:
		b.box(Vector3(gx - 0.15, 0, r.position.y + 0.8), Vector3(gx + 0.15, 4.6, r.position.y + 1.1), Color(0.3, 0.32, 0.36), true)
	b.box(Vector3(r.position.x + 12.0, 3.8, r.position.y + 0.85), Vector3(r.position.x + 30.0, 4.6, r.position.y + 1.05), Color(0.8, 0.2, 0.15))
	_label("АВТОРЫНОК", Vector3(r.position.x + 21.0, 4.2, r.position.y + 0.8), PI, 0.009, Color(1, 1, 1))
	# Будка продавца
	var k := Vector3(r.end.x - 4.0, 0, r.position.y + 6.0)
	b.box(k + Vector3(-1.6, 0, -1.4), k + Vector3(1.6, 2.5, 1.4), Color(0.8, 0.75, 0.55), true)
	b.box(k + Vector3(-1.8, 2.5, -1.6), k + Vector3(1.8, 2.65, 1.6), Color(0.35, 0.3, 0.25))
	b.box(k + Vector3(-1.0, 1.0, -1.42), k + Vector3(1.0, 1.9, -1.4), Color(0.45, 0.55, 0.6))
	# Сторгованные машины: ценники с «ПРОДАНО»
	var kinds := ["moskvich", "zaz", "uaz", "volga", "moskvich", "car"]
	var cols := [Color(0.75, 0.6, 0.3), Color(0.3, 0.5, 0.35), Color(0.4, 0.45, 0.32), Color(0.15, 0.15, 0.17), Color(0.55, 0.2, 0.2), Color(0.85, 0.85, 0.8)]
	var cars := MeshBuilder.new()
	cars.ground_shade = false
	for i in kinds.size():
		var p := Vector3(r.position.x + 5.0 + (i % 3) * 7.0, 0.05, r.position.y + 22.0 + (i / 3) * 9.0)
		cars.xf = Transform3D(Basis(Vector3.UP, 0.0), p)
		VehicleModels.npc(cars, kinds[i], cols[i])
		b.add_collider(p + Vector3(-0.9, 0, -2.2), p + Vector3(0.9, 1.5, 2.2))
		_label("ПРОДАНО", p + Vector3(0, 1.75, 0), 0.0, 0.004, Color(0.9, 0.2, 0.15)).billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	var cm := cars.build_mesh()
	cm.name = "MarketCars"
	add_child(cm)
	_person(k + Vector3(-2.2, 0, -0.6), PI * 0.8, Color(0.25, 0.25, 0.3), false)


# --- СТО и гаражи --------------------------------------------------------------

## Городское СТО «Автосервис»: два бокса, ворота к проезду. Ремонт — как на
## СТО у Каменки (world.gd), а после курсов в бурсе — смена механиком.
func _sto(b: MeshBuilder, glow: MeshBuilder) -> void:
	var r := STO
	var wall := Color(0.72, 0.74, 0.76)
	b.box(Vector3(r.position.x - 1.0, 0, r.position.y - 3.0), Vector3(r.end.x + 1.0, 0.05, r.end.y + 0.5), Color(0.36, 0.36, 0.35))
	b.box(Vector3(r.position.x, 0, r.end.y - 0.5), Vector3(r.end.x, 4.5, r.end.y), wall, true)
	for x in [r.position.x, r.get_center().x - 0.2, r.end.x - 0.4]:
		b.box(Vector3(x, 0, r.position.y), Vector3(x + 0.4, 4.5, r.end.y), wall, true)
	b.box(Vector3(r.position.x, 3.4, r.position.y), Vector3(r.end.x, 4.5, r.position.y + 0.4), wall, true)
	b.box(Vector3(r.position.x - 0.3, 4.5, r.position.y - 0.3), Vector3(r.end.x + 0.3, 4.75, r.end.y + 0.3), Color(0.38, 0.4, 0.42))
	# Подъёмник и смотровая яма, покрышки, стеллаж
	var c := r.get_center()
	b.box(Vector3(c.x - 6.0, 0.05, c.y - 2.0), Vector3(c.x - 4.6, 0.08, c.y + 4.0), Color(0.12, 0.12, 0.12))
	for s in [-1.0, 1.0]:
		b.box(Vector3(c.x + 4.8 + s * 1.3, 0, c.y), Vector3(c.x + 5.1 + s * 1.3, 2.2, c.y + 0.3), Color(0.85, 0.6, 0.15), true)
	for i in 5:
		b.box(Vector3(r.end.x + 0.4, i * 0.25, r.position.y + 1.0), Vector3(r.end.x + 1.2, i * 0.25 + 0.24, r.position.y + 1.8), Color(0.1, 0.1, 0.1))
	b.box(Vector3(c.x - 5.0, 3.55, r.position.y - 0.05), Vector3(c.x + 5.0, 4.35, r.position.y), Color(0.15, 0.3, 0.65))
	_label("СТО «АВТОСЕРВИС»", Vector3(c.x, 3.95, r.position.y - 0.07), PI, 0.0065, Color(1, 1, 1))
	glow.box(Vector3(c.x - 8.0, 3.2, r.position.y + 1.0), Vector3(c.x + 8.0, 3.3, r.position.y + 1.2), Color(0.95, 0.95, 1.0))
	var w := _world
	var at := Town.w(Vector3(c.x, 0, c.y))
	var fix := InteractZone.create("", Vector3(16.0, 2.4, 9.0))
	fix.name = "TownStoZone"
	fix.position = Vector3(c.x, 0, c.y)
	fix.prompt_fn = func() -> String: return w._repair_prompt(at)
	fix.activated.connect(func() -> void: w._repair(at))
	add_child(fix)
	# Мастер у стеллажа: покраска и новые запчасти
	var master := InteractZone.create("", Vector3(1.8, 2.2, 1.8))
	master.name = "StoMasterZone"
	master.position = Vector3(r.position.x - 1.5, 0, r.position.y + 4.0)
	master.prompt_fn = func() -> String:
		var h := TimeManager.hour()
		if h < 8.0 or h >= 20.0:
			return "СТО «Автосервис» работает с 8:00 до 20:00"
		return "E — мастер: покраска и замена запчастей на новые"
	master.activated.connect(open_master)
	add_child(master)
	_person(Vector3(r.position.x - 2.2, 0, r.position.y + 4.0), PI / 2.0, Color(0.55, 0.3, 0.15), false)
	b.box(Vector3(r.position.x - 1.2, 0, r.position.y + 5.2), Vector3(r.position.x - 0.1, 2.0, r.position.y + 7.4), Color(0.4, 0.3, 0.22))
	for i in 4:
		b.box(Vector3(r.position.x - 1.1, 0.4 + i * 0.4, r.position.y + 5.4), Vector3(r.position.x - 0.8, 0.7 + i * 0.4, r.position.y + 7.2), [Color(0.6, 0.1, 0.1), Color(0.15, 0.3, 0.6), Color(0.9, 0.9, 0.85), Color(0.2, 0.4, 0.22)][i])
	var job := InteractZone.create("", Vector3(1.6, 2.2, 1.6))
	job.name = "StoShiftZone"
	job.position = Vector3(r.end.x + 1.5, 0, r.position.y + 4.0)
	job.prompt_fn = _shift_prompt
	job.activated.connect(_shift)
	add_child(job)
	_person(Vector3(r.end.x + 2.2, 0, r.position.y + 4.0), -PI / 2.0, Color(0.2, 0.3, 0.55), false)


## Своя техника у ворот СТО — для окна мастера.
func sto_vehicles() -> Array:
	var at := Town.w(Vector3(STO.get_center().x, 0, STO.get_center().y))
	var out := []
	for v in get_tree().get_nodes_in_group("vehicles"):
		var car := v as Vehicle
		if car and car.owned() and not car.school and car.global_position.distance_to(at) < 18.0:
			out.append(car)
	return out


func open_master() -> void:
	var h := TimeManager.hour()
	if h < 8.0 or h >= 20.0:
		return
	if master_panel == null:
		master_panel = StoPanel.new()
		add_child(master_panel)
	SoundLibrary.play("click", -4.0)
	master_panel.open("sto", sto_vehicles())


func _shift_prompt() -> String:
	if not Progress.has_item("mechanic"):
		return "Мастер СТО: «Без корочки автослесаря не возьму. Курсы — в бурсе»"
	if sto_stage == 1:
		return "Мастер СТО: «Машина клиента на подъёмнике — найди, что сломано»"
	if sto_stage == 2:
		return "E — сдать машину клиенту: +%d грн" % sto_pay()
	if sto_day == TimeManager.day:
		return "Мастер СТО: «На сегодня хватит, приходи завтра»"
	var h := TimeManager.hour()
	if h < 8.0 or h >= 18.0:
		return "СТО работает с 8:00 до 18:00"
	return "E — смена механиком на СТО: принять машину, починить, сдать — +%d грн" % SHIFT_PAY


## Смена целиком сразу (для тестов): принять, починить верно, сдать.
func shift() -> int:
	if sto_stage == 0:
		_take_order()
	if sto_stage == 1:
		_repair_done(5, "")
	return _hand_over() if sto_stage == 2 else 0


## Мастер: нет заказа — берём, машина починена — сдаём.
func _shift() -> void:
	match sto_stage:
		0: _take_order()
		2: _hand_over()


## Этап 1: принять машину клиента — она встаёт на подъёмник с жалобой.
func _take_order() -> void:
	var h := TimeManager.hour()
	if not Progress.has_item("mechanic") or sto_day == TimeManager.day or h < 8.0 or h >= 18.0:
		return
	if NeedsManager.energy < 20.0:
		GameManager.notify("Слишком устал для смены. Выспись")
		return
	sto_stage = 1
	sto_fault = randi() % STO_FAULTS.size()
	sto_miss = 0
	SoundLibrary.play("click", -4.0, 1.2)
	_show_client()
	GameManager.notify("%s. Машина на подъёмнике — осмотри и поменяй что нужно" % STO_FAULTS[sto_fault][0])


## Этап 2: осмотреть машину — выбрать узел по жалобе клиента.
func _inspect() -> void:
	if sto_stage != 1:
		return
	if lesson_panel == null:
		lesson_panel = LessonPanel.new()
		add_child(lesson_panel)
	if lesson_panel.visible:
		return
	var f: Array = STO_FAULTS[sto_fault]
	if lesson_panel.done.is_connected(_repair_done):
		lesson_panel.done.disconnect(_repair_done)
	lesson_panel.done.connect(_repair_done, CONNECT_ONE_SHOT)
	lesson_panel.start_quiz("СТО — что менять?", [[f[0], f[1], f[2], f[3]]])


func _repair_done(grade: int, _comment: String) -> void:
	var f: Array = STO_FAULTS[sto_fault]
	if grade < 5:
		sto_miss += 1
		TimeManager.advance(20.0)
		GameManager.notify("Не то: снял, посмотрел — целое. Клиент ждёт, ищи дальше (премии уже не будет)")
		return
	sto_stage = 2
	SoundLibrary.play("hammer")
	TimeManager.advance(150.0)
	NeedsManager.energy = maxf(NeedsManager.energy - 15.0, 0.0)
	_show_client()
	GameManager.notify("Поменял: %s. Сдай машину мастеру — клиент ждёт" % String(f[1]).to_lower())


## Этап 3: сдать машину — оплата, без ошибок — премия. Сколько заплатили.
func _hand_over() -> int:
	if sto_stage != 2:
		return 0
	var pay := sto_pay()
	sto_stage = 0
	sto_day = TimeManager.day
	_show_client()
	GameManager.add_money(pay)
	SoundLibrary.play("cash")
	QuestManager.event("sto_shift")
	GameManager.notify("Клиент забрал машину: «Как новая!» +%d грн%s" % [pay, " (с премией)" if sto_miss == 0 else ""])
	return pay


func sto_pay() -> int:
	return SHIFT_PAY + (STO_BONUS if sto_miss == 0 else 0)


## Машина клиента на подъёмнике, стрелка и строка задания — по этапу смены.
func _show_client() -> void:
	if sto_stage == 0:
		# Строку и стрелку чистим, только если они были наши
		if _client_car:
			_client_car.queue_free()
			_client_car = null
			GameManager.challenge_line = ""
			GameManager.nav_target = Vector3.INF
			GameManager.nav_label = ""
		return
	if _client_car == null:
		_client_car = Node3D.new()
		_client_car.position = STO_CAR
		var b := MeshBuilder.new()
		b.ground_shade = false
		VehicleModels.npc(b, ["car", "moskvich", "zaz", "volga"][sto_fault % 4], [Color(0.7, 0.15, 0.12), Color(0.2, 0.35, 0.6), Color(0.9, 0.9, 0.88), Color(0.25, 0.45, 0.3)][sto_fault % 4])
		_client_car.add_child(b.build_mesh())
		var z := InteractZone.create("", Vector3(3.4, 2.2, 5.6))
		z.name = "StoClientCar"
		z.prompt_fn = func() -> String:
			if sto_stage == 1:
				return "E — осмотреть машину клиента. %s" % STO_FAULTS[sto_fault][0]
			return "Машина починена — сдай её мастеру у ворот"
		z.activated.connect(_inspect)
		_client_car.add_child(z)
		add_child(_client_car)
	var master := Town.w(Vector3(STO.end.x + 1.5, 0, STO.position.y + 4.0))
	if sto_stage == 1:
		GameManager.challenge_line = "СТО: машина на подъёмнике — найди поломку (%s)" % String(STO_FAULTS[sto_fault][0]).trim_prefix("Клиент: ")
		GameManager.nav_target = Town.w(STO_CAR)
		GameManager.nav_label = "машина клиента"
	else:
		GameManager.challenge_line = "СТО: сдай машину мастеру, +%d грн" % sto_pay()
		GameManager.nav_target = master
		GameManager.nav_label = "мастер СТО"


## Ряд гаражей у восточной улицы: первый продаётся. В своём гараже машину
## можно подлатать самому — бесплатно, но долго.
func _garages(b: MeshBuilder) -> void:
	var r := MY_GARAGES
	var gates := [Color(0.55, 0.3, 0.2), Color(0.35, 0.45, 0.55), Color(0.4, 0.5, 0.35), Color(0.6, 0.55, 0.3)]
	b.box(Vector3(r.position.x - 6.0, 0, r.position.y), Vector3(r.position.x, 0.04, r.end.y), Color(0.46, 0.43, 0.38))
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 2.6, r.end.y), Color(0.6, 0.58, 0.54), true)
	b.box(Vector3(r.position.x - 0.3, 2.6, r.position.y - 0.2), Vector3(r.end.x + 0.2, 2.75, r.end.y + 0.2), Color(0.32, 0.32, 0.34))
	for i in 4:
		var z0 := r.position.y + 0.6 + i * 6.4
		b.box(Vector3(r.position.x - 0.03, 0, z0), Vector3(r.position.x + 0.03, 2.25, z0 + 5.0), gates[i])
		b.box(Vector3(r.position.x - 0.05, 0, z0 + 2.48), Vector3(r.position.x + 0.05, 2.25, z0 + 2.52), (gates[i] as Color).darkened(0.35))
	var door := Vector3(r.position.x - 2.5, 0, r.position.y + 3.1)
	_garage_label = _label("", Vector3(r.position.x - 0.08, 2.0, r.position.y + 3.1), -PI / 2.0, 0.005, Color(0.95, 0.85, 0.3))
	var zone := InteractZone.create("", Vector3(4.5, 2.4, 5.0))
	zone.name = "GarageZone"
	zone.position = door
	zone.prompt_fn = _garage_prompt
	zone.activated.connect(use_garage)
	add_child(zone)
	_update_garage()


func _garage_car() -> Vehicle:
	var at := Town.w(Vector3(MY_GARAGES.position.x - 2.5, 0, MY_GARAGES.position.y + 3.1))
	for v in get_tree().get_nodes_in_group("vehicles"):
		var car := v as Vehicle
		if car and car.owned() and not car.school and car.global_position.distance_to(at) < 7.0:
			return car
	return null


func _garage_prompt() -> String:
	if not Progress.has_item("garage"):
		return "E — купить гараж за %d грн: чинить машину самому, бесплатно" % GARAGE_PRICE
	var car := _garage_car()
	if car == null:
		return "Твой гараж: подгони машину к воротам — подлатаешь сам"
	if car.condition >= 99.5:
		return "%s в порядке — %d%%" % [car.spec.title, int(car.condition)]
	return "E — подлатать %s самому: +30%%, 2 часа, бесплатно" % car.spec.title


func use_garage() -> void:
	if not Progress.has_item("garage"):
		if GameManager.spend(GARAGE_PRICE):
			Progress.add_item("garage")
			SoundLibrary.play("quest", -6.0)
			QuestManager.event("garage_bought")
			GameManager.notify("Купил гараж на Заводской! Здесь можно чинить машину самому")
			_update_garage()
		return
	var car := _garage_car()
	if car == null or car.condition >= 99.5:
		return
	SoundLibrary.play("hammer")
	TimeManager.advance(120.0)
	car.condition = minf(car.condition + 30.0, 100.0)
	GameManager.notify("Подлатал сам: %s — %d%%. %s" % [car.spec.title, int(car.condition), TimeManager.clock_text()])


func _update_garage() -> void:
	if _garage_label == null:
		return
	_garage_label.text = "ТВОЙ ГАРАЖ" if Progress.has_item("garage") else "ПРОДАЁТСЯ\n%d грн" % GARAGE_PRICE


# --- Бурса ----------------------------------------------------------------------

## Бурса — ПТУ: три этажа, вход к улице (+X), во дворе флагшток и ученики.
## Курсы автослесаря открывают смену на СТО.
func _college(b: MeshBuilder, glow: MeshBuilder, veg: Vegetation) -> void:
	var r := COLLEGE
	var wall := Color(0.82, 0.72, 0.55)
	var h := 10.2
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, h, r.end.y), wall, true)
	b.box(Vector3(r.position.x - 0.3, h, r.position.y - 0.3), Vector3(r.end.x + 0.3, h + 0.4, r.end.y + 0.3), Color(0.45, 0.45, 0.47))
	for fl in 3:
		var y := 1.0 + fl * 3.3
		b.box(Vector3(r.end.x, y - 0.25, r.position.y), Vector3(r.end.x + 0.05, y - 0.1, r.end.y), Color(0.95, 0.93, 0.88))
		var z := r.position.y + 1.4
		while z < r.end.y - 2.0:
			if fl > 0 or absf(z + 1.0 - r.get_center().y) > 2.5:
				b.box(Vector3(r.end.x, y, z), Vector3(r.end.x + 0.05, y + 2.0, z + 2.0), Color(0.3, 0.38, 0.45))
				if (int(z) + fl) % 4 != 0:
					glow.box(Vector3(r.end.x + 0.06, y + 0.1, z + 0.1), Vector3(r.end.x + 0.07, y + 1.9, z + 1.9), Color(1.0, 0.92, 0.7))
			z += 3.0
	var cz := r.get_center().y
	b.box(Vector3(r.end.x, 0, cz - 1.5), Vector3(r.end.x + 0.06, 2.6, cz + 1.5), Color(0.4, 0.28, 0.18))
	b.box(Vector3(r.end.x, 2.8, cz - 2.5), Vector3(r.end.x + 2.0, 3.0, cz + 2.5), Color(0.5, 0.5, 0.52))
	b.box(Vector3(r.end.x + 0.05, 7.6, cz - 7.0), Vector3(r.end.x + 0.1, 8.7, cz + 7.0), Color(0.2, 0.3, 0.6))
	_label("ПТУ №17 · БУРСА", Vector3(r.end.x + 0.12, 8.15, cz), PI / 2.0, 0.008, Color(1, 1, 1))
	_label("Автослесари · водители · электрики\nКурсы для всех желающих", Vector3(r.end.x + 0.08, 2.0, cz + 2.4), PI / 2.0, 0.0025, Color(0.1, 0.1, 0.12))
	# Двор: асфальт к улице, флагшток, скамейки, берёзы
	b.box(Vector3(r.end.x, 0, r.position.y + 6.0), Vector3(EAST_STREET.position.x - 2.0, 0.04, r.end.y - 6.0), Color(0.5, 0.5, 0.49))
	b.box(Vector3(r.end.x + 6.0, 0, cz + 8.0), Vector3(r.end.x + 6.12, 9.0, cz + 8.12), Color(0.75, 0.75, 0.78), true)
	b.box(Vector3(r.end.x + 6.12, 7.8, cz + 8.0), Vector3(r.end.x + 6.15, 8.9, cz + 9.6), Color(0.85, 0.2, 0.15))
	for z in [cz - 10.0, cz + 4.0]:
		_bench(b, Vector3(r.end.x + 9.5, 0, z), -PI / 2.0)
	for p in [Vector3(r.end.x + 4.0, 0, r.position.y + 3.0), Vector3(r.end.x + 4.0, 0, r.end.y - 3.0)]:
		_tree(b, veg, p, Vegetation.TreeKind.BIRCH)
	for i in 3:
		_person(Vector3(r.end.x + 5.0 + i * 0.9, 0, cz - 6.0 + i * 0.7), PI / 2.0 + i, [Color(0.2, 0.3, 0.6), Color(0.6, 0.2, 0.2), Color(0.3, 0.5, 0.3)][i], i == 1)
	var zone := InteractZone.create("", Vector3(2.4, 2.2, 3.0))
	zone.name = "CollegeZone"
	zone.position = Vector3(r.end.x + 1.4, 0, cz)
	zone.prompt_fn = _course_prompt
	zone.activated.connect(take_course)
	add_child(zone)


func _course_prompt() -> String:
	if Progress.has_item("mechanic"):
		return "Бурса: корочка автослесаря у тебя есть — на СТО «Автосервис» берут на смену"
	var h := TimeManager.hour()
	if h < 8.0 or h >= 17.0:
		return "Бурса: занятия курсов с 8:00 до 17:00"
	if course_day == TimeManager.day:
		return "Бурса: «На сегодня всё, приходи завтра»"
	if course_lessons >= COURSE_LESSONS:
		return "E — экзамен на автослесаря: 5 вопросов, нужно 4 верных"
	if not course_paid:
		return "E — курсы автослесаря: %d грн за всё, %d урока по 2 часа и экзамен" % [COURSE_PRICE, COURSE_LESSONS]
	return "E — урок на курсах автослесаря: %d из %d (2 часа)" % [course_lessons + 1, COURSE_LESSONS]


## Урок или экзамен в бурсе — вопросы в окне урока (как в школе).
func take_course() -> void:
	var h := TimeManager.hour()
	if Progress.has_item("mechanic") or h < 8.0 or h >= 17.0 or course_day == TimeManager.day:
		return
	if lesson_panel == null:
		lesson_panel = LessonPanel.new()
		add_child(lesson_panel)
	if lesson_panel.visible:
		return
	if not course_paid:
		if not GameManager.spend(COURSE_PRICE):
			return
		course_paid = true
	var exam := course_lessons >= COURSE_LESSONS
	var pool := MECHANIC_QUIZ.duplicate()
	pool.shuffle()
	var title := "Бурса — экзамен на автослесаря" if exam else "Бурса — урок %d из %d: устройство автомобиля" % [course_lessons + 1, COURSE_LESSONS]
	if lesson_panel.done.is_connected(_course_done):
		lesson_panel.done.disconnect(_course_done)
	lesson_panel.done.connect(_course_done.bind(exam), CONNECT_ONE_SHOT)
	lesson_panel.start_quiz(title, pool.slice(0, 5 if exam else 3))


func _course_done(grade: int, comment: String, exam: bool) -> void:
	course_day = TimeManager.day
	TimeManager.advance(60.0 if exam else LESSON_MIN)
	if exam:
		if grade >= 4:
			Progress.add_item("mechanic")
			SoundLibrary.play("quest", -6.0)
			QuestManager.event("course")
			GameManager.notify("Экзамен сдан (%s)! Корочка автослесаря — на СТО «Автосервис» берут на смену (+%d грн)" % [comment, SHIFT_PAY])
		else:
			GameManager.notify("Экзамен не сдан: %s, нужно 4 из 5. Пересдача завтра" % comment)
		return
	if grade >= 3:
		course_lessons += 1
		QuestManager.event("college_lesson")
		var next := "дальше экзамен" if course_lessons >= COURSE_LESSONS else "следующий урок завтра"
		GameManager.notify("Урок в бурсе: оценка %d (%s). Пройдено %d из %d — %s" % [grade, comment, course_lessons, COURSE_LESSONS, next])
	else:
		GameManager.notify("Урок не засчитан: двойка (%s). Приходи завтра" % comment)


# --- Новые дома и участки ----------------------------------------------------------

## Новый кирпичный дом в шесть этажей: балконы, подъезды с козырьками к улице.
func _flats(b: MeshBuilder, glow: MeshBuilder, r: Rect2) -> void:
	var brick := Color(0.72, 0.4, 0.3) if r.position.y < 100.0 else Color(0.85, 0.78, 0.6)
	var h := 6 * 2.9
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, h, r.end.y), brick, true)
	b.box(Vector3(r.position.x - 0.3, h, r.position.y - 0.3), Vector3(r.end.x + 0.3, h + 0.5, r.end.y + 0.3), Color(0.4, 0.4, 0.42))
	var fx := r.position.x
	for fl in 6:
		var y := 0.9 + fl * 2.9
		var z := r.position.y + 1.2
		var k := 0
		while z < r.end.y - 1.5:
			b.box(Vector3(fx - 0.05, y, z), Vector3(fx, y + 1.6, z + 1.6), Color(0.3, 0.38, 0.45))
			if (k * 7 + fl * 3) % 5 < 2:
				glow.box(Vector3(fx - 0.07, y + 0.1, z + 0.1), Vector3(fx - 0.06, y + 1.5, z + 1.5), Color(1.0, 0.88, 0.62))
			# Балкон у каждого второго окна, кроме первого этажа
			if fl > 0 and k % 2 == 1:
				b.box(Vector3(fx - 1.2, y - 0.6, z - 0.4), Vector3(fx, y - 0.45, z + 2.0), Color(0.75, 0.75, 0.73))
				b.box(Vector3(fx - 1.2, y - 0.45, z - 0.4), Vector3(fx - 1.1, y + 0.5, z + 2.0), Color(0.92, 0.92, 0.9))
			z += 2.6
			k += 1
	for i in 3:
		var ez := r.position.y + 6.0 + i * 14.0
		b.box(Vector3(fx - 0.06, 0, ez - 0.8), Vector3(fx, 2.2, ez + 0.8), Color(0.35, 0.25, 0.18))
		b.box(Vector3(fx - 1.6, 2.4, ez - 1.3), Vector3(fx, 2.55, ez + 1.3), Color(0.5, 0.5, 0.52))
		b.box(Vector3(fx - 1.6, 0, ez - 1.3), Vector3(fx, 0.15, ez + 1.3), Color(0.6, 0.6, 0.58))
		_bench(b, Vector3(fx - 2.6, 0, ez + 2.8), PI / 2.0)
	# Газон с бордюром перед домом и тропинки к подъездам
	b.box(Vector3(fx - 4.0, 0, r.position.y), Vector3(fx - 0.1, 0.04, r.end.y), Color(0.48, 0.48, 0.47))


## Дом в городе и квартира: у калитки (у подъезда) — купить, потом там же
## (дома — у двери) можно лечь спать до утра, как дома в Каменке.
func _homes() -> void:
	for h in HOMES:
		var id: String = h[0]
		var sign := _label("", (h[3] as Vector3) + Vector3(0, 2.6, 0), float(h[5]), 0.0045, Color(0.75, 0.15, 0.1))
		sign.outline_size = 8
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.name = "HomeSign_" + id
		var at_door := (h[3] as Vector3).is_equal_approx(h[4])
		var offer := func() -> String:
			return "E — купить %s за %d грн: можно ночевать в городе" % [h[1], int(h[2])]
		# Дом на участке — покупка у калитки; квартира — всё у подъезда
		if not at_door:
			var buy := InteractZone.create("", Vector3(2.4, 2.2, 2.4))
			buy.name = "HomeBuy_" + id
			buy.position = h[3]
			buy.prompt_fn = func() -> String:
				return "Твой %s — спать у двери" % String(h[1]) if Progress.has_item(id) else offer.call()
			buy.activated.connect(buy_home.bind(id))
			add_child(buy)
		var bed := InteractZone.create("", Vector3(2.4, 2.2, 2.4))
		bed.name = "HomeSleep_" + id
		bed.position = h[4]
		bed.prompt_fn = func() -> String:
			if Progress.has_item(id):
				return "E — домой: лечь спать до утра"
			return offer.call() if at_door else "Дом продаётся — договориться у калитки"
		bed.activated.connect(func() -> void:
			if Progress.has_item(id):
				_world._sleep()
			elif at_door:
				buy_home(id))
		add_child(bed)
	Progress.home_changed.connect(_update_homes)
	_update_homes()


## Купить дом в городе или квартиру. true — купил.
func buy_home(id: String) -> bool:
	for h in HOMES:
		if h[0] != id or Progress.has_item(id):
			continue
		if not GameManager.spend(int(h[2])):
			return false
		Progress.add_item(id)
		SoundLibrary.play("quest", -4.0)
		QuestManager.event("home_bought")
		GameManager.notify("Купил %s! Теперь можно ночевать в городе — у двери «E — домой»" % String(h[1]))
		return true
	return false


func _update_homes() -> void:
	for h in HOMES:
		var s := find_child("HomeSign_" + String(h[0]), true, false) as Label3D
		if s:
			var mine := Progress.has_item(String(h[0]))
			s.text = "ТВОЁ ЖИЛЬЁ" if mine else "ПРОДАЁТСЯ\n%d грн" % int(h[2])
			s.modulate = Color(0.2, 0.55, 0.2) if mine else Color(0.75, 0.15, 0.1)


## Частные участки: домик с двускатной крышей, штакетник, грядки, яблоня.
func _plots(b: MeshBuilder, veg: Vegetation) -> void:
	var r := PLOTS
	var walls := [Color(0.85, 0.8, 0.6), Color(0.6, 0.72, 0.82), Color(0.75, 0.85, 0.65), Color(0.9, 0.75, 0.6), Color(0.8, 0.8, 0.82), Color(0.7, 0.6, 0.5)]
	var roofs := [Color(0.55, 0.25, 0.18), Color(0.3, 0.42, 0.32), Color(0.45, 0.45, 0.5)]
	var w := r.size.x / 3.0
	var d := r.size.y / 2.0
	for i in 6:
		var x0 := r.position.x + (i % 3) * w
		var z0 := r.position.y + (i / 3) * d
		var c := Vector3(x0 + w * 0.5, 0, z0 + d * 0.5)
		# Штакетник по краю, калитка напротив двери домика
		_fence(b, Vector3(x0 + 0.3, 0, z0 + 0.3), Vector3(x0 + w - 0.3, 0, z0 + 0.3))
		_fence(b, Vector3(x0 + 0.3, 0, z0 + d - 0.3), Vector3(c.x - 0.8, 0, z0 + d - 0.3))
		_fence(b, Vector3(c.x + 0.8, 0, z0 + d - 0.3), Vector3(x0 + w - 0.3, 0, z0 + d - 0.3))
		_fence(b, Vector3(x0 + 0.3, 0, z0 + 0.3), Vector3(x0 + 0.3, 0, z0 + d - 0.3))
		_fence(b, Vector3(x0 + w - 0.3, 0, z0 + 0.3), Vector3(x0 + w - 0.3, 0, z0 + d - 0.3))
		# Домик
		var hx := 3.5
		var hz := 3.0
		var hc := c + Vector3(0, 0, -d * 0.18)
		b.box(hc + Vector3(-hx, 0, -hz), hc + Vector3(hx, 2.8, hz), walls[i], true)
		var roof: Color = roofs[i % roofs.size()]
		b.quad(hc + Vector3(-hx - 0.3, 2.8, hz + 0.4), hc + Vector3(hx + 0.3, 2.8, hz + 0.4), hc + Vector3(hx + 0.3, 4.6, 0), hc + Vector3(-hx - 0.3, 4.6, 0), roof, true)
		b.quad(hc + Vector3(hx + 0.3, 2.8, -hz - 0.4), hc + Vector3(-hx - 0.3, 2.8, -hz - 0.4), hc + Vector3(-hx - 0.3, 4.6, 0), hc + Vector3(hx + 0.3, 4.6, 0), roof.darkened(0.1), true)
		for s in [-1.0, 1.0]:
			b.tri(hc + Vector3(s * hx, 2.8, hz), hc + Vector3(s * hx, 2.8, -hz), hc + Vector3(s * hx, 4.6, 0), (walls[i] as Color).darkened(0.06), true)
		b.box(hc + Vector3(-0.6, 0, hz), hc + Vector3(0.6, 2.0, hz + 0.05), Color(0.4, 0.28, 0.18))
		for wx in [-2.3, 1.5]:
			b.box(hc + Vector3(wx, 1.0, hz), hc + Vector3(wx + 0.9, 2.0, hz + 0.05), Color(0.3, 0.42, 0.5))
		# Грядки и яблоня
		for k in 3:
			var gz := z0 + d * 0.62 + k * 1.6
			b.box(Vector3(x0 + 2.0, 0, gz), Vector3(x0 + w * 0.55, 0.18, gz + 0.9), Color(0.33, 0.24, 0.16))
			b.box(Vector3(x0 + 2.2, 0.18, gz + 0.3), Vector3(x0 + w * 0.55 - 0.2, 0.4, gz + 0.6), Color(0.3, 0.5, 0.22))
		_tree(b, veg, Vector3(x0 + w - 3.0, 0, z0 + d - 3.5), Vegetation.TreeKind.APPLE)


# --- Парк культуры ---------------------------------------------------------------

## Парк культуры и отдыха: арка у входа, аллеи, клумба, эстрада со скамьями,
## колесо обозрения (крутится; прокатиться — 20 грн), фонари и деревья.
func _park(b: MeshBuilder, glow: MeshBuilder, veg: Vegetation) -> void:
	var r := PARK
	var path := Color(0.66, 0.62, 0.55)
	# Аллеи крестом и вокруг
	var cx := r.get_center().x
	var cz := r.get_center().y
	b.box(Vector3(cx - 2.0, 0, r.position.y), Vector3(cx + 2.0, 0.04, r.end.y - 4.0), path)
	b.box(Vector3(r.position.x + 4.0, 0, cz - 2.0), Vector3(r.end.x, 0.04, cz + 2.0), path)
	b.box(Vector3(r.position.x + 4.0, 0, r.position.y + 4.0), Vector3(r.end.x - 4.0, 0.035, r.position.y + 6.5), path)
	b.box(Vector3(r.position.x + 4.0, 0, r.end.y - 6.5), Vector3(r.end.x - 4.0, 0.035, r.end.y - 4.0), path)
	b.box(Vector3(r.position.x + 4.0, 0, r.position.y + 4.0), Vector3(r.position.x + 6.5, 0.035, r.end.y - 4.0), path)
	# Арка у входа с востока (от рынка) и с севера (от школы)
	for gate in [[Vector3(r.end.x, 0, cz), PI / 2.0], [Vector3(cx, 0, r.position.y), PI]]:
		var g: Vector3 = gate[0]
		var bas := Basis(Vector3.UP, float(gate[1]))
		for s in [-1.0, 1.0]:
			var p: Vector3 = g + bas * Vector3(s * 2.8, 0, 0)
			b.box(p + Vector3(-0.35, 0, -0.35), p + Vector3(0.35, 4.6, 0.35), Color(0.9, 0.88, 0.82), true)
		b.box(g + bas * Vector3(-3.3, 4.6, -0.4), g + bas * Vector3(3.3, 5.6, 0.4), Color(0.85, 0.2, 0.15))
		_label("ПАРК КУЛЬТУРЫ\nИ ОТДЫХА", g + bas * Vector3(0, 5.1, 0.45), float(gate[1]), 0.0045, Color(1.0, 0.95, 0.75))
	# Клумба на перекрёстке аллей
	var flowers := [Color(0.85, 0.2, 0.2), Color(0.95, 0.8, 0.2), Color(0.9, 0.5, 0.7), Color(0.95, 0.95, 0.9)]
	b.box(Vector3(cx - 3.5, 0, cz - 3.5), Vector3(cx + 3.5, 0.35, cz + 3.5), Color(0.6, 0.6, 0.58), true)
	b.box(Vector3(cx - 3.2, 0.35, cz - 3.2), Vector3(cx + 3.2, 0.45, cz + 3.2), Color(0.3, 0.22, 0.15))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for f in 40:
		var fp := Vector3(cx + rng.randf_range(-3.0, 3.0), 0.45, cz + rng.randf_range(-3.0, 3.0))
		b.box(fp + Vector3(-0.09, 0, -0.09), fp + Vector3(0.09, 0.22, 0.09), flowers[f % flowers.size()])
	# Скамейки и фонари вдоль аллей
	for z in [r.position.y + 12.0, r.position.y + 22.0, cz + 10.0, cz + 20.0]:
		_bench(b, Vector3(cx - 3.0, 0, z), PI / 2.0)
		_bench(b, Vector3(cx + 3.0, 0, z), -PI / 2.0)
	for x in [r.position.x + 14.0, r.position.x + 24.0, cx + 12.0, cx + 24.0]:
		_bench(b, Vector3(x, 0, cz - 3.0), 0.0)
	for p in [Vector3(cx - 2.6, 0, r.position.y + 17.0), Vector3(cx + 2.6, 0, cz + 15.0), Vector3(r.position.x + 19.0, 0, cz + 2.6), Vector3(cx + 18.0, 0, cz - 2.6)]:
		b.box(p + Vector3(-0.08, 0, -0.08), p + Vector3(0.08, 4.0, 0.08), Color(0.2, 0.22, 0.2), true)
		b.box(p + Vector3(-0.25, 4.0, -0.25), p + Vector3(0.25, 4.1, 0.25), Color(0.2, 0.22, 0.2))
		glow.box(p + Vector3(-0.2, 3.6, -0.2), p + Vector3(0.2, 4.0, 0.2), Color(1.0, 0.92, 0.7))
	# Эстрада: полукруглая раковина, сцена, ряды скамей
	var st := Vector3(cx + 20.0, 0, r.end.y - 14.0)
	b.box(st + Vector3(-7.0, 0, 2.0), st + Vector3(7.0, 1.0, 7.0), Color(0.75, 0.72, 0.68), true)
	for k in 7:
		var a0 := PI * k / 7.0
		var a1 := PI * (k + 1) / 7.0
		var mid := Vector3(cos((a0 + a1) * 0.5) * 6.8, 0, 7.0 + sin((a0 + a1) * 0.5) * 2.5)
		b.box_rot(st + mid + Vector3(0, 3.5, 0), Vector3(3.2, 5.0, 0.25), -(a0 + a1) * 0.5 + PI / 2.0, Color(0.95, 0.95, 0.93))
	b.box(st + Vector3(-7.4, 6.0, 2.0), st + Vector3(7.4, 6.4, 9.5), Color(0.85, 0.85, 0.83))
	for row in 4:
		for s in [-1.0, 1.0]:
			_bench(b, st + Vector3(s * 3.2, 0, -3.0 - row * 2.2), 0.0)
	b.box(st + Vector3(-3.0, 6.4, 1.9), st + Vector3(3.0, 7.3, 2.0), Color(0.85, 0.2, 0.15))
	_label("ЭСТРАДА", st + Vector3(0, 6.85, 1.88), PI, 0.007, Color(1.0, 0.95, 0.8))
	# Деревья по краю парка: ели и берёзы, кусты
	var tr := RandomNumberGenerator.new()
	tr.seed = 1312
	for i in 46:
		var p := Vector3(tr.randf_range(r.position.x + 1.0, r.end.x - 1.0), 0, tr.randf_range(r.position.y + 1.0, r.end.y - 1.0))
		var near_path := absf(p.x - cx) < 4.5 or absf(p.z - cz) < 4.5 or p.distance_to(WHEEL) < WHEEL_R + 3.0 \
			or p.distance_to(st + Vector3(0, 0, 2.0)) < 12.0 or p.x < r.position.x + 7.5 and p.x > r.position.x + 3.0 \
			or (p.z < r.position.y + 7.5 and p.z > r.position.y + 3.0) or (p.z > r.end.y - 7.5 and p.z < r.end.y - 3.0)
		if near_path:
			continue
		var kind := [Vegetation.TreeKind.BIRCH, Vegetation.TreeKind.SPRUCE, Vegetation.TreeKind.BUSH][i % 3] as int
		_tree(b, veg, p, kind)
	_ferris_wheel(b)


## Колесо обозрения: опоры в общем меше, обод со спицами крутится, кабинки
## висят ровно (каждая — отдельный узел, видно только вблизи).
func _ferris_wheel(b: MeshBuilder) -> void:
	var c := WHEEL
	var hub_y := WHEEL_R + 1.5
	var steel := Color(0.85, 0.85, 0.88)
	for s in [-1.0, 1.0]:
		for z in [-1.4, 1.4]:
			var foot := c + Vector3(s * 5.0, 0, z)
			var top := c + Vector3(0, hub_y, z * 0.6)
			var mid := (foot + top) * 0.5
			var len := foot.distance_to(top)
			var saved := b.xf
			b.xf = Transform3D(Basis(Vector3.BACK, atan2(top.x - foot.x, top.y - foot.y) * -1.0), mid)
			b.box(Vector3(-0.15, -len * 0.5, -0.15), Vector3(0.15, len * 0.5, 0.15), Color(0.85, 0.25, 0.2))
			b.xf = saved
	b.add_collider(c + Vector3(-5.5, 0, -1.7), c + Vector3(-4.5, 3.0, 1.7))
	b.add_collider(c + Vector3(4.5, 0, -1.7), c + Vector3(5.5, 3.0, 1.7))
	b.box(c + Vector3(-1.6, 0, 1.8), c + Vector3(1.6, 0.4, 4.0), Color(0.6, 0.6, 0.58), true)
	# Обод со спицами
	var rb := MeshBuilder.new()
	rb.ground_shade = false
	var n := 16
	for k in n:
		var a := TAU * (k + 0.5) / n
		var seg := 2.0 * WHEEL_R * sin(PI / n)
		for z in [-0.9, 0.9]:
			rb.xf = Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * WHEEL_R, sin(a) * WHEEL_R, z))
			rb.box(Vector3(-0.08, -seg * 0.5 - 0.05, -0.08), Vector3(0.08, seg * 0.5 + 0.05, 0.08), steel)
		var sa := TAU * k / n
		rb.xf = Transform3D(Basis(Vector3.BACK, sa - PI / 2.0), Vector3(cos(sa), sin(sa), 0) * WHEEL_R * 0.5)
		rb.box(Vector3(-0.04, -WHEEL_R * 0.5, -0.04), Vector3(0.04, WHEEL_R * 0.5, 0.04), steel)
	rb.xf = Transform3D.IDENTITY
	rb.box(Vector3(-0.4, -0.4, -1.2), Vector3(0.4, 0.4, 1.2), Color(0.3, 0.3, 0.32))
	_rotor = rb.build_mesh()
	_rotor.name = "WheelRotor"
	_rotor.position = c + Vector3(0, hub_y, 0)
	add_child(_rotor)
	var colors := [Color(0.85, 0.2, 0.15), Color(0.95, 0.75, 0.2), Color(0.2, 0.5, 0.8), Color(0.3, 0.65, 0.35)]
	for i in 8:
		var cb := MeshBuilder.new()
		cb.ground_shade = false
		cb.box(Vector3(-0.03, 0.6, -0.03), Vector3(0.03, 1.1, 0.03), steel)
		cb.box(Vector3(-0.7, -0.4, -0.6), Vector3(0.7, 0.05, 0.6), colors[i % colors.size()])
		cb.box(Vector3(-0.75, 0.55, -0.65), Vector3(0.75, 0.65, 0.65), (colors[i % colors.size()] as Color).darkened(0.2))
		for sx in [-0.68, 0.62]:
			cb.box(Vector3(sx, 0.05, -0.55), Vector3(sx + 0.06, 0.55, -0.49), steel)
			cb.box(Vector3(sx, 0.05, 0.49), Vector3(sx + 0.06, 0.55, 0.55), steel)
		var mi := cb.build_mesh()
		mi.name = "Cabin%d" % i
		add_child(mi)
		_cabins.append(mi)
	_process(0.0)
	_label("КОЛЕСО ОБОЗРЕНИЯ", c + Vector3(0, 3.0, 2.0), 0.0, 0.006, Color(0.95, 0.85, 0.3))
	var zone := InteractZone.create("", Vector3(3.0, 2.2, 2.4))
	zone.name = "WheelZone"
	zone.position = c + Vector3(0, 0, 3.0)
	zone.prompt_fn = func() -> String:
		var h := TimeManager.hour()
		if h < 10.0 or h >= 22.0:
			return "Колесо обозрения работает с 10:00 до 22:00"
		var g := get_tree().get_first_node_in_group("girl") as Girl
		if g and g.with_player(20.0):
			return "E — прокатиться с Олей на колесе обозрения (%d грн за двоих, 15 мин)" % (WHEEL_PRICE * 2)
		return "E — прокатиться на колесе обозрения (%d грн, 15 мин): весь город как на ладони" % WHEEL_PRICE
	zone.activated.connect(ride_wheel)
	add_child(zone)


func ride_wheel() -> void:
	var h := TimeManager.hour()
	var g := get_tree().get_first_node_in_group("girl") as Girl
	var with_girl := g != null and g.with_player(20.0)
	var price := WHEEL_PRICE * (2 if with_girl else 1)
	if h < 10.0 or h >= 22.0 or not GameManager.spend(price):
		return
	TimeManager.advance(15.0)
	NeedsManager.rest(10.0)
	QuestManager.event("park_ride")
	if with_girl:
		g.like(8)
		QuestManager.event("wheel_olya")
		GameManager.notify("Прокатились с Олей на колесе обозрения. На самом верху она взяла тебя за руку: «Смотри, вон наша Каменка!»")
		return
	GameManager.notify("Прокатился на колесе обозрения: видно и Каменку, и реку, и завод. Отдохнул")


# --- Дворы -----------------------------------------------------------------------

## Детская площадка: песочница, качели, горка, карусель, турник, скамейки.
func _playground(b: MeshBuilder, r: Rect2) -> void:
	b.box(Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0.03, r.end.y), Color(0.6, 0.5, 0.36))
	var x := r.position.x + 2.0
	var z := r.position.y + 2.0
	var red := Color(0.85, 0.25, 0.2)
	var blue := Color(0.25, 0.45, 0.8)
	var yellow := Color(0.95, 0.8, 0.25)
	# Песочница с грибком
	b.box(Vector3(x, 0, z), Vector3(x + 3.0, 0.3, z + 3.0), Color(0.5, 0.36, 0.22))
	b.box(Vector3(x + 0.2, 0.25, z + 0.2), Vector3(x + 2.8, 0.28, z + 2.8), Color(0.88, 0.78, 0.52))
	b.box(Vector3(x + 1.45, 0, z + 1.45), Vector3(x + 1.55, 2.0, z + 1.55), Color(0.4, 0.3, 0.2))
	b.box(Vector3(x + 0.4, 2.0, z + 0.4), Vector3(x + 2.6, 2.2, z + 2.6), red)
	# Качели
	var sx := x + 5.5
	for dx in [0.0, 2.8]:
		b.box(Vector3(sx + dx, 0, z + 0.5), Vector3(sx + dx + 0.1, 2.4, z + 0.6), blue, true)
	b.box(Vector3(sx, 2.3, z + 0.5), Vector3(sx + 2.9, 2.4, z + 0.6), blue)
	for dx in [0.9, 1.9]:
		b.box(Vector3(sx + dx, 0.5, z + 0.53), Vector3(sx + dx + 0.03, 2.3, z + 0.57), Color(0.5, 0.5, 0.5))
	b.box(Vector3(sx + 0.8, 0.45, z + 0.3), Vector3(sx + 2.0, 0.52, z + 0.8), Color(0.55, 0.38, 0.22))
	# Горка
	var gx := x + 11.0
	b.box(Vector3(gx, 0, z), Vector3(gx + 1.2, 1.6, z + 1.2), yellow, true)
	b.box(Vector3(gx + 0.1, 1.6, z + 0.1), Vector3(gx + 1.1, 1.7, z + 1.1), Color(0.55, 0.38, 0.22))
	b.box_rot(Vector3(gx + 0.6, 0.8, z + 2.4), Vector3(0.8, 0.08, 2.6), 0.0, Color(0.75, 0.78, 0.8))
	b.box(Vector3(gx + 0.15, 0.6, z + 1.25), Vector3(gx + 1.05, 0.66, z + 3.6), Color(0.75, 0.78, 0.8))
	# Карусель
	var cc := Vector3(x + 4.0, 0, z + 7.5)
	b.box(cc + Vector3(-0.08, 0, -0.08), cc + Vector3(0.08, 1.1, 0.08), Color(0.4, 0.4, 0.42))
	for k in 8:
		var a := k * TAU / 8.0
		b.box_rot(cc + Vector3(cos(a), 0.4, sin(a)) * 1.0, Vector3(0.9, 0.06, 0.5), -a, red if k % 2 == 0 else yellow)
	# Турник и лесенка
	if r.size.x > 24.0:
		var tx := x + 18.0
		for dx in [0.0, 1.6]:
			b.box(Vector3(tx + dx, 0, z + 6.0), Vector3(tx + dx + 0.08, 2.2, z + 6.08), Color(0.3, 0.3, 0.32), true)
		b.box(Vector3(tx, 2.1, z + 6.02), Vector3(tx + 1.68, 2.15, z + 6.06), Color(0.6, 0.6, 0.62))
		# Рукоход: две стойки с каждой стороны, перекладины поперёк
		for dz in [5.0, 6.6]:
			for dx in [3.0, 6.0]:
				b.box(Vector3(tx + dx, 0, z + dz), Vector3(tx + dx + 0.08, 2.2, z + dz + 0.08), blue, true)
			b.box(Vector3(tx + 3.0, 2.12, z + dz), Vector3(tx + 6.08, 2.2, z + dz + 0.08), blue)
		for k in 7:
			b.box(Vector3(tx + 3.2 + k * 0.45, 2.2, z + 5.0), Vector3(tx + 3.24 + k * 0.45, 2.24, z + 6.68), Color(0.7, 0.7, 0.72))
	_bench(b, Vector3(r.end.x - 2.0, 0, r.position.y + 3.0), -PI / 2.0)
	_bench(b, Vector3(r.end.x - 2.0, 0, r.end.y - 3.0), -PI / 2.0)


# --- Мелочь -------------------------------------------------------------------------

## Скамейка: сиденье и спинка на ножках; yaw — куда смотрит сидящий (0 — на −Z).
func _bench(b: MeshBuilder, p: Vector3, yaw: float) -> void:
	var saved := b.xf
	b.xf = saved * Transform3D(Basis(Vector3.UP, yaw), p)
	b.box(Vector3(-0.9, 0.42, -0.2), Vector3(0.9, 0.47, 0.2), Color(0.5, 0.35, 0.2), true)
	b.box(Vector3(-0.9, 0.47, 0.18), Vector3(0.9, 0.85, 0.22), Color(0.5, 0.35, 0.2))
	for dx in [-0.8, 0.7]:
		b.box(Vector3(dx, 0, -0.18), Vector3(dx + 0.1, 0.42, 0.18), Color(0.25, 0.25, 0.27))
	b.xf = saved


## Штакетник от a до c (по X или по Z).
func _fence(b: MeshBuilder, a: Vector3, c: Vector3) -> void:
	var mn := Vector3(minf(a.x, c.x) - 0.04, 0, minf(a.z, c.z) - 0.04)
	var mx := Vector3(maxf(a.x, c.x) + 0.04, 0, maxf(a.z, c.z) + 0.04)
	b.box(mn + Vector3(0, 0.35, 0), mx + Vector3(0, 0.42, 0), Color(0.75, 0.68, 0.5))
	b.box(mn + Vector3(0, 0.85, 0), mx + Vector3(0, 0.92, 0), Color(0.75, 0.68, 0.5))
	b.add_collider(mn, mx + Vector3(0, 1.1, 0))
	var along_x := absf(c.x - a.x) > absf(c.z - a.z)
	var len := absf(c.x - a.x) if along_x else absf(c.z - a.z)
	var t := 0.0
	while t <= len:
		var p := mn + (Vector3(t, 0, 0.04) if along_x else Vector3(0.04, 0, t))
		b.box(p + Vector3(-0.04, 0, -0.04), p + Vector3(0.04, 1.1, 0.04), Color(0.8, 0.72, 0.52))
		t += 0.5


## Дерево: модель — у Vegetation (со сдвигом города), здесь — тень и ствол.
func _tree(b: MeshBuilder, veg: Vegetation, p: Vector3, kind: int) -> void:
	var s := 0.9 + fmod(absf(p.x * 0.37 + p.z * 0.71), 0.35)
	var yaw := fmod(p.x * 1.7 + p.z, TAU)
	b.box(p + Vector3(-1.3, 0, -1.3) * s, p + Vector3(1.3, 0.015, 1.3) * s, Color(0.2, 0.3, 0.14))
	if kind != Vegetation.TreeKind.BUSH:
		b.add_collider(p + Vector3(-0.16, 0, -0.16) * s, p + Vector3(0.16, 3.0, 0.16) * s)
	veg.add_tree(kind, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), p))


func _person(p: Vector3, yaw: float, shirt: Color, woman: bool) -> void:
	var pb := MeshBuilder.new()
	pb.ground_shade = false
	Villagers.person_model(pb, shirt, Color(0.2, 0.18, 0.15), false, woman)
	var mi := pb.build_mesh()
	mi.position = p
	mi.rotation.y = yaw
	add_child(mi)


func _label(text: String, p: Vector3, yaw: float, px: float, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = px
	l.modulate = color
	l.outline_size = 10
	l.position = p
	l.rotation.y = yaw
	add_child(l)
	return l


func save_state() -> Dictionary:
	return {"sto_day": sto_day, "sto_stage": sto_stage, "sto_fault": sto_fault, "sto_miss": sto_miss, "course_paid": course_paid, "lessons": course_lessons, "course_day": course_day}


func load_state(d: Dictionary) -> void:
	sto_day = int(d.get("sto_day", -1))
	sto_stage = int(d.get("sto_stage", 0))
	sto_fault = int(d.get("sto_fault", 0)) % STO_FAULTS.size()
	sto_miss = int(d.get("sto_miss", 0))
	_show_client()
	course_paid = bool(d.get("course_paid", false))
	course_lessons = int(d.get("lessons", 0))
	course_day = int(d.get("course_day", -1))
	_update_garage()
