extends Node3D
## Пахота на колхозном тракторе МТЗ-80.
##
## Трактор стоит у колхозного сарая, ездить на нём можно когда угодно.
## У трактора щит «ПАХОТА»: взял наряд (7:00–19:00, раз в день) — на поле
## к востоку загорается старт. Шесть борозд туда-обратно через кольца;
## за каждой пройденной бороздой на поле остаётся тёмная полоса пашни.
## Уложился — +700 грн, быстро — премия.

const PAY := 700
const FAST_BONUS := 200
const FAST_TIME := 240.0
const TRACTOR_POS := Vector3(-22.0, 0.1, -46.5)
## Борозды: от x0 до x1 на глубине z, через одну — обратно
const ROW_X0 := 40.0
const ROW_X1 := 100.0
const ROWS := [-92.0, -87.0, -82.0, -77.0, -72.0, -67.0]

var tractor: Vehicle
var challenge: DrivingChallenge
var done_day := 0
var _strips: Node3D
var _rows_done := 0


func _ready() -> void:
	add_to_group("persist")
	tractor = Vehicle.new()
	tractor.kind = "tractor"
	tractor.name = "Tractor"
	add_child(tractor)
	tractor.global_position = TRACTOR_POS
	tractor.rotation.y = -PI / 2.0
	tractor.fuel = tractor.tank() * 0.6
	# Щит с нарядом
	var sign_pos := TRACTOR_POS + Vector3(0, 0, -3.6)
	var b := MeshBuilder.new()
	for x in [-0.8, 0.7]:
		b.box(sign_pos + Vector3(x, 0, -0.05), sign_pos + Vector3(x + 0.1, 1.9, 0.05), Color(0.35, 0.3, 0.25))
	b.box(sign_pos + Vector3(-0.9, 1.2, -0.04), sign_pos + Vector3(0.9, 1.95, 0.04), Color(0.2, 0.4, 0.25))
	add_child(b.build_mesh())
	for side in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = "ПАХОТА\n+%d грн" % PAY
		l.font_size = 60
		l.pixel_size = 0.005
		l.outline_size = 8
		l.modulate = Color(0.95, 0.95, 0.85)
		l.position = sign_pos + Vector3(0, 1.58, 0.06 * side)
		l.rotation.y = 0.0 if side > 0.0 else PI
		add_child(l)
	var zone := InteractZone.create("", Vector3(2.4, 2.2, 2.0))
	zone.position = sign_pos + Vector3(0, 0, 0.9)
	zone.prompt_fn = _prompt
	zone.activated.connect(_take_order)
	add_child(zone)
	challenge = DrivingChallenge.new()
	challenge.name = "Plough"
	challenge.title = "Пахота"
	challenge.only_kind = "tractor"
	challenge.start_pos = Vector3(ROW_X0 - 6.0, 0, ROWS[0])
	challenge.point_radius = 4.0
	challenge.time_limit = 600.0
	var pts: Array[Vector3] = []
	for i in ROWS.size():
		var z: float = ROWS[i]
		var a := ROW_X0 if i % 2 == 0 else ROW_X1
		var e := ROW_X1 if i % 2 == 0 else ROW_X0
		pts.append(Vector3(a, 0, z))
		pts.append(Vector3(lerpf(a, e, 0.5), 0, z))
		pts.append(Vector3(e, 0, z))
	challenge.points = pts
	for i in ROWS.size():
		challenge.stage_names[i * 3] = "борозда %d из %d" % [i + 1, ROWS.size()]
	challenge.finished.connect(_result)
	add_child(challenge)
	_strips = Node3D.new()
	add_child(_strips)


func _prompt() -> String:
	var h := TimeManager.hour()
	if challenge.active():
		return ""
	if done_day == TimeManager.day:
		return "Пахота: на сегодня наряд выполнен. Завтра приходи"
	if h < 7.0 or h > 19.0:
		return "Пахота: наряды с 7:00 до 19:00"
	return "E — взять наряд на пахоту: 6 борозд на поле к востоку, +%d грн" % PAY


func _take_order() -> void:
	var h := TimeManager.hour()
	if challenge.active() or done_day == TimeManager.day or h < 7.0 or h > 19.0:
		return
	_clear_strips()
	_rows_done = 0
	challenge.arm()
	SoundLibrary.play("click")
	GameManager.notify("Бригадир: «Садись на МТЗ — и на поле за дорогой. Борозды ровно, через кольца!»")


func _process(_delta: float) -> void:
	# Пройдена борозда (три кольца) — на поле остаётся пашня
	if challenge.state == DrivingChallenge.State.RUNNING:
		var rows := challenge.idx / 3
		while _rows_done < rows:
			_add_strip(_rows_done)
			_rows_done += 1


func _add_strip(i: int) -> void:
	var z: float = ROWS[i]
	var b := MeshBuilder.new()
	b.ground_shade = false
	b.box(Vector3(ROW_X0, 0.07, z - 1.1), Vector3(ROW_X1, 0.1, z + 1.1), Color(0.24, 0.17, 0.11))
	var x := ROW_X0
	while x < ROW_X1:
		b.box(Vector3(x, 0.1, z - 1.0), Vector3(x + 1.5, 0.16, z - 0.7), Color(0.3, 0.22, 0.14))
		b.box(Vector3(x, 0.1, z + 0.2), Vector3(x + 1.5, 0.16, z + 0.5), Color(0.3, 0.22, 0.14))
		x += 1.6
	_strips.add_child(b.build_mesh())
	SoundLibrary.play("click", -8.0, 0.7)


func _clear_strips() -> void:
	for c in _strips.get_children():
		c.queue_free()


func _result(r: Dictionary) -> void:
	if not r.ok:
		GameManager.notify("Пахота сорвана: %s. Наряд можно взять снова" % r.why)
		return
	if _rows_done < ROWS.size():
		_add_strip(ROWS.size() - 1)
	done_day = TimeManager.day
	var pay := PAY
	var extra := ""
	if r.time < FAST_TIME:
		pay += FAST_BONUS
		extra = ", премия за скорость +%d" % FAST_BONUS
	GameManager.add_money(pay)
	SoundLibrary.play("cash")
	QuestManager.event("plough")
	NeedsManager.rest(-15.0)
	GameManager.notify("Поле вспахано за %d:%02d! +%d грн%s" % [int(r.time) / 60, int(r.time) % 60, pay, extra])


func save_state() -> Dictionary:
	return {"done": done_day}


func load_state(d: Dictionary) -> void:
	done_day = int(d.get("done", 0))
