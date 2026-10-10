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


## hollow — внутрь можно войти (WalkIn): дверь открыта, пол на цоколе.
func _house(b: MeshBuilder, c: Vector3, size: Vector3, wall: Color, roof: Color, trim: Color, hollow := false, lit: MeshBuilder = null) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	b.box(c + Vector3(-hx - 0.2, 0, -hz - 0.2), c + Vector3(hx + 0.2, 0.4, hz + 0.2), Color(0.5, 0.5, 0.48), true)
	if hollow:
		b.xf = Transform3D(Basis.IDENTITY, c)
		WalkIn.shell(b, Vector3(size.x, size.y, size.z), 0.4, wall, Color(0.85, 0.82, 0.7), Color(0.5, 0.4, 0.3), 0.0, 1.4, 2.2, lit)
		b.xf = Transform3D.IDENTITY
	else:
		b.box(c + Vector3(-hx, 0.4, -hz), c + Vector3(hx, size.y, hz), wall, true)
	if hollow:
		# Карниз — полосами по стенам: сплошной плитой он лёг бы под потолок
		for z in [-hz - 0.01, hz - 0.02]:
			b.box(c + Vector3(-hx - 0.01, size.y - 0.4, z), c + Vector3(hx + 0.01, size.y - 0.15, z + 0.03), trim)
		for x in [-hx - 0.01, hx - 0.02]:
			b.box(c + Vector3(x, size.y - 0.4, -hz - 0.01), c + Vector3(x + 0.03, size.y - 0.15, hz + 0.01), trim)
	else:
		b.box(c + Vector3(-hx - 0.01, size.y - 0.4, -hz - 0.01), c + Vector3(hx + 0.01, size.y - 0.15, hz + 0.01), trim)
	b.box(c + Vector3(-hx - 0.4, size.y, -hz - 0.4), c + Vector3(hx + 0.4, size.y + 0.25, hz + 0.4), roof)
	# Окна по фасаду, дверь посередине, крыльцо с навесом
	var x := -hx + 1.3
	while x < hx - 1.0:
		if absf(x) > 1.3:
			b.box(c + Vector3(x - 0.55, 1.2, hz), c + Vector3(x + 0.55, 2.5, hz + 0.05), Color(0.92, 0.92, 0.9))
			b.box(c + Vector3(x - 0.45, 1.3, hz + 0.05), c + Vector3(x + 0.45, 2.4, hz + 0.07), Color(0.32, 0.42, 0.5))
		x += 2.2
	if hollow:
		# Дверь открыта — створка у стены
		b.box(c + Vector3(0.7, 0.4, hz), c + Vector3(0.76, 2.6, hz + 1.3), Color(0.4, 0.28, 0.2))
	else:
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
	var lamps := MeshBuilder.new()
	lamps.ground_shade = false
	_house(b, c, Vector3(10.0, 3.6, 7.0), Color(0.93, 0.9, 0.8), Color(0.4, 0.42, 0.45), Color(0.55, 0.2, 0.18), true, lamps)
	_council_inside(b, lamps)
	var lm := lamps.build_mesh(true)
	lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lm)
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
	# Секретарь — за столом справа, почтальон — за стойкой почты слева
	_person(c + Vector3(3.0, 0.4, -2.3), 0.0, Color(0.5, 0.3, 0.45), true)
	_person(c + Vector3(-2.7, 0.4, -1.6), 0.0, Color(0.2, 0.35, 0.65), true)
	var desk := InteractZone.create("", Vector3(2.0, 2.2, 1.4))
	desk.name = "CouncilDesk"
	desk.position = c + Vector3(3.0, 0.4, -0.5)
	desk.prompt_fn = _council_prompt
	desk.activated.connect(_council)
	add_child(desk)
	# ЗАГС — у флага: здесь расписывают
	var zags := InteractZone.create("", Vector3(1.4, 2.2, 1.4))
	zags.name = "ZagsZone"
	zags.position = c + Vector3(1.5, 0.4, -2.2)
	zags.prompt_fn = _zags_prompt
	zags.activated.connect(wedding)
	add_child(zags)


## Внутри сельсовета (от COUNCIL, пол на 0.4, вход с +Z): слева — почта
## (стойка с двумя окошками, полки с посылками), справа — стол секретаря,
## флаг, шкаф с делами. Почтовые окошки — см. PostService (KAMENKA_WINDOW).
const KAMENKA_WINDOW := Vector3(-2.7, 0.4, -0.4)


func _council_inside(b: MeshBuilder, lamps: MeshBuilder) -> void:
	var c := COUNCIL
	var f := 0.4
	var wood := Color(0.5, 0.36, 0.24)
	var blue := Color(0.2, 0.38, 0.72)
	# Почта: стойка поперёк левой половины, над ней стекло с окошками
	WalkIn.counter(b, c + Vector3(-4.75, f, -1.0), c + Vector3(-0.6, f + 1.05, -0.4), blue, Color(0.8, 0.8, 0.78))
	b.box(c + Vector3(-4.75, f + 1.05, -0.72), c + Vector3(-0.6, f + 1.1, -0.68), Color(0.9, 0.9, 0.88))
	# Окошки — рамки без стекла (сквозь них видно почтальона)
	for x in [-3.7, -1.7]:
		for e in [-0.5, 0.5]:
			b.box(c + Vector3(x + e - 0.03, f + 1.1, -0.73), c + Vector3(x + e + 0.03, f + 2.0, -0.69), Color(0.9, 0.9, 0.88))
		b.box(c + Vector3(x - 0.53, f + 1.97, -0.73), c + Vector3(x + 0.53, f + 2.03, -0.69), Color(0.9, 0.9, 0.88))
	# Полки с посылками за стойкой
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for y in [f + 0.0, f + 0.75, f + 1.5]:
		b.box(c + Vector3(-4.75, y, -3.3), c + Vector3(-0.8, y + 0.04, -2.7), wood)
		var x := -4.6
		while x < -1.0:
			var w := r.randf_range(0.25, 0.45)
			b.box(c + Vector3(x, y + 0.04, -3.25), c + Vector3(x + w, y + r.randf_range(0.2, 0.55), -2.8), Color(0.72, 0.55, 0.34).lightened(r.randf() * 0.15))
			x += w + 0.06
	b.box(c + Vector3(-4.75, f, -3.3), c + Vector3(-4.7, f + 2.0, -2.7), wood)
	# Плакат «Почта СССР» и почтовый ящик у стойки
	b.box(c + Vector3(-4.79, f + 1.3, 0.5), c + Vector3(-4.78, f + 2.1, 1.7), blue)
	b.box(c + Vector3(-0.5, f + 0.6, -0.35), c + Vector3(-0.1, f + 1.1, 0.0), blue, true)
	# Сельсовет: стол секретаря, стул посетителя, шкаф, флаг
	b.box(c + Vector3(2.2, f, -1.8), c + Vector3(3.8, f + 0.75, -1.1), wood, true)
	b.box(c + Vector3(2.5, f + 0.75, -1.6), c + Vector3(2.9, f + 0.78, -1.3), Color(0.95, 0.95, 0.9))
	b.box(c + Vector3(3.3, f + 0.75, -1.6), c + Vector3(3.5, f + 0.95, -1.4), Color(0.15, 0.15, 0.15))
	b.box(c + Vector3(2.8, f, -0.6), c + Vector3(3.2, f + 0.45, -0.2), Color(0.35, 0.28, 0.2), true)
	b.box(c + Vector3(4.2, f, -3.25), c + Vector3(4.75, f + 2.2, -1.5), wood, true)
	b.box(c + Vector3(1.0, f, -3.2), c + Vector3(1.06, f + 2.3, -3.14), Color(0.7, 0.7, 0.72))
	b.box(c + Vector3(1.06, f + 1.6, -3.2), c + Vector3(1.9, f + 2.2, -3.18), Color(0.8, 0.15, 0.12))
	# Портрет и герб на стене
	b.box(c + Vector3(2.6, f + 1.6, -3.29), c + Vector3(3.4, f + 2.5, -3.28), Color(0.55, 0.45, 0.3))
	for p in [Vector3(-2.7, 3.48, -1.0), Vector3(2.8, 3.48, -1.0)]:
		WalkIn.lamp(lamps, c + p)
	_label("СЕЛЬСОВЕТ", c + Vector3(3.0, 2.75, -3.27), 0.004, Color(1, 1, 0.9), Color(0.5, 0.15, 0.12))


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
	QuestManager.event("doc_" + String(d[0]))
	var tips := {
		"passport": "Паспорт готов! С ним — в больницу на медкомиссию, потом в автошколу",
		"propiska": "Справка о прописке: теперь ты официально житель Каменки",
		"work_book": "Трудовая книжка: с категорией D возьмут водителем автобуса",
	}
	GameManager.notify(tips[d[0]])


## Свадьба: невеста рядом, сельсовет открыт.
func _zags_prompt() -> String:
	var g := get_tree().get_first_node_in_group("girl") as Girl
	if g == null or not g.engaged or g.married:
		return ""
	if not office_open():
		return "ЗАГС: распишут в сельсовете Пн–Сб с 8:00 до 17:00"
	if not g.with_player(10.0):
		return "ЗАГС: «А невеста где? Приводи Олю — распишем»"
	if not Progress.has_item("dress"):
		return "ЗАГС: «Невеста без платья? Купите на рынке в городе»"
	return "E — расписаться с Олей: свадьба!"


func wedding() -> void:
	var g := get_tree().get_first_node_in_group("girl") as Girl
	if _zags_prompt() != "E — расписаться с Олей: свадьба!":
		return
	TimeManager.advance(60.0)
	g.wed()


# --- Больница -----------------------------------------------------------------

func _build_hospital() -> void:
	# HOSPITAL — в координатах города; узел Civic стоит в начале мира
	var c := Town.w(HOSPITAL)
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
