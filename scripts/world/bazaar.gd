class_name Bazaar
extends Node3D
## Базар в подробностях и в жизни. Живёт внутри TownSouth (его координаты).
##   * Товар как настоящий: в ящиках помидоры, огурцы, картошка, яблоки,
##     виноград; арбузы горой на земле; банки молока и мёда, лотки яиц,
##     сало на доске, колбаса и тарань гирляндами. У каждой лавки — весы
##     с гирьками и картонные ценники.
##   * У каждой лавки с едой свой товар и свои цены (окно MarketPanel,
##     режим "food"): можно поторговаться — раз в день, повезёт — скидка,
##     нет — продавец обидится и поднимет цену.
##   * Жёлтая бочка «КВАС» у ворот: кружка за 5 грн, весной и летом.
##   * Продавцы за прилавками только в часы работы (7:00–16:00), зазывают
##     покупателей; между рядами ходят покупатели с авоськами и сумками.
##   * Вокруг — мешки, ящики, картонки, тачка, мусорный бак, лужи.

const P := preload("res://scripts/world/person_model.gd")
const Villagers := preload("res://scripts/world/villagers.gd")

const OPEN := 7.0
const CLOSE := 16.0
## Лавки с едой по порядку вдоль рядов.
const FOOD_KINDS := ["veg", "fruit", "dairy", "meat", "honey"]
const FOOD_TITLE := {
	"veg": "Овощи с огорода",
	"fruit": "Фрукты и арбузы",
	"dairy": "Молоко, сметана, яйца",
	"meat": "Сало и мясо",
	"honey": "Мёд, тарань, семечки",
}
## Товар: id → [название, цена, еды в запас, вода, бодрость, что это]
const FOOD := {
	"veg": {
		"potato": ["Картошка, ведро", 30, 2, 0, 0, "своя, рассыпчатая — жарить и варить"],
		"tomato": ["Помидоры с огурцами", 35, 1, 10, 0, "на салат, сочные — и поешь, и попьёшь"],
		"onion": ["Лук и морковка", 15, 1, 0, 0, "к борщу — дёшево"],
	},
	"fruit": {
		"apple": ["Яблоки «белый налив»", 20, 1, 10, 0, "кислые, хрустят"],
		"melon": ["Арбуз херсонский", 45, 2, 30, 0, "продавец постучит — звонкий, спелый"],
		"grape": ["Виноград", 40, 1, 15, 5, "сладкий, без косточек почти"],
	},
	"dairy": {
		"milk": ["Молоко, трёхлитровая банка", 30, 1, 25, 0, "утренней дойки, банку вернуть не надо"],
		"cream": ["Сметана и творог", 35, 2, 0, 0, "ложка стоит"],
		"eggs": ["Яйца, десяток", 25, 2, 0, 0, "домашние, желток оранжевый"],
	},
	"meat": {
		"salo": ["Сало домашнее", 60, 3, 0, 0, "с прослойкой, с чесноком"],
		"sausage": ["Колбаса «Докторская»", 50, 2, 0, 0, "по ГОСТу, говорит продавец"],
		"chicken": ["Курица домашняя", 70, 3, 0, 0, "на суп хватит на три дня"],
	},
	"honey": {
		"honey": ["Мёд гречишный, банка", 50, 1, 0, 15, "ложка мёда — и сил прибавилось"],
		"taran": ["Тарань вяленая", 30, 1, -5, 0, "солёная — потом пить захочется"],
		"seeds": ["Семечки, стакан", 5, 0, 0, 3, "жареные, в кулёчке из газеты"],
	},
}
## Что кричат продавцы.
const SHOUTS := [
	"Помидорчики свежие, сладкие!",
	"Молодой человек, подходи — дешевле не найдёшь!",
	"Сало домашнее, попробуй кусочек!",
	"Арбузы! Херсонские! Сахарные!",
	"Молочко утреннее, ещё тёплое!",
	"Мёд гречишный, от всех болезней!",
	"Девушка, берите яблочки — сама собирала!",
	"Семечки! Жареные! Стакан — пять гривен!",
]
const KVASS_PRICE := 5

var sellers: Array[Node3D] = []
var _shoppers: Array[MeshInstance3D] = []
var _paths: Array = []  # на покупателя: [z ряда, x от, x до, x сейчас, куда (+1/−1), стоит сек, фаза]
var _shout: Label3D
var _shout_t := 3.0
var _tick := 0.0
var _rng := RandomNumberGenerator.new()
## Торг: kind → [день, множитель цены]
var _deal := {}
var _kvass: InteractZone
var _kvass_pos := Vector3.ZERO


func _ready() -> void:
	name = "Bazaar"
	_rng.randomize()
	_shout = Label3D.new()
	_shout.font_size = 40
	_shout.pixel_size = 0.005
	_shout.outline_size = 10
	_shout.modulate = Color(1.0, 0.95, 0.8)
	_shout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_shout.visibility_range_end = 30.0
	_shout.visible = false
	add_child(_shout)


static func open_now() -> bool:
	var h := TimeManager.hour()
	return h >= OPEN and h < CLOSE


# --- Торговля -----------------------------------------------------------------

func _factor(kind: String) -> float:
	var d: Array = _deal.get(kind, [-1, 1.0])
	return float(d[1]) if int(d[0]) == TimeManager.day else 1.0


func price(kind: String, id: String) -> int:
	return int(round(int(FOOD[kind][id][1]) * _factor(kind)))


## Товар лавки для окна: id → [название, цена сейчас, что это].
func food_list(kind: String) -> Dictionary:
	var out := {}
	for id in FOOD[kind]:
		var it: Array = FOOD[kind][id]
		out[id] = [it[0], price(kind, id), it[5]]
	return out


## Поторговаться: раз в день у лавки. roll — для проверки (0..1), иначе
## случай. Удача — −20% на сегодня, нет — продавец обиделся, +10%.
func haggle(kind: String, roll := -1.0) -> String:
	var d: Array = _deal.get(kind, [-1, 1.0])
	if int(d[0]) == TimeManager.day:
		return "Уже торговался — больше не уступят" if float(d[1]) < 1.0 else "Продавец ещё дуется — цена та же"
	var r := roll if roll >= 0.0 else _rng.randf()
	QuestManager.event("haggle")
	if r < 0.55:
		_deal[kind] = [TimeManager.day, 0.8]
		return "«Ладно, для тебя — уступлю!» Сегодня здесь на 20% дешевле"
	_deal[kind] = [TimeManager.day, 1.1]
	return "«Не нравится — иди к соседке!» Обиделся: на 10% дороже"


## Купить товар id в лавке kind. true — купил.
func buy_food(kind: String, id: String) -> bool:
	if not open_now() or not FOOD.has(kind) or not FOOD[kind].has(id):
		return false
	var it: Array = FOOD[kind][id]
	var cost := price(kind, id)
	if not GameManager.spend(cost):
		return false
	NeedsManager.snacks += int(it[2])
	if int(it[3]) > 0:
		NeedsManager.drink(float(it[3]))
	elif int(it[3]) < 0:
		NeedsManager.water = maxf(NeedsManager.water + float(it[3]), 0.0)
	if int(it[4]) > 0:
		NeedsManager.rest(float(it[4]))
	SoundLibrary.play("cash", -4.0)
	QuestManager.event("market")
	GameManager.notify("Базар: %s (−%d грн)" % [it[0], cost])
	return true


## Кружка кваса из бочки.
func kvass() -> void:
	if not _kvass_open():
		GameManager.notify("Бочка с квасом стоит пустая — квас продают весной и летом с 9:00 до 18:00")
		return
	if GameManager.spend(KVASS_PRICE):
		NeedsManager.drink(35.0)
		SoundLibrary.play("cash", -6.0)
		QuestManager.event("kvass")
		GameManager.notify("Кружка холодного кваса — хорошо! (−%d грн)" % KVASS_PRICE)


func _kvass_open() -> bool:
	var h := TimeManager.hour()
	return WeatherManager.season() in [0, 3] and h >= 9.0 and h < 18.0


func _kvass_prompt() -> String:
	if not _kvass_open():
		return "Квас — весной и летом, с 9:00 до 18:00"
	return "E — кружка кваса (%d грн)" % KVASS_PRICE


# --- Жизнь: продавцы, покупатели, окрики ----------------------------------------

func _process(delta: float) -> void:
	_tick -= delta
	var pl := GameManager.player as Node3D
	var near := pl != null and pl.global_position.distance_to(global_position + Vector3(64, 0, 144)) < 90.0
	if _tick <= 0.0:
		_tick = 1.0
		var open := open_now()
		for s in sellers:
			s.visible = open
		for m in _shoppers:
			m.visible = open and near
		if not open:
			_shout.visible = false
	if not near or not open_now():
		return
	for i in _shoppers.size():
		_walk(i, delta)
	_shout_t -= delta
	if _shout_t <= 0.0:
		if _shout.visible:
			_shout.visible = false
			_shout_t = _rng.randf_range(3.0, 7.0)
		elif not sellers.is_empty():
			var s: Node3D = sellers[_rng.randi() % sellers.size()]
			_shout.text = SHOUTS[_rng.randi() % SHOUTS.size()]
			_shout.position = s.position + Vector3(0, 2.05, 0)
			_shout.visible = true
			_shout_t = 3.5


## Покупатель ходит вдоль ряда, у лавок останавливается и смотрит товар.
func _walk(i: int, delta: float) -> void:
	var m := _shoppers[i]
	var p: Array = _paths[i]
	if float(p[5]) > 0.0:
		p[5] = float(p[5]) - delta
		Villagers.set_walk(m, float(p[6]), 0.0)
		return
	var x := float(p[3]) + float(p[4]) * 1.0 * delta
	if x > float(p[2]) or x < float(p[1]):
		p[4] = -float(p[4])
		x = clampf(x, float(p[1]), float(p[2]))
	p[3] = x
	p[6] = float(p[6]) + delta * 4.2
	m.position = Vector3(x, 0, float(p[0]))
	m.rotation.y = -PI / 2.0 if float(p[4]) > 0.0 else PI / 2.0
	Villagers.set_walk(m, float(p[6]), 1.0)
	# У середины лавки — остановиться и повернуться к прилавку
	if _rng.randf() < delta * 0.25:
		p[5] = _rng.randf_range(2.0, 5.0)
		m.rotation.y = PI


## Покупатели: rows — z, где стоят у прилавков; x0..x1 — вдоль ряда.
func add_shoppers(rows: Array, x0: float, x1: float) -> void:
	var shirts := [Color(0.3, 0.45, 0.7), Color(0.75, 0.3, 0.3), Color(0.4, 0.55, 0.35), Color(0.85, 0.75, 0.5), Color(0.55, 0.35, 0.6)]
	for i in 5:
		var pb := MeshBuilder.new()
		pb.ground_shade = false
		var woman := i % 2 == 0
		Villagers.person_model(pb, shirts[i], Color(0.7, 0.3, 0.35) if woman else Color(0.25, 0.25, 0.3), false, woman)
		_carry_bag(pb, i)
		var m := Villagers.walking_mesh(pb)
		m.visibility_range_end = 70.0
		var z: float = rows[i % rows.size()] - 1.3 - (i % 3) * 0.35
		var x := lerpf(x0, x1, float(i) / 5.0)
		m.position = Vector3(x, 0, z)
		add_child(m)
		_shoppers.append(m)
		_paths.append([z, x0, x1, x, 1.0 if i % 2 == 0 else -1.0, 0.0, float(i)])


## В правой руке — авоська с картошкой или клетчатая сумка «челночница»;
## метка руки 0.6 — качается вместе с рукой.
static func _carry_bag(b: MeshBuilder, i: int) -> void:
	b.alpha = 0.6
	var h := Vector3(0.23, 0.7, -0.01)
	P.limb(b, h, h + Vector3(0.02, -0.1, 0.0), Vector2(0.006, 0.006), Vector2(0.006, 0.006), Color(0.2, 0.2, 0.2))
	if i % 2 == 0:
		# Авоська: сетка с картошкой и луком
		for k in 6:
			var c := h + Vector3(0.02 + (k % 2) * 0.05 - 0.025, -0.17 - (k / 2) * 0.05, (k % 3) * 0.03 - 0.03)
			P.ball(b, c, Vector3(0.03, 0.028, 0.03), Color(0.6, 0.45, 0.28) if k % 3 else Color(0.85, 0.6, 0.3), 2, 5)
		P.limb(b, h + Vector3(0.02, -0.1, 0.0), h + Vector3(0.02, -0.3, 0.0), Vector2(0.06, 0.05), Vector2(0.045, 0.04), Color(0.8, 0.75, 0.3))
	else:
		# Клетчатая сумка: сине-красная клетка
		var mn := h + Vector3(-0.0, -0.42, -0.14)
		b.box(mn, mn + Vector3(0.1, 0.32, 0.28), Color(0.25, 0.35, 0.7))
		for k in 4:
			b.box(mn + Vector3(-0.003, 0.04 + k * 0.08, 0.0), mn + Vector3(0.103, 0.06 + k * 0.08, 0.28), Color(0.8, 0.2, 0.2))
			b.box(mn + Vector3(-0.004, 0.0, 0.03 + k * 0.07), mn + Vector3(0.104, 0.32, 0.045 + k * 0.07), Color(0.92, 0.92, 0.92))
	b.alpha = 1.0


# --- Мелочи, которые рисуются (MeshBuilder для мелочи базара) ----------------

## Деревянный ящик с бортиками: mn — нижний угол, s — размер.
static func crate(b: MeshBuilder, mn: Vector3, s: Vector3, col := Color(0.72, 0.58, 0.38)) -> void:
	b.box(mn, mn + Vector3(s.x, 0.02, s.z), col.darkened(0.1))
	for k in 2:
		var y := mn.y + 0.02 + k * s.y * 0.5
		b.box(Vector3(mn.x, y, mn.z), Vector3(mn.x + s.x, y + s.y * 0.35, mn.z + 0.015), col)
		b.box(Vector3(mn.x, y, mn.z + s.z - 0.015), Vector3(mn.x + s.x, y + s.y * 0.35, mn.z + s.z), col)
		b.box(Vector3(mn.x, y, mn.z), Vector3(mn.x + 0.015, y + s.y * 0.35, mn.z + s.z), col)
		b.box(Vector3(mn.x + s.x - 0.015, y, mn.z), Vector3(mn.x + s.x, y + s.y * 0.35, mn.z + s.z), col)


## Горка плодов в ящике: ряды шариков радиуса r, к середине — выше.
static func heap(b: MeshBuilder, mn: Vector3, s: Vector3, r: float, cols: Array, squash := 0.9) -> void:
	var nx := maxi(int(s.x / (r * 2.1)), 1)
	var nz := maxi(int(s.z / (r * 2.1)), 1)
	for ix in nx:
		for iz in nz:
			var fx := (ix + 0.5) / nx
			var fz := (iz + 0.5) / nz
			var dome := 1.0 - (absf(fx - 0.5) + absf(fz - 0.5))
			var c := mn + Vector3(fx * s.x + (iz % 2) * r * 0.4, r * squash + dome * r * 1.6, fz * s.z)
			var col: Color = cols[(ix * 7 + iz * 3) % cols.size()]
			P.ball(b, c, Vector3(r, r * squash, r), col, 2, 5)


## Весы с чашками и гирьками.
static func scales(b: MeshBuilder, at: Vector3) -> void:
	var white := Color(0.9, 0.9, 0.86)
	var steel := Color(0.78, 0.8, 0.83)
	b.box(at + Vector3(-0.22, 0, -0.1), at + Vector3(0.22, 0.12, 0.1), white)
	b.box(at + Vector3(-0.04, 0.12, -0.03), at + Vector3(0.04, 0.2, 0.03), white.darkened(0.1))
	for s in [-1.0, 1.0]:
		P.limb(b, at + Vector3(s * 0.13, 0.13, 0), at + Vector3(s * 0.13, 0.15, 0), Vector2(0.11, 0.11), Vector2(0.12, 0.12), steel, true)
	# Гирьки на правой чашке, стрелка посередине
	for k in 3:
		P.limb(b, at + Vector3(0.1 + k * 0.035, 0.15, -0.02), at + Vector3(0.1 + k * 0.035, 0.19 - k * 0.01, -0.02), Vector2(0.015, 0.015), Vector2(0.012, 0.012), Color(0.25, 0.25, 0.27), true)
	b.box(at + Vector3(-0.005, 0.2, -0.031), at + Vector3(0.005, 0.27, -0.025), Color(0.1, 0.1, 0.1))


## Банка: стекло с содержимым и крышкой.
static func jar(b: MeshBuilder, at: Vector3, h: float, r: float, fill: Color, lid: Color) -> void:
	P.limb(b, at, at + Vector3(0, h * 0.85, 0), Vector2(r, r), Vector2(r, r), fill, true)
	P.limb(b, at + Vector3(0, h * 0.85, 0), at + Vector3(0, h, 0), Vector2(r, r), Vector2(r * 0.7, r * 0.7), fill.lightened(0.25))
	P.limb(b, at + Vector3(0, h, 0), at + Vector3(0, h + 0.02, 0), Vector2(r * 0.72, r * 0.72), Vector2(r * 0.72, r * 0.72), lid, true)


## Мешок: светлая мешковина, горловина завязана.
static func sack(b: MeshBuilder, at: Vector3, h: float, col := Color(0.76, 0.68, 0.5)) -> void:
	P.limb(b, at, at + Vector3(0, h, 0), Vector2(0.2, 0.17), Vector2(0.16, 0.14), col, true)
	P.limb(b, at + Vector3(0, h, 0), at + Vector3(0, h + 0.1, 0), Vector2(0.07, 0.06), Vector2(0.09, 0.08), col.darkened(0.08), true)


## Картонный ценник на палочке. Надпись — отдельно (Label3D у Bazaar).
static func tag_board(b: MeshBuilder, at: Vector3) -> void:
	b.box(at + Vector3(-0.005, -0.12, -0.005), at + Vector3(0.005, 0.0, 0.005), Color(0.75, 0.65, 0.45))
	b.box(at + Vector3(-0.1, 0.0, -0.01), at + Vector3(0.1, 0.11, 0.0), Color(0.85, 0.75, 0.55))


## Ценник с надписью над ящиком: text — «Помидоры 25» и т. п.
func tag(b: MeshBuilder, at: Vector3, text: String) -> void:
	tag_board(b, at)
	var l := Label3D.new()
	l.text = text
	l.font_size = 22
	l.pixel_size = 0.0035
	l.outline_size = 0
	l.modulate = Color(0.08, 0.08, 0.12)
	l.position = at + Vector3(0, 0.055, -0.012)
	l.rotation.y = PI
	l.visibility_range_end = 14.0
	l.double_sided = false
	add_child(l)


## Лавка с едой kind: прилавок x..x+5 по X, row..row+1.2 по Z, покупатель — с −Z.
func food_goods(b: MeshBuilder, x: float, row: float, kind: String) -> void:
	var top := 1.0
	var cs := Vector3(0.8, 0.16, 0.62)
	var spots: Array[Vector3] = []
	for g in 4:
		spots.append(Vector3(x + 0.2 + g * 0.95, top, row + 0.3))
	match kind:
		"veg":
			crate(b, spots[0], cs)
			heap(b, spots[0] + Vector3(0.03, 0.02, 0.03), cs - Vector3(0.06, 0, 0.06), 0.045, [Color(0.85, 0.12, 0.08), Color(0.78, 0.15, 0.1), Color(0.9, 0.25, 0.12)])
			tag(b, spots[0] + Vector3(0.4, 0.3, -0.02), "Помидоры 25")
			crate(b, spots[1], cs)
			for k in 18:
				var cx := spots[1].x + 0.1 + (k % 6) * 0.11
				var cz := spots[1].z + 0.12 + (k / 6) * 0.17
				var y := top + 0.06 + (0.04 if k / 6 == 1 else 0.0)
				P.limb(b, Vector3(cx, y, cz - 0.07), Vector3(cx + 0.01, y, cz + 0.07), Vector2(0.025, 0.025), Vector2(0.022, 0.022), Color(0.2, 0.45, 0.15) if k % 4 else Color(0.28, 0.52, 0.2), true)
			tag(b, spots[1] + Vector3(0.4, 0.3, -0.02), "Огурцы 15")
			crate(b, spots[2], cs)
			heap(b, spots[2] + Vector3(0.03, 0.02, 0.03), cs - Vector3(0.06, 0, 0.06), 0.05, [Color(0.65, 0.5, 0.32), Color(0.6, 0.45, 0.3), Color(0.72, 0.56, 0.36)], 0.75)
			tag(b, spots[2] + Vector3(0.4, 0.3, -0.02), "Картошка 6")
			# Капуста и морковка
			for k in 4:
				P.ball(b, spots[3] + Vector3(0.18 + (k % 2) * 0.4, 0.11, 0.17 + (k / 2) * 0.3), Vector3(0.12, 0.11, 0.12), Color(0.55, 0.75, 0.4) if k % 2 else Color(0.6, 0.8, 0.45), 3, 6)
			for k in 6:
				var c := spots[3] + Vector3(0.25 + k * 0.06, 0.03, -0.0)
				P.limb(b, c, c + Vector3(0.0, 0.0, -0.16), Vector2(0.02, 0.02), Vector2(0.004, 0.004), Color(0.95, 0.5, 0.1), true)
			tag(b, spots[3] + Vector3(0.4, 0.33, -0.02), "Капуста 8")
			# Мешки с картошкой и сетка лука у прилавка
			sack(b, Vector3(x + 0.4, 0, row - 0.45), 0.55)
			sack(b, Vector3(x + 0.85, 0, row - 0.35), 0.5)
			P.ball(b, Vector3(x + 4.6, 0.2, row - 0.35), Vector3(0.17, 0.2, 0.17), Color(0.85, 0.55, 0.25), 3, 6)
		"fruit":
			crate(b, spots[0], cs)
			heap(b, spots[0] + Vector3(0.03, 0.02, 0.03), cs - Vector3(0.06, 0, 0.06), 0.045, [Color(0.85, 0.15, 0.1), Color(0.7, 0.75, 0.2), Color(0.9, 0.3, 0.15)])
			tag(b, spots[0] + Vector3(0.4, 0.3, -0.02), "Яблоки 10")
			crate(b, spots[1], cs)
			heap(b, spots[1] + Vector3(0.03, 0.02, 0.03), cs - Vector3(0.06, 0, 0.06), 0.045, [Color(0.9, 0.82, 0.3), Color(0.85, 0.78, 0.25)], 1.2)
			tag(b, spots[1] + Vector3(0.4, 0.3, -0.02), "Груши 15")
			# Виноград гроздьями
			crate(b, spots[2], cs)
			for k in 4:
				var gc := spots[2] + Vector3(0.18 + (k % 2) * 0.4, 0.1, 0.17 + (k / 2) * 0.28)
				for j in 9:
					var o := Vector3((j % 3 - 1) * 0.035, -(j / 3) * 0.03, ((j * 5) % 3 - 1) * 0.03 * (1.0 - j / 9.0))
					P.ball(b, gc + o, Vector3(0.022, 0.024, 0.022), Color(0.42, 0.18, 0.45) if k % 2 else Color(0.6, 0.75, 0.3), 2, 5)
			tag(b, spots[2] + Vector3(0.4, 0.3, -0.02), "Виноград 30")
			# Разрезанный арбуз на прилавке
			P.ball(b, spots[3] + Vector3(0.4, 0.0, 0.3), Vector3(0.2, 0.17, 0.2), Color(0.2, 0.45, 0.2), 4, 8, true)
			P.limb(b, spots[3] + Vector3(0.4, 0.0, 0.3), spots[3] + Vector3(0.4, 0.01, 0.3), Vector2(0.19, 0.19), Vector2(0.18, 0.18), Color(0.9, 0.2, 0.25), true)
			tag(b, spots[3] + Vector3(0.4, 0.33, -0.02), "Арбуз 3 / кг")
			# Гора арбузов на земле перед прилавком
			for k in 9:
				var wx := x + 1.2 + (k % 5) * 0.48 + (k / 5) * 0.24
				var wy := 0.17 + (k / 5) * 0.27
				P.ball(b, Vector3(wx, wy, row - 0.55), Vector3(0.22, 0.18, 0.18), Color(0.2, 0.42, 0.18) if k % 2 else Color(0.28, 0.5, 0.22), 3, 7)
		"dairy":
			# Трёхлитровые банки молока
			for k in 5:
				jar(b, Vector3(x + 0.35 + k * 0.24, top, row + 0.35), 0.3, 0.09, Color(0.97, 0.96, 0.92), Color(0.3, 0.45, 0.8))
			tag(b, Vector3(x + 0.8, top + 0.45, row + 0.25), "Молоко 10 / л")
			# Сметана в банках поменьше
			for k in 4:
				jar(b, Vector3(x + 1.75 + k * 0.17, top, row + 0.45), 0.16, 0.06, Color(1.0, 0.98, 0.9), Color(0.85, 0.85, 0.85))
			tag(b, Vector3(x + 2.0, top + 0.3, row + 0.3), "Сметана 20")
			# Лотки яиц
			for k in 2:
				var e := Vector3(x + 2.6 + k * 0.5, top, row + 0.3)
				b.box(e, e + Vector3(0.42, 0.04, 0.32), Color(0.62, 0.6, 0.55))
				for j in 20:
					P.ball(b, e + Vector3(0.05 + (j % 5) * 0.08, 0.06, 0.05 + (j / 5) * 0.075), Vector3(0.024, 0.032, 0.024), Color(0.96, 0.93, 0.85) if (j + k) % 3 else Color(0.8, 0.6, 0.42), 2, 5)
			tag(b, Vector3(x + 3.1, top + 0.25, row + 0.25), "Яйца 25 / дес.")
			# Головка сыра и бидон на земле
			P.limb(b, Vector3(x + 4.4, top, row + 0.5), Vector3(x + 4.4, top + 0.12, row + 0.5), Vector2(0.17, 0.17), Vector2(0.17, 0.17), Color(0.95, 0.8, 0.35), true)
			P.limb(b, Vector3(x + 4.5, 0, row - 0.4), Vector3(x + 4.5, 0.45, row - 0.4), Vector2(0.16, 0.16), Vector2(0.15, 0.15), Color(0.78, 0.8, 0.83), true)
			P.limb(b, Vector3(x + 4.5, 0.45, row - 0.4), Vector3(x + 4.5, 0.58, row - 0.4), Vector2(0.15, 0.15), Vector2(0.08, 0.08), Color(0.78, 0.8, 0.83), true)
		"meat":
			# Разделочная доска с салом: шкурка, белый пласт, мясная прослойка
			b.box(Vector3(x + 0.25, top, row + 0.2), Vector3(x + 2.2, top + 0.04, row + 0.95), Color(0.75, 0.62, 0.42))
			for k in 4:
				var s := Vector3(x + 0.35 + k * 0.45, top + 0.04, row + 0.3)
				b.box(s, s + Vector3(0.38, 0.06, 0.5), Color(0.97, 0.94, 0.88))
				b.box(s + Vector3(0, 0.06, 0), s + Vector3(0.38, 0.075, 0.5), Color(0.85, 0.45, 0.42))
				b.box(s + Vector3(0, 0.075, 0), s + Vector3(0.38, 0.1, 0.5), Color(0.96, 0.92, 0.86))
				b.box(s + Vector3(0, 0.1, 0), s + Vector3(0.38, 0.11, 0.5), Color(0.72, 0.5, 0.3))
			tag(b, Vector3(x + 1.2, top + 0.35, row + 0.2), "Сало 60 / кг")
			# Нож и топорик
			b.box(Vector3(x + 2.0, top + 0.04, row + 0.35), Vector3(x + 2.03, top + 0.06, row + 0.7), Color(0.85, 0.86, 0.9))
			b.box(Vector3(x + 2.0, top + 0.04, row + 0.7), Vector3(x + 2.04, top + 0.07, row + 0.85), Color(0.3, 0.2, 0.12))
			# Курицы
			for k in 3:
				var c := Vector3(x + 2.6 + k * 0.45, top + 0.09, row + 0.55)
				# Тушка на спинке, ножки кверху
				P.ball(b, c, Vector3(0.15, 0.09, 0.11), Color(0.98, 0.88, 0.7), 4, 8)
				P.ball(b, c + Vector3(-0.1, 0.03, 0), Vector3(0.07, 0.06, 0.08), Color(0.97, 0.86, 0.68), 3, 6)
				for s in [-1.0, 1.0]:
					P.limb(b, c + Vector3(0.06, 0.05, s * 0.05), c + Vector3(0.13, 0.15, s * 0.06), Vector2(0.035, 0.035), Vector2(0.02, 0.02), Color(0.98, 0.85, 0.65))
					P.ball(b, c + Vector3(0.135, 0.16, s * 0.06), Vector3(0.016, 0.016, 0.016), Color(0.96, 0.9, 0.8), 2, 5)
			tag(b, Vector3(x + 3.0, top + 0.35, row + 0.25), "Курица 70")
			# Колбасы и сосиски на перекладине под навесом
			b.box(Vector3(x + 0.3, 2.15, row + 0.9), Vector3(x + 4.7, 2.19, row + 0.94), Color(0.4, 0.4, 0.42))
			for k in 11:
				var hx := x + 0.5 + k * 0.38
				var long := 0.35 + (k % 3) * 0.12
				P.limb(b, Vector3(hx, 2.15, row + 0.92), Vector3(hx, 2.12, row + 0.92), Vector2(0.004, 0.004), Vector2(0.004, 0.004), Color(0.9, 0.9, 0.85))
				P.limb(b, Vector3(hx, 2.12, row + 0.92), Vector3(hx + 0.02, 2.12 - long, row + 0.92), Vector2(0.035, 0.035), Vector2(0.032, 0.032),
					[Color(0.55, 0.2, 0.15), Color(0.85, 0.5, 0.45), Color(0.4, 0.18, 0.12)][k % 3], true)
		_:
			# Мёд: банки янтарные, с тряпочкой на крышке
			for k in 6:
				jar(b, Vector3(x + 0.35 + (k % 3) * 0.24, top, row + 0.3 + (k / 3) * 0.3), 0.2, 0.075, Color(0.9, 0.55, 0.1) if k % 2 else Color(0.8, 0.45, 0.08), Color(0.85, 0.3, 0.25) if k % 3 else Color(0.95, 0.95, 0.9))
			tag(b, Vector3(x + 0.6, top + 0.4, row + 0.2), "Мёд 50")
			# Рамка с сотами
			b.box(Vector3(x + 1.2, top, row + 0.6), Vector3(x + 1.7, top + 0.32, row + 0.64), Color(0.6, 0.45, 0.25))
			b.box(Vector3(x + 1.23, top + 0.03, row + 0.595), Vector3(x + 1.67, top + 0.29, row + 0.6), Color(0.95, 0.72, 0.2))
			for k in 12:
				var hx := x + 1.27 + (k % 4) * 0.11
				var hy := top + 0.06 + (k / 4) * 0.08
				b.box(Vector3(hx, hy, row + 0.592), Vector3(hx + 0.05, hy + 0.045, row + 0.595), Color(0.85, 0.55, 0.1))
			# Семечки: мешок с горкой и гранёный стакан
			sack(b, Vector3(x + 2.4, top, row + 0.6), 0.25, Color(0.85, 0.82, 0.75))
			P.ball(b, Vector3(x + 2.4, top + 0.27, row + 0.6), Vector3(0.14, 0.05, 0.12), Color(0.15, 0.13, 0.12), 2, 7, true)
			P.limb(b, Vector3(x + 2.75, top, row + 0.4), Vector3(x + 2.75, top + 0.1, row + 0.4), Vector2(0.035, 0.035), Vector2(0.042, 0.042), Color(0.75, 0.85, 0.85), true)
			tag(b, Vector3(x + 2.5, top + 0.5, row + 0.3), "Семечки 5 / стакан")
			# Тарань гирляндой на верёвке
			b.box(Vector3(x + 3.1, 2.15, row + 0.9), Vector3(x + 4.8, 2.17, row + 0.92), Color(0.75, 0.7, 0.55))
			for k in 8:
				var fx := x + 3.2 + k * 0.2
				P.limb(b, Vector3(fx, 2.14, row + 0.91), Vector3(fx, 1.86, row + 0.91), Vector2(0.012, 0.05), Vector2(0.006, 0.03), Color(0.7, 0.6, 0.45) if k % 2 else Color(0.62, 0.55, 0.42), true)
			tag(b, Vector3(x + 3.9, top + 0.3, row + 0.25), "Тарань 30")
	scales(b, Vector3(x + 4.45, top, row + 0.8) if kind != "dairy" else Vector3(x + 3.85, top, row + 0.95))
	# Табуретка продавца и ящики с запасом за прилавком
	b.box(Vector3(x + 1.0, 0, row + 2.3), Vector3(x + 1.35, 0.45, row + 2.65), Color(0.55, 0.42, 0.28))
	crate(b, Vector3(x + 3.6, 0, row + 2.0), Vector3(0.6, 0.3, 0.45), Color(0.8, 0.3, 0.25))
	crate(b, Vector3(x + 3.6, 0.3, row + 2.0), Vector3(0.6, 0.3, 0.45), Color(0.25, 0.4, 0.75))


## Квасная бочка: жёлтая цистерна на колёсах, кран, столик с кружками.
func kvass_barrel(b: MeshBuilder, at: Vector3) -> void:
	var yellow := Color(0.95, 0.75, 0.15)
	P.limb(b, at + Vector3(-1.0, 0.85, 0), at + Vector3(1.0, 0.85, 0), Vector2(0.55, 0.55), Vector2(0.55, 0.55), yellow, true)
	for s in [-1.0, 1.0]:
		P.ball(b, at + Vector3(s * 1.0, 0.85, 0), Vector3(0.12, 0.55, 0.55), yellow.darkened(0.05), 4, 10)
		P.limb(b, at + Vector3(0.3, 0.3, s * 0.5), at + Vector3(0.3, 0.3, s * 0.62), Vector2(0.3, 0.3), Vector2(0.3, 0.3), Color(0.1, 0.1, 0.1), true)
	b.box(at + Vector3(-1.6, 0.25, -0.05), at + Vector3(-0.9, 0.3, 0.05), Color(0.3, 0.3, 0.3))
	b.box(at + Vector3(-1.65, 0.0, -0.05), at + Vector3(-1.55, 0.3, 0.05), Color(0.3, 0.3, 0.3))
	b.add_collider(at + Vector3(-1.1, 0, -0.6), at + Vector3(1.1, 1.4, 0.6))
	# Надпись «КВАС» — красная полоса
	b.box(at + Vector3(-0.5, 0.95, -0.56), at + Vector3(0.5, 1.2, -0.54), Color(0.85, 0.15, 0.1))
	var l := Label3D.new()
	l.text = "КВАС"
	l.font_size = 48
	l.pixel_size = 0.006
	l.outline_size = 0
	l.modulate = Color(1, 1, 0.9)
	l.position = at + Vector3(0, 1.075, -0.565)
	l.rotation.y = PI
	l.visibility_range_end = 120.0
	add_child(l)
	# Кран и столик с кружками
	P.limb(b, at + Vector3(0.0, 0.5, -0.5), at + Vector3(0.0, 0.5, -0.68), Vector2(0.02, 0.02), Vector2(0.02, 0.02), Color(0.7, 0.7, 0.72), true)
	var t := at + Vector3(0.8, 0, -1.0)
	b.box(t + Vector3(-0.35, 0.72, -0.3), t + Vector3(0.35, 0.76, 0.3), Color(0.85, 0.85, 0.82))
	for s in [-1.0, 1.0]:
		b.box(t + Vector3(s * 0.3 - 0.02, 0, -0.02), t + Vector3(s * 0.3 + 0.02, 0.72, 0.02), Color(0.4, 0.4, 0.42))
	for k in 4:
		var m := t + Vector3(-0.2 + k * 0.13, 0.76, (k % 2) * 0.1 - 0.05)
		P.limb(b, m, m + Vector3(0, 0.12, 0), Vector2(0.035, 0.035), Vector2(0.04, 0.04), Color(0.55, 0.32, 0.12) if k % 2 else Color(0.8, 0.9, 0.9), true)
	# Продавщица кваса в белом халате, под зонтиком
	var pb := MeshBuilder.new()
	pb.ground_shade = false
	Villagers.person_model(pb, Color(0.95, 0.95, 0.95), Color(0.95, 0.95, 0.95), false, true)
	var seller := pb.build_mesh()
	seller.position = at + Vector3(0.2, 0, -1.3)
	seller.rotation.y = 0.6
	seller.visibility_range_end = 120.0
	add_child(seller)
	sellers.append(seller)
	b.box(at + Vector3(1.6, 0, -1.6), at + Vector3(1.64, 2.3, -1.56), Color(0.4, 0.4, 0.42))
	for k in 8:
		var a0 := TAU * k / 8.0
		var a1 := TAU * (k + 1) / 8.0
		var c := at + Vector3(1.62, 2.4, -1.58)
		b.tri(c, c + Vector3(cos(a1) * 1.1, -0.35, sin(a1) * 1.1), c + Vector3(cos(a0) * 1.1, -0.35, sin(a0) * 1.1), Color(0.85, 0.15, 0.1) if k % 2 else Color(0.95, 0.95, 0.9), true)
	_kvass_pos = at + Vector3(0.3, 0, -1.1)
	_kvass = InteractZone.create("", Vector3(2.0, 2.0, 1.6))
	_kvass.name = "Kvass"
	_kvass.position = _kvass_pos
	_kvass.prompt_fn = _kvass_prompt
	_kvass.activated.connect(kvass)
	add_child(_kvass)


## Мелочь вокруг рядов: тачка с мешками, картонки, мусорный бак, лужи,
## поддоны, ковры на заборе у лавки «Для дома».
static func clutter(b: MeshBuilder, r: Rect2) -> void:
	# Лужи и пятна на асфальте
	for p in [Vector2(6, 15), Vector2(20, 17), Vector2(33, 14.5), Vector2(14, 4), Vector2(38, 27)]:
		var c := Vector3(r.position.x + p.x, 0.052, r.position.y + p.y)
		b.box(c - Vector3(0.9, 0, 0.5), c + Vector3(0.9, 0.004, 0.5), Color(0.33, 0.35, 0.37))
		b.box(c - Vector3(0.5, 0, 0.8), c + Vector3(0.5, 0.005, 0.8), Color(0.31, 0.33, 0.36))
	# Тачка с мешками у ворот
	var t := Vector3(r.end.x - 3.0, 0, r.position.y + 21.5)
	b.box(t + Vector3(-0.35, 0.35, -0.6), t + Vector3(0.35, 0.65, 0.4), Color(0.35, 0.5, 0.35))
	P.limb(b, t + Vector3(0, 0.2, -0.75), t + Vector3(0.0, 0.2, -0.65), Vector2(0.2, 0.2), Vector2(0.2, 0.2), Color(0.1, 0.1, 0.1), true)
	for s in [-1.0, 1.0]:
		b.box(t + Vector3(s * 0.3 - 0.02, 0.4, 0.4), t + Vector3(s * 0.3 + 0.02, 0.6, 1.2), Color(0.3, 0.3, 0.3))
		b.box(t + Vector3(s * 0.3 - 0.02, 0.0, 0.3), t + Vector3(s * 0.3 + 0.02, 0.4, 0.34), Color(0.3, 0.3, 0.3))
	sack(b, t + Vector3(0, 0.6, -0.15), 0.35)
	# Пустые картонные коробки стопкой и поддоны
	for k in 3:
		var c := Vector3(r.position.x + 1.5, k * 0.35, r.end.y - 2.0 + (k % 2) * 0.1)
		b.box(c, c + Vector3(0.6, 0.34, 0.45), Color(0.72, 0.58, 0.4))
		b.box(c + Vector3(0, 0.34, 0.2), c + Vector3(0.6, 0.345, 0.25), Color(0.8, 0.7, 0.5))
	for k in 2:
		var c := Vector3(r.position.x + 2.6, k * 0.14, r.end.y - 2.4)
		for j in 5:
			b.box(c + Vector3(0, 0.1, j * 0.25), c + Vector3(1.2, 0.13, j * 0.25 + 0.1), Color(0.7, 0.6, 0.42))
		for j in 3:
			b.box(c + Vector3(j * 0.55, 0, 0), c + Vector3(j * 0.55 + 0.1, 0.1, 1.1), Color(0.6, 0.5, 0.35))
	# Мусорный бак
	var bin := Vector3(r.position.x + 1.2, 0, r.position.y + 16.0)
	b.box(bin, bin + Vector3(1.2, 1.0, 0.9), Color(0.25, 0.4, 0.3), true)
	b.box(bin + Vector3(-0.02, 1.0, -0.02), bin + Vector3(1.22, 1.05, 0.92), Color(0.2, 0.32, 0.24))
	P.ball(b, bin + Vector3(0.4, 1.05, 0.4), Vector3(0.2, 0.12, 0.18), Color(0.15, 0.15, 0.15), 2, 6, true)
	# Ковры на заборе вдоль задней стороны
	var rugs := [Color(0.6, 0.12, 0.12), Color(0.2, 0.3, 0.55), Color(0.75, 0.55, 0.25)]
	for k in 3:
		var c := Vector3(r.position.x + 6.0 + k * 1.7, 0.3, r.end.y - 0.15)
		b.box(c, c + Vector3(1.5, 1.45, 0.03), rugs[k])
		b.box(c + Vector3(0.12, 0.12, -0.005), c + Vector3(1.38, 1.33, 0.0), rugs[k].lightened(0.25))
		b.box(c + Vector3(0.25, 0.25, -0.01), c + Vector3(1.25, 1.2, -0.005), rugs[k])
		b.box(c + Vector3(0.6, 0.55, -0.015), c + Vector3(0.9, 0.9, -0.01), Color(0.95, 0.85, 0.5))
