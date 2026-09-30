class_name School
extends Node3D
## Школа № 1 в южной части города — в неё можно зайти и учиться.
##
## Внутри на первом этаже: вестибюль с вахтёршей и доской почёта, класс с
## партами, доской и учительницей, столовая с буфетом. Уроки по будням:
## днём с ребятами (8:00–14:00), вечером — вечерняя школа (18:00–21:00).
## Урок — вопрос учителя и три ответа: верно — «пять», нет — «два».
## Десять уроков со средним баллом от 3,5 — выпускной и аттестат.

const Villagers := preload("res://scripts/world/villagers.gd")
## Корпус: x0..x1, z0..z1; вход посередине северной стены (к улице).
const X0 := 42.0
const X1 := 74.0
const Z0 := 168.0
const Z1 := 179.0
const FLOOR_H := 3.6
const FLOORS := 3
const T := 0.3
const DOOR_X := 58.0
## Перегородки: класс — западнее, столовая — восточнее вестибюля.
const CLASS_WALL_X := 52.0
const CANTEEN_WALL_X := 64.0
const LESSON_MIN := 45.0
const LESSONS_PER_DAY := 4
const LESSONS_FOR_CERT := 10
const CERT_BONUS := 250
const BUFFET_PRICE := 25

## Вопросы: [предмет, вопрос, верный ответ, неверный, неверный].
const QUESTIONS := [
	["Математика", "Сколько будет 7 × 8?", "56", "54", "63"],
	["Математика", "Бак «Жигулей» — 39 литров, в нём 13. Сколько долить до полного?", "26", "24", "52"],
	["Математика", "Электричка едет 80 км/ч. Сколько проедет за 45 минут?", "60 км", "45 км", "80 км"],
	["Математика", "Буханка хлеба — 12 грн. Сколько стоят пять буханок?", "60 грн", "50 грн", "72 грн"],
	["Математика", "Чему равен корень из 144?", "12", "14", "72"],
	["География", "Как называется река у Каменки?", "Быстрая", "Волга", "Каменка"],
	["География", "С какой стороны восходит солнце?", "На востоке", "На западе", "На севере"],
	["География", "Самое глубокое озеро в мире?", "Байкал", "Ладожское", "Каспийское"],
	["География", "Столица Украины?", "Киев", "Харьков", "Одесса"],
	["География", "Какое село района дальше всех на севере?", "Горки", "Лужки", "Малиновка"],
	["Физика", "Почему зимой скользко на льду?", "Мало трение", "Лёд тяжёлый", "Сильный ветер"],
	["Физика", "В чём измеряют силу тока?", "В амперах", "В вольтах", "В ваттах"],
	["Физика", "Вода кипит при нормальном давлении при…", "100 °C", "90 °C", "120 °C"],
	["История", "В каком году Гагарин полетел в космос?", "1961", "1957", "1969"],
	["История", "Кто написал «Кобзарь»?", "Шевченко", "Пушкин", "Франко"],
	["История", "В каком году закончилась Великая Отечественная война?", "1945", "1941", "1944"],
	["Русский язык", "Как правильно?", "Жи-ши пиши с И", "Жи-ши пиши с Ы", "Как слышится"],
	["Русский язык", "Какое слово — глагол?", "Ехать", "Дорога", "Быстрый"],
	["Русский язык", "Сколько гласных в слове «машина»?", "Три", "Две", "Четыре"],
	["Биология", "Что даёт корова?", "Молоко", "Мёд", "Шерсть"],
	["Биология", "Сколько ног у паука?", "Восемь", "Шесть", "Десять"],
	["Биология", "Какое дерево в лесу с белой корой?", "Берёза", "Ель", "Дуб"],
	["ПДД", "На какой свет светофора можно ехать?", "На зелёный", "На жёлтый", "На красный"],
	["ПДД", "Что означает знак «Андреевский крест»?", "Переезд без шлагбаума", "Кладбище", "Тупик"],
	["ПДД", "Шлагбаум на переезде опускается. Что делать?", "Остановиться и ждать", "Проскочить", "Объехать"],
	["ПДД", "Кому уступают у пешеходного перехода?", "Пешеходам", "Автобусам", "Никому"],
]
const TEACHER_LINES := ["Садись, отвечай", "Тишина в классе! Вопрос", "Не списывай. Слушай внимательно", "Открываем тетради"]

var lessons := 0
var grades: Array = []
var lessons_today := 0
var _today := -1
var _asked: Array = []
## Текущий урок: [предмет, вопрос, верный, …] и порядок ответов.
var _q: Array = []
var _answers: Array = []
var _panel: CanvasLayer
var _title: Label
var _question: Label
var _buttons: Array[Button] = []
var _kids: Array[MeshInstance3D] = []
var _teacher: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("persist")
	_rng.randomize()
	_build()
	_build_panel()


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


## Школа открыта: будни с 7:30 до 21:00.
static func is_open() -> bool:
	var wd := TimeManager.weekday()
	var h := TimeManager.hour()
	return wd != "сб" and wd != "вс" and h >= 7.5 and h < 21.0


func average() -> float:
	if grades.is_empty():
		return 0.0
	var s := 0.0
	for g in grades:
		s += float(g)
	return s / grades.size()


# --- Здание -------------------------------------------------------------------

func _build() -> void:
	var b := MeshBuilder.new()
	var glow := MeshBuilder.new()
	glow.ground_shade = false
	var wall := Color(0.85, 0.72, 0.62)
	var green := Color(0.45, 0.62, 0.52)
	var white := Color(0.93, 0.93, 0.88)
	var top := FLOOR_H * FLOORS
	# Наружные стены первого этажа с проёмом двери, над ними — этажи целиком
	b.box(Vector3(X0, 0, Z0), Vector3(DOOR_X - 1.1, FLOOR_H, Z0 + T), wall, true)
	b.box(Vector3(DOOR_X + 1.1, 0, Z0), Vector3(X1, FLOOR_H, Z0 + T), wall, true)
	b.box(Vector3(DOOR_X - 1.1, 2.5, Z0), Vector3(DOOR_X + 1.1, FLOOR_H, Z0 + T), wall)
	b.box(Vector3(X0, 0, Z1 - T), Vector3(X1, FLOOR_H, Z1), wall, true)
	b.box(Vector3(X0, 0, Z0), Vector3(X0 + T, FLOOR_H, Z1), wall, true)
	b.box(Vector3(X1 - T, 0, Z0), Vector3(X1, FLOOR_H, Z1), wall, true)
	b.box(Vector3(X0, FLOOR_H, Z0), Vector3(X1, top, Z1), wall, true)
	b.box(Vector3(X0 - 0.2, top, Z0 - 0.2), Vector3(X1 + 0.2, top + 0.4, Z1 + 0.2), Color(0.45, 0.45, 0.47))
	# Внутри: пол из крашеных досок, потолок, стены — зелёная панель и побелка
	b.box(Vector3(X0 + T, 0, Z0 + T), Vector3(X1 - T, 0.04, Z1 - T), Color(0.5, 0.32, 0.2))
	var x := X0 + T
	while x < X1 - T:
		b.box(Vector3(x, 0.04, Z0 + T), Vector3(x + 0.03, 0.045, Z1 - T), Color(0.4, 0.26, 0.16))
		x += 0.6
	b.box(Vector3(X0 + T, FLOOR_H - 0.05, Z0 + T), Vector3(X1 - T, FLOOR_H - 0.02, Z1 - T), white)
	for side in [[Vector3(X0 + T, 0, Z0 + T), Vector3(X1 - T, 0, Z0 + T + 0.01)], [Vector3(X0 + T, 0, Z1 - T - 0.01), Vector3(X1 - T, 0, Z1 - T)],
			[Vector3(X0 + T, 0, Z0 + T), Vector3(X0 + T + 0.01, 0, Z1 - T)], [Vector3(X1 - T - 0.01, 0, Z0 + T), Vector3(X1 - T, 0, Z1 - T)]]:
		var a: Vector3 = side[0]
		var e: Vector3 = side[1]
		b.box(a + Vector3(0, 0.04, 0), e + Vector3(0, 1.5, 0), green)
		b.box(a + Vector3(0, 1.5, 0), e + Vector3(0, FLOOR_H - 0.05, 0), white)
	# Перегородки с дверными проёмами у входа
	for wx in [CLASS_WALL_X, CANTEEN_WALL_X]:
		b.box(Vector3(wx - 0.1, 0, Z0 + T), Vector3(wx + 0.1, FLOOR_H, Z0 + 1.0), white, true)
		b.box(Vector3(wx - 0.1, 0, Z0 + 2.4), Vector3(wx + 0.1, FLOOR_H, Z1 - T), white, true)
		b.box(Vector3(wx - 0.1, 2.5, Z0 + 1.0), Vector3(wx + 0.1, FLOOR_H, Z0 + 2.4), white)
		for s in [-0.12, 0.1]:
			b.box(Vector3(wx + s, 0.04, Z0 + 2.4), Vector3(wx + s + 0.02, 1.5, Z1 - T), green)
	# Окна: снаружи на всех этажах, на первом — и изнутри
	for f in FLOORS:
		var y := 1.0 + f * FLOOR_H
		x = X0 + 1.2
		while x < X1 - 1.5:
			var door := f == 0 and absf(x + 0.9 - DOOR_X) < 2.2
			if not door:
				for zf in [Z0 - 0.03, Z1 - 0.01]:
					b.box(Vector3(x, y, zf), Vector3(x + 1.8, y + 1.7, zf + 0.04), Color(0.9, 0.9, 0.88))
					glow.box(Vector3(x + 0.1, y + 0.1, zf - 0.01), Vector3(x + 1.7, y + 1.6, zf + 0.05), Color(0.9, 0.9, 0.8))
				if f == 0:
					for zf in [Z0 + T + 0.01, Z1 - T - 0.03]:
						b.box(Vector3(x, y, zf), Vector3(x + 1.8, y + 1.7, zf + 0.02), Color(0.92, 0.92, 0.9))
						b.box(Vector3(x + 0.1, y + 0.1, zf - 0.005), Vector3(x + 1.7, y + 1.6, zf + 0.025), Color(0.62, 0.78, 0.9))
			x += 2.6
	# Крыльцо, козырёк, дверь-рама, вывеска
	b.box(Vector3(DOOR_X - 2.5, 0, Z0 - 2.0), Vector3(DOOR_X + 2.5, 0.12, Z0), Color(0.6, 0.6, 0.58))
	b.box(Vector3(DOOR_X - 2.5, 3.0, Z0 - 2.0), Vector3(DOOR_X + 2.5, 3.2, Z0), Color(0.45, 0.45, 0.47))
	for s in [-1.2, 1.1]:
		b.box(Vector3(DOOR_X + s, 0, Z0 - 0.06), Vector3(DOOR_X + s + 0.1, 2.5, Z0 + T + 0.02), Color(0.4, 0.3, 0.22))
	_label("ШКОЛА № 1", Vector3(DOOR_X, 3.6, Z0 - 0.06), PI, 0.01, Color(1, 1, 1))
	_label("Уроки: пн–пт 8:00–14:00\nВечерняя школа 18:00–21:00", Vector3(DOOR_X + 1.9, 1.8, Z0 - 0.07), PI, 0.0035, Color(1, 1, 0.9))
	b.box(Vector3(DOOR_X + 1.3, 1.45, Z0 - 0.06), Vector3(DOOR_X + 2.5, 2.15, Z0 - 0.02), Color(0.15, 0.3, 0.55))
	_hall(b)
	_classroom(b)
	_canteen(b)
	var mi := b.build_mesh()
	mi.name = "SchoolMesh"
	add_child(mi)
	var body := b.build_body()
	body.name = "SchoolCollision"
	add_child(body)
	# Свет внутри первого этажа — только когда игрок рядом
	for lx in [(X0 + CLASS_WALL_X) * 0.5, DOOR_X, (CANTEEN_WALL_X + X1) * 0.5]:
		var l := OmniLight3D.new()
		l.position = Vector3(lx, FLOOR_H - 0.6, (Z0 + Z1) * 0.5)
		l.omni_range = 8.0
		l.light_energy = 0.8
		l.light_color = Color(1.0, 0.95, 0.85)
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 30.0
		l.distance_fade_length = 10.0
		l.name = "Lamp"
		add_child(l)
		glow.box(l.position + Vector3(-0.6, 0.45, -0.15), l.position + Vector3(0.6, 0.55, 0.15), Color(1, 1, 0.95))
	var gm := glow.build_mesh(true)
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gm)


func _label(text: String, p: Vector3, yaw: float, px: float, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = px
	l.outline_size = 0
	l.modulate = col
	l.position = p
	l.rotation.y = yaw
	l.visibility_range_end = 120.0
	add_child(l)
	return l


func _person(p: Vector3, yaw: float, shirt: Color, hat: Color, sit: bool, woman: bool, scale := 1.0) -> MeshInstance3D:
	var pb := MeshBuilder.new()
	pb.ground_shade = false
	Villagers.person_model(pb, shirt, hat, sit, woman)
	var mi := pb.build_mesh()
	mi.position = p
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * scale
	mi.visibility_range_end = 60.0
	add_child(mi)
	return mi


## Вестибюль: вахтёрша за столом, вешалка, доска почёта, расписание.
func _hall(b: MeshBuilder) -> void:
	var desk := Vector3(DOOR_X + 3.4, 0, Z0 + 3.0)
	b.box(desk + Vector3(-0.8, 0, -0.4), desk + Vector3(0.8, 0.8, 0.4), Color(0.45, 0.3, 0.2), true)
	b.box(desk + Vector3(-0.85, 0.8, -0.45), desk + Vector3(0.85, 0.84, 0.45), Color(0.55, 0.38, 0.25))
	b.box(desk + Vector3(-0.2, 0.84, -0.2), desk + Vector3(0.2, 0.92, 0.2), Color(0.1, 0.1, 0.1))
	_person(desk + Vector3(0, 0, 0.95), 0.0, Color(0.35, 0.3, 0.45), Color(0.55, 0.5, 0.45), true, true)
	b.box(desk + Vector3(-0.3, 0.4, 0.7), desk + Vector3(0.3, 0.46, 1.2), Color(0.4, 0.3, 0.2))
	# Вешалка у западной перегородки
	b.box(Vector3(CLASS_WALL_X + 0.12, 1.6, Z0 + 3.5), Vector3(CLASS_WALL_X + 0.22, 1.7, Z0 + 8.0), Color(0.4, 0.3, 0.2))
	for k in 6:
		var cz := Z0 + 3.8 + k * 0.75
		b.box(Vector3(CLASS_WALL_X + 0.2, 0.9, cz - 0.22), Vector3(CLASS_WALL_X + 0.4, 1.65, cz + 0.22), [Color(0.3, 0.3, 0.45), Color(0.5, 0.25, 0.2), Color(0.3, 0.4, 0.3)][k % 3])
	# Доска почёта напротив входа и расписание
	var back := Z1 - T - 0.02
	b.box(Vector3(DOOR_X - 2.0, 1.2, back - 0.04), Vector3(DOOR_X + 2.0, 2.8, back), Color(0.6, 0.15, 0.12))
	for k in 6:
		var px := DOOR_X - 1.6 + (k % 3) * 1.1
		var py := 1.4 + (k / 3) * 0.7
		b.box(Vector3(px, py, back - 0.06), Vector3(px + 0.8, py + 0.55, back - 0.04), Color(0.9, 0.88, 0.8))
	_label("ДОСКА ПОЧЁТА", Vector3(DOOR_X, 2.95, back - 0.05), 0.0, 0.0035, Color(0.1, 0.1, 0.1)).rotation.y = PI
	b.box(Vector3(DOOR_X - 5.0 + 0.8, 1.2, back - 0.03), Vector3(DOOR_X - 2.8, 2.6, back), Color(0.95, 0.95, 0.9))
	_label("РАСПИСАНИЕ\nматематика\nгеография\nфизика\nистория\nрусский\nбиология\nПДД", Vector3(DOOR_X - 3.5, 1.95, back - 0.04), PI, 0.0022, Color(0.1, 0.1, 0.15))


## Класс: доска у западной стены, стол учительницы, три ряда парт.
## Одна парта — для игрока (зона урока).
func _classroom(b: MeshBuilder) -> void:
	var bx := X0 + T + 0.02
	var cz := (Z0 + Z1) * 0.5
	b.box(Vector3(bx, 0.9, cz - 2.5), Vector3(bx + 0.05, 2.3, cz + 2.5), Color(0.12, 0.25, 0.18))
	b.box(Vector3(bx, 0.85, cz - 2.6), Vector3(bx + 0.12, 0.9, cz + 2.6), Color(0.5, 0.35, 0.22))
	_label("Классная работа", Vector3(bx + 0.06, 2.0, cz), PI / 2.0, 0.003, Color(0.95, 0.95, 0.95))
	_label("2 × 2 = 4", Vector3(bx + 0.06, 1.5, cz - 1.2), PI / 2.0, 0.003, Color(0.95, 0.95, 0.95))
	# Портреты над доской
	for k in 3:
		var pz := cz - 3.5 + k * 3.5
		b.box(Vector3(bx, 2.5, pz - 0.35), Vector3(bx + 0.04, 3.2, pz + 0.35), Color(0.45, 0.32, 0.2))
		b.box(Vector3(bx + 0.04, 2.58, pz - 0.27), Vector3(bx + 0.05, 3.12, pz + 0.27), Color(0.8, 0.75, 0.65))
	# Стол учительницы и сама учительница
	var td := Vector3(X0 + 2.2, 0, cz + 2.8)
	b.box(td + Vector3(-0.4, 0, -0.7), td + Vector3(0.4, 0.78, 0.7), Color(0.45, 0.3, 0.2), true)
	b.box(td + Vector3(-0.2, 0.78, -0.3), td + Vector3(0.1, 0.84, 0.1), Color(0.8, 0.2, 0.15))
	_teacher = _person(Vector3(X0 + 1.3, 0, cz - 0.5), -PI / 2.0, Color(0.55, 0.3, 0.4), Color(0.5, 0.4, 0.3), false, true)
	# Парты: ряды вдоль класса, лицом к доске (к −X)
	var k := 0
	for col in 3:
		var dz := Z0 + 2.3 + col * 3.0
		for row in 3:
			var dx := X0 + 4.0 + row * 1.9
			b.box(Vector3(dx - 0.3, 0, dz - 0.7), Vector3(dx + 0.3, 0.72, dz + 0.7), Color(0.35, 0.5, 0.4), true)
			b.box(Vector3(dx - 0.35, 0.72, dz - 0.75), Vector3(dx + 0.35, 0.76, dz + 0.75), Color(0.6, 0.45, 0.3))
			for s in [-0.35, 0.35]:
				b.box(Vector3(dx + 0.45, 0, dz + s - 0.2), Vector3(dx + 0.85, 0.44, dz + s + 0.2), Color(0.5, 0.36, 0.22))
			var mine := col == 1 and row == 2
			if mine:
				var zone := InteractZone.create("", Vector3(1.4, 2.0, 2.0))
				zone.position = Vector3(dx + 0.8, 0, dz)
				zone.name = "Desk"
				zone.prompt_fn = lesson_prompt
				zone.activated.connect(start_lesson)
				add_child(zone)
			else:
				for s in [-0.35, 0.35]:
					if (k + int(s * 10.0)) % 3 == 0:
						continue
					var kid := _person(Vector3(dx + 0.65, 0, dz + s), PI / 2.0, [Color(0.9, 0.9, 0.9), Color(0.25, 0.3, 0.5), Color(0.6, 0.2, 0.2)][k % 3],
						Color(0.3, 0.2, 0.15), true, (k + int(s * 10.0)) % 2 == 0, 0.78)
					_kids.append(kid)
			k += 1


## Столовая: столы с лавками, буфет с пирожками и компотом.
func _canteen(b: MeshBuilder) -> void:
	for t in 3:
		var tz := Z0 + 3.0 + t * 2.6
		var tx := CANTEEN_WALL_X + 3.0
		b.box(Vector3(tx - 1.2, 0, tz - 0.4), Vector3(tx + 1.2, 0.75, tz + 0.4), Color(0.85, 0.85, 0.82), true)
		for s in [-0.75, 0.75]:
			b.box(Vector3(tx - 1.2, 0, tz + s - 0.15), Vector3(tx + 1.2, 0.45, tz + s + 0.15), Color(0.5, 0.36, 0.22))
		for g in 3:
			b.box(Vector3(tx - 0.8 + g * 0.7, 0.75, tz - 0.1), Vector3(tx - 0.65 + g * 0.7, 0.9, tz + 0.05), Color(0.8, 0.5, 0.3))
	var bar := X1 - T - 1.0
	b.box(Vector3(bar - 0.5, 0, Z0 + 2.5), Vector3(bar + 0.5, 1.05, Z1 - 1.5), Color(0.8, 0.8, 0.78), true)
	for k in 6:
		var gz := Z0 + 3.0 + k * 1.0
		b.box(Vector3(bar - 0.3, 1.05, gz), Vector3(bar + 0.1, 1.2, gz + 0.5), [Color(0.85, 0.6, 0.3), Color(0.7, 0.35, 0.4)][k % 2])
	_person(Vector3(bar + 0.8, 0, (Z0 + Z1) * 0.5), PI / 2.0, Color(0.95, 0.95, 0.95), Color(0.95, 0.95, 0.95), false, true)
	_label("БУФЕТ", Vector3(X1 - T - 0.03, 2.6, (Z0 + Z1) * 0.5), -PI / 2.0, 0.005, Color(0.2, 0.3, 0.6))
	var zone := InteractZone.create("", Vector3(1.6, 2.0, 5.0))
	zone.position = Vector3(bar - 1.3, 0, (Z0 + Z1) * 0.5)
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

func lesson_prompt() -> String:
	if lesson_time() == "":
		return "Уроков сейчас нет. Пн–Пт 8:00–14:00, вечерняя школа 18:00–21:00"
	if _today == TimeManager.day and lessons_today >= LESSONS_PER_DAY:
		return "Учительница: «На сегодня хватит, приходи завтра»"
	if Progress.has_doc("school_cert"):
		return "E — урок (45 мин). Аттестат уже есть — учись для себя"
	return "E — сесть за парту: урок (45 мин). Уроков: %d из %d" % [lessons, LESSONS_FOR_CERT]


## Начать урок: вопрос учителя на экране, игра на паузе, пока не ответишь.
func start_lesson() -> void:
	if lesson_time() == "" or _panel.visible:
		return
	if _today != TimeManager.day:
		_today = TimeManager.day
		lessons_today = 0
	if lessons_today >= LESSONS_PER_DAY:
		GameManager.notify("Учительница: «На сегодня хватит, приходи завтра»")
		return
	var pool: Array = []
	for i in QUESTIONS.size():
		if not _asked.has(i):
			pool.append(i)
	if pool.is_empty():
		_asked.clear()
		pool = range(QUESTIONS.size())
	var qi: int = pool[_rng.randi() % pool.size()]
	_asked.append(qi)
	_q = QUESTIONS[qi]
	_answers = [_q[2], _q[3], _q[4]]
	_answers.shuffle()
	_title.text = "%s · %s" % [_q[0], TEACHER_LINES[_rng.randi() % TEACHER_LINES.size()]]
	_question.text = _q[1]
	for i in 3:
		_buttons[i].text = "%d) %s" % [i + 1, _answers[i]]
	_panel.visible = true
	_buttons[0].grab_focus()
	get_tree().paused = true
	SoundLibrary.play("whistle", -12.0, 1.8)


## Ответ на вопрос урока (номер кнопки 0–2).
func answer(i: int) -> void:
	if not _panel.visible:
		return
	_panel.visible = false
	get_tree().paused = false
	var right: bool = _answers[i] == _q[2]
	var grade := 5 if right else 2
	grades.append(grade)
	lessons += 1
	lessons_today += 1
	TimeManager.advance(LESSON_MIN)
	NeedsManager.energy = maxf(NeedsManager.energy - 4.0, 0.0)
	QuestManager.event("lesson")
	if right:
		SoundLibrary.play("quest", -4.0, 1.3)
		GameManager.notify("%s: «Молодец, пять!» Средний балл %.1f" % [_q[0], average()])
	else:
		GameManager.notify("%s: «Два! Правильно — %s». Средний балл %.1f" % [_q[0], _q[2], average()])
	_check_cert()


## Выпускной: десять уроков и средний балл от 3,5 — аттестат и премия.
func _check_cert() -> void:
	if Progress.has_doc("school_cert") or lessons < LESSONS_FOR_CERT:
		return
	if average() < 3.5:
		GameManager.notify("Директор: «Средний балл %.1f — маловато. Подтяни оценки до 3,5»" % average())
		return
	Progress.add_doc("school_cert")
	GameManager.money += CERT_BONUS
	QuestManager.event("school_cert")
	SoundLibrary.play("quest", 0.0, 1.0)
	GameManager.notify("Выпускной! Аттестат о среднем образовании, средний балл %.1f. Колхоз дарит %d грн" % [average(), CERT_BONUS])


func _build_panel() -> void:
	_panel = CanvasLayer.new()
	_panel.layer = 20
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	add_child(_panel)
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_CENTER)
	bg.custom_minimum_size = Vector2(560, 0)
	bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.22, 0.16, 0.96)
	sb.border_color = Color(0.5, 0.35, 0.22)
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(18)
	bg.add_theme_stylebox_override("panel", sb)
	_panel.add_child(bg)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	bg.add_child(box)
	_title = Label.new()
	_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	_title.add_theme_font_size_override("font_size", 18)
	box.add_child(_title)
	_question = Label.new()
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question.custom_minimum_size = Vector2(520, 0)
	_question.add_theme_font_size_override("font_size", 24)
	_question.add_theme_color_override("font_color", Color(0.97, 0.97, 0.95))
	box.add_child(_question)
	for i in 3:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 52)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(answer.bind(i))
		box.add_child(btn)
		_buttons.append(btn)


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		match k.physical_keycode:
			KEY_1, KEY_KP_1:
				answer(0)
			KEY_2, KEY_KP_2:
				answer(1)
			KEY_3, KEY_KP_3:
				answer(2)
		get_viewport().set_input_as_handled()


## Днём в классе сидят ребята, учительница у доски; вечером — пусто,
## одна учительница вечерней школы.
func _process(_delta: float) -> void:
	var day := lesson_time() == "day"
	for kid in _kids:
		kid.visible = day
	_teacher.visible = lesson_time() != ""


func save_state() -> Dictionary:
	return {"lessons": lessons, "grades": grades, "today": _today, "today_n": lessons_today}


func load_state(d: Dictionary) -> void:
	lessons = int(d.get("lessons", 0))
	grades = (d.get("grades", []) as Array).duplicate()
	_today = int(d.get("today", -1))
	lessons_today = int(d.get("today_n", 0))
