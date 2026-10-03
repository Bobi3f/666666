class_name School
extends Node3D
## Школа № 1 на западе города, за рынком — в неё можно зайти и учиться.
## Вокруг — школьный двор за забором: ворота и дорожка к крыльцу,
## спортплощадка с футбольным полем, турником и брусьями, флагшток,
## клумбы, деревья, лавочки; от главной улицы — подъезд.
##
## Первый этаж: вестибюль с вахтёршей, коридор и пять кабинетов —
## математика, литература, рисование (ИЗО), лепка (скульптура) и столовая.
## Уроки по будням: днём с ребятами (8:00–14:00) и вечерняя школа
## (18:00–21:00). У каждого предмета своё задание (lesson_panel.gd):
## математика — примеры, литература — вопросы о книгах, рисование — по
## контуру пальцем, лепка — силуэт на гончарном круге. Оценка 2–5.
## По два урока каждого предмета со средним баллом от 3,5 — аттестат.
##
## Для телефона: коробка здания и окна — в общем меше города (build),
## всё внутреннее — отдельными мешами, которые рисуются только вблизи;
## настоящего света нет — лампы светятся сами.

const Villagers := preload("res://scripts/world/villagers.gd")
## Где стоит школа: всё ниже (X0…, кабинеты, двор) — в своих координатах,
## здание целиком сдвинуто на ORIGIN (узел School стоит там же).
const ORIGIN := Vector3(-48.0, 0, -68.0)
## Школьный двор за забором (свои координаты) и ворота в нём.
const YARD := Rect2(32.0, 138.0, 54.0, 58.0)
const X0 := 42.0
const X1 := 76.0
const Z0 := 168.0
const Z1 := 191.0
const FLOOR_H := 3.6
const FLOORS := 3
const T := 0.3
const DOOR_X := 59.0
## Коридор между северными и южными кабинетами.
const ZN := 177.0
const ZS := 180.5
## Кабинеты: [id, название, x0, x1, z0, z1, x двери].
const ROOMS := [
	["math", "Математика", 42.0, 54.0, 168.0, 177.0, 51.9],
	["canteen", "Столовая", 64.0, 76.0, 168.0, 177.0, 66.4],
	["lit", "Литература", 42.0, 53.0, 180.5, 191.0, 50.9],
	["art", "Рисование", 53.0, 64.5, 180.5, 191.0, 58.9],
	["clay", "Лепка", 64.5, 76.0, 180.5, 191.0, 66.9],
]
const SUBJECTS := {"math": "Математика", "lit": "Литература", "art": "Рисование", "clay": "Лепка"}
const TEACHERS := {"math": "Марья Ивановна", "lit": "Анна Петровна", "art": "Виктор Семёнович", "clay": "Галина Фёдоровна"}
const LESSON_MIN := 45.0
const LESSONS_PER_DAY := 4
const PER_SUBJECT := 2
const CERT_BONUS := 250
const BUFFET_PRICE := 25
const INSIDE_RANGE := 45.0

## Литература: [вопрос, верный, неверный, неверный].
const LIT := [
	["Кто написал «Евгения Онегина»?", "Пушкин", "Лермонтов", "Гоголь"],
	["Кто автор рассказа «Муму»?", "Тургенев", "Толстой", "Чехов"],
	["Кого в «Ревизоре» приняли за ревизора?", "Хлестакова", "Чичикова", "Обломова"],
	["Кто написал басню «Стрекоза и Муравей»?", "Крылов", "Пушкин", "Есенин"],
	["Кто автор «Кобзаря»?", "Шевченко", "Франко", "Котляревский"],
	["Кто написал «Войну и мир»?", "Лев Толстой", "Достоевский", "Тургенев"],
	["Кто написал «Мёртвые души»?", "Гоголь", "Грибоедов", "Куприн"],
	["Кто написал рассказ «Каштанка»?", "Чехов", "Бунин", "Горький"],
	["Илья Муромец, Добрыня Никитич и…", "Алёша Попович", "Иван Царевич", "Садко"],
	["Кто автор «Лесной песни»?", "Леся Украинка", "Марко Вовчок", "Шевченко"],
	["В какой сказке Пушкина старик ловит рыбку?", "О рыбаке и рыбке", "О царе Салтане", "О попе и Балде"],
	["Кто написал «Тараса Бульбу»?", "Гоголь", "Шолохов", "Толстой"],
	["Кто написал «Преступление и наказание»?", "Достоевский", "Чехов", "Лермонтов"],
	["Чьё стихотворение «Белая берёза под моим окном»?", "Есенина", "Маяковского", "Блока"],
	["Кто написал «Энеиду» на украинском?", "Котляревский", "Сковорода", "Франко"],
	["Как зовут героя «Тихого Дона»?", "Григорий Мелехов", "Пьер Безухов", "Павка Корчагин"],
	["Кто автор «Героя нашего времени»?", "Лермонтов", "Пушкин", "Грибоедов"],
	["Как называется сказка Ершова?", "Конёк-Горбунок", "Колобок", "Морозко"],
]
const DRAW_SHAPES := {"sun": "солнце", "house": "домик", "tree": "ёлку", "apple": "яблоко", "fish": "рыбу"}
const CLAY_SHAPES := {"vase": "вазу", "jug": "кувшин", "pot": "горшок", "bowl": "чашу"}

## Оценки: [предмет, оценка].
var grades: Array = []
var lessons_today := 0
var _today := -1
var _subject := ""
var _asked_lit: Array = []
var panel: LessonPanel
var _kids: MeshInstance3D
var _teachers: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("persist")
	_rng.randomize()
	panel = LessonPanel.new()
	panel.done.connect(_on_done)
	add_child(panel)


## Когда идут уроки: будни 8–14 и вечерняя школа 18–21.
static func lesson_time() -> String:
	var wd := TimeManager.weekday()
	if wd == "сб" or wd == "вс":
		return ""
	var h := TimeManager.hour()
	if h >= 8.0 and h < 14.0:
		return "day"
	if h >= 18.0 and h < 21.0:
		return "evening"
	return ""


## Школа (и буфет) открыта: будни с 7:30 до 21:00.
static func is_open() -> bool:
	var wd := TimeManager.weekday()
	var h := TimeManager.hour()
	return wd != "сб" and wd != "вс" and h >= 7.5 and h < 21.0


var lessons: int:
	get:
		return grades.size()


func average() -> float:
	if grades.is_empty():
		return 0.0
	var s := 0.0
	for g in grades:
		s += float(g[1])
	return s / grades.size()


func count(subject: String) -> int:
	var n := 0
	for g in grades:
		if g[0] == subject:
			n += 1
	return n


func progress_text() -> String:
	var parts := []
	for s in ["math", "lit", "art", "clay"]:
		parts.append("%s %d/%d" % [(SUBJECTS[s] as String).left(3), mini(count(s), PER_SUBJECT), PER_SUBJECT])
	return " · ".join(parts)


# --- Здание -------------------------------------------------------------------

## b, glow — общий меш города (коробка, окна снаружи, коллизии стен).
## Внутреннее — в своих мешах с малой дальностью видимости.
## Точка в своих координатах школы → в мире.
static func at(p: Vector3) -> Vector3:
	return p + ORIGIN


func build(b: MeshBuilder, glow: MeshBuilder) -> void:
	position = ORIGIN
	# Коробка и двор — в общем меше города: сдвигаем его на место школы
	var b_xf := b.xf
	var g_xf := glow.xf
	b.xf = Transform3D(Basis.IDENTITY, ORIGIN)
	glow.xf = b.xf
	_shell(b, glow)
	_grounds(b)
	b.xf = b_xf
	glow.xf = g_xf
	var ib := MeshBuilder.new()
	var lamps := MeshBuilder.new()
	lamps.ground_shade = false
	var kb := MeshBuilder.new()
	kb.ground_shade = false
	var tb := MeshBuilder.new()
	tb.ground_shade = false
	_inside(ib, lamps)
	_hall(ib)
	_math(ib, kb, tb)
	_literature(ib, kb, tb)
	_art(ib, kb, tb)
	_clay_room(ib, kb, tb)
	_canteen(ib)
	var mi := ib.build_mesh()
	mi.name = "Inside"
	mi.visibility_range_end = INSIDE_RANGE
	add_child(mi)
	var body := ib.build_body()
	body.name = "InsideCollision"
	add_child(body)
	var lm := lamps.build_mesh(true)
	lm.visibility_range_end = INSIDE_RANGE
	lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lm)
	_kids = kb.build_mesh()
	_kids.name = "Kids"
	_kids.visibility_range_end = INSIDE_RANGE
	add_child(_kids)
	_teachers = tb.build_mesh()
	_teachers.name = "Teachers"
	_teachers.visibility_range_end = INSIDE_RANGE
	add_child(_teachers)


## Коробка: наружные стены первого этажа с дверью, этажи выше целиком,
## крыша, окна на всех этажах, крыльцо с козырьком и вывеской.
func _shell(b: MeshBuilder, glow: MeshBuilder) -> void:
	var wall := Color(0.85, 0.72, 0.62)
	var top := FLOOR_H * FLOORS
	b.box(Vector3(X0, 0, Z0), Vector3(DOOR_X - 1.1, FLOOR_H, Z0 + T), wall, true)
	b.box(Vector3(DOOR_X + 1.1, 0, Z0), Vector3(X1, FLOOR_H, Z0 + T), wall, true)
	b.box(Vector3(DOOR_X - 1.1, 2.5, Z0), Vector3(DOOR_X + 1.1, FLOOR_H, Z0 + T), wall)
	b.box(Vector3(X0, 0, Z1 - T), Vector3(X1, FLOOR_H, Z1), wall, true)
	b.box(Vector3(X0, 0, Z0), Vector3(X0 + T, FLOOR_H, Z1), wall, true)
	b.box(Vector3(X1 - T, 0, Z0), Vector3(X1, FLOOR_H, Z1), wall, true)
	b.box(Vector3(X0, FLOOR_H, Z0), Vector3(X1, top, Z1), wall, true)
	b.box(Vector3(X0 - 0.2, top, Z0 - 0.2), Vector3(X1 + 0.2, top + 0.4, Z1 + 0.2), Color(0.45, 0.45, 0.47))
	# Белый карниз между этажами — только полосами по периметру
	var band := Color(0.93, 0.92, 0.88)
	b.box(Vector3(X0 - 0.05, FLOOR_H - 0.1, Z0 - 0.05), Vector3(X1 + 0.05, FLOOR_H, Z0), band)
	b.box(Vector3(X0 - 0.05, FLOOR_H - 0.1, Z1), Vector3(X1 + 0.05, FLOOR_H, Z1 + 0.05), band)
	b.box(Vector3(X0 - 0.05, FLOOR_H - 0.1, Z0), Vector3(X0, FLOOR_H, Z1), band)
	b.box(Vector3(X1, FLOOR_H - 0.1, Z0), Vector3(X1 + 0.05, FLOOR_H, Z1), band)
	for f in FLOORS:
		var y := 1.0 + f * FLOOR_H
		var x := X0 + 1.2
		while x < X1 - 1.5:
			if not (f == 0 and absf(x + 0.9 - DOOR_X) < 2.2):
				for zf in [Z0 - 0.03, Z1 - 0.01]:
					b.box(Vector3(x, y, zf), Vector3(x + 1.8, y + 1.7, zf + 0.04), Color(0.9, 0.9, 0.88))
					glow.box(Vector3(x + 0.1, y + 0.1, zf - 0.01), Vector3(x + 1.7, y + 1.6, zf + 0.05), Color(0.9, 0.9, 0.8))
			x += 2.6
		var z := Z0 + 1.5
		while z < Z1 - 1.5:
			for xf in [X0 - 0.03, X1 - 0.01]:
				b.box(Vector3(xf, y, z), Vector3(xf + 0.04, y + 1.7, z + 1.8), Color(0.9, 0.9, 0.88))
				glow.box(Vector3(xf - 0.01, y + 0.1, z + 0.1), Vector3(xf + 0.05, y + 1.6, z + 1.7), Color(0.9, 0.9, 0.8))
			z += 2.6
	b.box(Vector3(DOOR_X - 2.5, 0, Z0 - 2.0), Vector3(DOOR_X + 2.5, 0.12, Z0), Color(0.6, 0.6, 0.58))
	b.box(Vector3(DOOR_X - 2.5, 3.0, Z0 - 2.0), Vector3(DOOR_X + 2.5, 3.2, Z0), Color(0.45, 0.45, 0.47))
	for s in [-1.2, 1.1]:
		b.box(Vector3(DOOR_X + s, 0, Z0 - 0.06), Vector3(DOOR_X + s + 0.1, 2.5, Z0 + T + 0.02), Color(0.4, 0.3, 0.22))
	b.box(Vector3(DOOR_X + 1.3, 1.45, Z0 - 0.06), Vector3(DOOR_X + 2.5, 2.15, Z0 - 0.02), Color(0.15, 0.3, 0.55))
	_label("ШКОЛА № 1", Vector3(DOOR_X, 3.6, Z0 - 0.06), PI, 0.01, Color(1, 1, 1), 150.0)
	_label("Уроки: пн–пт 8:00–14:00\nВечерняя школа 18:00–21:00", Vector3(DOOR_X + 1.9, 1.8, Z0 - 0.07), PI, 0.0035, Color(1, 1, 0.9), 40.0)


## Школьный двор: забор с воротами, дорожка к крыльцу, спортплощадка,
## флагшток, клумбы, деревья, лавочки и подъезд от главной улицы.
func _grounds(b: MeshBuilder) -> void:
	var y := YARD
	var x0 := y.position.x
	var x1 := y.end.x
	var z0 := y.position.y
	var z1 := y.end.y
	var green := Color(0.25, 0.42, 0.3)
	var white := Color(0.95, 0.95, 0.92)
	# Подъезд: от главной улицы на запад и к воротам
	var asphalt := Color(0.3, 0.3, 0.31)
	b.box(Vector3(DOOR_X - 6.0, 0, 122.0), Vector3(89.0, 0.05, 129.0), asphalt)
	b.box(Vector3(DOOR_X - 2.5, 0, 129.0), Vector3(DOOR_X + 2.5, 0.05, z0 + 0.5), asphalt)
	# Площадка у ворот: «зебра» и знак «Осторожно, дети»
	for i in 6:
		b.box(Vector3(DOOR_X - 2.3 + i * 0.85, 0.05, 123.5), Vector3(DOOR_X - 1.8 + i * 0.85, 0.07, 127.5), white)
	b.box(Vector3(DOOR_X + 3.2, 0, z0 - 2.0), Vector3(DOOR_X + 3.28, 2.4, z0 - 1.92), Color(0.6, 0.6, 0.62))
	b.box(Vector3(DOOR_X + 2.85, 1.8, z0 - 2.03), Vector3(DOOR_X + 3.63, 2.5, z0 - 1.99), Color(0.95, 0.9, 0.25))
	# Забор: столбики через 2.5 м и две перекладины, ворота у дорожки
	var gate0 := DOOR_X - 2.0
	var gate1 := DOOR_X + 2.0
	var runs := [[Vector3(x0, 0, z0), Vector3(gate0, 0, z0)], [Vector3(gate1, 0, z0), Vector3(x1, 0, z0)],
		[Vector3(x0, 0, z1), Vector3(x1, 0, z1)], [Vector3(x0, 0, z0), Vector3(x0, 0, z1)], [Vector3(x1, 0, z0), Vector3(x1, 0, z1)]]
	for r in runs:
		var a: Vector3 = r[0]
		var c: Vector3 = r[1]
		var len := a.distance_to(c)
		var dir := (c - a) / len
		var k := 0.0
		while k <= len + 0.01:
			var p := a + dir * k
			b.box(p + Vector3(-0.05, 0, -0.05), p + Vector3(0.05, 1.5, 0.05), green)
			k += 2.5
		for h in [0.35, 1.35]:
			var mn := Vector3(minf(a.x, c.x) - 0.02, h, minf(a.z, c.z) - 0.02)
			var mx := Vector3(maxf(a.x, c.x) + 0.02, h + 0.06, maxf(a.z, c.z) + 0.02)
			b.box(mn, mx, green)
		# Сетка — частые тонкие прутья (вдали — мелочь, не рисуется)
		k = 0.0
		while k < len:
			var p := a + dir * k
			b.box(p + Vector3(-0.012, 0.35, -0.012), p + Vector3(0.012, 1.35, 0.012), green.lightened(0.15))
			k += 0.5
		b.add_collider(Vector3(minf(a.x, c.x) - 0.06, 0, minf(a.z, c.z) - 0.06), Vector3(maxf(a.x, c.x) + 0.06, 1.5, maxf(a.z, c.z) + 0.06))
	# Ворота открыты — створки к забору
	for sx in [-1.0, 1.0]:
		var gx: float = DOOR_X + sx * 2.0
		b.box(Vector3(gx - 0.08, 0, z0 - 0.08), Vector3(gx + 0.08, 1.8, z0 + 0.08), green.darkened(0.3), true)
		b.box(Vector3(gx - 0.03, 0.2, z0 + 0.1), Vector3(gx + 0.03, 1.5, z0 + 1.9), green)
	# Дорожка от ворот к крыльцу и поперечная — к спортплощадке
	var tile := Color(0.6, 0.58, 0.55)
	b.box(Vector3(DOOR_X - 1.5, 0, z0), Vector3(DOOR_X + 1.5, 0.04, Z0 - 2.0), tile)
	b.box(Vector3(x0 + 3.0, 0, 161.0), Vector3(DOOR_X - 1.5, 0.04, 162.6), tile)
	# Спортплощадка: поле с разметкой и воротами, вокруг — беговая дорожка
	var f := Rect2(x0 + 3.0, z0 + 3.0, 15.0, 11.0)
	b.box(Vector3(f.position.x - 1.2, 0, f.position.y - 1.2), Vector3(f.end.x + 1.2, 0.03, f.end.y + 1.2), Color(0.62, 0.32, 0.24))
	b.box(Vector3(f.position.x, 0, f.position.y), Vector3(f.end.x, 0.05, f.end.y), Color(0.33, 0.58, 0.28))
	for zz in [f.position.y + 0.2, f.end.y - 0.3]:
		b.box(Vector3(f.position.x + 0.2, 0.05, zz), Vector3(f.end.x - 0.2, 0.06, zz + 0.1), white)
	var fcz := f.get_center().y
	b.box(Vector3(f.get_center().x - 0.05, 0.05, f.position.y + 0.2), Vector3(f.get_center().x + 0.05, 0.06, f.end.y - 0.2), white)
	for gx in [f.position.x + 0.3, f.end.x - 0.3]:
		for gz in [fcz - 1.5, fcz + 1.5]:
			b.box(Vector3(gx - 0.05, 0, gz - 0.05), Vector3(gx + 0.05, 1.5, gz + 0.05), white, true)
		b.box(Vector3(gx - 0.05, 1.45, fcz - 1.5), Vector3(gx + 0.05, 1.55, fcz + 1.55), white)
	# Турник, брусья и «шведская стенка» у площадки
	var t := Vector3(x0 + 3.0, 0, f.end.y + 3.0)
	for dz in [0.0, 2.0]:
		b.box(t + Vector3(-0.05, 0, dz - 0.05), t + Vector3(0.05, 2.4, dz + 0.05), Color(0.4, 0.45, 0.5), true)
	b.box(t + Vector3(-0.03, 2.3, 0.0), t + Vector3(0.03, 2.36, 2.0), Color(0.65, 0.65, 0.67))
	var br := t + Vector3(3.0, 0, 0)
	for dx in [0.0, 1.8]:
		for dz in [0.0, 0.6]:
			b.box(br + Vector3(dx - 0.04, 0, dz - 0.04), br + Vector3(dx + 0.04, 1.4, dz + 0.04), Color(0.4, 0.45, 0.5))
		b.box(br + Vector3(-0.1, 1.35, -0.03), br + Vector3(1.9, 1.42, 0.03), Color(0.55, 0.4, 0.25))
		b.box(br + Vector3(-0.1, 1.35, 0.57), br + Vector3(1.9, 1.42, 0.63), Color(0.55, 0.4, 0.25))
	var sw := t + Vector3(7.0, 0, 0)
	for dx in [0.0, 1.6]:
		b.box(sw + Vector3(dx - 0.05, 0, -0.05), sw + Vector3(dx + 0.05, 2.6, 0.05), Color(0.6, 0.45, 0.3), true)
	for i in 8:
		b.box(sw + Vector3(0.0, 0.3 + i * 0.3, -0.02), sw + Vector3(1.6, 0.34 + i * 0.3, 0.02), Color(0.6, 0.45, 0.3))
	# Флагшток у крыльца
	var fp := Vector3(DOOR_X + 5.0, 0, Z0 - 4.0)
	b.box(fp + Vector3(-0.06, 0, -0.06), fp + Vector3(0.06, 9.0, 0.06), Color(0.8, 0.8, 0.82), true)
	b.box(fp + Vector3(0.06, 7.6, -0.02), fp + Vector3(1.8, 8.2, 0.02), Color(0.2, 0.45, 0.8))
	b.box(fp + Vector3(0.06, 7.0, -0.02), fp + Vector3(1.8, 7.6, 0.02), Color(0.95, 0.8, 0.15))
	# Клумбы с цветами вдоль дорожки и лавочки
	var r := RandomNumberGenerator.new()
	r.seed = 1001
	for side in [-1.0, 1.0]:
		var bx: float = DOOR_X + side * 4.5
		b.box(Vector3(bx - 1.2, 0, z0 + 6.0), Vector3(bx + 1.2, 0.25, Z0 - 6.0), Color(0.9, 0.9, 0.88))
		b.box(Vector3(bx - 1.1, 0, z0 + 6.1), Vector3(bx + 1.1, 0.3, Z0 - 6.1), Color(0.35, 0.25, 0.18))
		var fz := z0 + 6.5
		while fz < Z0 - 6.5:
			for fx in [bx - 0.6, bx, bx + 0.6]:
				var col: Color = [Color(0.95, 0.3, 0.3), Color(0.98, 0.85, 0.2), Color(0.85, 0.5, 0.9), Color(0.98, 0.98, 0.95)][r.randi() % 4]
				b.box(Vector3(fx - 0.08, 0.3, fz - 0.08), Vector3(fx + 0.08, 0.45, fz + 0.08), col)
			fz += 0.7
		for bz in [z0 + 9.0, z0 + 18.0]:
			var lx: float = DOOR_X + side * 6.6
			b.box(Vector3(lx - 0.25, 0.4, bz - 1.0), Vector3(lx + 0.25, 0.46, bz + 1.0), Color(0.55, 0.4, 0.25), true)
			b.box(Vector3(lx + side * 0.25 - 0.03, 0.46, bz - 1.0), Vector3(lx + side * 0.25 + 0.03, 0.9, bz + 1.0), Color(0.55, 0.4, 0.25))
			for e in [-0.8, 0.8]:
				b.box(Vector3(lx - 0.2, 0, bz + e - 0.04), Vector3(lx + 0.2, 0.4, bz + e + 0.04), Color(0.3, 0.3, 0.32))
	# Берёзы и клёны во дворе — у забора, не на площадке
	for tp in [Vector3(x1 - 3.0, 0, z0 + 4.0), Vector3(x1 - 3.0, 0, z0 + 12.0), Vector3(x1 - 3.0, 0, z0 + 20.0),
			Vector3(x1 - 10.0, 0, z0 + 3.0), Vector3(x0 + 2.5, 0, z1 - 3.0), Vector3(x1 - 3.0, 0, z1 - 3.0)]:
		_yard_tree(b, tp, r)


## Дерево во дворе: белый или бурый ствол и крона из нескольких комков.
func _yard_tree(b: MeshBuilder, p: Vector3, r: RandomNumberGenerator) -> void:
	var birch := r.randf() < 0.5
	b.box(p + Vector3(-0.14, 0, -0.14), p + Vector3(0.14, 3.2, 0.14), Color(0.9, 0.9, 0.86) if birch else Color(0.4, 0.3, 0.22), true)
	var leaf := Color(0.33, 0.55, 0.22) if birch else Color(0.26, 0.45, 0.2)
	for i in 5:
		var c := p + Vector3(r.randf_range(-0.9, 0.9), r.randf_range(3.0, 5.2), r.randf_range(-0.9, 0.9))
		b.box_rot(c, Vector3(1.6, 1.3, 1.6) * r.randf_range(0.8, 1.2), r.randf() * TAU, leaf.lightened(r.randf() * 0.12))


## Стена вдоль X на z от x0 до x1 с проёмами [x_center] шириной 1.8 м.
func _wall_z(ib: MeshBuilder, z: float, x0: float, x1: float, doors: Array) -> void:
	var cuts: Array = [x0]
	for d in doors:
		cuts.append(float(d) - 0.9)
		cuts.append(float(d) + 0.9)
	cuts.append(x1)
	for i in range(0, cuts.size(), 2):
		_wall_piece(ib, Vector3(cuts[i], 0, z - 0.1), Vector3(cuts[i + 1], FLOOR_H, z + 0.1))
	for d in doors:
		ib.box(Vector3(float(d) - 0.9, 2.5, z - 0.1), Vector3(float(d) + 0.9, FLOOR_H, z + 0.1), Color(0.93, 0.93, 0.88))
		for s in [-0.95, 0.9]:
			ib.box(Vector3(float(d) + s, 0, z - 0.13), Vector3(float(d) + s + 0.05, 2.5, z + 0.13), Color(0.55, 0.4, 0.28))


## Стена вдоль Z на x от z0 до z1, сплошная.
func _wall_x(ib: MeshBuilder, x: float, z0: float, z1: float) -> void:
	_wall_piece(ib, Vector3(x - 0.1, 0, z0), Vector3(x + 0.1, FLOOR_H, z1))


## Кусок перегородки: побелка сверху, зелёная панель снизу, коллизия.
func _wall_piece(ib: MeshBuilder, mn: Vector3, mx: Vector3) -> void:
	if mx.x - mn.x < 0.05 or mx.z - mn.z < 0.05:
		return
	ib.box(mn, mx, Color(0.93, 0.93, 0.88), true)
	ib.box(mn + Vector3(-0.012, 0.04, -0.012), Vector3(mx.x + 0.012, 1.5, mx.z + 0.012), Color(0.45, 0.62, 0.52))


func _inside(ib: MeshBuilder, lamps: MeshBuilder) -> void:
	var green := Color(0.45, 0.62, 0.52)
	var white := Color(0.93, 0.93, 0.88)
	# Пол — крашеные доски, потолок — побелка
	ib.box(Vector3(X0 + T, 0, Z0 + T), Vector3(X1 - T, 0.04, Z1 - T), Color(0.5, 0.32, 0.2))
	var x := X0 + T
	while x < X1 - T:
		ib.box(Vector3(x, 0.04, Z0 + T), Vector3(x + 0.03, 0.045, Z1 - T), Color(0.4, 0.26, 0.16))
		x += 0.6
	# Потолок — в меше ламп (без освещения): снизу его не видно тёмным
	lamps.box(Vector3(X0 + T, FLOOR_H - 0.06, Z0 + T), Vector3(X1 - T, FLOOR_H - 0.03, Z1 - T), Color(0.8, 0.8, 0.77))
	# Внутренние стороны наружных стен
	for side in [[Vector3(X0 + T, 0, Z0 + T), Vector3(X1 - T, 0, Z0 + T + 0.01)], [Vector3(X0 + T, 0, Z1 - T - 0.01), Vector3(X1 - T, 0, Z1 - T)],
			[Vector3(X0 + T, 0, Z0 + T), Vector3(X0 + T + 0.01, 0, Z1 - T)], [Vector3(X1 - T - 0.01, 0, Z0 + T), Vector3(X1 - T, 0, Z1 - T)]]:
		var a: Vector3 = side[0]
		var e: Vector3 = side[1]
		ib.box(a + Vector3(0, 0.04, 0), e + Vector3(0, 1.5, 0), green)
		ib.box(a + Vector3(0, 1.5, 0), e + Vector3(0, FLOOR_H - 0.06, 0), white)
	# Окна изнутри: как снаружи, светлое «небо» в стекле
	for zf in [Z0 + T + 0.01, Z1 - T - 0.03]:
		x = X0 + 1.2
		while x < X1 - 1.5:
			if not (zf < ZN and absf(x + 0.9 - DOOR_X) < 2.2):
				ib.box(Vector3(x, 1.0, zf), Vector3(x + 1.8, 2.7, zf + 0.02), white)
				ib.box(Vector3(x + 0.1, 1.1, zf - 0.005), Vector3(x + 1.7, 2.6, zf + 0.025), Color(0.62, 0.78, 0.9))
			x += 2.6
	for xf in [X0 + T + 0.01, X1 - T - 0.03]:
		var z := Z0 + 1.5
		while z < Z1 - 1.5:
			if z + 1.8 < ZN or z > ZS:
				ib.box(Vector3(xf, 1.0, z), Vector3(xf + 0.02, 2.7, z + 1.8), white)
				ib.box(Vector3(xf - 0.005, 1.1, z + 0.1), Vector3(xf + 0.025, 2.6, z + 1.7), Color(0.62, 0.78, 0.9))
			z += 2.6
	# Перегородки: северные кабинеты, коридор, южные кабинеты
	_wall_z(ib, ZN, X0 + T, 54.0, [ROOMS[0][6]])
	_wall_z(ib, ZN, 64.0, X1 - T, [ROOMS[1][6]])
	_wall_x(ib, 54.0, Z0 + T, ZN + 0.1)
	_wall_x(ib, 64.0, Z0 + T, ZN + 0.1)
	_wall_z(ib, ZS, X0 + T, X1 - T, [ROOMS[2][6], ROOMS[3][6], ROOMS[4][6]])
	_wall_x(ib, 53.0, ZS - 0.1, Z1 - T)
	_wall_x(ib, 64.5, ZS - 0.1, Z1 - T)
	# Таблички над дверями и лампы-светильники в каждом помещении
	for r in ROOMS:
		# Табличка над дверью — со стороны коридора
		var north := float(r[4]) < ZN
		var dz: float = ZN + 0.12 if north else ZS - 0.12
		var face := 1.0 if north else -1.0
		_label(r[1], Vector3(float(r[6]), 2.85, dz + face * 0.02), 0.0 if north else PI, 0.0035, Color(0.1, 0.1, 0.15), 20.0)
		ib.box(Vector3(float(r[6]) - 0.7, 2.65, minf(dz, dz + face * 0.02)), Vector3(float(r[6]) + 0.7, 3.05, maxf(dz, dz + face * 0.02)), Color(0.95, 0.95, 0.9))
		var c := Vector3((float(r[2]) + float(r[3])) * 0.5, FLOOR_H - 0.06, (float(r[4]) + float(r[5])) * 0.5)
		for dx in [-2.5, 2.5]:
			lamps.box(c + Vector3(dx - 0.7, -0.1, -0.15), c + Vector3(dx + 0.7, -0.01, 0.15), Color(1, 1, 0.95))
	for lx in [46.0, 52.0, 59.0, 66.0, 72.0]:
		lamps.box(Vector3(lx - 0.7, FLOOR_H - 0.16, (ZN + ZS) * 0.5 - 0.15), Vector3(lx + 0.7, FLOOR_H - 0.07, (ZN + ZS) * 0.5 + 0.15), Color(1, 1, 0.95))
	lamps.box(Vector3(DOOR_X - 0.7, FLOOR_H - 0.16, 172.0), Vector3(DOOR_X + 0.7, FLOOR_H - 0.07, 172.3), Color(1, 1, 0.95))
	# Коридор: цветы в кадках и лавки у стен
	for px in [44.0, 56.5, 70.0]:
		ib.box(Vector3(px - 0.25, 0, ZS - 0.65), Vector3(px + 0.25, 0.45, ZS - 0.15), Color(0.5, 0.35, 0.22))
		ib.box(Vector3(px - 0.35, 0.45, ZS - 0.75), Vector3(px + 0.35, 1.1, ZS - 0.05), Color(0.25, 0.5, 0.25))
	for bx in [47.0, 69.5]:
		ib.box(Vector3(bx - 1.0, 0.4, ZN + 0.15), Vector3(bx + 1.0, 0.46, ZN + 0.55), Color(0.5, 0.36, 0.22))


func _label(text: String, p: Vector3, yaw: float, px: float, col: Color, see: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = px
	l.outline_size = 0
	l.modulate = col
	l.position = p
	l.rotation.y = yaw
	l.visibility_range_end = see
	add_child(l)
	return l


## Человек в меш b: сидит или стоит, лицом по yaw (0 — к −Z).
func _person(b: MeshBuilder, p: Vector3, yaw: float, shirt: Color, hat: Color, sit: bool, woman: bool, s := 1.0) -> void:
	var saved := b.xf
	b.xf = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), p)
	Villagers.person_model(b, shirt, hat, sit, woman)
	b.xf = saved


func _kid_colors(k: int) -> Array:
	return [[Color(0.9, 0.9, 0.9), Color(0.25, 0.3, 0.5), Color(0.6, 0.2, 0.2), Color(0.3, 0.5, 0.35)][k % 4],
		[Color(0.3, 0.2, 0.15), Color(0.8, 0.7, 0.4), Color(0.15, 0.12, 0.1)][k % 3]]


## Доска на западной стене кабинета.
func _board(ib: MeshBuilder, x: float, cz: float, lines: Array) -> void:
	ib.box(Vector3(x, 0.9, cz - 2.2), Vector3(x + 0.05, 2.3, cz + 2.2), Color(0.12, 0.25, 0.18))
	ib.box(Vector3(x, 0.85, cz - 2.3), Vector3(x + 0.12, 0.9, cz + 2.3), Color(0.5, 0.35, 0.22))
	for i in lines.size():
		_label(lines[i], Vector3(x + 0.06, 2.0 - i * 0.45, cz), PI / 2.0, 0.003, Color(0.95, 0.95, 0.95), 18.0)


## Ряды парт лицом к доске (к −X); одна парта — игрока, с зоной урока.
func _desks(ib: MeshBuilder, kb: MeshBuilder, xs: Array, zs: Array, mine: Vector2i, subject: String) -> void:
	var k := 0
	for ci in zs.size():
		for ri in xs.size():
			var dx: float = xs[ri]
			var dz: float = zs[ci]
			ib.box(Vector3(dx - 0.3, 0, dz - 0.7), Vector3(dx + 0.3, 0.72, dz + 0.7), Color(0.35, 0.5, 0.4), true)
			ib.box(Vector3(dx - 0.35, 0.72, dz - 0.75), Vector3(dx + 0.35, 0.76, dz + 0.75), Color(0.6, 0.45, 0.3))
			for s in [-0.35, 0.35]:
				ib.box(Vector3(dx + 0.45, 0, dz + s - 0.2), Vector3(dx + 0.85, 0.44, dz + s + 0.2), Color(0.5, 0.36, 0.22))
			if Vector2i(ri, ci) == mine:
				ib.box(Vector3(dx - 0.2, 0.76, dz - 0.3), Vector3(dx + 0.15, 0.78, dz + 0.1), Color(0.95, 0.95, 0.9))
				_zone(subject, Vector3(dx + 0.8, 0, dz), Vector3(1.4, 2.0, 2.0))
			else:
				for s in [-0.35, 0.35]:
					if (k * 7 + int(s * 10.0)) % 5 == 0:
						continue
					var col := _kid_colors(k + int(s * 10.0))
					_person(kb, Vector3(dx + 0.65, 0, dz + s), PI / 2.0, col[0], col[1], true, (k + int(s * 10.0)) % 2 == 0, 0.78)
			k += 1


func _zone(subject: String, p: Vector3, size: Vector3) -> void:
	var zone := InteractZone.create("", size)
	zone.position = p
	zone.name = "Lesson_" + subject
	zone.prompt_fn = lesson_prompt.bind(subject)
	zone.activated.connect(start_lesson.bind(subject))
	add_child(zone)


## Вестибюль: вахтёрша, вешалка, доска почёта и расписание.
func _hall(ib: MeshBuilder) -> void:
	var desk := Vector3(DOOR_X + 3.0, 0, Z0 + 2.5)
	ib.box(desk + Vector3(-0.8, 0, -0.4), desk + Vector3(0.8, 0.8, 0.4), Color(0.45, 0.3, 0.2), true)
	ib.box(desk + Vector3(-0.85, 0.8, -0.45), desk + Vector3(0.85, 0.84, 0.45), Color(0.55, 0.38, 0.25))
	ib.box(desk + Vector3(-0.2, 0.84, -0.2), desk + Vector3(0.2, 0.92, 0.2), Color(0.1, 0.1, 0.1))
	_person(ib, desk + Vector3(0, 0, 0.95), 0.0, Color(0.35, 0.3, 0.45), Color(0.55, 0.5, 0.45), true, true)
	ib.box(desk + Vector3(-0.3, 0.4, 0.7), desk + Vector3(0.3, 0.46, 1.2), Color(0.4, 0.3, 0.2))
	# Вешалка на западной стене вестибюля
	ib.box(Vector3(54.12, 1.6, Z0 + 1.5), Vector3(54.22, 1.7, Z0 + 6.5), Color(0.4, 0.3, 0.2))
	for k in 6:
		var cz := Z0 + 1.8 + k * 0.8
		ib.box(Vector3(54.2, 0.9, cz - 0.22), Vector3(54.4, 1.65, cz + 0.22), [Color(0.3, 0.3, 0.45), Color(0.5, 0.25, 0.2), Color(0.3, 0.4, 0.3)][k % 3])
	# Доска почёта и расписание на восточной стене вестибюля
	var wx := 63.88
	ib.box(Vector3(wx - 0.04, 1.2, Z0 + 4.8), Vector3(wx, 2.8, Z0 + 8.4), Color(0.6, 0.15, 0.12))
	for k in 6:
		var pz := Z0 + 5.1 + (k % 3) * 1.1
		var py := 1.4 + (k / 3) * 0.7
		ib.box(Vector3(wx - 0.06, py, pz), Vector3(wx - 0.04, py + 0.55, pz + 0.8), Color(0.9, 0.88, 0.8))
	_label("ДОСКА ПОЧЁТА", Vector3(wx - 0.05, 2.95, Z0 + 6.6), -PI / 2.0, 0.0035, Color(0.1, 0.1, 0.1), 20.0)
	ib.box(Vector3(wx - 0.03, 1.2, Z0 + 1.2), Vector3(wx, 2.6, Z0 + 4.2), Color(0.95, 0.95, 0.9))
	_label("РАСПИСАНИЕ\n1. Математика\n2. Литература\n3. Рисование\n4. Лепка", Vector3(wx - 0.04, 1.9, Z0 + 2.7), -PI / 2.0, 0.0024, Color(0.1, 0.1, 0.15), 20.0)


func _math(ib: MeshBuilder, kb: MeshBuilder, tb: MeshBuilder) -> void:
	var cz := (Z0 + ZN) * 0.5
	_board(ib, X0 + T + 0.02, cz, ["Математика", "a² + b² = c²", "7 × 8 = 56"])
	ib.box(Vector3(X0 + 1.8, 0, cz + 2.3), Vector3(X0 + 2.6, 0.78, cz + 3.7), Color(0.45, 0.3, 0.2), true)
	_person(tb, Vector3(X0 + 1.2, 0, cz - 0.4), -PI / 2.0, Color(0.55, 0.3, 0.4), Color(0.5, 0.4, 0.3), false, true)
	# Треугольник и счёты на стене
	ib.box(Vector3(X0 + T + 0.02, 2.4, cz + 2.8), Vector3(X0 + T + 0.06, 3.2, cz + 3.6), Color(0.7, 0.55, 0.3))
	_desks(ib, kb, [45.5, 47.4, 49.3], [170.0, 172.6, 175.2], Vector2i(2, 1), "math")


func _literature(ib: MeshBuilder, kb: MeshBuilder, tb: MeshBuilder) -> void:
	var cz := (ZS + Z1) * 0.5
	_board(ib, X0 + T + 0.02, cz, ["Литература", "«Мороз и солнце;", "день чудесный!»"])
	# Портреты писателей и шкафы с книгами у южной стены
	for k in 4:
		var px := 44.0 + k * 2.2
		ib.box(Vector3(px, 2.3, Z1 - T - 0.04), Vector3(px + 0.8, 3.2, Z1 - T), Color(0.45, 0.32, 0.2))
		ib.box(Vector3(px + 0.08, 2.38, Z1 - T - 0.05), Vector3(px + 0.72, 3.12, Z1 - T - 0.04), Color(0.8, 0.75, 0.65))
	var colors := [Color(0.6, 0.15, 0.12), Color(0.15, 0.3, 0.55), Color(0.2, 0.45, 0.25), Color(0.7, 0.55, 0.2), Color(0.35, 0.2, 0.35)]
	for sx in [49.5, 51.2]:
		# Шкаф: задняя стенка, бока, полки — книги видно
		var wood := Color(0.45, 0.3, 0.2)
		ib.box(Vector3(sx, 0, Z1 - T - 0.06), Vector3(sx + 1.5, 2.1, Z1 - T), wood, true)
		ib.add_collider(Vector3(sx, 0, Z1 - T - 0.5), Vector3(sx + 1.5, 2.1, Z1 - T))
		for bx0 in [sx, sx + 1.44]:
			ib.box(Vector3(bx0, 0, Z1 - T - 0.5), Vector3(bx0 + 0.06, 2.1, Z1 - T), wood)
		for shelf in 5:
			ib.box(Vector3(sx, 0.14 + shelf * 0.48, Z1 - T - 0.5), Vector3(sx + 1.5, 0.2 + shelf * 0.48, Z1 - T), wood.lightened(0.1))
		for shelf in 4:
			var y := 0.2 + shelf * 0.48
			var bx: float = sx + 0.08
			var k := 0
			while bx < sx + 1.4:
				var w := 0.06 + (k % 3) * 0.02
				ib.box(Vector3(bx, y, Z1 - T - 0.45), Vector3(bx + w, y + 0.32 + (k % 2) * 0.06, Z1 - T - 0.52 + 0.3), colors[(k + shelf) % colors.size()])
				bx += w + 0.01
				k += 1
	_person(tb, Vector3(X0 + 1.2, 0, cz + 0.6), -PI / 2.0, Color(0.3, 0.35, 0.5), Color(0.35, 0.3, 0.25), false, true)
	_desks(ib, kb, [45.5, 47.4, 49.3], [182.6, 185.2, 187.8], Vector2i(2, 2), "lit")


func _art(ib: MeshBuilder, kb: MeshBuilder, tb: MeshBuilder) -> void:
	# Натюрморт у южной стены: стол, ваза, яблоки, драпировка
	var still := Vector3(58.8, 0, 189.4)
	ib.box(still + Vector3(-0.8, 0, -0.5), still + Vector3(0.8, 0.8, 0.5), Color(0.5, 0.36, 0.22), true)
	ib.box(still + Vector3(-0.85, 0.8, -0.55), still + Vector3(0.85, 0.83, 0.55), Color(0.75, 0.2, 0.2))
	ib.box(still + Vector3(-0.15, 0.83, -0.15), still + Vector3(0.15, 1.3, 0.15), Color(0.3, 0.45, 0.7))
	for a in [Vector3(0.4, 0, 0.1), Vector3(0.52, 0, -0.12), Vector3(-0.45, 0, 0.0)]:
		ib.box(still + a + Vector3(-0.07, 0.83, -0.07), still + a + Vector3(0.07, 0.97, 0.07), Color(0.9, 0.2, 0.1) if a.x > 0.0 else Color(0.95, 0.8, 0.2))
	# Картины учеников по стенам
	var pics := [Color(0.3, 0.55, 0.85), Color(0.95, 0.75, 0.2), Color(0.35, 0.65, 0.3), Color(0.85, 0.4, 0.3)]
	for k in 4:
		var pz := ZS + 1.8 + k * 2.3
		ib.box(Vector3(64.38, 1.6, pz), Vector3(64.4, 2.5, pz + 1.2), Color(0.95, 0.95, 0.92))
		ib.box(Vector3(64.37, 1.7, pz + 0.1), Vector3(64.38, 2.4, pz + 1.1), pics[k])
	# Мольберты лицом к натюрморту (к +Z), за ними ребята
	var k := 0
	for ez in [184.2, 187.0]:
		for ex in [55.5, 58.5, 61.8]:
			var e := Vector3(ex, 0, ez)
			for s in [-0.35, 0.35]:
				ib.box(e + Vector3(s - 0.03, 0, -0.03), e + Vector3(s + 0.03, 1.7, 0.03), Color(0.55, 0.4, 0.25))
			ib.box(e + Vector3(-0.03, 0, -0.5), e + Vector3(0.03, 1.6, -0.44), Color(0.55, 0.4, 0.25))
			ib.box(e + Vector3(-0.45, 0.85, -0.05), e + Vector3(0.45, 1.6, 0.0), Color(0.97, 0.96, 0.92))
			ib.box(e + Vector3(-0.45, 0.82, -0.08), e + Vector3(0.45, 0.86, 0.05), Color(0.55, 0.4, 0.25))
			if ex == 61.8 and ez == 184.2:
				_zone("art", e + Vector3(0, 0, -1.0), Vector3(1.4, 2.0, 1.4))
			else:
				ib.box(e + Vector3(-0.3, 1.0, 0.0), e + Vector3(0.3, 1.45, 0.01), pics[k % pics.size()])
				var col := _kid_colors(k + 3)
				_person(kb, e + Vector3(0, 0, -0.9), PI, col[0], col[1], false, k % 2 == 1, 0.8)
			k += 1
	_person(tb, Vector3(62.8, 0, 188.5), PI * 0.75, Color(0.35, 0.3, 0.25), Color(0.2, 0.2, 0.2), false, false)


func _clay_room(ib: MeshBuilder, kb: MeshBuilder, tb: MeshBuilder) -> void:
	# Полки с горшками у восточной стены
	for shelf in 3:
		var y := 0.6 + shelf * 0.6
		ib.box(Vector3(X1 - T - 0.45, y, ZS + 1.5), Vector3(X1 - T, y + 0.05, Z1 - 1.5), Color(0.5, 0.36, 0.22))
		var z := ZS + 1.7
		var k := 0
		while z < Z1 - 1.8:
			var h := 0.2 + (k % 3) * 0.08
			ib.box(Vector3(X1 - T - 0.38, y + 0.05, z), Vector3(X1 - T - 0.12, y + 0.05 + h, z + 0.26), Color(0.72, 0.42, 0.28).darkened((k % 4) * 0.08))
			z += 0.55
			k += 1
	# Бюст на постаменте у двери
	var bust := Vector3(69.0, 0, ZS + 1.0)
	ib.box(bust + Vector3(-0.3, 0, -0.3), bust + Vector3(0.3, 1.1, 0.3), Color(0.8, 0.8, 0.78), true)
	ib.box(bust + Vector3(-0.25, 1.1, -0.18), bust + Vector3(0.25, 1.4, 0.18), Color(0.9, 0.9, 0.88))
	ib.box(bust + Vector3(-0.12, 1.4, -0.12), bust + Vector3(0.12, 1.72, 0.12), Color(0.9, 0.9, 0.88))
	# Гончарные круги: тумба, диск, глина; за кругами ребята
	var k := 0
	for wz in [185.0, 188.5]:
		for wx in [67.2, 70.4, 73.4]:
			var w := Vector3(wx, 0, wz)
			ib.box(w + Vector3(-0.35, 0, -0.35), w + Vector3(0.35, 0.7, 0.35), Color(0.35, 0.35, 0.37), true)
			ib.box(w + Vector3(-0.45, 0.7, -0.45), w + Vector3(0.45, 0.76, 0.45), Color(0.55, 0.55, 0.57))
			ib.box(w + Vector3(-0.18, 0.76, -0.18), w + Vector3(0.18, 1.0 + (k % 3) * 0.08, 0.18), Color(0.72, 0.42, 0.28))
			ib.box(w + Vector3(-0.2, 0, -1.05), w + Vector3(0.2, 0.44, -0.65), Color(0.5, 0.36, 0.22))
			if wx == 73.4 and wz == 185.0:
				_zone("clay", w + Vector3(0, 0, -1.0), Vector3(1.4, 2.0, 1.4))
			else:
				var col := _kid_colors(k + 5)
				_person(kb, w + Vector3(0, 0, -0.85), PI, col[0], col[1], true, k % 2 == 0, 0.8)
			k += 1
	_person(tb, Vector3(66.0, 0, 189.8), PI * 0.8, Color(0.6, 0.45, 0.35), Color(0.4, 0.3, 0.25), false, true)


## Столовая: столы с лавками, буфет с пирожками и компотом.
func _canteen(ib: MeshBuilder) -> void:
	for t in 3:
		var tz := Z0 + 2.2 + t * 2.4
		var tx := 69.0
		ib.box(Vector3(tx - 1.2, 0, tz - 0.4), Vector3(tx + 1.2, 0.75, tz + 0.4), Color(0.85, 0.85, 0.82), true)
		for s in [-0.75, 0.75]:
			ib.box(Vector3(tx - 1.2, 0, tz + s - 0.15), Vector3(tx + 1.2, 0.45, tz + s + 0.15), Color(0.5, 0.36, 0.22))
		for g in 3:
			ib.box(Vector3(tx - 0.8 + g * 0.7, 0.75, tz - 0.1), Vector3(tx - 0.65 + g * 0.7, 0.9, tz + 0.05), Color(0.8, 0.5, 0.3))
	var bar := X1 - T - 1.3
	ib.box(Vector3(bar - 0.5, 0, Z0 + 1.0), Vector3(bar + 0.5, 1.05, ZN - 1.2), Color(0.8, 0.8, 0.78), true)
	for k in 6:
		var gz := Z0 + 1.4 + k * 1.1
		ib.box(Vector3(bar - 0.3, 1.05, gz), Vector3(bar + 0.1, 1.2, gz + 0.5), [Color(0.85, 0.6, 0.3), Color(0.7, 0.35, 0.4)][k % 2])
	_person(ib, Vector3(bar + 0.85, 0, (Z0 + ZN) * 0.5), PI / 2.0, Color(0.95, 0.95, 0.95), Color(0.95, 0.95, 0.95), false, true)
	_label("БУФЕТ", Vector3(X1 - T - 0.03, 2.6, (Z0 + ZN) * 0.5), -PI / 2.0, 0.005, Color(0.2, 0.3, 0.6), 25.0)
	var zone := InteractZone.create("", Vector3(1.6, 2.0, 5.0))
	zone.position = Vector3(bar - 1.3, 0, (Z0 + ZN) * 0.5)
	zone.name = "Buffet"
	zone.prompt_fn = func() -> String:
		if not is_open():
			return "Буфет закрыт"
		return "E — пирожок и компот (%d грн)" % BUFFET_PRICE
	zone.activated.connect(buy_buffet)
	add_child(zone)


func buy_buffet() -> void:
	if not is_open():
		return
	if GameManager.spend(BUFFET_PRICE):
		NeedsManager.snacks += 1
		GameManager.notify("Пирожок с капустой и компот. Съесть — Q")


# --- Уроки --------------------------------------------------------------------

func lesson_prompt(subject: String) -> String:
	var name: String = SUBJECTS[subject]
	if lesson_time() == "":
		return "%s: уроков сейчас нет. Пн–Пт 8:00–14:00, вечерняя школа 18:00–21:00" % name
	if _today == TimeManager.day and lessons_today >= LESSONS_PER_DAY:
		return "%s: «На сегодня хватит, приходи завтра»" % TEACHERS[subject]
	var verb := "сесть за парту"
	if subject == "art":
		verb = "встать к мольберту"
	elif subject == "clay":
		verb = "сесть за гончарный круг"
	return "E — %s: %s (45 мин). %s" % [verb, name.to_lower(), progress_text()]


## Начать урок: своё задание у каждого предмета, игра на паузе.
func start_lesson(subject: String) -> void:
	if lesson_time() == "" or panel.visible:
		return
	if _today != TimeManager.day:
		_today = TimeManager.day
		lessons_today = 0
	if lessons_today >= LESSONS_PER_DAY:
		GameManager.notify("%s: «На сегодня хватит, приходи завтра»" % TEACHERS[subject])
		return
	_subject = subject
	var who: String = TEACHERS[subject]
	match subject:
		"math":
			panel.start_quiz("Математика · %s: «Решаем примеры в уме»" % who, math_items())
		"lit":
			panel.start_quiz("Литература · %s: «Проверим, кто читал»" % who, lit_items())
		"art":
			var keys := DRAW_SHAPES.keys()
			var shape: String = keys[_rng.randi() % keys.size()]
			panel.start_draw("Рисование · %s: «Нарисуй %s — веди пальцем по контуру»" % [who, DRAW_SHAPES[shape]], shape)
		"clay":
			var keys := CLAY_SHAPES.keys()
			var shape: String = keys[_rng.randi() % keys.size()]
			panel.start_clay("Лепка · %s: «Вылепи %s — веди пальцем по краю глины, повтори пунктир»" % [who, CLAY_SHAPES[shape]], shape)
	SoundLibrary.play("whistle", -12.0, 1.8)


## Четыре примера: умножение, сложение, вычитание и задачка.
func math_items() -> Array:
	var out := []
	var a := _rng.randi_range(3, 9)
	var b := _rng.randi_range(3, 9)
	out.append(_math_item("%d × %d = ?" % [a, b], a * b))
	a = _rng.randi_range(15, 79)
	b = _rng.randi_range(12, 49)
	out.append(_math_item("%d + %d = ?" % [a, b], a + b))
	a = _rng.randi_range(50, 99)
	b = _rng.randi_range(11, 45)
	out.append(_math_item("%d − %d = ?" % [a, b], a - b))
	var tasks := [
		["Буханка хлеба — %d грн. Сколько стоят %d буханки?", 12, 3],
		["В баке %d л, долили %d л. Сколько стало?", 13, 26],
		["Корова даёт %d л молока в день. Сколько за %d дня?", 12, 4],
		["Автобус везёт %d человек, вышли %d. Сколько осталось?", 38, 17],
	]
	var t: Array = tasks[_rng.randi() % tasks.size()]
	var x: int = t[1]
	var y: int = t[2]
	var ans := x * y if (t[0] as String).contains("Сколько стоят") or (t[0] as String).contains("за %d") else (x + y if (t[0] as String).contains("долили") else x - y)
	out.append(_math_item((t[0] as String) % [x, y], ans))
	return out


func _math_item(q: String, ans: int) -> Array:
	var d1 := _rng.randi_range(1, 3) * (1 if _rng.randf() < 0.5 else -1)
	var d2 := d1 + (2 if d1 > 0 else -2) * -1
	if d2 == 0:
		d2 = 5
	return [q, str(ans), str(ans + d1 * (10 if ans > 40 and _rng.randf() < 0.4 else 1)), str(ans + d2)]


## Три вопроса по литературе, без повторов, пока не пройдены все.
func lit_items() -> Array:
	var out := []
	for n in 3:
		var pool := []
		for i in LIT.size():
			if not _asked_lit.has(i):
				pool.append(i)
		if pool.is_empty():
			_asked_lit.clear()
			pool = range(LIT.size())
		var i: int = pool[_rng.randi() % pool.size()]
		_asked_lit.append(i)
		out.append(LIT[i])
	return out


func _on_done(grade: int, comment: String) -> void:
	var subject := _subject
	grades.append([subject, grade])
	lessons_today += 1
	TimeManager.advance(LESSON_MIN)
	NeedsManager.energy = maxf(NeedsManager.energy - 4.0, 0.0)
	QuestManager.event("lesson")
	var who: String = TEACHERS[subject]
	var said := {5: "Отлично, пять!", 4: "Хорошо, четыре", 3: "Тройка. Старайся", 2: "Два! Позор"}
	if grade >= 4:
		SoundLibrary.play("quest", -4.0, 1.3)
	GameManager.notify("%s: «%s» (%s). Средний балл %.1f" % [who, said[grade], comment, average()])
	_check_cert()


## Выпускной: по два урока каждого предмета и средний балл от 3,5.
func _check_cert() -> void:
	if Progress.has_doc("school_cert"):
		return
	for s in SUBJECTS:
		if count(s) < PER_SUBJECT:
			return
	if average() < 3.5:
		GameManager.notify("Директор: «Средний балл %.1f — маловато для аттестата. Подтяни до 3,5»" % average())
		return
	Progress.add_doc("school_cert")
	GameManager.money += CERT_BONUS
	QuestManager.event("school_cert")
	SoundLibrary.play("quest", 0.0, 1.0)
	GameManager.notify("Выпускной! Аттестат о среднем образовании, средний балл %.1f. Колхоз дарит %d грн" % [average(), CERT_BONUS])


## Днём в классах ребята, во время уроков — учителя.
func _process(_delta: float) -> void:
	if _kids == null:
		return
	var lt := lesson_time()
	_kids.visible = lt == "day"
	_teachers.visible = lt != ""


func save_state() -> Dictionary:
	return {"grades": grades, "today": _today, "today_n": lessons_today}


func load_state(d: Dictionary) -> void:
	grades.clear()
	for g in d.get("grades", []):
		# В старых сохранениях оценки без предмета — считаем математикой
		grades.append(g if g is Array else ["math", int(g)])
	_today = int(d.get("today", -1))
	lessons_today = int(d.get("today_n", 0))
