class_name FunGame
extends Node3D
## Развлечение на перемене: настольный теннис, кикер (настольный футбол) и
## армрестлинг. Всё на одной кнопке E — играется и с клавиатуры, и с телефона.
##   * «ping» (теннис, кикер): мяч летает от соперника к тебе — E, когда он
##     у твоего края. 10 подач, попал 7 — победа.
##   * «arm» (армрестлинг): жми E часто — рука соперника уходит вниз; он
##     давит сам. Дожал до 100 — победа, прижали к нулю — проигрыш.
## Победа — приз раз в день, событие «fun» (для заданий и достижений).

signal finished(won: bool)

var kind := "ping"
var title := ""
var opponent := ""
var prize := 30
## Где стол и как он стоит: мяч летает вдоль оси X стола, игрок — с +X.
var table_len := 2.6
var ball_y := 0.85

var active := false
var won_day := -1
var _t := 0.0
var _hits := 0
var _serves := 0
var _pressed := -1
var _power := 50.0
var _ball: MeshInstance3D
var _zone: InteractZone

const SERVES := 10
const NEED := 7
const PERIOD := 1.1
const WINDOW := 0.17
const ARM_TIME := 9.0


func _ready() -> void:
	if kind == "ping":
		_ball = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.045 if title.contains("теннис") else 0.06
		s.height = s.radius * 2.0
		s.radial_segments = 8
		s.rings = 4
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.95, 0.85) if title.contains("теннис") else Color(0.95, 0.95, 0.95)
		s.material = m
		_ball.mesh = s
		_ball.visible = false
		add_child(_ball)
	_zone = InteractZone.create("", Vector3(2.2, 2.2, 2.2))
	_zone.position = Vector3(table_len * 0.5 + 0.7, 0, 0)
	_zone.prompt_fn = prompt
	_zone.activated.connect(press)
	add_child(_zone)


func prompt() -> String:
	if active:
		return "E — отбить!" if kind == "ping" else "E — жми чаще!"
	var prize_on := won_day != TimeManager.day and prize > 0
	if kind == "ping":
		if prize_on:
			return "E — %s с %s: 10 подач, E — когда мяч у тебя (приз %d грн)" % [title, opponent, prize]
		return "E — %s с %s: 10 подач, E — когда мяч у тебя" % [title, opponent]
	if prize_on:
		return "E — %s с %s: жми E чаще, чем он давит (приз %d грн)" % [title, opponent, prize]
	return "E — %s с %s: жми E чаще, чем он давит" % [title, opponent]


## E: начать игру или отбить / дожать.
func press() -> void:
	if not active:
		if NeedsManager.energy < 6.0:
			GameManager.notify("Сил нет даже на %s — отдохни" % title.to_lower())
			return
		active = true
		_t = 0.0
		_hits = 0
		_serves = 0
		_pressed = -1
		_power = 50.0
		if _ball:
			_ball.visible = true
		SoundLibrary.play("click", -4.0)
		return
	if kind == "ping":
		# Попадание: мяч у твоего края (конец периода), одна попытка на подачу
		var serve := int(_t / PERIOD)
		var ph := fmod(_t, PERIOD)
		var near := PERIOD - ph < WINDOW or ph < WINDOW * 0.5
		var target := serve if PERIOD - ph < WINDOW else serve - 1
		if near and target >= 0 and target != _pressed:
			_pressed = target
			_hits += 1
			SoundLibrary.play("click", -2.0, 1.6)
	else:
		_power = minf(_power + 6.0, 100.0)
		if _power >= 100.0:
			_stop(true, "%s: дожал руку %s!" % [title, opponent])


func _process(delta: float) -> void:
	if not active:
		return
	var p := GameManager.player as Node3D
	if p == null or p.global_position.distance_to(global_position) > 6.0:
		_stop(false, "Ушёл из-за стола — игра не считается")
		return
	_t += delta
	if kind == "ping":
		var serve := int(_t / PERIOD)
		var ph := fmod(_t, PERIOD) / PERIOD
		# Мяч: от соперника (−X) к игроку (+X) дугой с отскоком посередине
		var x := lerpf(-table_len * 0.5, table_len * 0.5, ph)
		var y := ball_y + absf(sin(ph * TAU)) * 0.25
		_ball.position = Vector3(x, y, sin(serve * 1.7) * 0.25)
		GameManager.challenge_line = "%s: отбито %d из %d, подача %d/%d" % [title, _hits, SERVES, mini(serve + 1, SERVES), SERVES]
		if serve >= SERVES:
			_stop(_hits >= NEED, "%s: отбил %d из %d" % [title, _hits, SERVES])
	else:
		# Соперник давит сам, к концу — сильнее
		_power -= delta * (9.0 + _t * 0.8)
		var bar := int(_power / 10.0)
		GameManager.challenge_line = "%s: [%s%s] — жми E!" % [title, "█".repeat(clampi(bar, 0, 10)), "·".repeat(clampi(10 - bar, 0, 10))]
		if _power >= 100.0:
			_stop(true, "%s: дожал руку %s!" % [title, opponent])
		elif _power <= 0.0 or _t > ARM_TIME:
			_stop(false, "%s: %s оказался сильнее" % [title, opponent])


func _stop(win: bool, text: String) -> void:
	active = false
	GameManager.challenge_line = ""
	if _ball:
		_ball.visible = false
	NeedsManager.rest(-3.0)
	QuestManager.event("fun")
	if win:
		QuestManager.event("fun_win")
		if won_day != TimeManager.day and prize > 0:
			won_day = TimeManager.day
			GameManager.add_money(prize)
			SoundLibrary.play("cash")
			text = "%s — победа! Приз %d грн" % [text, prize]
		else:
			SoundLibrary.play("cheer", -6.0)
			text = "%s — победа!" % text
	GameManager.notify(text)
	finished.emit(win)


## Стол для игры (в builder b, координаты узла): теннисный, кикер или
## стол для армрестлинга. Строит то, что подходит kind/title.
func build_table(b: MeshBuilder, at: Vector3) -> void:
	var leg := Color(0.25, 0.25, 0.27)
	if kind == "arm":
		b.box(at + Vector3(-0.45, 0, -0.45), at + Vector3(0.45, 0.95, 0.45), Color(0.45, 0.3, 0.2), true)
		b.box(at + Vector3(-0.5, 0.95, -0.5), at + Vector3(0.5, 1.0, 0.5), Color(0.55, 0.38, 0.25))
		for s in [-1.0, 1.0]:
			b.box(at + Vector3(s * 0.38 - 0.04, 1.0, -0.04), at + Vector3(s * 0.38 + 0.04, 1.12, 0.04), Color(0.85, 0.2, 0.15))
		return
	var hl := table_len * 0.5
	var top := Color(0.15, 0.4, 0.25) if title.contains("теннис") else Color(0.2, 0.5, 0.25)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(at + Vector3(sx * (hl - 0.15) - 0.04, 0, sz * 0.6 - 0.04), at + Vector3(sx * (hl - 0.15) + 0.04, ball_y - 0.05, sz * 0.6 + 0.04), leg)
	b.box(at + Vector3(-hl, ball_y - 0.08, -0.75), at + Vector3(hl, ball_y - 0.03, 0.75), top, true)
	if title.contains("теннис"):
		b.box(at + Vector3(-0.01, ball_y - 0.03, -0.8), at + Vector3(0.01, ball_y + 0.12, 0.8), Color(0.95, 0.95, 0.95))
		b.box(at + Vector3(-hl, ball_y - 0.029, -0.01), at + Vector3(hl, ball_y - 0.027, 0.01), Color(0.95, 0.95, 0.95))
	else:
		# Кикер: борта, ворота, штанги с фигурками
		for sz in [-1.0, 1.0]:
			b.box(at + Vector3(-hl, ball_y - 0.03, sz * 0.75 - 0.05), at + Vector3(hl, ball_y + 0.15, sz * 0.75), Color(0.45, 0.3, 0.2), true)
		for k in 4:
			var x := -hl + 0.35 + k * (table_len - 0.7) / 3.0
			b.box(at + Vector3(x - 0.015, ball_y + 0.1, -0.95), at + Vector3(x + 0.015, ball_y + 0.13, 0.95), Color(0.75, 0.75, 0.78))
			for f in 3:
				b.box(at + Vector3(x - 0.03, ball_y - 0.02, -0.45 + f * 0.45 - 0.03), at + Vector3(x + 0.03, ball_y + 0.12, -0.45 + f * 0.45 + 0.03), Color(0.85, 0.15, 0.15) if k % 2 == 0 else Color(0.15, 0.3, 0.85))
