class_name Civic
extends Node3D
## Сельсовет в Каменке и районная больница в городе — здесь делают документы.
##
## Сельсовет: паспорт (фото, анкета, пара часов), справка о прописке,
## трудовая книжка. Больница: медкомиссия для водителей (нужен паспорт) —
## без неё в автошколе экзамен не принимают; процедуры, если совсем без сил.

const Villagers := preload("res://scripts/world/villagers.gd")
## Сельсовет — на краю села у колхозного сарая, входом к улице
const COUNCIL := Vector3(-55.5, 0, -52.0)
## Больница — в городе у гаражей, входом к дороге (к +Z)
const HOSPITAL := Vector3(170.0, 0, 37.0)

## [id, что просит, цена, минут, нужен ли паспорт]
const COUNCIL_DOCS := [
	["passport", "паспорт: фото и анкета", 100, 120, false],
	["propiska", "справку о прописке", 20, 20, true],
	["work_book", "трудовую книжку", 30, 30, true],
]
const MED_PRICE := 150
const CURE_PRICE := 100


func _ready() -> void:
	_build_council()
	_build_hospital()


## Открыто ли учреждение: будни и суббота с 8 до 17.
static func office_open() -> bool:
	var h := TimeManager.hour()
	return h >= 8.0 and h < 17.0 and TimeManager.weekday() != "вс"


func _house(b: MeshBuilder, c: Vector3, size: Vector3, wall: Color, roof: Color, trim: Color) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	b.box(c + Vector3(-hx - 0.2, 0, -hz - 0.2), c + Vector3(hx + 0.2, 0.4, hz + 0.2), Color(0.5, 0.5, 0.48), true)
	b.box(c + Vector3(-hx, 0.4, -hz), c + Vector3(hx, size.y, hz), wall, true)
	b.box(c + Vector3(-hx - 0.01, size.y - 0.4, -hz - 0.01), c + Vector3(hx + 0.01, size.y - 0.15, hz + 0.01), trim)
	b.box(c + Vector3(-hx - 0.4, size.y, -hz - 0.4), c + Vector3(hx + 0.4, size.y + 0.25, hz + 0.4), roof)
	# Окна по фасаду, дверь посередине, крыльцо с навесом
	var x := -hx + 1.3
	while x < hx - 1.0:
		if absf(x) > 1.3:
			b.box(c + Vector3(x - 0.55, 1.2, hz), c + Vector3(x + 0.55, 2.5, hz + 0.05), Color(0.92, 0.92, 0.9))
			b.box(c + Vector3(x - 0.45, 1.3, hz + 0.05), c + Vector3(x + 0.45, 2.4, hz + 0.07), Color(0.32, 0.42, 0.5))
		x += 2.2
	b.box(c + Vector3(-0.7, 0.4, hz), c + Vector3(0.7, 2.6, hz + 0.06), Color(0.4, 0.28, 0.2))
	b.box(c + Vector3(-1.6, 0, hz), c + Vector3(1.6, 0.4, hz + 1.6), Color(0.6, 0.6, 0.58), true)
	b.box(c + Vector3(-1.7, 2.9, hz), c + Vector3(1.7, 3.05, hz + 1.7), roof)
	for sx in [-1.5, 1.4]:
		b.box(c + Vector3(sx, 0.4, hz + 1.4), c + Vector3(sx + 0.1, 2.9, hz + 1.5), Color(0.85, 0.85, 0.82))


func _label(text: String, pos: Vector3, px: float, col: Color, outline := Color(0, 0, 0, 0)) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = px
	l.outline_size = 10 if outline.a > 0.0 else 0
	l.outline_modulate = outline
	l.modulate = col
	l.position = pos
	add_child(l)


func _person(pos: Vector3, yaw: float, shirt: Color, woman: bool) -> void:
	var pb := MeshBuilder.new()
	pb.ground_shade = false
	Villagers.person_model(pb, shirt, Color(0.3, 0.25, 0.2), false, woman)
	var mi := pb.build_mesh()
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)


# --- Сельсовет ----------------------------------------------------------------

func _build_council() -> void:
	var c := COUNCIL
	var b := MeshBuilder.new()
	_house(b, c, Vector3(10.0, 3.6, 7.0), Color(0.93, 0.9, 0.8), Color(0.4, 0.42, 0.45), Color(0.55, 0.2, 0.18))
	# Доска объявлений и лавочка у входа, флагшток
	b.box(c + Vector3(2.6, 0, 5.2), c + Vector3(2.7, 1.9, 5.3), Color(0.35, 0.3, 0.25))
	b.box(c + Vector3(3.6, 0, 5.2), c + Vector3(3.7, 1.9, 5.3), Color(0.35, 0.3, 0.25))
	b.box(c + Vector3(2.5, 1.0, 5.3), c + Vector3(3.8, 1.9, 5.36), Color(0.5, 0.38, 0.26))
	for i in 4:
		b.box(c + Vector3(2.6 + (i % 2) * 0.6, 1.1 + (i / 2) * 0.4, 5.36), c + Vector3(3.1 + (i % 2) * 0.6, 1.45 + (i / 2) * 0.4, 5.38), Color(0.95, 0.95, 0.9))
	b.box(c + Vector3(-3.4, 0.42, 5.0), c + Vector3(-2.0, 0.48, 5.4), Color(0.5, 0.36, 0.22), true)
	add_child(b.build_mesh())
	add_child(b.build_body())
	_label("СЕЛЬСОВЕТ", c + Vector3(0, 3.28, 3.52), 0.006, Color(1, 1, 0.92))
	_label("Паспорт · прописка · трудовая\nПн–Сб 8:00–17:00", c + Vector3(3.15, 1.95, 5.4), 0.0016, Color(0.1, 0.1, 0.12))
	_person(c + Vector3(1.8, 0.4, 4.6), 0.0, Color(0.5, 0.3, 0.45), true)
	var desk := InteractZone.create("", Vector3(3.4, 2.2, 2.4))
	desk.position = c + Vector3(0, 0, 5.2)
	desk.prompt_fn = _council_prompt
	desk.activated.connect(_council)
	add_child(desk)


## Что сейчас можно сделать в сельсовете: первый документ, которого нет.
func _council_next() -> Array:
	for d in COUNCIL_DOCS:
		if not Progress.has_doc(d[0]):
			return d
	return []


func _council_prompt() -> String:
	if not office_open():
		return "Сельсовет закрыт. Пн–Сб с 8:00 до 17:00"
	var d := _council_next()
	if d.is_empty():
		return "Секретарь: «Все документы у тебя есть. Паспорт, прописка, трудовая — в порядке»"
	return "E — оформить %s (%d грн, %d мин)" % [d[1], d[2], d[3]]


func _council() -> void:
	if not office_open():
		return
	var d := _council_next()
	if d.is_empty() or not GameManager.spend(int(d[2])):
		return
	TimeManager.advance(float(d[3]))
	Progress.add_doc(d[0])
	SoundLibrary.play("quest", -2.0, 1.1)
	QuestManager.event("document")
	var tips := {
		"passport": "Паспорт готов! С ним — в больницу на медкомиссию, потом в автошколу",
		"propiska": "Справка о прописке: теперь ты официально житель Каменки",
		"work_book": "Трудовая книжка: с категорией D возьмут водителем автобуса",
	}
	GameManager.notify(tips[d[0]])


# --- Больница -----------------------------------------------------------------

func _build_hospital() -> void:
	var c := HOSPITAL
	var b := MeshBuilder.new()
	_house(b, c, Vector3(18.0, 6.8, 10.0), Color(0.95, 0.95, 0.93), Color(0.45, 0.47, 0.5), Color(0.2, 0.55, 0.55))
	# Второй этаж окнами, красный крест над входом
	var x := -7.7
	while x < 8.0:
		b.box(c + Vector3(x - 0.55, 4.2, 5.0), c + Vector3(x + 0.55, 5.5, 5.05), Color(0.92, 0.92, 0.9))
		b.box(c + Vector3(x - 0.45, 4.3, 5.05), c + Vector3(x + 0.45, 5.4, 5.07), Color(0.32, 0.42, 0.5))
		x += 2.2
	b.box(c + Vector3(-0.9, 3.4, 5.05), c + Vector3(0.9, 3.95, 5.1), Color(0.85, 0.12, 0.12))
	b.box(c + Vector3(-0.27, 3.1, 5.05), c + Vector3(0.27, 4.25, 5.1), Color(0.85, 0.12, 0.12))
	b.box(c + Vector3(-9.5, 0, 5.2), c + Vector3(9.5, 0.04, 12.0), Color(0.42, 0.42, 0.43))
	add_child(b.build_mesh())
	add_child(b.build_body())
	_label("БОЛЬНИЦА", c + Vector3(0, 6.45, 5.12), 0.008, Color(0.1, 0.35, 0.4))
	_label("Медкомиссия водителей · процедуры\nЕжедневно 8:00–17:00", c + Vector3(3.0, 2.3, 5.1), 0.002, Color(0.1, 0.1, 0.12))
	_person(c + Vector3(-1.8, 0.4, 6.1), 0.0, Color(0.95, 0.95, 0.95), true)
	# «Скорая»: белые Жигули с красной полосой и мигалкой
	var amb := Police.car(self, c + Vector3(6.5, 0.05, 9.0), PI / 2.0)
	(amb[1] as StandardMaterial3D).albedo_color = Color(0.1, 0.3, 1.0)
	var l := Label3D.new()
	l.text = "СКОРАЯ"
	l.font_size = 64
	l.pixel_size = 0.004
	l.modulate = Color(0.85, 0.1, 0.1)
	l.position = c + Vector3(6.5, 1.46, 9.0)
	l.rotation = Vector3(-PI / 2.0, PI / 2.0, 0)
	add_child(l)
	var med := InteractZone.create("", Vector3(2.4, 2.2, 2.4))
	med.position = c + Vector3(-1.2, 0, 6.2)
	med.prompt_fn = _med_prompt
	med.activated.connect(_med)
	add_child(med)
	var cure := InteractZone.create("", Vector3(2.4, 2.2, 2.4))
	cure.position = c + Vector3(1.8, 0, 6.2)
	cure.prompt_fn = func() -> String:
		var h := TimeManager.hour()
		if h < 8.0 or h >= 17.0:
			return ""
		return "E — процедуры и витамины: силы +40 (%d грн, 1 час)" % CURE_PRICE
	cure.activated.connect(_cure)
	add_child(cure)


func _med_prompt() -> String:
	var h := TimeManager.hour()
	if h < 8.0 or h >= 17.0:
		return "Больница: приём с 8:00 до 17:00"
	if Progress.has_doc("med"):
		return "Врач: «Медсправка у тебя есть — годен к вождению»"
	if not Progress.has_doc("passport"):
		return "Регистратура: «Без паспорта не записываем — паспорт в сельсовете»"
	return "E — медкомиссия для водителей (%d грн, 2 часа)" % MED_PRICE


func _med() -> void:
	var h := TimeManager.hour()
	if h < 8.0 or h >= 17.0 or Progress.has_doc("med") or not Progress.has_doc("passport"):
		return
	if not GameManager.spend(MED_PRICE):
		return
	TimeManager.advance(120.0)
	Progress.add_doc("med")
	QuestManager.event("med_ok")
	SoundLibrary.play("quest", -2.0, 1.1)
	QuestManager.event("document")
	GameManager.notify("Окулист, терапевт, хирург — годен! Медсправка есть: теперь в автошколу на любую категорию")


func _cure() -> void:
	var h := TimeManager.hour()
	if h < 8.0 or h >= 17.0 or not GameManager.spend(CURE_PRICE):
		return
	TimeManager.advance(60.0)
	NeedsManager.rest(40.0)
	SoundLibrary.play("click", -4.0)
	GameManager.notify("Медсестра поставила капельницу с витаминами — полегчало, силы +40")
