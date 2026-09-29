extends Node3D
## Пост ГАИ на трассе у Каменки, напротив АЗС — там, где знаки «60».
## Советский «стакан»: стеклянная будка на бетонной ноге, рядом милицейские
## «Жигули» с мигалкой и инспектор с жезлом.
##
## Быстрее 60 км/ч — свисток и штраф 200 грн (раз в полторы минуты).
## Иногда инспектор машет жезлом — проверка документов: остановись у поста.
## Без прав — штраф 300, машина разбита — 100. Уехал — 500.
## Нечем платить — штраф в долг, гасить в отделении милиции в городе.

const ZONE_X0 := -125.0
const ZONE_X1 := -75.0
const LIMIT := 60.0
const FINE := 200
const BOOTH := Vector3(-100.0, 0, -9.2)
const FINE_NO_LICENSE := 300
const FINE_BROKEN := 100
const FINE_ESCAPE := 500
## Как часто останавливают на проверку (доля проездов, раз в день)
var check_chance := 0.35

## Проверка документов: инспектор ждёт, пока остановишься
var stop_wanted := false
var _stop_t := 0.0
var _check_day := -1
var _blink: Array = []
var _t := 0.0
var _wand: Node3D

var _cool := 0.0
var _cop: Node3D
var _fines := 0


func _ready() -> void:
	var b := MeshBuilder.new()
	# «Стакан»: бетонная нога, стеклянная будка наверху, лесенка
	var c := BOOTH
	var concrete := Color(0.78, 0.78, 0.75)
	b.box(c + Vector3(-1.4, 0, -1.4), c + Vector3(1.4, 0.3, 1.4), concrete.darkened(0.1), true)
	b.box(c + Vector3(-0.5, 0.3, -0.5), c + Vector3(0.5, 2.6, 0.5), concrete, true)
	b.box(c + Vector3(-1.5, 2.6, -1.5), c + Vector3(1.5, 2.85, 1.5), concrete.darkened(0.05))
	# Стёкла по кругу в белых рамах, синяя полоса снизу
	b.box(c + Vector3(-1.4, 2.85, -1.4), c + Vector3(1.4, 3.35, 1.4), Color(0.9, 0.9, 0.88))
	b.box(c + Vector3(-1.41, 3.1, -1.41), c + Vector3(1.41, 3.3, 1.41), Color(0.15, 0.3, 0.65))
	b.box(c + Vector3(-1.35, 3.35, -1.35), c + Vector3(1.35, 4.6, 1.35), Color(0.35, 0.47, 0.55))
	for x in [-1.37, -0.45, 0.45, 1.33]:
		for z in [-1.4, 1.36]:
			b.box(c + Vector3(x, 3.35, z), c + Vector3(x + 0.05, 4.6, z + 0.05), Color(0.92, 0.92, 0.9))
			b.box(c + Vector3(z, 3.35, x), c + Vector3(z + 0.05, 4.6, x + 0.05), Color(0.92, 0.92, 0.9))
	b.box(c + Vector3(-1.7, 4.6, -1.7), c + Vector3(1.7, 4.8, 1.7), Color(0.3, 0.3, 0.32))
	b.box(c + Vector3(-0.2, 4.8, -0.2), c + Vector3(0.2, 5.1, 0.2), Color(0.8, 0.1, 0.1))
	# Лесенка сзади
	for i in 8:
		b.box(c + Vector3(-0.4, 0.3 + i * 0.3, -1.5 - (7 - i) * 0.25), c + Vector3(0.4, 0.38 + i * 0.3, -1.25 - (7 - i) * 0.25), Color(0.4, 0.4, 0.42))
	# Бордюр площадки и полосатый отбойник вдоль обочины
	b.box(c + Vector3(-6.0, 0, 3.0), c + Vector3(8.0, 0.12, 3.25), Color(0.85, 0.85, 0.82))
	for i in 7:
		var bx := c + Vector3(-5.0 + i * 2.0, 0, 3.12)
		b.box(bx + Vector3(-0.08, 0, -0.08), bx + Vector3(0.08, 0.8, 0.08), Color(0.95, 0.95, 0.95) if i % 2 == 0 else Color(0.85, 0.15, 0.1))
	add_child(b.build_mesh())
	add_child(b.build_body())
	for side in [[Vector3(0, 3.22, 1.43), 0.0], [Vector3(1.43, 3.22, 0), PI / 2.0], [Vector3(-1.43, 3.22, 0), -PI / 2.0]]:
		var sign := Label3D.new()
		sign.text = "ГАИ"
		sign.font_size = 64
		sign.pixel_size = 0.006
		sign.outline_size = 0
		sign.modulate = Color(1, 1, 1)
		sign.position = c + side[0]
		sign.rotation.y = side[1]
		add_child(sign)
	_blink = Police.car(self, c + Vector3(6.5, 0.05, 0.8), -PI / 2.0)
	# Инспектор у обочины, лицом к дороге, с полосатым жезлом
	var pb := MeshBuilder.new()
	pb.ground_shade = false
	preload("res://scripts/world/villagers.gd").person_model(pb, Color(0.3, 0.36, 0.3), Color(0.2, 0.25, 0.4), false, false)
	_cop = Node3D.new()
	_cop.add_child(pb.build_mesh())
	# Жезл — отдельно: машет, когда останавливает
	_wand = Node3D.new()
	_wand.position = Vector3(0.3, 1.0, 0)
	var wb := MeshBuilder.new()
	wb.ground_shade = false
	for i in 5:
		wb.box(Vector3(-0.025, i * 0.1, -0.025), Vector3(0.025, (i + 1) * 0.1, 0.025), Color(0.95, 0.95, 0.95) if i % 2 == 0 else Color(0.1, 0.1, 0.1))
	_wand.add_child(wb.build_mesh())
	_cop.add_child(_wand)
	_cop.position = c + Vector3(1.8, 0, 2.2)
	_cop.rotation.y = PI
	add_child(_cop)


func _process(delta: float) -> void:
	_t += delta
	Police.blink(_blink, _t)
	_cool = maxf(_cool - delta, 0.0)
	# Жезл: поднят и машет, когда просят остановиться
	_wand.rotation.z = lerpf(_wand.rotation.z, (1.9 + sin(_t * 6.0) * 0.4) if stop_wanted else 0.2, minf(delta * 6.0, 1.0))
	var v := GameManager.vehicle as Vehicle
	if stop_wanted:
		_check_stop(v, delta)
	if v == null or v.driver == null:
		return
	var p := v.global_position
	# Инспектор провожает взглядом
	if absf(p.x - _cop.position.x) < 60.0:
		var to := p - _cop.position
		_cop.rotation.y = lerp_angle(_cop.rotation.y, atan2(-to.x, -to.z), delta * 3.0)
	if _cool > 0.0 or p.x < ZONE_X0 or p.x > ZONE_X1 or absf(p.z) > 5.0:
		return
	var kmh := v.speed_kmh()
	if kmh <= LIMIT:
		# Проверка документов: раз в день, не всем подряд
		if not stop_wanted and _check_day != TimeManager.day and kmh > 10.0 and absf(p.x - BOOTH.x) < 20.0:
			_check_day = TimeManager.day
			if randf() < check_chance:
				request_stop()
		return
	# Спор с Колькой — инспектор закрывает глаза (Колька — его племянник)
	var race = get_parent().get("_race")
	if race and race.active():
		return
	_cool = 90.0
	SoundLibrary.play_at("whistle", _cop.position + Vector3(0, 1.6, 0), 4.0)
	GameManager.vibrate(120)
	_fine(FINE, "Инспектор ГАИ: «%d км/ч при ограничении 60! Штраф %d грн»" % [int(kmh), FINE])


## Инспектор машет жезлом: остановись у поста.
func request_stop() -> void:
	stop_wanted = true
	_stop_t = 0.0
	SoundLibrary.play_at("whistle", _cop.position + Vector3(0, 1.6, 0), 4.0)
	GameManager.vibrate(120)
	GameManager.notify("Инспектор машет жезлом: «Водитель, остановитесь у поста! Проверка документов»")


func _check_stop(v: Vehicle, delta: float) -> void:
	_stop_t += delta
	var who := (v if v else GameManager.player) as Node3D
	if who == null:
		return
	var d := Vector2(who.global_position.x - _cop.position.x, who.global_position.z - _cop.position.z).length()
	# Остановился рядом (или вышел к инспектору пешком) — проверка
	if d < 16.0 and (v == null or v.speed_kmh() < 3.0):
		stop_wanted = false
		_inspect(v)
		return
	# Уехал — штраф побольше
	if d > 60.0 or _stop_t > 60.0:
		stop_wanted = false
		_fine(FINE_ESCAPE, "Уехал от инспектора ГАИ! Номер записали — штраф %d грн" % FINE_ESCAPE)


func _inspect(v: Vehicle) -> void:
	if not Progress.license:
		_fine(FINE_NO_LICENSE, "Инспектор: «Права? Нету? Штраф %d грн — и в автошколу!»" % FINE_NO_LICENSE)
		return
	if v and v.condition < 30.0:
		_fine(FINE_BROKEN, "Инспектор: «Машина еле живая — штраф %d грн, почини на СТО»" % FINE_BROKEN)
		return
	QuestManager.event("gai_check")
	GameManager.notify("Инспектор: «Документы в порядке. Счастливого пути!»")


## Штраф: с денег, а если их нет — в долг (гасить в отделении милиции).
func _fine(sum: int, text: String) -> void:
	QuestManager.event("fined")
	if GameManager.money >= sum and GameManager.spend(sum):
		_fines += 1
		GameManager.notify(text)
		return
	var police := get_parent().get_node_or_null("Police") as Police
	if police:
		police.add_debt(sum)
	GameManager.notify(text + ". Денег нет — долг, оплатить в отделении милиции в городе")
