class_name Interiors
extends Node3D
## Внутри зданий города: банк, больница, ПТУ (бурса), завод «Искра». Дверь
## (E) переносит в помещение — у каждого свой интерьер — дверь изнутри
## выводит обратно на крыльцо. Помещения стоят высоко над своими зданиями
## (ROOM_Y) и видны, только пока игрок внутри: снаружи они ничего не стоят.
## Внутри работает то же, что у дверей: вклад, медкомиссия, курсы, а на
## заводе — своя официальная работа (смена у станков, 5 уровней).

const ROOM_Y := 400.0
## id → [название, вход (город), куда выйти (город), взгляд при выходе,
##        размер помещения: ширина, глубина, высота]
const ROOMS := {
	"bank": ["Банк", Vector3(201.0, 0, 13.0), Vector3(201.0, 0, 10.8), 0.0, Vector3(14, 4.5, 10)],
	"hospital": ["Больница", Vector3(170.0, 0, 42.7), Vector3(170.0, 0, 44.6), PI, Vector3(16, 3.8, 10)],
	"college": ["ПТУ №17", Vector3(250.9, 0, 122.6), Vector3(252.8, 0, 122.6), -PI / 2.0, Vector3(18, 3.6, 12)],
	"factory": ["Завод «Искра»", Vector3(163.0, 0, 218.2), Vector3(163.0, 0, 216.4), 0.0, Vector3(26, 8.0, 18)],
}
const FACTORY_PAY := 120

var current := ""
var factory_job: RouteJob
var _rooms := {}
var _world: Node3D
var _check := 0.0


func build(world: Node3D) -> void:
	_world = world
	name = "Interiors"
	for id in ROOMS:
		var room := Node3D.new()
		room.name = "Room_" + id
		room.position = origin(id)
		room.visible = false
		add_child(room)
		_rooms[id] = room
		_shell(room, id)
		match id:
			"bank":
				_bank(room)
			"hospital":
				_hospital(room)
			"college":
				_college(room)
			"factory":
				_factory(room)
		# Вход снаружи — у двери здания
		var door := InteractZone.create("", Vector3(1.6, 2.2, 1.2))
		door.name = "Door_" + id
		door.position = Town.w(ROOMS[id][1])
		door.prompt_fn = func() -> String: return "E — войти: %s" % ROOMS[id][0]
		door.activated.connect(enter.bind(id))
		add_child(door)
	_factory_job()


## Где стоит помещение id (центр пола): высоко над своим зданием.
static func origin(id: String) -> Vector3:
	var d: Vector3 = Town.w(ROOMS[id][1])
	return Vector3(d.x, ROOM_Y, d.z)


static func size(id: String) -> Vector3:
	var s: Vector3 = ROOMS[id][4]
	return Vector3(s.x, s.y, s.z)


## Войти: помещение видно, игрок — у двери изнутри, лицом в зал.
func enter(id: String) -> void:
	var p := GameManager.player as Node3D
	if p == null or GameManager.vehicle != null:
		return
	_show(id)
	var d := size(id).z
	p.global_position = origin(id) + Vector3(0, 0.1, d * 0.5 - 1.6)
	p.rotation.y = 0.0
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	SoundLibrary.play("click", -6.0, 0.8)
	QuestManager.event("enter_" + id)


## Выйти на крыльцо.
func leave() -> void:
	if current == "":
		return
	var id := current
	var p := GameManager.player as Node3D
	_show("")
	if p:
		p.global_position = Town.w(ROOMS[id][2]) + Vector3(0, 0.1, 0)
		p.rotation.y = float(ROOMS[id][3])
		if p is CharacterBody3D:
			(p as CharacterBody3D).velocity = Vector3.ZERO
		p.reset_physics_interpolation()
	SoundLibrary.play("click", -6.0, 0.8)


func _show(id: String) -> void:
	current = id
	GameManager.indoors = id
	for k in _rooms:
		(_rooms[k] as Node3D).visible = k == id


## Игрок попал внутрь или вышел не через дверь (загрузка, сон, обморок,
## автобус) — помещение показывается или прячется само.
func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	var p := GameManager.player as Node3D
	if p == null:
		return
	if p.global_position.y < ROOM_Y - 50.0:
		if current != "":
			_show("")
		return
	var best := ""
	var dist := 1e9
	for id in ROOMS:
		var dd := Vector2(p.global_position.x - origin(id).x, p.global_position.z - origin(id).z).length()
		if dd < dist:
			dist = dd
			best = id
	if best != current:
		_show(best)


# --- Коробка помещения ----------------------------------------------------------

## Пол, стены, потолок, дверь с выходом, лампы и свет. Дверь — в стене +Z.
func _shell(room: Node3D, id: String) -> void:
	var s := size(id)
	var hx := s.x * 0.5
	var hz := s.z * 0.5
	var h := s.y
	var cols := {
		"bank": [Color(0.86, 0.84, 0.8), Color(0.62, 0.55, 0.45), Color(0.72, 0.7, 0.66)],
		"hospital": [Color(0.93, 0.93, 0.9), Color(0.45, 0.62, 0.55), Color(0.55, 0.5, 0.45)],
		"college": [Color(0.86, 0.8, 0.68), Color(0.45, 0.55, 0.62), Color(0.5, 0.36, 0.25)],
		"factory": [Color(0.62, 0.58, 0.52), Color(0.35, 0.42, 0.45), Color(0.38, 0.38, 0.37)],
	}
	var wall: Color = cols[id][0]
	var panel: Color = cols[id][1]
	var floor_col: Color = cols[id][2]
	var b := MeshBuilder.new()
	b.ground_shade = false
	b.box(Vector3(-hx, -0.2, -hz), Vector3(hx, 0, hz), floor_col, true)
	b.box(Vector3(-hx, h, -hz), Vector3(hx, h + 0.2, hz), wall.lightened(0.1), true)
	for side in [-1.0, 1.0]:
		b.box(Vector3(side * hx - 0.1, 0, -hz), Vector3(side * hx + 0.1, h, hz), wall, true)
		b.box(Vector3(-hx, 0, side * hz - 0.1), Vector3(hx, h, side * hz + 0.1), wall, true)
		# Панели до пояса — по-советски, крашеные
		b.box(Vector3(side * hx - side * 0.12 - 0.01, 0, -hz), Vector3(side * hx - side * 0.12 + 0.01, 1.4, hz), panel)
		b.box(Vector3(-hx, 0, side * hz - side * 0.12 - 0.01), Vector3(hx, 1.4, side * hz - side * 0.12 + 0.01), panel)
	# Дверь изнутри
	b.box(Vector3(-0.7, 0, hz - 0.14), Vector3(0.7, 2.2, hz - 0.11), Color(0.45, 0.3, 0.2))
	b.box(Vector3(0.45, 1.0, hz - 0.18), Vector3(0.55, 1.1, hz - 0.14), Color(0.8, 0.75, 0.5))
	var mesh := b.build_mesh()
	room.add_child(mesh)
	room.add_child(b.build_body())
	# Лампы на потолке светятся сами, общий свет — одна лампа на зал
	var glow := MeshBuilder.new()
	glow.ground_shade = false
	var x := -hx + 2.5
	while x < hx - 1.0:
		var z := -hz + 2.5
		while z < hz - 1.0:
			glow.box(Vector3(x - 0.6, h - 0.06, z - 0.15), Vector3(x + 0.6, h - 0.01, z + 0.15), Color(1.0, 0.97, 0.88))
			z += 4.0
		x += 4.0
	room.add_child(glow.build_mesh(true))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, h - 0.6, 0)
	lamp.omni_range = maxf(s.x, s.z) * 0.9
	lamp.light_energy = 1.4
	lamp.omni_attenuation = 0.6
	room.add_child(lamp)
	var out := InteractZone.create("", Vector3(1.8, 2.2, 1.2))
	out.name = "Exit_" + id
	out.position = Vector3(0, 0, hz - 0.7)
	out.prompt_fn = func() -> String: return "E — выйти на улицу"
	out.activated.connect(leave)
	room.add_child(out)


func _label(room: Node3D, text: String, at: Vector3, yaw: float, px: float, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = px
	l.outline_size = 0
	l.modulate = col
	l.position = at
	l.rotation.y = yaw
	room.add_child(l)


## Человек (сотрудник, посетитель): одним мешем, с шейдером людей.
func _person(room: Node3D, at: Vector3, yaw: float, shirt: Color, sit := false, woman := false) -> void:
	var b := MeshBuilder.new()
	b.ground_shade = false
	preload("res://scripts/world/villagers.gd").person_model(b, shirt, shirt.darkened(0.4), sit, woman)
	var mi := b.build_mesh()
	mi.position = at
	mi.rotation.y = yaw
	room.add_child(mi)


func _zone(room: Node3D, at: Vector3, prompt: Callable, action: Callable) -> InteractZone:
	var z := InteractZone.create("", Vector3(1.8, 2.2, 1.6))
	z.position = at
	z.prompt_fn = prompt
	z.activated.connect(action)
	room.add_child(z)
	return z


# --- Банк ------------------------------------------------------------------------

## Мраморный зал: три окошка за стеклом с кассирами, табло курсов, диваны,
## фикус, сейф в глубине. Вклад кладётся и снимается в окошках.
func _bank(room: Node3D) -> void:
	var b := MeshBuilder.new()
	b.ground_shade = false
	# Шашечный мрамор
	for i in 7:
		for j in 5:
			if (i + j) % 2 == 0:
				b.box(Vector3(-7 + i * 2.0, 0.0, -5 + j * 2.0), Vector3(-5 + i * 2.0, 0.01, -3 + j * 2.0), Color(0.55, 0.52, 0.48))
	# Стойка с окошками и стеклом
	b.box(Vector3(-6.0, 0, -2.6), Vector3(6.0, 1.1, -2.0), Color(0.45, 0.3, 0.22), true)
	b.box(Vector3(-6.1, 1.1, -2.7), Vector3(6.1, 1.15, -1.9), Color(0.75, 0.7, 0.62))
	b.box(Vector3(-6.0, 1.15, -2.32), Vector3(6.0, 2.6, -2.28), Color(0.7, 0.85, 0.9))
	for k in 4:
		b.box(Vector3(-6.0 + k * 4.0 - 0.06, 1.15, -2.4), Vector3(-6.0 + k * 4.0 + 0.06, 2.7, -2.2), Color(0.45, 0.3, 0.22))
	# Табло курсов над окошками, сейф в глубине
	b.box(Vector3(-2.2, 3.0, -4.88), Vector3(2.2, 4.0, -4.86), Color(0.08, 0.1, 0.12))
	b.box(Vector3(4.2, 0, -4.9), Vector3(6.2, 2.2, -4.6), Color(0.45, 0.47, 0.5), true)
	PersonModel.limb(b, Vector3(5.2, 1.1, -4.6), Vector3(5.2, 1.1, -4.55), Vector2(0.7, 0.7), Vector2(0.7, 0.7), Color(0.6, 0.62, 0.66), true)
	# Диваны и фикусы у входа
	for side in [-1.0, 1.0]:
		var sx: float = side * 5.0
		b.box(Vector3(sx - 1.2, 0, 2.2), Vector3(sx + 1.2, 0.45, 3.0), Color(0.35, 0.18, 0.15), true)
		b.box(Vector3(sx - 1.2, 0.45, 2.8), Vector3(sx + 1.2, 0.95, 3.0), Color(0.35, 0.18, 0.15))
		b.box(Vector3(side * 6.4 - 0.25, 0, 4.0), Vector3(side * 6.4 + 0.25, 0.5, 4.5), Color(0.5, 0.35, 0.25))
		PersonModel.ball(b, Vector3(side * 6.4, 1.0, 4.25), Vector3(0.5, 0.6, 0.5), Color(0.2, 0.45, 0.2), 3, 8)
	room.add_child(b.build_mesh())
	room.add_child(b.build_body())
	_label(room, "КУРС ВАЛЮТ\nUSD 27.50  ·  EUR 30.10  ·  RUB 0.31", Vector3(0, 3.5, -4.84), 0.0, 0.006, Color(1.0, 0.75, 0.2))
	_label(room, "БАНК · ВКЛАДЫ 10% ГОДОВЫХ", Vector3(0, 3.9, 4.88), PI, 0.007, Color(0.2, 0.35, 0.3))
	for k in 3:
		_person(room, Vector3(-4.0 + k * 4.0, 0, -3.4), 0.0, [Color(0.85, 0.85, 0.9), Color(0.3, 0.4, 0.55), Color(0.85, 0.85, 0.9)][k], true, k != 1)
	_person(room, Vector3(5.0, 0, 2.6), PI, Color(0.5, 0.35, 0.3), true)
	var put_p := func() -> String:
		if GameManager.money <= 300:
			return "Кассир: «Вклад %d грн, 10%% годовых. Положить нечего — 300 грн оставьте на жизнь»" % Daily.deposit
		return "E — положить на вклад %d грн (10%% годовых)" % (GameManager.money - 300)
	var put_a := func() -> void:
		var sum := Daily.put_money()
		if sum > 0:
			SoundLibrary.play("cash")
			GameManager.notify("Положил %d грн. На вкладе: %d грн — проценты каждое утро" % [sum, Daily.deposit])
	var take_p := func() -> String:
		if Daily.deposit > 0:
			return "E — снять вклад: %d грн" % Daily.deposit
		return "Кассир: «Вклада у вас нет. Открыть — в соседнем окошке»"
	var take_a := func() -> void:
		var sum := Daily.take_money()
		if sum > 0:
			SoundLibrary.play("cash")
			GameManager.notify("Снял со вклада %d грн" % sum)
	var info_p := func() -> String:
		return "Кассир: «На вкладе %d грн. Проценты — каждое утро, 10%% в игровой год»" % Daily.deposit
	_zone(room, Vector3(-4.0, 0, -1.2), put_p, put_a)
	_zone(room, Vector3(0.0, 0, -1.2), take_p, take_a)
	_zone(room, Vector3(4.0, 0, -1.2), info_p, func() -> void: pass)


# --- Больница --------------------------------------------------------------------

## Приёмный покой: регистратура с окошком, скамейки, кабинет врача за
## перегородкой (стол, кушетка, таблица для зрения), процедурная с ширмой.
func _hospital(room: Node3D) -> void:
	var b := MeshBuilder.new()
	b.ground_shade = false
	# Регистратура
	b.box(Vector3(-7.8, 0, -1.5), Vector3(-4.5, 1.1, -0.9), Color(0.85, 0.85, 0.82), true)
	b.box(Vector3(-7.8, 1.1, -1.25), Vector3(-4.5, 2.4, -1.2), Color(0.75, 0.88, 0.9))
	# Скамейки вдоль стены
	for k in 3:
		var x := -1.5 + k * 2.6
		b.box(Vector3(x - 1.0, 0.42, 3.9), Vector3(x + 1.0, 0.48, 4.5), Color(0.5, 0.35, 0.22), true)
		b.box(Vector3(x - 1.0, 0.48, 4.5), Vector3(x + 1.0, 0.95, 4.6), Color(0.5, 0.35, 0.22))
	# Перегородка кабинета врача с проёмом
	b.box(Vector3(-8, 0, -2.0), Vector3(-1.0, 3.8, -1.9), Color(0.93, 0.93, 0.9), true)
	b.box(Vector3(1.0, 0, -2.0), Vector3(8, 3.8, -1.9), Color(0.93, 0.93, 0.9), true)
	# Кабинет: стол, кушетка, таблица для зрения
	b.box(Vector3(-5.0, 0, -4.4), Vector3(-3.0, 0.75, -3.4), Color(0.6, 0.45, 0.3), true)
	b.box(Vector3(2.5, 0, -4.6), Vector3(5.0, 0.6, -3.8), Color(0.85, 0.85, 0.82), true)
	b.box(Vector3(2.5, 0.6, -4.6), Vector3(5.0, 0.72, -3.8), Color(0.45, 0.6, 0.55))
	b.box(Vector3(-1.0, 1.2, -4.9), Vector3(0.2, 2.6, -4.88), Color(0.98, 0.98, 0.98))
	# Ширма процедурной
	for k in 3:
		b.box(Vector3(6.0 + k * 0.6, 0, -1.8), Vector3(6.55 + k * 0.6, 1.9, -1.75), Color(0.75, 0.85, 0.85))
	room.add_child(b.build_mesh())
	room.add_child(b.build_body())
	_label(room, "РЕГИСТРАТУРА", Vector3(-6.2, 2.7, -1.15), 0.0, 0.005, Color(0.1, 0.35, 0.4))
	_label(room, "Ш Б\nМ Н К\nЫ И Б Ш", Vector3(-0.4, 1.9, -4.86), 0.0, 0.006, Color(0.05, 0.05, 0.05))
	_label(room, "МЫТЬ РУКИ ПЕРЕД ЕДОЙ!", Vector3(4.0, 2.4, 4.86), PI, 0.005, Color(0.7, 0.15, 0.15))
	_person(room, Vector3(-6.2, 0, -1.9), 0.0, Color(0.95, 0.95, 0.95), true, true)
	_person(room, Vector3(-4.0, 0, -4.6), 0.0, Color(0.95, 0.95, 0.95), true)
	_person(room, Vector3(1.1, 0, 4.0), PI, Color(0.4, 0.4, 0.5), true, true)
	var civic := _world.get_node_or_null("Civic")
	if civic:
		_zone(room, Vector3(-6.2, 0, -0.2), civic._med_prompt, civic._med)
		var cure_p := func() -> String:
			var h := TimeManager.hour()
			if h < 8.0 or h >= 17.0:
				return "Медсестра: «Процедурная с 8:00 до 17:00»"
			return "E — процедуры и витамины: силы +40 (%d грн, 1 час)" % Civic.CURE_PRICE
		_zone(room, Vector3(6.6, 0, -0.8), cure_p, civic._cure)


# --- ПТУ -------------------------------------------------------------------------

## Класс бурсы: парты рядами с учениками, доска «ПДД», стол мастера, мотор
## на стенде, плакаты. У стола мастера — курсы автослесарей.
func _college(room: Node3D) -> void:
	var b := MeshBuilder.new()
	b.ground_shade = false
	b.box(Vector3(-3.5, 1.0, -4.88), Vector3(3.5, 2.8, -4.85), Color(0.12, 0.25, 0.15))
	b.box(Vector3(-3.6, 0.9, -4.85), Vector3(3.6, 0.95, -4.7), Color(0.5, 0.36, 0.25))
	b.box(Vector3(-1.2, 0, -3.6), Vector3(1.2, 0.75, -2.8), Color(0.45, 0.3, 0.2), true)
	for r in 3:
		for c in 2:
			var x := -2.6 + c * 5.2
			var z := -1.4 + r * 1.7
			b.box(Vector3(x - 1.1, 0, z - 0.35), Vector3(x + 1.1, 0.72, z + 0.35), Color(0.55, 0.42, 0.28), true)
	# Учебный двигатель на стенде
	b.box(Vector3(4.6, 0, -4.4), Vector3(5.6, 0.7, -3.4), Color(0.3, 0.3, 0.32), true)
	b.box(Vector3(4.7, 0.7, -4.2), Vector3(5.5, 1.3, -3.6), Color(0.25, 0.35, 0.5))
	room.add_child(b.build_mesh())
	room.add_child(b.build_body())
	_label(room, "ПДД · УСТРОЙСТВО АВТОМОБИЛЯ", Vector3(0, 2.3, -4.83), 0.0, 0.006, Color(0.95, 0.95, 0.9))
	_label(room, "ТЕХНИКА БЕЗОПАСНОСТИ\nПРЕВЫШЕ ВСЕГО", Vector3(-5.95, 2.4, 0), PI / 2.0, 0.005, Color(0.7, 0.15, 0.15))
	_label(room, "ДВС ВМЗ-2101", Vector3(5.1, 1.6, -3.5), 0.0, 0.004, Color(0.1, 0.1, 0.1))
	_person(room, Vector3(0, 0, -3.9), 0.0, Color(0.35, 0.35, 0.4))
	for k in 4:
		_person(room, Vector3(-3.0 + (k % 2) * 5.2, 0, -0.8 + (k / 2) * 1.7), PI, [Color(0.2, 0.3, 0.6), Color(0.6, 0.2, 0.2), Color(0.3, 0.5, 0.3), Color(0.5, 0.45, 0.2)][k], true, k == 1)
	var east := _world.get_node_or_null("TownEast")
	if east:
		_zone(room, Vector3(0, 0, -2.2), east._course_prompt, east.take_course)
	# Развлечения на перемене: теннисный стол и стол для армрестлинга
	var fb := MeshBuilder.new()
	fb.ground_shade = false
	ping = _fun(room, fb, "ping", "Настольный теннис", "Серёгой из группы", Vector3(-6.4, 0, 3.0), 2.6, 25)
	arm = _fun(room, fb, "arm", "Армрестлинг", "Толяном-качком", Vector3(6.2, 0, 3.0), 1.0, 40)
	room.add_child(fb.build_mesh())
	room.add_child(fb.build_body())
	_label(room, "КРУЖОК НАСТОЛЬНОГО ТЕННИСА", Vector3(-8.95, 2.4, 3.0), PI / 2.0, 0.005, Color(0.15, 0.35, 0.6))


var ping: FunGame
var arm: FunGame


## Развлечение: стол в fb, соперник с той стороны, узел игры — в комнате.
func _fun(room: Node3D, fb: MeshBuilder, kind: String, title: String, who: String, at: Vector3, length: float, prize: int) -> FunGame:
	var g := FunGame.new()
	g.kind = kind
	g.title = title
	g.opponent = who
	g.prize = prize
	g.table_len = length
	g.position = at
	g.name = "Fun_" + kind
	g.build_table(fb, at)
	room.add_child(g)
	_person(room, at + Vector3(-length * 0.5 - 0.55, 0, 0), PI / 2.0, Color(0.55, 0.25, 0.2) if kind == "arm" else Color(0.25, 0.45, 0.3))
	return g


# --- Завод -----------------------------------------------------------------------

## Цех: станки рядами, конвейер, кран-балка под потолком, ящики с деталями,
## мастер у пульта. Смена — обойти четыре станка (работа у каждого).
func _factory(room: Node3D) -> void:
	var b := MeshBuilder.new()
	b.ground_shade = false
	# Разметка проходов
	b.box(Vector3(-12, 0.0, -0.6), Vector3(12, 0.012, -0.45), Color(0.9, 0.75, 0.1))
	b.box(Vector3(-12, 0.0, 0.45), Vector3(12, 0.012, 0.6), Color(0.9, 0.75, 0.1))
	for st in station_spots():
		var p: Vector3 = st
		b.box(p + Vector3(-0.9, 0, -2.2), p + Vector3(0.9, 1.1, -0.8), Color(0.3, 0.42, 0.38), true)
		b.box(p + Vector3(-0.5, 1.1, -2.0), p + Vector3(0.5, 1.8, -1.2), Color(0.35, 0.45, 0.4))
		b.box(p + Vector3(-0.15, 1.2, -1.2), p + Vector3(0.15, 1.5, -0.9), Color(0.75, 0.75, 0.78))
	# Конвейер вдоль задней стены
	b.box(Vector3(-11, 0, -8.2), Vector3(11, 0.9, -7.2), Color(0.25, 0.25, 0.27), true)
	b.box(Vector3(-11, 0.9, -8.1), Vector3(11, 0.95, -7.3), Color(0.12, 0.12, 0.12))
	for k in 9:
		b.box(Vector3(-10 + k * 2.4, 0.95, -7.95), Vector3(-9.4 + k * 2.4, 1.3, -7.45), Color(0.6, 0.5, 0.3))
	# Кран-балка
	b.box(Vector3(-12.8, 6.8, -1.0), Vector3(12.8, 7.2, -0.6), Color(0.85, 0.65, 0.1))
	b.box(Vector3(-1.0, 6.2, -1.1), Vector3(0.0, 6.8, -0.5), Color(0.3, 0.3, 0.3))
	b.box(Vector3(-0.55, 3.5, -0.85), Vector3(-0.45, 6.2, -0.75), Color(0.2, 0.2, 0.2))
	# Ящики с деталями
	for k in 6:
		var x := 8.0 + (k % 3) * 1.2
		var y := float(k / 3) * 0.8
		b.box(Vector3(x, y, 5.5), Vector3(x + 1.1, y + 0.8, 6.6), Color(0.55, 0.42, 0.25), true)
	# Пульт мастера у входа
	b.box(Vector3(-9.5, 0, 6.0), Vector3(-7.5, 1.2, 6.8), Color(0.4, 0.45, 0.5), true)
	room.add_child(b.build_mesh())
	room.add_child(b.build_body())
	_label(room, "ЗАВОД «ИСКРА» · ЦЕХ №2", Vector3(0, 6.0, -8.88), 0.0, 0.012, Color(0.9, 0.9, 0.9))
	_label(room, "ПЛАН — ЗАКОН!", Vector3(-12.85, 4.0, 0), PI / 2.0, 0.01, Color(0.85, 0.15, 0.1))
	_person(room, Vector3(-8.5, 0, 5.6), 0.0, Color(0.25, 0.3, 0.45))
	for k in 3:
		_person(room, Vector3(-9.0 + k * 9.0, 0, -6.6), 0.0, Color(0.2, 0.25, 0.35))


## Четыре станка цеха (в координатах помещения).
static func station_spots() -> Array:
	return [Vector3(-8.0, 0, -2.5), Vector3(-2.7, 0, -2.5), Vector3(2.7, 0, -2.5), Vector3(8.0, 0, -2.5)]


## Смена на заводе — официальная работа (трудовая книжка, будни 7–17):
## обойти четыре станка, у каждого — полчаса работы. 5 уровней.
func _factory_job() -> void:
	var o := origin("factory")
	var j := RouteJob.new()
	j.name = "FactoryJob"
	j.id = "factory"
	j.title = "Завод «Искра»"
	j.describe = "смена у станков: 4 детали, по полчаса"
	j.giver = o + Vector3(-8.5, 0, 6.6)
	j.giver_size = Vector3(2.0, 2.2, 1.6)
	j.mode = "foot"
	j.radius = 1.4
	j.work_each = 30.0
	j.work_what = "Точу деталь"
	j.verb = "Деталь готова"
	j.sign_text = "ОТДЕЛ КАДРОВ"
	j.sign_pixel = 0.004
	j.sign_height = 2.4
	j.open_from = 7.0
	j.open_to = 17.0
	j.blocked_fn = func() -> String:
		if not Progress.has_doc("work_book"):
			return "Отдел кадров: «Без трудовой книжки не оформим — её дают в сельсовете»"
		if TimeManager.weekday() == "вс":
			return "Завод: в воскресенье выходной"
		return ""
	j.stops_fn = func() -> Array:
		var out := []
		var names := ["токарный станок", "фрезерный станок", "сверлильный станок", "шлифовальный станок"]
		var spots := station_spots()
		for i in spots.size():
			out.append([names[i], o + (spots[i] as Vector3)])
		return out
	j.pay_fn = func(stops: Array) -> int: return stops.size() * FACTORY_PAY
	_world.add_child(j)
	factory_job = j
